import AppKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers
import FontPreviewerCore

struct AppAlert: Identifiable {
    let id = UUID()
    var title: String
    var message: String
}

@MainActor
final class AppModel: ObservableObject {
    @Published var study: FontStudy = .blank()
    @Published var selectedRecordID: UUID?
    @Published var filter = StudyFilter()
    @Published private(set) var runtimeFonts: [UUID: RuntimeFontFace] = [:]
    @Published private(set) var projectURL: URL?
    @Published private(set) var isDirty = false
    @Published var isShowingExportSheet = false
    @Published private(set) var isImporting = false
    @Published private(set) var isExporting = false
    @Published var activeAlert: AppAlert?
    @Published private(set) var lastExportURL: URL?

    private let watcher = FontSourceWatcher()
    private var autosaveTask: Task<Void, Never>?
    private var reloadTasks: [String: Task<Void, Never>] = [:]
    private var documentGeneration = UUID()

    var filteredRecords: [FontFaceRecord] {
        filter.apply(to: study.records)
    }

    var selectedRecord: FontFaceRecord? {
        guard let selectedRecordID else { return nil }
        return study.records.first(where: { $0.id == selectedRecordID })
    }

    var windowTitle: String {
        let base = study.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return (base.isEmpty ? "Untitled font study" : base) + (isDirty ? " — Edited" : "")
    }

    func runtime(for recordID: UUID) -> RuntimeFontFace? {
        runtimeFonts[recordID]
    }

    func sourceURL(for record: FontFaceRecord) -> URL {
        StudyPathResolver.resolvedURL(for: record.sourcePath, projectURL: projectURL)
    }

    func sourceExists(for record: FontFaceRecord) -> Bool {
        FileManager.default.fileExists(atPath: sourceURL(for: record).path)
    }

    func requestNewStudy() {
        guard confirmDiscardChanges() else { return }
        beginDocumentTransition()
        study = .blank()
        projectURL = nil
        runtimeFonts = [:]
        selectedRecordID = nil
        filter = StudyFilter()
        isDirty = false
        watcher.stop()
    }

    func requestOpenProject(_ url: URL) {
        guard confirmDiscardChanges() else { return }
        do {
            let loaded = try ProjectCodec.load(from: url)
            beginDocumentTransition()
            study = loaded
            projectURL = url.standardizedFileURL
            selectedRecordID = loaded.records.first?.id
            filter = StudyFilter()
            loadRuntimeFonts()
            isDirty = false
            refreshWatcher()
        } catch {
            show(error: error, title: "Could not open font study")
        }
    }

    func presentProjectOpenPanel() {
        guard confirmDiscardChanges() else { return }
        let panel = NSOpenPanel()
        panel.title = "Open Font Study"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [projectContentType]
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let loaded = try ProjectCodec.load(from: url)
                beginDocumentTransition()
                study = loaded
                projectURL = url.standardizedFileURL
                selectedRecordID = loaded.records.first?.id
                filter = StudyFilter()
                loadRuntimeFonts()
                isDirty = false
                refreshWatcher()
            } catch {
                show(error: error, title: "Could not open font study")
            }
        }
    }

    func presentProjectSavePanel() {
        let panel = NSSavePanel()
        panel.title = "Save Font Study"
        panel.nameFieldStringValue = suggestedProjectFileName()
        panel.allowedContentTypes = [projectContentType]
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            performSave(to: url)
        }
    }

    func saveCurrentProject() {
        if let projectURL {
            performSave(to: projectURL)
        } else {
            presentProjectSavePanel()
        }
    }

    func presentFontImportPanel() {
        let panel = NSOpenPanel()
        panel.title = "Import Fonts or a Folder"
        panel.prompt = "Import"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.resolvesAliases = true
        panel.allowedContentTypes = FontCatalog.supportedExtensions.compactMap {
            UTType(filenameExtension: $0)
        }
        if panel.runModal() == .OK {
            importSelections(panel.urls)
        }
    }

    func importSelections(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        isImporting = true
        let result = FontCatalog.importFaces(from: urls, projectURL: projectURL)
        isImporting = false

        var existing = Set(study.records.map { FontIdentity.key(for: $0) })
        var added: [FontFaceRecord] = []
        for record in result.records {
            guard existing.insert(FontIdentity.key(for: record)).inserted else { continue }
            added.append(record)
            if let runtime = result.runtimes[record.id] {
                runtimeFonts[record.id] = runtime
            }
        }

        if !added.isEmpty {
            study.records.append(contentsOf: added)
            selectedRecordID = selectedRecordID ?? added.first?.id
            markDirty()
            refreshWatcher()
        }

        if !result.failures.isEmpty {
            let firstFailures = result.failures.prefix(6).map {
                "• \($0.url.lastPathComponent): \($0.reason)"
            }.joined(separator: "\n")
            let remainder = result.failures.count > 6 ? "\n…and \(result.failures.count - 6) more." : ""
            activeAlert = AppAlert(
                title: added.isEmpty ? "No fonts imported" : "Some fonts were skipped",
                message: firstFailures + remainder
            )
        } else if added.isEmpty {
            activeAlert = AppAlert(
                title: "Nothing new to import",
                message: "Every readable face in that selection is already in this study."
            )
        }
    }

    func setStudyTitle(_ value: String) {
        guard study.title != value else { return }
        study.title = value
        markDirty()
    }

    func setSampleText(_ value: String) {
        guard study.sampleText != value else { return }
        study.sampleText = value
        study.samplePreset = .custom
        markDirty()
    }

    func setPreset(_ preset: SamplePreset) {
        guard study.samplePreset != preset else { return }
        study.samplePreset = preset
        study.specimenKind = PresetLibrary.kind(for: preset)
        if preset != .custom { study.sampleText = PresetLibrary.text(for: preset) }
        markDirty()
    }

    func setBackground(_ background: PreviewBackground) {
        guard study.background != background else { return }
        study.background = background
        markDirty()
    }

    func setLayout(_ layout: PreviewLayout) {
        guard study.layout != layout else { return }
        study.layout = layout
        markDirty()
    }

    func setSelectedStatus(_ status: ReviewStatus) {
        guard let selectedRecordID else { return }
        updateRecord(selectedRecordID) { $0.status = status }
    }

    func setStatus(_ status: ReviewStatus, for recordID: UUID) {
        updateRecord(recordID) { $0.status = status }
    }

    func setCasing(_ casing: TextCasing, for recordID: UUID) {
        updateRecord(recordID) { $0.casing = casing }
    }

    func setAxisValue(_ value: Double, axis: FontAxis, for recordID: UUID) {
        updateRecord(recordID) {
            $0.axisValues[axis.identifier] = min(axis.maximum, max(axis.minimum, value))
        }
    }

    func resetAxes(for recordID: UUID) {
        updateRecord(recordID) { record in
            for axis in record.axes { record.axisValues[axis.identifier] = axis.defaultValue }
        }
    }

    func setTags(_ raw: String, for recordID: UUID) {
        let tags = raw
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        updateRecord(recordID) { $0.tags = Array(Set(tags)).sorted() }
    }

    func setNotes(_ notes: String, for recordID: UUID) {
        updateRecord(recordID) { $0.notes = notes }
    }

    func removeSelectedRecord() {
        guard let selectedRecordID,
              let index = study.records.firstIndex(where: { $0.id == selectedRecordID })
        else { return }
        study.records.remove(at: index)
        runtimeFonts.removeValue(forKey: selectedRecordID)
        self.selectedRecordID = study.records.indices.contains(index)
            ? study.records[index].id
            : study.records.last?.id
        markDirty()
        refreshWatcher()
    }

    func moveRecord(_ recordID: UUID, before destinationID: UUID) {
        StudyLogic.move(recordID: recordID, before: destinationID, in: &study.records)
        markDirty()
    }

    func relinkSource(for recordID: UUID) {
        guard let index = study.records.firstIndex(where: { $0.id == recordID }) else { return }
        let panel = NSOpenPanel()
        panel.title = "Relink \(study.records[index].fileName)"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = FontCatalog.supportedExtensions.compactMap {
            UTType(filenameExtension: $0)
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }

        var replacement = StudyPathResolver.replacingSource(
            in: study.records[index],
            with: url,
            projectURL: projectURL
        )
        replacement.faceIndex = study.records[index].faceIndex
        guard let loaded = FontCatalog.reload(record: replacement, projectURL: projectURL) else {
            activeAlert = AppAlert(
                title: "That file does not contain the expected face",
                message: "Choose the original font file or a compatible replacement with face index \(replacement.faceIndex)."
            )
            return
        }
        study.records[index] = loaded.0
        runtimeFonts[recordID] = loaded.1
        markDirty()
        refreshWatcher()
    }

    func revealSelectedSource() {
        guard let record = selectedRecord else { return }
        NSWorkspace.shared.activateFileViewerSelecting([sourceURL(for: record)])
    }

    func export(_ options: ExportOptions) {
        guard !isExporting else { return }
        isExporting = true
        do {
            let result = try BoardExporter.export(
                study: study,
                projectURL: projectURL,
                runtimeFonts: runtimeFonts,
                options: options
            )
            lastExportURL = result
            NSWorkspace.shared.activateFileViewerSelecting([result])
        } catch {
            show(error: error, title: "Export failed")
        }
        isExporting = false
    }

    func applicationShouldTerminate() -> NSApplication.TerminateReply {
        confirmDiscardChanges() ? .terminateNow : .terminateCancel
    }

    private func updateRecord(_ id: UUID, mutate: (inout FontFaceRecord) -> Void) {
        guard let index = study.records.firstIndex(where: { $0.id == id }) else { return }
        mutate(&study.records[index])
        markDirty()
    }

    private func markDirty() {
        study.updatedAt = Date()
        isDirty = true
        scheduleAutosave()
    }

    private func scheduleAutosave() {
        guard let destination = projectURL else { return }
        autosaveTask?.cancel()
        let generation = documentGeneration
        autosaveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled, let self else { return }
            guard self.documentGeneration == generation,
                  self.projectURL == destination,
                  self.isDirty
            else { return }
            self.performSave(to: destination, reportErrors: false)
        }
    }

    private func performSave(to destination: URL, reportErrors: Bool = true) {
        do {
            autosaveTask?.cancel()
            let oldProjectURL = projectURL
            var copy = study
            for index in copy.records.indices {
                let absolute = StudyPathResolver.resolvedURL(
                    for: copy.records[index].sourcePath,
                    projectURL: oldProjectURL
                )
                copy.records[index].sourcePath = StudyPathResolver.storedPath(
                    for: absolute,
                    projectURL: destination
                )
            }
            let saved = try ProjectCodec.save(copy, to: destination.standardizedFileURL)
            study = saved
            projectURL = destination.standardizedFileURL
            isDirty = false
            documentGeneration = UUID()
            refreshRuntimeSourceURLs()
            refreshWatcher()
        } catch {
            if reportErrors { show(error: error, title: "Could not save font study") }
        }
    }

    private func confirmDiscardChanges() -> Bool {
        guard isDirty else { return true }
        let alert = NSAlert()
        alert.messageText = "Save changes to \(study.title)?"
        alert.informativeText = "Unsaved review states, notes, axis values, and ordering will be lost."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Don’t Save")
        alert.addButton(withTitle: "Cancel")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            if let projectURL {
                performSave(to: projectURL)
                return !isDirty
            }
            let panel = NSSavePanel()
            panel.title = "Save Font Study"
            panel.nameFieldStringValue = suggestedProjectFileName()
            panel.allowedContentTypes = [projectContentType]
            panel.canCreateDirectories = true
            guard panel.runModal() == .OK, let url = panel.url else { return false }
            performSave(to: url)
            return !isDirty
        case .alertSecondButtonReturn:
            return true
        default:
            return false
        }
    }

    private func beginDocumentTransition() {
        autosaveTask?.cancel()
        reloadTasks.values.forEach { $0.cancel() }
        reloadTasks.removeAll()
        documentGeneration = UUID()
        watcher.stop()
    }

    private func loadRuntimeFonts() {
        runtimeFonts = [:]
        for index in study.records.indices {
            let record = study.records[index]
            if let loaded = FontCatalog.reload(record: record, projectURL: projectURL) {
                study.records[index] = loaded.0
                runtimeFonts[record.id] = loaded.1
            }
        }
    }

    private func refreshRuntimeSourceURLs() {
        var refreshed: [UUID: RuntimeFontFace] = [:]
        for record in study.records {
            if let loaded = FontCatalog.reload(record: record, projectURL: projectURL) {
                refreshed[record.id] = loaded.1
            }
        }
        runtimeFonts = refreshed
    }

    private func refreshWatcher() {
        let urls = study.records.map { sourceURL(for: $0) }
        watcher.replace(urls: urls) { [weak self] changedURL in
            Task { @MainActor in
                self?.scheduleReload(for: changedURL)
            }
        }
    }

    private func scheduleReload(for url: URL) {
        let key = url.standardizedFileURL.path
        reloadTasks[key]?.cancel()
        reloadTasks[key] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled, let self else { return }
            self.reloadSource(at: url)
            self.reloadTasks.removeValue(forKey: key)
        }
    }

    private func reloadSource(at url: URL) {
        let path = url.standardizedFileURL.resolvingSymlinksInPath().path
        var changed = false
        for index in study.records.indices {
            let recordURL = sourceURL(for: study.records[index])
                .standardizedFileURL
                .resolvingSymlinksInPath()
            guard recordURL.path == path else { continue }
            let oldID = study.records[index].id
            if let loaded = FontCatalog.reload(record: study.records[index], projectURL: projectURL) {
                study.records[index] = loaded.0
                runtimeFonts[oldID] = loaded.1
                changed = true
            } else {
                runtimeFonts.removeValue(forKey: oldID)
            }
        }
        if changed { markDirty() }
    }

    private func suggestedProjectFileName() -> String {
        StudyExportPlanner.slug(study.title) + ".pitchfontstudy"
    }

    private func show(error: Error, title: String) {
        activeAlert = AppAlert(title: title, message: error.localizedDescription)
    }

    private var projectContentType: UTType {
        UTType(filenameExtension: "pitchfontstudy") ?? .json
    }
}
