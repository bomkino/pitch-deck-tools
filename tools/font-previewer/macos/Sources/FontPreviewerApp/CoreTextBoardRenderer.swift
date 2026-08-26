import AppKit
import CoreGraphics
import CoreText
import Foundation
import FontPreviewerCore

struct SpecimenRenderRequest {
    var record: FontFaceRecord
    var runtime: RuntimeFontFace
    var text: String
    var specimenKind: SpecimenKind
    var background: PreviewBackground
    var sequenceLabel: String?
    var showMetadata: Bool
}

enum CoreTextBoardRenderer {
    static let defaultBoardSize = CGSize(width: 2_576, height: 1_080)

    static func drawSpecimen(
        request: SpecimenRenderRequest,
        in rect: CGRect,
        context: CGContext
    ) {
        context.saveGState()
        defer { context.restoreGState() }
        context.setAllowsAntialiasing(true)
        context.setShouldAntialias(true)
        context.setShouldSmoothFonts(true)

        drawBackground(request.background, in: rect, context: context)

        let metadataHeight: CGFloat = request.showMetadata ? max(46, rect.height * 0.09) : 0
        let horizontalInset = max(20, rect.width * 0.045)
        let lowerInset = max(20, rect.height * 0.055)
        let upperInset = max(20, rect.height * 0.055) + metadataHeight
        let textRect = CGRect(
            x: rect.minX + horizontalInset,
            y: rect.minY + lowerInset,
            width: rect.width - horizontalInset * 2,
            height: max(20, rect.height - lowerInset - upperInset)
        )

        let transformed = SpecimenTextTransform.apply(request.record.casing, to: request.text)
        switch request.background {
        case .dark:
            drawMainText(transformed, request: request, color: Palette.paper, in: textRect, context: context)
        case .light:
            drawMainText(transformed, request: request, color: Palette.ink, in: textRect, context: context)
        case .split:
            let splitX = rect.midX
            context.saveGState()
            context.clip(to: CGRect(x: rect.minX, y: rect.minY, width: splitX - rect.minX, height: rect.height))
            drawMainText(transformed, request: request, color: Palette.paper, in: textRect, context: context)
            context.restoreGState()

            context.saveGState()
            context.clip(to: CGRect(x: splitX, y: rect.minY, width: rect.maxX - splitX, height: rect.height))
            drawMainText(transformed, request: request, color: Palette.ink, in: textRect, context: context)
            context.restoreGState()
        }

        if request.showMetadata {
            drawMetadata(request: request, in: rect, context: context)
        }
    }

    static func drawBoard(
        study: FontStudy,
        records: [FontFaceRecord],
        runtimeFonts: [UUID: RuntimeFontFace],
        pageIndex: Int,
        size: CGSize = defaultBoardSize,
        context: CGContext
    ) {
        let bounds = CGRect(origin: .zero, size: size)
        context.setFillColor(Palette.canvas.cgColor)
        context.fill(bounds)

        if study.layout == .fourUp {
            let outer: CGFloat = 34
            let gutter: CGFloat = 22
            let tileWidth = (size.width - outer * 2 - gutter) / 2
            let tileHeight = (size.height - outer * 2 - gutter) / 2

            for slot in 0..<4 {
                let column = slot % 2
                let row = slot / 2
                let x = outer + CGFloat(column) * (tileWidth + gutter)
                let y = size.height - outer - tileHeight - CGFloat(row) * (tileHeight + gutter)
                let tile = CGRect(x: x, y: y, width: tileWidth, height: tileHeight)
                drawTileShell(in: tile, context: context)

                guard records.indices.contains(slot),
                      let runtime = runtimeFonts[records[slot].id]
                else {
                    drawEmptyTile(in: tile, context: context)
                    continue
                }
                let request = SpecimenRenderRequest(
                    record: records[slot],
                    runtime: runtime,
                    text: study.sampleText,
                    specimenKind: study.specimenKind,
                    background: study.background,
                    sequenceLabel: sequence(page: pageIndex, slot: slot + 1, fourUp: true),
                    showMetadata: true
                )
                clipRounded(tile, radius: 18, context: context) {
                    drawSpecimen(request: request, in: tile, context: context)
                }
            }
        } else {
            let outer: CGFloat = 38
            let tile = bounds.insetBy(dx: outer, dy: outer)
            drawTileShell(in: tile, context: context)
            if let record = records.first, let runtime = runtimeFonts[record.id] {
                let request = SpecimenRenderRequest(
                    record: record,
                    runtime: runtime,
                    text: study.sampleText,
                    specimenKind: study.specimenKind,
                    background: study.background,
                    sequenceLabel: sequence(page: pageIndex, slot: 1, fourUp: false),
                    showMetadata: true
                )
                clipRounded(tile, radius: 22, context: context) {
                    drawSpecimen(request: request, in: tile, context: context)
                }
            } else {
                drawEmptyTile(in: tile, context: context)
            }
        }
    }

    private static func drawMainText(
        _ text: String,
        request: SpecimenRenderRequest,
        color: CGColor,
        in rect: CGRect,
        context: CGContext
    ) {
        guard !text.isEmpty else { return }
        let size = fittedPointSize(text: text, request: request, rect: rect)
        let font = request.runtime.makeFont(size: size, variations: request.record.axisValues)
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
            NSAttributedString.Key(kCTKernAttributeName as String): tracking(for: request.specimenKind, size: size),
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let framesetter = CTFramesetterCreateWithAttributedString(attributed as CFAttributedString)
        let measured = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter,
            CFRange(location: 0, length: attributed.length),
            nil,
            CGSize(width: rect.width, height: rect.height),
            nil
        )
        let height = min(rect.height, ceil(measured.height + 4))
        let centered = CGRect(
            x: rect.minX,
            y: rect.midY - height / 2,
            width: rect.width,
            height: height
        )
        let path = CGPath(rect: centered, transform: nil)
        let frame = CTFramesetterCreateFrame(
            framesetter,
            CFRange(location: 0, length: attributed.length),
            path,
            nil
        )
        context.textMatrix = .identity
        CTFrameDraw(frame, context)
    }

    private static func fittedPointSize(
        text: String,
        request: SpecimenRenderRequest,
        rect: CGRect
    ) -> CGFloat {
        let baseline = CGFloat(PresetLibrary.recommendedPointSize(for: request.specimenKind))
        let scale = max(0.35, min(2.4, rect.width / 1_100))
        var low = max(9, baseline * scale * 0.28)
        var high = min(rect.height * 0.76, baseline * scale * 2.35)

        for _ in 0..<12 {
            let candidate = (low + high) / 2
            if fits(text: text, request: request, pointSize: candidate, rect: rect) {
                low = candidate
            } else {
                high = candidate
            }
        }
        return floor(low * 10) / 10
    }

    private static func fits(
        text: String,
        request: SpecimenRenderRequest,
        pointSize: CGFloat,
        rect: CGRect
    ) -> Bool {
        let font = request.runtime.makeFont(size: pointSize, variations: request.record.axisValues)
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTKernAttributeName as String): tracking(for: request.specimenKind, size: pointSize),
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let framesetter = CTFramesetterCreateWithAttributedString(attributed as CFAttributedString)
        let measured = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter,
            CFRange(location: 0, length: attributed.length),
            nil,
            CGSize(width: rect.width, height: .greatestFiniteMagnitude),
            nil
        )
        return measured.width <= rect.width + 1 && measured.height <= rect.height + 1
    }

    private static func tracking(for kind: SpecimenKind, size: CGFloat) -> CGFloat {
        switch kind {
        case .display: return size * -0.018
        case .paragraph: return size * -0.006
        case .data: return size * -0.01
        case .micro: return size * 0.018
        }
    }

    private static func drawMetadata(
        request: SpecimenRenderRequest,
        in rect: CGRect,
        context: CGContext
    ) {
        let inset = max(16, rect.width * 0.035)
        let baseline = rect.maxY - max(24, rect.height * 0.045)
        let missing = request.runtime.missingScalars(
            in: SpecimenTextTransform.apply(request.record.casing, to: request.text),
            variations: request.record.axisValues
        )
        let left = [request.sequenceLabel, request.record.displayName]
            .compactMap { $0 }
            .joined(separator: "  ·  ")
        let axisSummary = request.record.axes.compactMap { axis -> String? in
            guard let value = request.record.axisValues[axis.identifier] else { return nil }
            return "\(axis.tag) \(formatAxis(value))"
        }.joined(separator: "  ")
        let right = missing.isEmpty
            ? axisSummary
            : "Missing \(missing.map { String($0) }.joined())" + (axisSummary.isEmpty ? "" : "  ·  \(axisSummary)")

        switch request.background {
        case .dark:
            drawMetadataLine(left: left, right: right, color: Palette.paperMuted, y: baseline, rect: rect.insetBy(dx: inset, dy: 0), context: context)
        case .light:
            drawMetadataLine(left: left, right: right, color: Palette.inkMuted, y: baseline, rect: rect.insetBy(dx: inset, dy: 0), context: context)
        case .split:
            context.saveGState()
            context.clip(to: CGRect(x: rect.minX, y: rect.minY, width: rect.width / 2, height: rect.height))
            drawMetadataLine(left: left, right: right, color: Palette.paperMuted, y: baseline, rect: rect.insetBy(dx: inset, dy: 0), context: context)
            context.restoreGState()
            context.saveGState()
            context.clip(to: CGRect(x: rect.midX, y: rect.minY, width: rect.width / 2, height: rect.height))
            drawMetadataLine(left: left, right: right, color: Palette.inkMuted, y: baseline, rect: rect.insetBy(dx: inset, dy: 0), context: context)
            context.restoreGState()
        }
    }

    private static func drawMetadataLine(
        left: String,
        right: String,
        color: CGColor,
        y: CGFloat,
        rect: CGRect,
        context: CGContext
    ) {
        let font = CTFontCreateUIFontForLanguage(.smallSystem, max(10, rect.width * 0.0095), nil)
            ?? CTFontCreateWithName("Helvetica" as CFString, 12, nil)
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
            NSAttributedString.Key(kCTKernAttributeName as String): 0.4,
        ]
        drawSingleLine(left, attributes: attributes, origin: CGPoint(x: rect.minX, y: y), context: context)

        guard !right.isEmpty else { return }
        let attributed = NSAttributedString(string: right, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attributed)
        let width = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
        context.textPosition = CGPoint(x: max(rect.midX, rect.maxX - width), y: y)
        CTLineDraw(line, context)
    }

    private static func drawSingleLine(
        _ text: String,
        attributes: [NSAttributedString.Key: Any],
        origin: CGPoint,
        context: CGContext
    ) {
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
        context.textMatrix = .identity
        context.textPosition = origin
        CTLineDraw(line, context)
    }

    private static func drawBackground(
        _ background: PreviewBackground,
        in rect: CGRect,
        context: CGContext
    ) {
        switch background {
        case .dark:
            context.setFillColor(Palette.ink.cgColor)
            context.fill(rect)
        case .light:
            context.setFillColor(Palette.paper.cgColor)
            context.fill(rect)
        case .split:
            context.setFillColor(Palette.ink.cgColor)
            context.fill(CGRect(x: rect.minX, y: rect.minY, width: rect.width / 2, height: rect.height))
            context.setFillColor(Palette.paper.cgColor)
            context.fill(CGRect(x: rect.midX, y: rect.minY, width: rect.width / 2, height: rect.height))
        }
    }

    private static func drawTileShell(in rect: CGRect, context: CGContext) {
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -8), blur: 24, color: NSColor.black.withAlphaComponent(0.24).cgColor)
        context.setFillColor(NSColor.black.withAlphaComponent(0.20).cgColor)
        context.addPath(CGPath(roundedRect: rect, cornerWidth: 22, cornerHeight: 22, transform: nil))
        context.fillPath()
        context.restoreGState()
    }

    private static func drawEmptyTile(in rect: CGRect, context: CGContext) {
        context.setFillColor(Palette.empty.cgColor)
        context.addPath(CGPath(roundedRect: rect, cornerWidth: 20, cornerHeight: 20, transform: nil))
        context.fillPath()
        let font = CTFontCreateUIFontForLanguage(.system, 18, nil)
            ?? CTFontCreateWithName("Helvetica" as CFString, 18, nil)
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): Palette.emptyText.cgColor,
        ]
        let label = "Empty comparison slot"
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: label, attributes: attributes))
        let width = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
        context.textPosition = CGPoint(x: rect.midX - width / 2, y: rect.midY)
        CTLineDraw(line, context)
    }

    private static func clipRounded(
        _ rect: CGRect,
        radius: CGFloat,
        context: CGContext,
        draw: () -> Void
    ) {
        context.saveGState()
        context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
        context.clip()
        draw()
        context.restoreGState()
    }

    private static func sequence(page: Int, slot: Int, fourUp: Bool) -> String {
        if fourUp { return String(format: "%02d.%d", page, slot) }
        return String(format: "%02d", page)
    }

    private static func formatAxis(_ value: Double) -> String {
        if abs(value.rounded() - value) < 0.01 { return String(Int(value.rounded())) }
        return String(format: "%.1f", value)
    }
}

private enum Palette {
    static let ink = NSColor(calibratedWhite: 0.055, alpha: 1)
    static let inkMuted = NSColor(calibratedWhite: 0.28, alpha: 1).cgColor
    static let paper = NSColor(calibratedRed: 0.965, green: 0.952, blue: 0.925, alpha: 1)
    static let paperMuted = NSColor(calibratedRed: 0.74, green: 0.72, blue: 0.68, alpha: 1).cgColor
    static let canvas = NSColor(calibratedWhite: 0.025, alpha: 1)
    static let empty = NSColor(calibratedWhite: 0.10, alpha: 1)
    static let emptyText = NSColor(calibratedWhite: 0.48, alpha: 1)
}
