import AppKit
import FontPreviewerCore
import FontPreviewerMacKit
import SwiftUI
import UniformTypeIdentifiers

struct WorkspaceView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.undoManager) private var undoManager
    @State private var dropTargeted = false

    var body: some View {
        NavigationSplitView {
            FontSidebar()
                .navigationSplitViewColumnWidth(min: 230, ideal: 285, max: 380)
        } content: {
            WorkspaceCanvas()
                .navigationSplitViewColumnWidth(min: 640, ideal: 900)
        } detail: {
            FontInspector()
                .navigationSplitViewColumnWidth(min: 280, ideal: 330, max: 420)
        }
        .navigationTitle(model.windowTitle)
        .toolbar { toolbar }
        .onAppear { model.undoManager = undoManager }
        .onDrop(of: [.fileURL], isTargeted: $dropTargeted, perform: importDroppedItems)
        .overlay {
            if dropTargeted { DropOverlay() }
            if model.isBusy { OperationOverlay() }
        }
        .alert(item: $model.activeAlert) { item in
            Alert(
                title: Text(item.title),
                message: Text(item.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .sheet(isPresented: $model.isShowingExportSheet) { ExportSheet() }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button(action: model.presentFontImportPanel) {
                Label("Import fonts", systemImage: "plus")
            }
            .help("Import font files or folders (⌘I)")
        }
        ToolbarItem(placement: .principal) {
            Picker("Preview mode", selection: Binding(
                get: { model.study.layout },
                set: model.setLayout
            )) {
                ForEach(PreviewMode.allCases) { mode in Text(mode.label).tag(mode) }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 620)
            .accessibilityLabel("Preview mode")
        }
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                model.isShowingExportSheet = true
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .disabled(model.study.records.isEmpty || model.isBusy)
            .help("Export review boards and handoff files (⇧⌘E)")
        }
    }

    private func importDroppedItems(_ providers: [NSItemProvider]) -> Bool {
        let matching = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        guard !matching.isEmpty else { return false }
        let lock = NSLock()
        var urls: [URL] = []
        var remaining = matching.count
        for provider in matching {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let url: URL?
                if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else if let value = item as? URL {
                    url = value
                } else if let value = item as? NSURL {
                    url = value as URL
                } else {
                    url = nil
                }
                lock.lock()
                if let url { urls.append(url) }
                remaining -= 1
                let complete = remaining == 0
                let result = urls
                lock.unlock()
                if complete {
                    Task { @MainActor in model.importSelections(result) }
                }
            }
        }
        return true
    }
}

private struct FontSidebar: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Search · tag:warm · role:body", text: Binding(
                    get: { model.filter.query },
                    set: model.setFilterQuery
                ))
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Search fonts")

                HStack(spacing: 6) {
                    ForEach(ReviewStatus.allCases) { status in
                        FilterChip(
                            label: "\(status.label) \(model.counts[status, default: 0])",
                            isOn: model.filter.statuses.contains(status),
                            action: { model.toggleStatusFilter(status) }
                        )
                    }
                }

                HStack {
                    Menu {
                        ForEach(FontRole.allCases) { role in
                            Button {
                                model.toggleRoleFilter(role)
                            } label: {
                                if model.filter.roles.contains(role) {
                                    Label(role.label, systemImage: "checkmark")
                                } else {
                                    Text(role.label)
                                }
                            }
                        }
                    } label: {
                        Label("Roles", systemImage: "tag")
                    }
                    .menuStyle(.borderlessButton)

                    Toggle("Variable", isOn: Binding(
                        get: { model.filter.variableOnly },
                        set: model.setVariableOnly
                    ))
                    .toggleStyle(.checkbox)
                    .controlSize(.small)

                    Toggle("Missing", isOn: Binding(
                        get: { model.filter.missingSourceOnly },
                        set: model.setMissingOnly
                    ))
                    .toggleStyle(.checkbox)
                    .controlSize(.small)
                }

                HStack {
                    Picker("Sort", selection: Binding(
                        get: { model.filter.sort },
                        set: model.setFilterSort
                    )) {
                        ForEach(StudySort.allCases) { sort in Text(sort.label).tag(sort) }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 150)
                    Spacer()
                    Button("Reset") { model.resetFilters() }
                        .buttonStyle(.link)
                        .controlSize(.small)
                }
            }
            .padding(14)

            Divider()

            if model.study.records.isEmpty {
                SidebarEmptyState()
            } else if model.filteredRecords.isEmpty {
                UnavailableState(
                    title: "No matching fonts",
                    systemImage: "line.3.horizontal.decrease.circle",
                    message: "Reset the filters or try a broader search."
                )
            } else {
                List(selection: $model.selectedRecordID) {
                    ForEach(model.filteredRecords) { record in
                        FontRow(record: record)
                            .tag(record.id)
                    }
                }
                .listStyle(.sidebar)
            }

            Divider()
            HStack {
                Text("\(model.filteredRecords.count) shown · \(model.study.records.count) total")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: model.presentFontImportPanel) {
                    Image(systemName: "plus.circle.fill")
                }
                .buttonStyle(.plain)
                .help("Import fonts")
            }
            .padding(12)
        }
    }
}

private struct FontRow: View {
    @EnvironmentObject private var model: AppModel
    let record: FontFaceRecord

    var body: some View {
        HStack(spacing: 10) {
            StatusDot(status: record.status)
            VStack(alignment: .leading, spacing: 3) {
                Text(record.familyName.isEmpty ? record.fileName : record.familyName)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(record.styleName.isEmpty ? "Regular" : record.styleName)
                    if record.isVariable { Text("VAR") }
                    if record.role != .unassigned { Text(record.role.label.uppercased()) }
                }
                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            Spacer(minLength: 4)
            if !model.sourceExists(for: record) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .help("Source font missing")
            }
            if model.study.comparisonIDs.contains(record.id) {
                Image(systemName: "square.grid.2x2.fill")
                    .foregroundStyle(.primary)
                    .help("In comparison")
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(record.displayName), \(record.status.label), \(record.role.label)")
    }
}

private struct SidebarEmptyState: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "textformat")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.secondary)
            Text("No fonts yet")
                .font(.headline)
            Text("Drop font files or a folder anywhere in the window. Nothing leaves this Mac.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 220)
            Button("Import Fonts or Folder…", action: model.presentFontImportPanel)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

private struct WorkspaceCanvas: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            SpecimenControls()
            Divider()
            Group {
                if model.study.records.isEmpty {
                    CanvasEmptyState()
                } else {
                    scene
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: NSColor(calibratedWhite: 0.025, alpha: 1)))
        }
    }

    @ViewBuilder
    private var scene: some View {
        switch model.study.layout {
        case .review:
            ReviewGrid()
        case .focus:
            SingleScene(record: model.selectedRecord)
        case .compare:
            BoardScene(records: model.comparisonRecords)
        case .waterfall, .metrics, .glyphs:
            SingleScene(record: model.selectedRecord)
        case .pairing:
            BoardScene(records: model.study.records)
        }
    }
}

private struct SpecimenControls: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                TextField("Study title", text: Binding(
                    get: { model.study.title },
                    set: model.setStudyTitle
                ))
                .textFieldStyle(.plain)
                .font(.system(size: 20, weight: .semibold))
                .accessibilityLabel("Study title")

                Picker("Preset", selection: Binding(
                    get: { model.study.samplePreset },
                    set: model.setPreset
                )) {
                    ForEach(SamplePreset.allCases) { preset in Text(preset.label).tag(preset) }
                }
                .frame(width: 170)

                Picker("Background", selection: Binding(
                    get: { model.study.background },
                    set: model.setBackground
                )) {
                    ForEach(PreviewBackground.allCases) { background in Text(background.label).tag(background) }
                }
                .pickerStyle(.segmented)
                .frame(width: 205)
            }

            HStack(alignment: .top, spacing: 12) {
                TextEditor(text: Binding(
                    get: { model.study.sampleText },
                    set: model.setSampleText
                ))
                .font(.system(size: 13))
                .frame(minHeight: 48, maxHeight: 74)
                .padding(6)
                .background(Color(nsColor: .textBackgroundColor).opacity(0.65), in: RoundedRectangle(cornerRadius: 7))
                .accessibilityLabel("Specimen text")

                VStack(spacing: 8) {
                    HStack {
                        Picker("Alignment", selection: Binding(
                            get: { model.study.alignment },
                            set: model.setAlignment
                        )) {
                            ForEach(TextAlignment.allCases) { alignment in Text(alignment.label).tag(alignment) }
                        }
                        .labelsHidden()
                        .frame(width: 115)

                        Picker("Scale", selection: Binding(
                            get: { model.study.specimenKind },
                            set: model.setSpecimenKind
                        )) {
                            ForEach(SpecimenKind.allCases) { kind in Text(kind.label).tag(kind) }
                        }
                        .labelsHidden()
                        .frame(width: 110)
                    }
                    HStack(spacing: 12) {
                        Toggle("Meta", isOn: Binding(
                            get: { model.study.showMetadata },
                            set: model.setShowMetadata
                        ))
                        .toggleStyle(.checkbox)
                        Toggle("Guides", isOn: Binding(
                            get: { model.study.showGuides },
                            set: model.setShowGuides
                        ))
                        .toggleStyle(.checkbox)
                    }
                    .font(.caption)
                }
            }
        }
        .padding(14)
        .background(.regularMaterial)
    }
}

private struct ReviewGrid: View {
    @EnvironmentObject private var model: AppModel
    private let columns = [GridItem(.adaptive(minimum: 330, maximum: 560), spacing: 16)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(Array(model.filteredRecords.enumerated()), id: \.element.id) { offset, record in
                    SpecimenCard(record: record, sequence: offset + 1)
                }
            }
            .padding(20)
        }
    }
}

private struct SpecimenCard: View {
    @EnvironmentObject private var model: AppModel
    let record: FontFaceRecord
    let sequence: Int

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                StatusDot(status: record.status)
                Text(record.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                Spacer()
                if record.isVariable {
                    Text("VARIABLE")
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Button {
                    model.toggleComparison(record.id)
                } label: {
                    Image(systemName: model.study.comparisonIDs.contains(record.id) ? "square.grid.2x2.fill" : "square.grid.2x2")
                }
                .buttonStyle(.plain)
                .help(model.study.comparisonIDs.contains(record.id) ? "Remove from comparison" : "Add to comparison")
            }
            .padding(10)

            SpecimenCanvas(
                study: cardStudy,
                records: [record],
                runtimeFonts: model.runtimeFonts,
                pageIndex: sequence
            )
            .aspectRatio(2_576 / 1_080, contentMode: .fit)
            .accessibilityLabel("Specimen preview for \(record.displayName)")
        }
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(model.selectedRecordID == record.id ? Color.accentColor : Color.primary.opacity(0.10), lineWidth: model.selectedRecordID == record.id ? 2 : 1)
        }
        .contentShape(Rectangle())
        .onTapGesture { model.selectedRecordID = record.id }
        .contextMenu {
            ForEach(ReviewStatus.allCases) { status in
                Button("Mark \(status.label)") { model.setStatus(status, for: record.id) }
            }
            Divider()
            Button(model.study.comparisonIDs.contains(record.id) ? "Remove from Comparison" : "Add to Comparison") {
                model.toggleComparison(record.id)
            }
            Button("Use as Display Font") { model.assignPairingHeading(record.id) }
            Button("Use as Body Font") { model.assignPairingBody(record.id) }
        }
    }

    private var cardStudy: FontStudy {
        var copy = model.study
        copy.layout = .focus
        copy.showMetadata = false
        copy.showGuides = false
        return copy
    }
}

private struct SingleScene: View {
    @EnvironmentObject private var model: AppModel
    let record: FontFaceRecord?

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            if let record {
                SpecimenCanvas(
                    study: model.study,
                    records: [record],
                    runtimeFonts: model.runtimeFonts
                )
                .frame(minWidth: 760, minHeight: 320)
                .aspectRatio(2_576 / 1_080, contentMode: .fit)
                .padding(24)
                .accessibilityLabel("\(model.study.layout.label) preview for \(record.displayName)")
            } else {
                SelectFontState()
            }
        }
    }
}

private struct BoardScene: View {
    @EnvironmentObject private var model: AppModel
    let records: [FontFaceRecord]

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            SpecimenCanvas(
                study: model.study,
                records: records,
                runtimeFonts: model.runtimeFonts
            )
            .frame(minWidth: 820, minHeight: 344)
            .aspectRatio(2_576 / 1_080, contentMode: .fit)
            .padding(24)
            .accessibilityLabel("\(model.study.layout.label) typography board")
        }
    }
}

private struct CanvasEmptyState: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 16) {
            Text("Aa")
                .font(.system(size: 72, weight: .light, design: .serif))
                .foregroundStyle(.secondary)
            Text("Build a font study")
                .font(.title2.bold())
            Text("Import individual files or an entire type library. Review every face locally, without installing it and without uploading it.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)
            Button("Import Fonts or Folder…", action: model.presentFontImportPanel)
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

private struct SelectFontState: View {
    var body: some View {
        UnavailableState(
            title: "Select a font",
            systemImage: "cursorarrow.click",
            message: "Choose a face in the sidebar to inspect it here."
        )
        .frame(minWidth: 600, minHeight: 380)
    }
}


private struct UnavailableState: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.secondary)
            Text(title).font(.headline)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

private struct DropOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "arrow.down.doc.fill")
                    .font(.system(size: 42))
                Text("Drop fonts or folders")
                    .font(.title2.bold())
                Text("OTF · TTF · TTC · OTC · dfont · WOFF · WOFF2")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            .padding(36)
            .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 18))
        }
        .allowsHitTesting(false)
        .transition(.opacity)
    }
}

private struct OperationOverlay: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 12) {
            if let progress = model.exportProgress {
                ProgressView(value: progress.fraction)
                    .frame(width: 260)
                Text(progress.message)
                    .font(.callout.weight(.medium))
            } else {
                ProgressView()
                Text(model.isImporting ? "Reading font faces…" : "Working…")
                    .font(.callout.weight(.medium))
            }
            Button("Cancel") { model.cancelCurrentOperation() }
                .controlSize(.small)
        }
        .padding(22)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 14))
        .shadow(radius: 22)
    }
}

private struct FilterChip: View {
    let label: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(isOn ? Color.primary.opacity(0.16) : Color.clear, in: Capsule())
                .overlay(Capsule().stroke(Color.primary.opacity(0.16)))
        }
        .buttonStyle(.plain)
        .accessibilityValue(isOn ? "Included" : "Excluded")
    }
}

struct StatusDot: View {
    let status: ReviewStatus

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .accessibilityHidden(true)
    }

    private var color: Color {
        switch status {
        case .keep: return .green
        case .maybe: return .orange
        case .reject: return .red
        }
    }
}
