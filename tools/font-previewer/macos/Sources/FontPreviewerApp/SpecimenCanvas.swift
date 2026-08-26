import AppKit
import FontPreviewerCore
import FontPreviewerMacKit
import SwiftUI

struct SpecimenCanvas: NSViewRepresentable {
    var study: FontStudy
    var records: [FontFaceRecord]
    var runtimeFonts: [UUID: RuntimeFontFace]
    var pageIndex: Int = 1

    func makeNSView(context: Context) -> CanvasNSView {
        let view = CanvasNSView()
        view.study = study
        view.records = records
        view.runtimeFonts = runtimeFonts
        view.pageIndex = pageIndex
        return view
    }

    func updateNSView(_ nsView: CanvasNSView, context: Context) {
        nsView.study = study
        nsView.records = records
        nsView.runtimeFonts = runtimeFonts
        nsView.pageIndex = pageIndex
        nsView.needsDisplay = true
    }
}

final class CanvasNSView: NSView {
    var study: FontStudy = .blank()
    var records: [FontFaceRecord] = []
    var runtimeFonts: [UUID: RuntimeFontFace] = [:]
    var pageIndex = 1

    override var isFlipped: Bool { false }
    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        BoardRenderer.drawBoard(
            study: study,
            records: records,
            runtimeFonts: runtimeFonts,
            pageIndex: pageIndex,
            size: bounds.size,
            context: context
        )
    }
}
