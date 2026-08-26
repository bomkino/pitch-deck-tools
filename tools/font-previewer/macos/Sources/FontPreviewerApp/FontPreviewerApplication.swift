import AppKit
import SwiftUI
import FontPreviewerCore

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
                }
                .onOpenURL { url in
                    model.requestOpenProject(url)
                }
        }
        .defaultSize(width: 1_440, height: 920)
        .commands {
            FontPreviewerCommands(model: model)
        }
    }
}

final class FontPreviewerAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        AppModelBridge.shared.model?.applicationShouldTerminate() ?? .terminateNow
    }
}

final class AppModelBridge {
    static let shared = AppModelBridge()
    weak var model: AppModel?
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
        }

        CommandGroup(replacing: .saveItem) {
            Button("Save") { model.saveCurrentProject() }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(!model.isDirty && model.projectURL != nil)
            Button("Save As…") { model.presentProjectSavePanel() }
                .keyboardShortcut("s", modifiers: [.command, .shift])
        }

        CommandMenu("Fonts") {
            Button("Import Fonts or Folder…") { model.presentFontImportPanel() }
                .keyboardShortcut("i", modifiers: .command)
            Button("Export Review Boards…") { model.isShowingExportSheet = true }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(model.study.records.isEmpty)
            Divider()
            Button("Mark Keep") { model.setSelectedStatus(.keep) }
                .keyboardShortcut("1", modifiers: [])
                .disabled(model.selectedRecordID == nil)
            Button("Mark Maybe") { model.setSelectedStatus(.maybe) }
                .keyboardShortcut("2", modifiers: [])
                .disabled(model.selectedRecordID == nil)
            Button("Mark Reject") { model.setSelectedStatus(.reject) }
                .keyboardShortcut("3", modifiers: [])
                .disabled(model.selectedRecordID == nil)
            Divider()
            Button("Reveal Selected Font in Finder") { model.revealSelectedSource() }
                .disabled(model.selectedRecordID == nil)
        }
    }
}
