import AppKit
import FontPreviewerCore
import FontPreviewerMacKit
import SwiftUI

struct FontInspector: View {
    @EnvironmentObject private var model: AppModel
    @State private var tagsDraft = ""

    var body: some View {
        Group {
            if let record = model.selectedRecord {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        identity(record)
                        review(record)
                        typography(record)
                        if !record.axes.isEmpty { variations(record) }
                        if !record.featureGroups.isEmpty { features(record) }
                        coverage(record)
                        notes(record)
                        source(record)
                    }
                    .padding(16)
                }
                .onAppear { tagsDraft = record.tags.joined(separator: ", ") }
                .onChange(of: model.selectedRecordID) { _ in
                    tagsDraft = model.selectedRecord?.tags.joined(separator: ", ") ?? ""
                }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "sidebar.right")
                        .font(.system(size: 30, weight: .light))
                        .foregroundStyle(.secondary)
                    Text("No font selected")
                        .font(.headline)
                    Text("Choose a face to review its axes, features, coverage, notes, and source.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 240)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(24)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private func identity(_ record: FontFaceRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(record.familyName.isEmpty ? record.fileName : record.familyName)
                .font(.title3.bold())
                .textSelection(.enabled)
            Text(record.styleName.isEmpty ? "Regular" : record.styleName)
                .font(.callout)
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                InspectorBadge(record.format)
                if record.isVariable { InspectorBadge("VARIABLE") }
                if record.faceIndex > 0 || ["TTC", "OTC"].contains(record.format.uppercased()) {
                    InspectorBadge("FACE \(record.faceIndex)")
                }
            }
            Text(record.postScriptName)
                .font(.caption.monospaced())
                .foregroundStyle(.tertiary)
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private func review(_ record: FontFaceRecord) -> some View {
        InspectorSection("Review") {
            Picker("Decision", selection: Binding(
                get: { record.status },
                set: { model.setStatus($0, for: record.id) }
            )) {
                ForEach(ReviewStatus.allCases) { status in Text(status.label).tag(status) }
            }
            .pickerStyle(.segmented)

            Picker("Role", selection: Binding(
                get: { record.role },
                set: { model.setRole($0, for: record.id) }
            )) {
                ForEach(FontRole.allCases) { role in Text(role.label).tag(role) }
            }

            Picker("Casing", selection: Binding(
                get: { record.casing },
                set: { model.setCasing($0, for: record.id) }
            )) {
                ForEach(TextCasing.allCases) { casing in Text(casing.label).tag(casing) }
            }

            HStack(spacing: 8) {
                Button {
                    model.toggleComparison(record.id)
                } label: {
                    Label(
                        model.study.comparisonIDs.contains(record.id) ? "Compared" : "Compare",
                        systemImage: model.study.comparisonIDs.contains(record.id) ? "checkmark.square.fill" : "square.grid.2x2"
                    )
                }
                .buttonStyle(.bordered)
                .help("Add or remove this face from the four-up comparison")

                Menu("Pair as…") {
                    Button("Display font") { model.assignPairingHeading(record.id) }
                    Button("Body font") { model.assignPairingBody(record.id) }
                }
                .menuStyle(.borderlessButton)
            }

            HStack {
                Button(action: { model.moveSelected(offset: -1) }) {
                    Label("Earlier", systemImage: "arrow.up")
                }
                Button(action: { model.moveSelected(offset: 1) }) {
                    Label("Later", systemImage: "arrow.down")
                }
            }
            .controlSize(.small)
        }
    }

    @ViewBuilder
    private func typography(_ record: FontFaceRecord) -> some View {
        InspectorSection("Study typography") {
            LabeledContent("Tracking") {
                Text(String(format: "%+.3f em", model.study.tracking))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: Binding(
                get: { model.study.tracking },
                set: model.setTracking
            ), in: -0.08...0.12, step: 0.001)
            .accessibilityLabel("Tracking")

            LabeledContent("Line height") {
                Text(String(format: "%.2f×", model.study.lineHeight))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: Binding(
                get: { model.study.lineHeight },
                set: model.setLineHeight
            ), in: 0.80...2.00, step: 0.01)
            .accessibilityLabel("Line height")

            HStack {
                Toggle("Metadata", isOn: Binding(
                    get: { model.study.showMetadata },
                    set: model.setShowMetadata
                ))
                Toggle("Guides", isOn: Binding(
                    get: { model.study.showGuides },
                    set: model.setShowGuides
                ))
            }
            .toggleStyle(.checkbox)
            .font(.caption)
        }
    }

    @ViewBuilder
    private func variations(_ record: FontFaceRecord) -> some View {
        InspectorSection("Variable axes") {
            ForEach(record.axes) { axis in
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(axis.name)
                            .font(.caption.weight(.medium))
                        Text(axis.tag)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Text(axisValue(record, axis: axis))
                            .font(.caption.monospacedDigit())
                    }
                    Slider(value: Binding(
                        get: { record.axisValues[axis.identifier] ?? axis.defaultValue },
                        set: { model.setAxisValue($0, axis: axis, for: record.id) }
                    ), in: axis.minimum...axis.maximum)
                    .accessibilityLabel(axis.name)
                }
            }
            Button("Reset all axes") { model.resetAxes(for: record.id) }
                .controlSize(.small)
        }
    }

    @ViewBuilder
    private func features(_ record: FontFaceRecord) -> some View {
        InspectorSection("OpenType features") {
            ForEach(record.featureGroups) { group in
                Picker(group.name, selection: Binding(
                    get: {
                        record.featureSelections[group.typeIdentifier]
                            ?? group.options.first(where: \.isDefault)?.selectorIdentifier
                            ?? group.options.first?.selectorIdentifier
                            ?? 0
                    },
                    set: { model.setFeatureSelection($0, group: group, for: record.id) }
                )) {
                    ForEach(group.options) { option in
                        Text(option.name).tag(option.selectorIdentifier)
                    }
                }
                .help(group.isExclusive ? "Choose one selector" : "Choose a CoreText feature selector")
            }
        }
    }

    @ViewBuilder
    private func coverage(_ record: FontFaceRecord) -> some View {
        InspectorSection("Coverage & metrics") {
            LabeledContent("Glyphs", value: "\(record.metrics.glyphCount)")
            LabeledContent("Units per em", value: "\(record.metrics.unitsPerEm)")
            LabeledContent("Cap / x-height") {
                Text("\(format(record.metrics.capHeight)) / \(format(record.metrics.xHeight))")
                    .font(.caption.monospacedDigit())
            }
            if !record.metrics.symbolicTraits.isEmpty {
                LabeledContent("Traits", value: record.metrics.symbolicTraits.joined(separator: ", "))
            }

            Divider()
            ForEach(record.coverage.scriptRatios.sorted(by: { $0.key < $1.key }), id: \.key) { script, ratio in
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(script).font(.caption)
                        Spacer()
                        Text("\(Int((ratio * 100).rounded()))%")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    ProgressView(value: ratio)
                        .controlSize(.small)
                }
            }
            Text("Coverage is a probe, not a shaping guarantee. Complex scripts still need visual testing.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func notes(_ record: FontFaceRecord) -> some View {
        InspectorSection("Tags & notes") {
            HStack {
                TextField("warm, cinematic, editorial", text: $tagsDraft)
                    .onSubmit { model.setTags(tagsDraft, for: record.id) }
                Button("Apply") { model.setTags(tagsDraft, for: record.id) }
                    .controlSize(.small)
            }
            Text("Comma-separated. Search later with tag:warm.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            TextEditor(text: Binding(
                get: { record.notes },
                set: { model.setNotes($0, for: record.id) }
            ))
            .frame(minHeight: 90)
            .padding(5)
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
            .accessibilityLabel("Review notes")
        }
    }

    @ViewBuilder
    private func source(_ record: FontFaceRecord) -> some View {
        InspectorSection("Source") {
            if !model.sourceExists(for: record) {
                Label("Source file missing", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
            Text(record.sourcePath)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .lineLimit(4)
            LabeledContent("Size", value: ByteCountFormatter.string(fromByteCount: record.fileSize, countStyle: .file))
            if let modified = record.sourceModifiedAt {
                LabeledContent("Modified", value: modified.formatted(date: .abbreviated, time: .shortened))
            }
            HStack {
                Button("Reveal", action: model.revealSelectedSource)
                    .disabled(!model.sourceExists(for: record))
                Button("Relink…") { model.relinkSource(for: record.id) }
            }
            .controlSize(.small)
            Divider()
            Button(role: .destructive, action: model.confirmAndRemoveSelectedRecord) {
                Label("Remove from study", systemImage: "trash")
            }
        }
    }

    private func axisValue(_ record: FontFaceRecord, axis: FontAxis) -> String {
        let value = record.axisValues[axis.identifier] ?? axis.defaultValue
        if abs(value.rounded() - value) < 0.01 { return String(Int(value.rounded())) }
        return String(format: "%.1f", value)
    }

    private func format(_ value: Double) -> String {
        if abs(value.rounded() - value) < 0.01 { return String(Int(value.rounded())) }
        return String(format: "%.1f", value)
    }
}

private struct InspectorSection<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
                .tracking(0.7)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 2)
    }
}

private struct InspectorBadge: View {
    let value: String

    init(_ value: String) { self.value = value }

    var body: some View {
        Text(value)
            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.primary.opacity(0.08), in: Capsule())
            .foregroundStyle(.secondary)
    }
}
