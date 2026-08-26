import AppKit
import Foundation
import FontPreviewerCore
import FontPreviewerMacKit
import SwiftUI
import UniformTypeIdentifiers

struct AppAlert: Identifiable {
    let id = UUID()
    var title: String
    var message: String
}

private struct RuntimeLoadResult: @unchecked Sendable {
    var records: [FontFaceRecord]
    var runtimes: [UUID: RuntimeFontFace]
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
    @Published private(set) var exportProgress: ExportProgress?
    @Published var activeAlert: AppAlert?
    @Published private(set) var lastExportURL: URL?

    weak var undoManager: UndoManager?

    private let watcher = FontSourceWatcher()
    private var autosaveTask: Task<Void, Never>?
    private var importTask: Task<Void, Never>?
    private var exportTask: Task<Void, Never>?
    private var reloadTasks: [String: Task<Void, Never>] = [:]
    private var documentGeneration = UUID()

    var filteredRecords: [FontFaceRecord] {
        filter.apply(to: study.records, sourceExists: { [weak self] record in
            self?.sourceExists(for: record) ?? false
        })
    }

    var selectedRecord: FontFaceRecord? {
        guard let selectedRecordID else { return nil }
        return study.records.first(where: { $0.id == selectedRecordID })
    }

    var comparisonRecords: [FontFaceRecord] { StudyLogic.comparisonRecords(in: study) }

    var windowTitle: String {
        let base = study.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return (base.isEmpty ? "Untitled font study" : base) + (isDirty ? " — Edited" : "")
    }

    var counts: [ReviewStatus: Int] { StudyLogic.counts(in: study.records) }

    var isBusy: Bool { isImporting || isExporting }

    func runtime(for recordID: UUID) -> RuntimeFontFace? { runtimeFonts[recordID] }

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
            isDirty = false
            loadRuntimeFonts(for: loaded, projectURL: projectURL)
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
        if panel.runModal() == .OK, let url = panel.url { requestOpenProject(url) }
    }

    func presentProjectSavePanel() {
        let panel = NSSavePanel()
        panel.title = "Save Font Study"
        panel.nameFieldStringValue = suggestedProjectFileName()
        panel.allowedContentTypes = [projectContentType]
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url { performSave(to: url) }
    }

    func saveCurrentProject() {
        if let projectURL { performSave(to: projectURL) }
        else { presentProjectSavePanel() }
    }

    func presentFontImportPanel() {
        let panel = NSOpenPanel()
        panel.title = "Import Fonts or Folders"
        panel.prompt = "Import"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.resolvesAliases = true
        panel.allowedContentTypes = FontCatalog.supportedExtensions.compactMap { UTType(filenameExtension: $0) }
        if panel.runModal() == .OK { importSelections(panel.urls) }
    }

    func importSelections(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        importTask?.cancel()
        isImporting = true
        let generation = documentGeneration
        let destinationProject = projectURL
        importTask = Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) {
                FontCatalog.importFaces(from: urls, projectURL: destinationProject)
            }.value
            guard !Task.isCancelled, let self, self.documentGeneration == generation else { return }
            self.isImporting = false
            self.applyImport(result)
        }
    }

    func cancelCurrentOperation() {
        importTask?.cancel()
        exportTask?.cancel()
        isImporting = false
        isExporting = false
        exportProgress = nil
    }

    func setStudyTitle(_ value: String) {
        mutateStudy(actionName: "Edit Study Title") { $0.title = value }
    }

    func setSampleText(_ value: String) {
        mutateStudy(actionName: "Edit Specimen Text") {
            $0.sampleText = value
            $0.samplePreset = .custom
        }
    }

    func setPreset(_ preset: SamplePreset) {
        mutateStudy(actionName: "Change Specimen Preset") {
            $0.samplePreset = preset
            $0.specimenKind = PresetLibrary.kind(for: preset)
            if preset != .custom { $0.sampleText = PresetLibrary.text(for: preset) }
        }
    }

    func setSpecimenKind(_ kind: SpecimenKind) {
        mutateStudy(actionName: "Change Specimen Scale") { $0.specimenKind = kind }
    }

    func setBackground(_ background: PreviewBackground) {
        mutateStudy(actionName: "Change Background") { $0.background = background }
    }

    func setLayout(_ layout: PreviewMode) {
        mutateStudy(actionName: "Change Preview Mode") { $0.layout = layout }
    }

    func setAlignment(_ alignment: TextAlignment) {
        mutateStudy(actionName: "Change Alignment") { $0.alignment = alignment }
    }

    func setTracking(_ value: Double) {
        mutateStudy(actionName: "Change Tracking") { $0.tracking = min(0.25, max(-0.25, value)) }
    }

    func setLineHeight(_ value: Double) {
        mutateStudy(actionName: "Change Line Height") { $0.lineHeight = min(3, max(0.7, value)) }
    }

    func setShowMetadata(_ value: Bool) {
        mutateStudy(actionName: "Toggle Metadata") { $0.showMetadata = value }
    }

    func setShowGuides(_ value: Bool) {
        mutateStudy(actionName: "Toggle Guides") { $0.showGuides = value }
    }

    func setSelectedStatus(_ status: ReviewStatus) {
        guard let selectedRecordID else { return }
        setStatus(status, for: selectedRecordID)
    }

    func setStatus(_ status: ReviewStatus, for recordID: UUID) {
        updateRecord(recordID, actionName: "Mark \(status.label)") { $0.status = status }
    }

    func bulkSetStatus(_ status: ReviewStatus, visibleOnly: Bool) {
        let ids = Set((visibleOnly ? filteredRecords : study.records).map(\.id))
        mutateStudy(actionName: "Mark Fonts \(status.label)") { study in
            for index in study.records.indices where ids.contains(study.records[index].id) {
                study.records[index].status = status
            }
        }
    }

    func setRole(_ role: FontRole, for recordID: UUID) {
        updateRecord(recordID, actionName: "Assign Font Role") { $0.role = role }
    }

    func setCasing(_ casing: TextCasing, for recordID: UUID) {
        updateRecord(recordID, actionName: "Change Casing") { $0.casing = casing }
    }

    func setAxisValue(_ value: Double, axis: FontAxis, for recordID: UUID) {
        updateRecord(recordID, actionName: "Adjust \(axis.name)") {
            $0.axisValues[axis.identifier] = min(axis.maximum, max(axis.minimum, value))
        }
    }

    func resetAxes(for recordID: UUID) {
        updateRecord(recordID, actionName: "Reset Variable Axes") { record in
            for axis in record.axes { record.axisValues[axis.identifier] = axis.defaultValue }
        }
    }

    func setFeatureSelection(_ selector: Int, group: FontFeatureGroup, for recordID: UUID) {
        guard group.options.contains(where: { $0.selectorIdentifier == selector }) else { return }
        updateRecord(recordID, actionName: "Change OpenType Feature") {
            $0.featureSelections[group.typeIdentifier] = selector
        }
    }

    func setTags(_ raw: String, for recordID: UUID) {
        let tags = raw.split(separator: ",").map {
            String($0).trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }
        updateRecord(recordID, actionName: "Edit Tags") { $0.tags = Array(Set(tags)).sorted() }
    }

    func setNotes(_ notes: String, for recordID: UUID) {
        updateRecord(recordID, actionName: "Edit Notes") { $0.notes = notes }
    }

    func toggleComparison(_ recordID: UUID) {
        mutateStudy(actionName: "Edit Comparison") { study in
            if let index = study.comparisonIDs.firstIndex(of: recordID) {
                study.comparisonIDs.remove(at: index)
            } else {
                if study.comparisonIDs.count == 4 { study.comparisonIDs.removeFirst() }
                study.comparisonIDs.append(recordID)
            }
        }
    }

    func assignPairingHeading(_ recordID: UUID) {
        mutateStudy(actionName: "Assign Display Font") {
            $0.pairingHeadingID = recordID
            if $0.pairingBodyID == recordID { $0.pairingBodyID = nil }
        }
    }

    func assignPairingBody(_ recordID: UUID) {
        mutateStudy(actionName: "Assign Body Font") {
            $0.pairingBodyID = recordID
            if $0.pairingHeadingID == recordID { $0.pairingHeadingID = nil }
        }
    }

    func moveSelected(offset: Int) {
        guard let selectedRecordID else { return }
        mutateStudy(actionName: "Reorder Font") {
            StudyLogic.move(recordID: selectedRecordID, offset: offset, in: &$0.records)
        }
    }

    func selectRelative(offset: Int) {
        let visible = filteredRecords
        guard !visible.isEmpty else { selectedRecordID = nil; return }
        guard let selectedRecordID,
              let index = visible.firstIndex(where: { $0.id == selectedRecordID })
        else { self.selectedRecordID = visible.first?.id; return }
        self.selectedRecordID = visible[max(0, min(visible.count - 1, index + offset))].id
    }

    func confirmAndRemoveSelectedRecord() {
        guard let selectedRecord else { return }
        let alert = NSAlert()
        alert.messageText = "Remove \(selectedRecord.displayName) from this study?"
        alert.informativeText = "The source font file will not be deleted. Review notes and decisions for this face will be removed from the study."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        removeSelectedRecord()
    }

    func relinkSource(for recordID: UUID) {
        guard let index = study.records.firstIndex(where: { $0.id == recordID }) else { return }
        let panel = NSOpenPanel()
        panel.title = "Relink \(study.records[index].fileName)"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = FontCatalog.supportedExtensions.compactMap { UTType(filenameExtension: $0) }
        guard panel.runModal() == .OK, let url = panel.url else { return }

        var replacement = StudyPathResolver.replacingSource(in: study.records[index], with: url, projectURL: projectURL)
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
        exportProgress = .init(completed: 0, total: 1, message: "Preparing export")
        let snapshot = study
        let sourceProject = projectURL
        let runtimes = runtimeFonts
        exportTask?.cancel()
        exportTask = Task { [weak self] in
            do {
                let result = try await Task.detached(priority: .userInitiated) {
                    try await BoardExporter.export(
                        study: snapshot,
                        projectURL: sourceProject,
                        runtimeFonts: runtimes,
                        options: options,
                        progress: { update in
                            Task { @MainActor [weak self] in self?.exportProgress = update }
                        }
                    )
                }.value
                guard !Task.isCancelled, let self else { return }
                self.lastExportURL = result.folderURL
                self.isExporting = false
                self.exportProgress = nil
                NSWorkspace.shared.activateFileViewerSelecting([result.folderURL])
            } catch is CancellationError {
                self?.isExporting = false
                self?.exportProgress = nil
            } catch {
                self?.isExporting = false
                self?.exportProgress = nil
                self?.show(error: error, title: "Export failed")
            }
        }
    }

    func setFilterQuery(_ value: String) { filter.query = value }
    func setFilterSort(_ value: StudySort) { filter.sort = value }
    func setVariableOnly(_ value: Bool) { filter.variableOnly = value }
    func setMissingOnly(_ value: Bool) { filter.missingSourceOnly = value }

    func toggleStatusFilter(_ status: ReviewStatus) {
        if filter.statuses.contains(status) { filter.statuses.remove(status) }
        else { filter.statuses.insert(status) }
    }

    func toggleRoleFilter(_ role: FontRole) {
        if filter.roles.contains(role) { filter.roles.remove(role) }
        else { filter.roles.insert(role) }
    }

    func resetFilters() { filter = StudyFilter() }

    func applicationShouldTerminate() -> NSApplication.TerminateReply {
        confirmDiscardChanges() ? .terminateNow : .terminateCancel
    }

    private func applyImport(_ result: FontImportResult) {
        var existing = Set(study.records.map { FontIdentity.key(for: $0, projectURL: projectURL) })
        var added: [FontFaceRecord] = []
        for record in result.records {
            guard existing.insert(FontIdentity.key(for: record, projectURL: projectURL)).inserted else { continue }
            added.append(record)
            if let runtime = result.runtimes[record.id] { runtimeFonts[record.id] = runtime }
        }
        if !added.isEmpty {
            study.records.append(contentsOf: added)
            selectedRecordID = selectedRecordID ?? added.first?.id
            markDirty()
            refreshWatcher()
        }
        if !result.failures.isEmpty {
            let firstFailures = result.failures.prefix(8).map { "• \($0.url.lastPathComponent): \($0.reason)" }.joined(separator: "\n")
            let remainder = result.failures.count > 8 ? "\n…and \(result.failures.count - 8) more." : ""
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

    private func updateRecord(
        _ id: UUID,
        actionName: String,
        mutate: (inout FontFaceRecord) -> Void
    ) {
        mutateStudy(actionName: actionName) { study in
            guard let index = study.records.firstIndex(where: { $0.id == id }) else { return }
            mutate(&study.records[index])
        }
    }

    private func mutateStudy(actionName: String, mutate: (inout FontStudy) -> Void) {
        let before = study
        mutate(&study)
        guard study != before else { return }
        registerUndo(snapshot: before, actionName: actionName)
        markDirty()
    }

    private func registerUndo(snapshot: FontStudy, actionName: String) {
        undoManager?.registerUndo(withTarget: self) { target in
            let redo = target.study
            target.study = snapshot
            target.registerUndo(snapshot: redo, actionName: actionName)
            target.markDirty()
        }
        undoManager?.setActionName(actionName)
    }

    private func removeSelectedRecord() {
        guard let selectedRecordID,
              let index = study.records.firstIndex(where: { $0.id == selectedRecordID })
        else { return }
        study.records.remove(at: index)
        study.comparisonIDs.removeAll { $0 == selectedRecordID }
        if study.pairingHeadingID == selectedRecordID { study.pairingHeadingID = nil }
        if study.pairingBodyID == selectedRecordID { study.pairingBodyID = nil }
        runtimeFonts.removeValue(forKey: selectedRecordID)
        self.selectedRecordID = study.records.indices.contains(index) ? study.records[index].id : study.records.last?.id
        markDirty()
        refreshWatcher()
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
            try? await Task.sleep(nanoseconds: 850_000_000)
            guard !Task.isCancelled, let self,
                  self.documentGeneration == generation,
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
                let absolute = StudyPathResolver.resolvedURL(for: copy.records[index].sourcePath, projectURL: oldProjectURL)
                copy.records[index].sourcePath = StudyPathResolver.storedPath(for: absolute, projectURL: destination)
            }
            let saved = try ProjectCodec.save(copy, to: destination.standardizedFileURL)
            study = saved
            projectURL = destination.standardizedFileURL
            isDirty = false
            documentGeneration = UUID()
            refreshWatcher()
        } catch {
            if reportErrors { show(error: error, title: "Could not save font study") }
        }
    }

    private func confirmDiscardChanges() -> Bool {
        guard isDirty else { return true }
        let alert = NSAlert()
        alert.messageText = "Save changes to \(study.title)?"
        alert.informativeText = "Unsaved review states, notes, feature settings, axis values, and ordering will be lost."
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
        importTask?.cancel()
        exportTask?.cancel()
        reloadTasks.values.forEach { $0.cancel() }
        reloadTasks.removeAll()
        documentGeneration = UUID()
        watcher.stop()
        isImporting = false
        isExporting = false
        exportProgress = nil
    }

    private func loadRuntimeFonts(for loadedStudy: FontStudy, projectURL: URL?) {
        isImporting = !loadedStudy.records.isEmpty
        let generation = documentGeneration
        importTask = Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) {
                var records = loadedStudy.records
                var runtimes: [UUID: RuntimeFontFace] = [:]
                for index in records.indices {
                    if Task.isCancelled { break }
                    if let loaded = FontCatalog.reload(record: records[index], projectURL: projectURL) {
                        records[index] = loaded.0
                        runtimes[loaded.0.id] = loaded.1
                    }
                }
                return RuntimeLoadResult(records: records, runtimes: runtimes)
            }.value
            guard !Task.isCancelled, let self, self.documentGeneration == generation else { return }
            self.study.records = result.records
            self.runtimeFonts = result.runtimes
            self.isImporting = false
            self.refreshWatcher()
        }
    }

    private func refreshWatcher() {
        let urls = study.records.map { sourceURL(for: $0) }
        watcher.replace(urls: urls) { [weak self] changedURL in
            Task { @MainActor in self?.scheduleReload(for: changedURL) }
        }
    }

    private func scheduleReload(for url: URL) {
        let key = url.standardizedFileURL.path
        reloadTasks[key]?.cancel()
        let generation = documentGeneration
        reloadTasks[key] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled, let self, self.documentGeneration == generation else { return }
            await self.reloadSource(at: url, generation: generation)
            self.reloadTasks.removeValue(forKey: key)
        }
    }

    private func reloadSource(at url: URL, generation: UUID) async {
        let path = url.standardizedFileURL.resolvingSymlinksInPath().path
        let matching = study.records.filter {
            sourceURL(for: $0).standardizedFileURL.resolvingSymlinksInPath().path == path
        }
        let sourceProject = projectURL
        let loaded = await Task.detached(priority: .utility) {
            matching.compactMap { record in FontCatalog.reload(record: record, projectURL: sourceProject) }
        }.value
        guard documentGeneration == generation else { return }
        var changed = false
        for (record, runtime) in loaded {
            guard let index = study.records.firstIndex(where: { $0.id == record.id }) else { continue }
            study.records[index] = record
            runtimeFonts[record.id] = runtime
            changed = true
        }
        let loadedIDs = Set(loaded.map { $0.0.id })
        for record in matching where !loadedIDs.contains(record.id) { runtimeFonts.removeValue(forKey: record.id) }
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
