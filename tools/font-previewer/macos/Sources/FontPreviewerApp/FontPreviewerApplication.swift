import AppKit
import FontPreviewerCore
import SwiftUI

@main
struct FontPreviewerApplication: App {
    @NSApplicationDelegateAdaptor(FontPreviewerAppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            WorkspaceView()
                .environmentObject(model)
                .frame(minWidth: 1_080, minHeight: 700)
                .onAppear {
                    AppModelBridge.shared.model = model
                    if let pending = AppModelBridge.shared.pendingProjectURL {
                        AppModelBridge.shared.pendingProjectURL = nil
                        model.requestOpenProject(pending)
                    }
                }
                .onOpenURL { url in model.requestOpenProject(url) }
        }
        .defaultSize(width: 1_480, height: 930)
        .windowResizability(.contentMinSize)
        .commands { FontPreviewerCommands(model: model) }
    }
}

final class FontPreviewerAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        AppModelBridge.shared.model?.applicationShouldTerminate() ?? .terminateNow
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        guard let first = filenames.first else {
            sender.reply(toOpenOrPrint: .failure)
            return
        }
        let url = URL(fileURLWithPath: first)
        if let model = AppModelBridge.shared.model { model.requestOpenProject(url) }
        else { AppModelBridge.shared.pendingProjectURL = url }
        sender.reply(toOpenOrPrint: .success)
    }
}

final class AppModelBridge {
    static let shared = AppModelBridge()
    weak var model: AppModel?
    var pendingProjectURL: URL?
    private init() {}
}

struct FontPreviewerCommands: Commands {
    @ObservedObject var model: AppModel

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Font Study") { model.requestNewStudy() }
                .keyboardShortcut("n", modifiers: .command)
            Button("Open Font Study…") { model.presentProjectOpenPanel() }
                .keyboardShortcut("o", modifiers: .command)
            Divider()
            Button("Import Fonts or Folder…") { model.presentFontImportPanel() }
                .keyboardShortcut("i", modifiers: .command)
        }

        CommandGroup(replacing: .saveItem) {
            Button("Save") { model.saveCurrentProject() }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(!model.isDirty && model.projectURL != nil)
            Button("Save As…") { model.presentProjectSavePanel() }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            Divider()
            Button("Export Font Review…") { model.isShowingExportSheet = true }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(model.study.records.isEmpty || model.isBusy)
        }

        CommandMenu("Review") {
            Button("Mark Keep") { model.setSelectedStatus(.keep) }
                .keyboardShortcut("1", modifiers: [])
                .disabled(model.selectedRecordID == nil)
            Button("Mark Maybe") { model.setSelectedStatus(.maybe) }
                .keyboardShortcut("2", modifiers: [])
                .disabled(model.selectedRecordID == nil)
            Button("Mark Reject") { model.setSelectedStatus(.reject) }
                .keyboardShortcut("3", modifiers: [])
                .disabled(model.selectedRecordID == nil)
            Button("Toggle Comparison") {
                if let id = model.selectedRecordID { model.toggleComparison(id) }
            }
            .keyboardShortcut("4", modifiers: [])
            .disabled(model.selectedRecordID == nil)

            Divider()
            Button("Previous Font") { model.selectRelative(offset: -1) }
                .keyboardShortcut(.upArrow, modifiers: [.command])
            Button("Next Font") { model.selectRelative(offset: 1) }
                .keyboardShortcut(.downArrow, modifiers: [.command])
            Divider()
            Button("Reveal Selected Font in Finder") { model.revealSelectedSource() }
                .disabled(model.selectedRecordID == nil)
            Button("Remove Selected Font…") { model.confirmAndRemoveSelectedRecord() }
                .keyboardShortcut(.delete, modifiers: [.command])
                .disabled(model.selectedRecordID == nil)
        }

        CommandMenu("Preview") {
            ForEach(PreviewMode.allCases) { mode in
                Button(mode.label) { model.setLayout(mode) }
            }
            Divider()
            Button("Dark Background") { model.setBackground(.dark) }
            Button("Light Background") { model.setBackground(.light) }
            Button("Split Background") { model.setBackground(.split) }
        }
    }
}
