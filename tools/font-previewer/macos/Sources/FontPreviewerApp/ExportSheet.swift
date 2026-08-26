import AppKit
import FontPreviewerCore
import FontPreviewerMacKit
import SwiftUI

struct ExportSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var statuses: Set<ReviewStatus> = [.keep, .maybe]
    @State private var formats: Set<StudyExportFormat> = [.png, .pdf, .json, .markdown]
    @State private var canvas: CanvasPreset = .cinema
    @State private var includeFontCopies = false
    @State private var includeAbsolutePaths = false
    @State private var acknowledgedCopyPermission = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Export font review")
                        .font(.title2.bold())
                    Text("Boards, contact sheet, and a reusable handoff—not screenshots.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider()

            Form {
                Section("Include decisions") {
                    HStack {
                        ForEach(ReviewStatus.allCases) { status in
                            Toggle(status.label, isOn: membership(status, in: $statuses))
                                .toggleStyle(.checkbox)
                        }
                    }
                    Text("\(selectedCount) font faces will be exported.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Files") {
                    ForEach(StudyExportFormat.allCases) { format in
                        Toggle(format.label, isOn: membership(format, in: $formats))
                            .toggleStyle(.checkbox)
                    }
                    Picker("Canvas", selection: $canvas) {
                        ForEach(CanvasPreset.allCases) { preset in Text(preset.label).tag(preset) }
                    }
                    .disabled(!formats.contains(.png) && !formats.contains(.pdf))
                }

                Section("Privacy & source files") {
                    Toggle("Include absolute source paths in JSON", isOn: $includeAbsolutePaths)
                        .toggleStyle(.checkbox)
                    Text("Off by default. Relative project data and local folder names stay out of the handoff.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Toggle("Copy source font files into export", isOn: $includeFontCopies)
                        .toggleStyle(.checkbox)
                    if includeFontCopies {
                        Toggle("I have permission to copy these font files", isOn: $acknowledgedCopyPermission)
                            .toggleStyle(.checkbox)
                            .foregroundStyle(acknowledgedCopyPermission ? .primary : .orange)
                        Text("The app cannot determine licence terms. This copies files; it does not grant redistribution rights.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
            .padding(.horizontal, 8)

            Divider()

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Choose Folder and Export…", action: chooseDestination)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canExport)
            }
            .padding(20)
        }
        .frame(width: 570, height: 650)
    }

    private var selectedCount: Int {
        model.study.records.filter { statuses.contains($0.status) }.count
    }

    private var canExport: Bool {
        !statuses.isEmpty
            && !formats.isEmpty
            && selectedCount > 0
            && (!includeFontCopies || acknowledgedCopyPermission)
    }

    private func chooseDestination() {
        let panel = NSOpenPanel()
        panel.title = "Choose Export Destination"
        panel.prompt = "Export Here"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        let options = ExportOptions(
            destinationDirectory: destination,
            canvasPreset: canvas,
            formats: formats,
            selection: .init(
                statuses: statuses,
                includeFontCopies: includeFontCopies,
                includeAbsoluteSourcePaths: includeAbsolutePaths
            ),
            acknowledgesFontCopyingPermission: acknowledgedCopyPermission
        )
        model.export(options)
        dismiss()
    }

    private func membership<T: Hashable>(_ value: T, in set: Binding<Set<T>>) -> Binding<Bool> {
        Binding(
            get: { set.wrappedValue.contains(value) },
            set: { enabled in
                if enabled { set.wrappedValue.insert(value) }
                else { set.wrappedValue.remove(value) }
            }
        )
    }
}
