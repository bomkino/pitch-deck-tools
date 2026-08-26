import AppKit
import CoreGraphics
import CoreText
import Foundation
import FontPreviewerCore

public enum BoardRenderer {
    public static let defaultBoardSize = CGSize(width: 2_576, height: 1_080)

    public static func drawBoard(
        study: FontStudy,
        records: [FontFaceRecord],
        runtimeFonts: [UUID: RuntimeFontFace],
        pageIndex: Int,
        size: CGSize = defaultBoardSize,
        context: CGContext
    ) {
        let bounds = CGRect(origin: .zero, size: size)
        fill(Palette.canvas, rect: bounds, context: context)

        switch study.layout {
        case .compare:
            drawComparison(
                study: study,
                records: Array(records.prefix(4)),
                runtimeFonts: runtimeFonts,
                pageIndex: pageIndex,
                in: bounds,
                context: context
            )
        case .waterfall:
            drawSceneShell(in: bounds, context: context) { sceneRect in
                if let record = records.first, let runtime = runtimeFonts[record.id] {
                    drawWaterfall(record: record, runtime: runtime, study: study, in: sceneRect, context: context)
                } else { drawEmpty(in: sceneRect, context: context) }
            }
        case .metrics:
            drawSceneShell(in: bounds, context: context) { sceneRect in
                if let record = records.first, let runtime = runtimeFonts[record.id] {
                    drawMetrics(record: record, runtime: runtime, study: study, in: sceneRect, context: context)
                } else { drawEmpty(in: sceneRect, context: context) }
            }
        case .glyphs:
            drawSceneShell(in: bounds, context: context) { sceneRect in
                if let record = records.first, let runtime = runtimeFonts[record.id] {
                    drawGlyphGrid(record: record, runtime: runtime, study: study, in: sceneRect, context: context)
                } else { drawEmpty(in: sceneRect, context: context) }
            }
        case .pairing:
            drawSceneShell(in: bounds, context: context) { sceneRect in
                let pair = StudyLogic.pairingRecords(in: study)
                if let heading = pair.heading,
                   let body = pair.body,
                   let headingRuntime = runtimeFonts[heading.id],
                   let bodyRuntime = runtimeFonts[body.id] {
                    drawPairing(
                        heading: heading,
                        headingRuntime: headingRuntime,
                        body: body,
                        bodyRuntime: bodyRuntime,
                        study: study,
                        in: sceneRect,
                        context: context
                    )
                } else { drawEmpty(in: sceneRect, context: context, label: "Assign display and body fonts to test a pairing") }
            }
        case .review, .focus:
            drawSceneShell(in: bounds, context: context) { sceneRect in
                if let record = records.first, let runtime = runtimeFonts[record.id] {
                    drawSpecimen(
                        record: record,
                        runtime: runtime,
                        study: study,
                        sequenceLabel: String(format: "%02d", pageIndex),
                        in: sceneRect,
                        context: context
                    )
                } else { drawEmpty(in: sceneRect, context: context) }
            }
        }
    }

    public static func drawSpecimen(
        record: FontFaceRecord,
        runtime: RuntimeFontFace,
        study: FontStudy,
        sequenceLabel: String? = nil,
        in rect: CGRect,
        context: CGContext
    ) {
        context.saveGState()
        defer { context.restoreGState() }
        configure(context)
        drawBackground(study.background, in: rect, context: context)

        let metadataHeight: CGFloat = study.showMetadata ? max(48, rect.height * 0.09) : 0
        let horizontalInset = max(22, rect.width * 0.05)
        let verticalInset = max(22, rect.height * 0.055)
        let textRect = CGRect(
            x: rect.minX + horizontalInset,
            y: rect.minY + verticalInset,
            width: max(20, rect.width - horizontalInset * 2),
            height: max(20, rect.height - verticalInset * 2 - metadataHeight)
        )
        let transformed = SpecimenTextTransform.apply(record.casing, to: study.sampleText)
        drawTextAcrossBackground(
            transformed,
            record: record,
            runtime: runtime,
            study: study,
            rect: textRect,
            context: context
        )

        if study.showGuides { drawLayoutGuides(in: textRect, background: study.background, context: context) }
        if study.showMetadata {
            drawMetadata(
                record: record,
                runtime: runtime,
                study: study,
                sequenceLabel: sequenceLabel,
                in: rect,
                context: context
            )
        }
    }

    public static func drawWaterfall(
        record: FontFaceRecord,
        runtime: RuntimeFontFace,
        study: FontStudy,
        in rect: CGRect,
        context: CGContext
    ) {
        configure(context)
        drawBackground(study.background, in: rect, context: context)
        let transformed = SpecimenTextTransform.apply(record.casing, to: study.sampleText)
        let sizes = PresetLibrary.waterfallSizes
        let inset = max(26, rect.width * 0.042)
        let headerHeight = max(64, rect.height * 0.10)
        let content = CGRect(x: rect.minX + inset, y: rect.minY + inset, width: rect.width - inset * 2, height: rect.height - inset * 2 - headerHeight)
        let rowHeight = content.height / CGFloat(sizes.count)

        drawHeader(
            title: "Waterfall · \(record.displayName)",
            detail: axisSummary(record),
            background: study.background,
            in: CGRect(x: rect.minX + inset, y: rect.maxY - inset - headerHeight, width: rect.width - inset * 2, height: headerHeight),
            context: context
        )

        for (index, rawSize) in sizes.enumerated() {
            let row = CGRect(
                x: content.minX,
                y: content.maxY - CGFloat(index + 1) * rowHeight,
                width: content.width,
                height: rowHeight
            )
            let labelWidth = max(58, rect.width * 0.045)
            drawSystemLine(
                "\(Int(rawSize))",
                size: max(10, min(15, rowHeight * 0.32)),
                color: colorForMetadata(study.background, lightSide: false),
                origin: CGPoint(x: row.minX, y: row.midY - 5),
                maxWidth: labelWidth,
                context: context
            )
            let textRect = CGRect(x: row.minX + labelWidth, y: row.minY, width: row.width - labelWidth, height: row.height)
            drawTextAcrossBackground(
                transformed,
                record: record,
                runtime: runtime,
                study: study,
                rect: textRect,
                context: context,
                pointSizeOverride: CGFloat(rawSize) * max(0.72, rect.width / 2_576)
            )
            if index < sizes.count - 1 {
                strokeHorizontal(y: row.minY, in: content, color: Palette.guide, context: context)
            }
        }
    }

    public static func drawMetrics(
        record: FontFaceRecord,
        runtime: RuntimeFontFace,
        study: FontStudy,
        in rect: CGRect,
        context: CGContext
    ) {
        configure(context)
        drawBackground(study.background, in: rect, context: context)
        let inset = max(30, rect.width * 0.05)
        let pointSize = min(rect.height * 0.40, rect.width * 0.18)
        let font = runtime.makeFont(
            size: pointSize,
            variations: record.axisValues,
            featureSelections: record.featureSelections
        )
        let sample = "Hpxag"
        let line = textLine(sample, font: font, color: Palette.paper, tracking: pointSize * study.tracking)
        let lineWidth = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
        let baseline = rect.midY - pointSize * 0.12
        let originX = rect.midX - lineWidth / 2

        drawHeader(
            title: "Metrics · \(record.displayName)",
            detail: "UPM \(record.metrics.unitsPerEm) · \(record.metrics.glyphCount) glyphs",
            background: study.background,
            in: CGRect(x: rect.minX + inset, y: rect.maxY - inset - 64, width: rect.width - inset * 2, height: 64),
            context: context
        )

        let guides: [(String, CGFloat, NSColor)] = [
            ("ascent", baseline + CTFontGetAscent(font), Palette.blue),
            ("cap", baseline + CTFontGetCapHeight(font), Palette.green),
            ("x-height", baseline + CTFontGetXHeight(font), Palette.orange),
            ("baseline", baseline, Palette.paperMutedColor),
            ("descent", baseline - CTFontGetDescent(font), Palette.red),
        ]
        for (label, y, color) in guides {
            strokeHorizontal(y: y, in: rect.insetBy(dx: inset, dy: 0), color: color.withAlphaComponent(0.55).cgColor, context: context)
            drawSystemLine(
                label,
                size: 12,
                color: color.cgColor,
                origin: CGPoint(x: rect.minX + inset, y: y + 6),
                maxWidth: 90,
                context: context
            )
        }

        drawLineAcrossBackground(
            line,
            darkLine: textLine(sample, font: font, color: Palette.paper, tracking: pointSize * study.tracking),
            lightLine: textLine(sample, font: font, color: Palette.ink, tracking: pointSize * study.tracking),
            origin: CGPoint(x: originX, y: baseline),
            background: study.background,
            rect: rect,
            context: context
        )

        let footer = [
            "Ascent \(format(CTFontGetAscent(font)))",
            "Descent \(format(CTFontGetDescent(font)))",
            "Cap \(format(CTFontGetCapHeight(font)))",
            "x-height \(format(CTFontGetXHeight(font)))",
            "Leading \(format(CTFontGetLeading(font)))",
            "Slant \(format(CTFontGetSlantAngle(font)))°",
        ].joined(separator: "   ·   ")
        drawSystemLine(
            footer,
            size: 13,
            color: colorForMetadata(study.background, lightSide: false),
            origin: CGPoint(x: rect.minX + inset, y: rect.minY + inset),
            maxWidth: rect.width - inset * 2,
            context: context
        )
    }

    public static func drawGlyphGrid(
        record: FontFaceRecord,
        runtime: RuntimeFontFace,
        study: FontStudy,
        in rect: CGRect,
        context: CGContext
    ) {
        configure(context)
        drawBackground(study.background, in: rect, context: context)
        let inset = max(24, rect.width * 0.035)
        let headerHeight = max(70, rect.height * 0.10)
        let gridRect = CGRect(
            x: rect.minX + inset,
            y: rect.minY + inset,
            width: rect.width - inset * 2,
            height: rect.height - inset * 2 - headerHeight
        )
        drawHeader(
            title: "Glyphs · \(record.displayName)",
            detail: "\(record.metrics.glyphCount) glyphs · coverage probes \(record.coverage.supportedScalarCount)",
            background: study.background,
            in: CGRect(x: gridRect.minX, y: gridRect.maxY, width: gridRect.width, height: headerHeight),
            context: context
        )

        var seen: Set<String> = []
        let characters = (PresetLibrary.glyphGridText + study.sampleText).map(String.init).filter { seen.insert($0).inserted }
        let columns = 12
        let rows = 5
        let visible = Array(characters.prefix(columns * rows))
        let cellWidth = gridRect.width / CGFloat(columns)
        let cellHeight = gridRect.height / CGFloat(rows)
        let fontSize = min(cellHeight * 0.52, cellWidth * 0.56)
        let font = runtime.makeFont(size: fontSize, variations: record.axisValues, featureSelections: record.featureSelections)

        for index in 0..<(columns * rows) {
            let column = index % columns
            let row = index / columns
            let cell = CGRect(
                x: gridRect.minX + CGFloat(column) * cellWidth,
                y: gridRect.maxY - CGFloat(row + 1) * cellHeight,
                width: cellWidth,
                height: cellHeight
            )
            context.setStrokeColor(Palette.guide)
            context.setLineWidth(1)
            context.stroke(cell)
            guard visible.indices.contains(index) else { continue }
            let character = visible[index]
            let missing = runtime.missingScalars(
                in: character,
                variations: record.axisValues,
                featureSelections: record.featureSelections
            ).isEmpty == false
            let dark = textLine(character, font: font, color: missing ? Palette.red.cgColor : Palette.paper, tracking: 0)
            let light = textLine(character, font: font, color: missing ? Palette.red.cgColor : Palette.ink, tracking: 0)
            let width = CGFloat(CTLineGetTypographicBounds(dark, nil, nil, nil))
            drawLineAcrossBackground(
                dark,
                darkLine: dark,
                lightLine: light,
                origin: CGPoint(x: cell.midX - width / 2, y: cell.midY - fontSize * 0.28),
                background: study.background,
                rect: cell,
                context: context
            )
            let code = character.unicodeScalars.map { String(format: "U+%04X", $0.value) }.joined(separator: "+")
            drawSystemLine(
                code,
                size: max(8, min(11, cellHeight * 0.10)),
                color: colorForMetadata(study.background, lightSide: cell.midX > rect.midX),
                origin: CGPoint(x: cell.minX + 8, y: cell.minY + 8),
                maxWidth: cell.width - 16,
                context: context
            )
        }
    }

    public static func drawPairing(
        heading: FontFaceRecord,
        headingRuntime: RuntimeFontFace,
        body: FontFaceRecord,
        bodyRuntime: RuntimeFontFace,
        study: FontStudy,
        in rect: CGRect,
        context: CGContext
    ) {
        configure(context)
        drawBackground(study.background, in: rect, context: context)
        let inset = max(42, rect.width * 0.065)
        let content = rect.insetBy(dx: inset, dy: inset)
        let kickerRect = CGRect(x: content.minX, y: content.maxY - content.height * 0.12, width: content.width, height: content.height * 0.08)
        let headingRect = CGRect(x: content.minX, y: content.minY + content.height * 0.43, width: content.width * 0.82, height: content.height * 0.40)
        let bodyRect = CGRect(x: content.minX, y: content.minY + content.height * 0.12, width: content.width * 0.58, height: content.height * 0.25)

        var kickerStudy = study
        kickerStudy.sampleText = "TYPE PAIRING · DECK-STAGE TEST"
        kickerStudy.specimenKind = .micro
        kickerStudy.tracking = 0.08
        drawTextAcrossBackground(
            kickerStudy.sampleText,
            record: body,
            runtime: bodyRuntime,
            study: kickerStudy,
            rect: kickerRect,
            context: context,
            pointSizeOverride: max(13, rect.width * 0.009)
        )

        var headingStudy = study
        headingStudy.specimenKind = .display
        headingStudy.alignment = .leading
        drawTextAcrossBackground(
            SpecimenTextTransform.apply(heading.casing, to: study.sampleText),
            record: heading,
            runtime: headingRuntime,
            study: headingStudy,
            rect: headingRect,
            context: context
        )

        var bodyStudy = study
        bodyStudy.sampleText = PresetLibrary.text(for: .paragraph)
        bodyStudy.specimenKind = .paragraph
        bodyStudy.alignment = .leading
        bodyStudy.tracking = 0
        bodyStudy.lineHeight = max(1.25, study.lineHeight)
        drawTextAcrossBackground(
            SpecimenTextTransform.apply(body.casing, to: bodyStudy.sampleText),
            record: body,
            runtime: bodyRuntime,
            study: bodyStudy,
            rect: bodyRect,
            context: context,
            pointSizeOverride: max(24, rect.width * 0.016)
        )

        let meta = "DISPLAY  \(heading.displayName)     BODY  \(body.displayName)"
        drawSystemLine(
            meta,
            size: max(11, rect.width * 0.008),
            color: colorForMetadata(study.background, lightSide: false),
            origin: CGPoint(x: content.minX, y: content.minY),
            maxWidth: content.width,
            context: context
        )
    }

    private static func drawComparison(
        study: FontStudy,
        records: [FontFaceRecord],
        runtimeFonts: [UUID: RuntimeFontFace],
        pageIndex: Int,
        in bounds: CGRect,
        context: CGContext
    ) {
        let outer = max(24, bounds.width * 0.014)
        let gutter = max(16, bounds.width * 0.009)
        let tileWidth = (bounds.width - outer * 2 - gutter) / 2
        let tileHeight = (bounds.height - outer * 2 - gutter) / 2

        for slot in 0..<4 {
            let column = slot % 2
            let row = slot / 2
            let tile = CGRect(
                x: bounds.minX + outer + CGFloat(column) * (tileWidth + gutter),
                y: bounds.maxY - outer - tileHeight - CGFloat(row) * (tileHeight + gutter),
                width: tileWidth,
                height: tileHeight
            )
            drawTileShadow(in: tile, context: context)
            clipRounded(tile, radius: max(12, bounds.width * 0.007), context: context) {
                guard records.indices.contains(slot), let runtime = runtimeFonts[records[slot].id] else {
                    drawEmpty(in: tile, context: context, label: "Empty comparison slot")
                    return
                }
                drawSpecimen(
                    record: records[slot],
                    runtime: runtime,
                    study: study,
                    sequenceLabel: String(format: "%02d.%d", pageIndex, slot + 1),
                    in: tile,
                    context: context
                )
            }
        }
    }

    private static func drawSceneShell(
        in bounds: CGRect,
        context: CGContext,
        draw: (CGRect) -> Void
    ) {
        let outer = max(28, bounds.width * 0.016)
        let scene = bounds.insetBy(dx: outer, dy: outer)
        drawTileShadow(in: scene, context: context)
        clipRounded(scene, radius: max(14, bounds.width * 0.008), context: context) { draw(scene) }
    }

    private static func drawTextAcrossBackground(
        _ text: String,
        record: FontFaceRecord,
        runtime: RuntimeFontFace,
        study: FontStudy,
        rect: CGRect,
        context: CGContext,
        pointSizeOverride: CGFloat? = nil
    ) {
        guard !text.isEmpty else { return }
        let pointSize = pointSizeOverride ?? fittedPointSize(
            text: text,
            record: record,
            runtime: runtime,
            study: study,
            rect: rect
        )
        let font = runtime.makeFont(
            size: pointSize,
            variations: record.axisValues,
            featureSelections: record.featureSelections
        )
        let dark = attributed(
            text,
            font: font,
            color: Palette.paper,
            study: study,
            pointSize: pointSize
        )
        let light = attributed(
            text,
            font: font,
            color: Palette.ink,
            study: study,
            pointSize: pointSize
        )
        drawAttributedAcrossBackground(dark: dark, light: light, in: rect, background: study.background, context: context)
    }

    private static func fittedPointSize(
        text: String,
        record: FontFaceRecord,
        runtime: RuntimeFontFace,
        study: FontStudy,
        rect: CGRect
    ) -> CGFloat {
        let baseline = CGFloat(PresetLibrary.recommendedPointSize(for: study.specimenKind))
        let scale = max(0.32, min(2.8, rect.width / 1_100))
        var low = max(8, baseline * scale * 0.22)
        var high = min(rect.height * 0.86, baseline * scale * 2.6)
        for _ in 0..<14 {
            let candidate = (low + high) / 2
            if fits(text: text, record: record, runtime: runtime, study: study, pointSize: candidate, rect: rect) {
                low = candidate
            } else { high = candidate }
        }
        return floor(low * 10) / 10
    }

    private static func fits(
        text: String,
        record: FontFaceRecord,
        runtime: RuntimeFontFace,
        study: FontStudy,
        pointSize: CGFloat,
        rect: CGRect
    ) -> Bool {
        let font = runtime.makeFont(
            size: pointSize,
            variations: record.axisValues,
            featureSelections: record.featureSelections
        )
        let value = attributed(text, font: font, color: Palette.paper, study: study, pointSize: pointSize)
        let framesetter = CTFramesetterCreateWithAttributedString(value as CFAttributedString)
        let measured = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter,
            CFRange(location: 0, length: value.length),
            nil,
            CGSize(width: rect.width, height: .greatestFiniteMagnitude),
            nil
        )
        return measured.width <= rect.width + 1 && measured.height <= rect.height + 1
    }

    private static func attributed(
        _ text: String,
        font: CTFont,
        color: CGColor,
        study: FontStudy,
        pointSize: CGFloat
    ) -> NSAttributedString {
        let paragraph = paragraphStyle(alignment: study.alignment, lineHeight: study.lineHeight)
        return NSAttributedString(string: text, attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
            NSAttributedString.Key(kCTKernAttributeName as String): pointSize * CGFloat(study.tracking),
            NSAttributedString.Key(kCTParagraphStyleAttributeName as String): paragraph,
        ])
    }

    private static func paragraphStyle(alignment: TextAlignment, lineHeight: Double) -> CTParagraphStyle {
        var ctAlignment: CTTextAlignment
        switch alignment {
        case .leading: ctAlignment = .left
        case .center: ctAlignment = .center
        case .trailing: ctAlignment = .right
        case .justified: ctAlignment = .justified
        }
        var multiple = CGFloat(min(3, max(0.7, lineHeight)))
        return withUnsafePointer(to: &ctAlignment) { alignmentPointer in
            withUnsafePointer(to: &multiple) { multiplePointer in
                var settings = [
                    CTParagraphStyleSetting(
                        spec: .alignment,
                        valueSize: MemoryLayout<CTTextAlignment>.size,
                        value: alignmentPointer
                    ),
                    CTParagraphStyleSetting(
                        spec: .lineHeightMultiple,
                        valueSize: MemoryLayout<CGFloat>.size,
                        value: multiplePointer
                    ),
                ]
                return CTParagraphStyleCreate(&settings, settings.count)
            }
        }
    }

    private static func drawAttributedAcrossBackground(
        dark: NSAttributedString,
        light: NSAttributedString,
        in rect: CGRect,
        background: PreviewBackground,
        context: CGContext
    ) {
        switch background {
        case .dark: drawAttributed(dark, in: rect, context: context)
        case .light: drawAttributed(light, in: rect, context: context)
        case .split:
            context.saveGState()
            context.clip(to: CGRect(x: rect.minX, y: rect.minY, width: max(0, rect.midX - rect.minX), height: rect.height))
            drawAttributed(dark, in: rect, context: context)
            context.restoreGState()
            context.saveGState()
            context.clip(to: CGRect(x: rect.midX, y: rect.minY, width: max(0, rect.maxX - rect.midX), height: rect.height))
            drawAttributed(light, in: rect, context: context)
            context.restoreGState()
        }
    }

    private static func drawAttributed(_ value: NSAttributedString, in rect: CGRect, context: CGContext) {
        let framesetter = CTFramesetterCreateWithAttributedString(value as CFAttributedString)
        let measured = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter,
            CFRange(location: 0, length: value.length),
            nil,
            CGSize(width: rect.width, height: rect.height),
            nil
        )
        let height = min(rect.height, ceil(measured.height + 6))
        let centered = CGRect(x: rect.minX, y: rect.midY - height / 2, width: rect.width, height: height)
        let frame = CTFramesetterCreateFrame(
            framesetter,
            CFRange(location: 0, length: value.length),
            CGPath(rect: centered, transform: nil),
            nil
        )
        context.textMatrix = .identity
        CTFrameDraw(frame, context)
    }

    private static func drawMetadata(
        record: FontFaceRecord,
        runtime: RuntimeFontFace,
        study: FontStudy,
        sequenceLabel: String?,
        in rect: CGRect,
        context: CGContext
    ) {
        let inset = max(16, rect.width * 0.035)
        let baseline = rect.maxY - max(24, rect.height * 0.045)
        let transformed = SpecimenTextTransform.apply(record.casing, to: study.sampleText)
        let missing = runtime.missingScalars(
            in: transformed,
            variations: record.axisValues,
            featureSelections: record.featureSelections
        )
        let left = [sequenceLabel, record.displayName, record.role == .unassigned ? nil : record.role.label]
            .compactMap { $0 }
            .joined(separator: "  ·  ")
        let axes = axisSummary(record)
        let right = missing.isEmpty
            ? axes
            : "Missing \(missing.prefix(8).map(String.init).joined())" + (axes.isEmpty ? "" : "  ·  \(axes)")
        drawMetadataAcrossBackground(
            left: left,
            right: right,
            y: baseline,
            rect: rect.insetBy(dx: inset, dy: 0),
            background: study.background,
            context: context
        )
    }

    private static func drawMetadataAcrossBackground(
        left: String,
        right: String,
        y: CGFloat,
        rect: CGRect,
        background: PreviewBackground,
        context: CGContext
    ) {
        switch background {
        case .dark:
            drawMetadataLine(left: left, right: right, color: Palette.paperMuted, y: y, rect: rect, context: context)
        case .light:
            drawMetadataLine(left: left, right: right, color: Palette.inkMuted, y: y, rect: rect, context: context)
        case .split:
            context.saveGState()
            context.clip(to: CGRect(x: rect.minX, y: rect.minY, width: rect.midX - rect.minX, height: rect.height))
            drawMetadataLine(left: left, right: right, color: Palette.paperMuted, y: y, rect: rect, context: context)
            context.restoreGState()
            context.saveGState()
            context.clip(to: CGRect(x: rect.midX, y: rect.minY, width: rect.maxX - rect.midX, height: rect.height))
            drawMetadataLine(left: left, right: right, color: Palette.inkMuted, y: y, rect: rect, context: context)
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
        let size = max(10, min(20, rect.width * 0.0095))
        let font = systemFont(size: size, monospaced: true)
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
            NSAttributedString.Key(kCTKernAttributeName as String): 0.35,
        ]
        drawTruncatedLine(left, attributes: attributes, origin: CGPoint(x: rect.minX, y: y), maxWidth: rect.width * 0.57, context: context)
        guard !right.isEmpty else { return }
        let line = truncatedLine(right, attributes: attributes, maxWidth: rect.width * 0.40)
        let width = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
        context.textPosition = CGPoint(x: rect.maxX - width, y: y)
        CTLineDraw(line, context)
    }

    private static func drawHeader(
        title: String,
        detail: String,
        background: PreviewBackground,
        in rect: CGRect,
        context: CGContext
    ) {
        let titleColor = background == .light ? Palette.ink : Palette.paper
        let detailColor = colorForMetadata(background, lightSide: false)
        drawSystemLine(title, size: max(14, rect.height * 0.28), color: titleColor, origin: CGPoint(x: rect.minX, y: rect.midY), maxWidth: rect.width * 0.65, context: context)
        let detailLine = systemLine(detail, size: max(10, rect.height * 0.19), color: detailColor)
        let width = CGFloat(CTLineGetTypographicBounds(detailLine, nil, nil, nil))
        context.textPosition = CGPoint(x: max(rect.midX, rect.maxX - width), y: rect.midY)
        CTLineDraw(detailLine, context)
    }

    private static func drawLayoutGuides(in rect: CGRect, background: PreviewBackground, context: CGContext) {
        context.saveGState()
        context.setLineWidth(1)
        context.setLineDash(phase: 0, lengths: [6, 6])
        context.setStrokeColor(Palette.guide)
        context.stroke(rect)
        context.move(to: CGPoint(x: rect.midX, y: rect.minY))
        context.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        context.move(to: CGPoint(x: rect.minX, y: rect.midY))
        context.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        context.strokePath()
        context.restoreGState()
    }

    private static func drawBackground(_ background: PreviewBackground, in rect: CGRect, context: CGContext) {
        switch background {
        case .dark: fill(Palette.inkColor, rect: rect, context: context)
        case .light: fill(Palette.paperColor, rect: rect, context: context)
        case .split:
            fill(Palette.inkColor, rect: CGRect(x: rect.minX, y: rect.minY, width: rect.width / 2, height: rect.height), context: context)
            fill(Palette.paperColor, rect: CGRect(x: rect.midX, y: rect.minY, width: rect.width / 2, height: rect.height), context: context)
        }
    }

    private static func drawTileShadow(in rect: CGRect, context: CGContext) {
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -8), blur: 28, color: NSColor.black.withAlphaComponent(0.36).cgColor)
        fillPath(CGPath(roundedRect: rect, cornerWidth: 22, cornerHeight: 22, transform: nil), color: NSColor.black.withAlphaComponent(0.28), context: context)
        context.restoreGState()
    }

    private static func drawEmpty(in rect: CGRect, context: CGContext, label: String = "No renderable font") {
        fillPath(CGPath(roundedRect: rect, cornerWidth: 20, cornerHeight: 20, transform: nil), color: Palette.empty, context: context)
        let line = systemLine(label, size: max(14, rect.width * 0.012), color: Palette.emptyText.cgColor)
        let width = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
        context.textPosition = CGPoint(x: rect.midX - width / 2, y: rect.midY)
        CTLineDraw(line, context)
    }

    private static func drawLineAcrossBackground(
        _ line: CTLine,
        darkLine: CTLine,
        lightLine: CTLine,
        origin: CGPoint,
        background: PreviewBackground,
        rect: CGRect,
        context: CGContext
    ) {
        switch background {
        case .dark:
            context.textPosition = origin
            CTLineDraw(darkLine, context)
        case .light:
            context.textPosition = origin
            CTLineDraw(lightLine, context)
        case .split:
            context.saveGState()
            context.clip(to: CGRect(x: rect.minX, y: rect.minY, width: rect.midX - rect.minX, height: rect.height))
            context.textPosition = origin
            CTLineDraw(darkLine, context)
            context.restoreGState()
            context.saveGState()
            context.clip(to: CGRect(x: rect.midX, y: rect.minY, width: rect.maxX - rect.midX, height: rect.height))
            context.textPosition = origin
            CTLineDraw(lightLine, context)
            context.restoreGState()
        }
        _ = line
    }

    private static func textLine(_ text: String, font: CTFont, color: CGColor, tracking: CGFloat) -> CTLine {
        CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
            NSAttributedString.Key(kCTKernAttributeName as String): tracking,
        ]))
    }

    private static func systemLine(_ text: String, size: CGFloat, color: CGColor) -> CTLine {
        textLine(text, font: systemFont(size: size, monospaced: false), color: color, tracking: 0.2)
    }

    private static func drawSystemLine(
        _ text: String,
        size: CGFloat,
        color: CGColor,
        origin: CGPoint,
        maxWidth: CGFloat,
        context: CGContext
    ) {
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): systemFont(size: size, monospaced: false),
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
        ]
        drawTruncatedLine(text, attributes: attributes, origin: origin, maxWidth: maxWidth, context: context)
    }

    private static func drawTruncatedLine(
        _ text: String,
        attributes: [NSAttributedString.Key: Any],
        origin: CGPoint,
        maxWidth: CGFloat,
        context: CGContext
    ) {
        let line = truncatedLine(text, attributes: attributes, maxWidth: maxWidth)
        context.textMatrix = .identity
        context.textPosition = origin
        CTLineDraw(line, context)
    }

    private static func truncatedLine(
        _ text: String,
        attributes: [NSAttributedString.Key: Any],
        maxWidth: CGFloat
    ) -> CTLine {
        let source = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
        guard CGFloat(CTLineGetTypographicBounds(source, nil, nil, nil)) > maxWidth else { return source }
        let token = CTLineCreateWithAttributedString(NSAttributedString(string: "…", attributes: attributes))
        return CTLineCreateTruncatedLine(source, maxWidth, .end, token) ?? source
    }

    private static func systemFont(size: CGFloat, monospaced: Bool) -> CTFont {
        let name = monospaced ? "SFMono-Regular" : ".AppleSystemUIFont"
        return CTFontCreateWithName(name as CFString, size, nil)
    }

    private static func axisSummary(_ record: FontFaceRecord) -> String {
        record.axes.compactMap { axis -> String? in
            guard let value = record.axisValues[axis.identifier] else { return nil }
            return "\(axis.tag) \(format(value))"
        }.joined(separator: "  ")
    }

    private static func colorForMetadata(_ background: PreviewBackground, lightSide: Bool) -> CGColor {
        switch background {
        case .dark: return Palette.paperMuted
        case .light: return Palette.inkMuted
        case .split: return lightSide ? Palette.inkMuted : Palette.paperMuted
        }
    }

    private static func strokeHorizontal(y: CGFloat, in rect: CGRect, color: CGColor, context: CGContext) {
        context.saveGState()
        context.setStrokeColor(color)
        context.setLineWidth(1)
        context.move(to: CGPoint(x: rect.minX, y: y))
        context.addLine(to: CGPoint(x: rect.maxX, y: y))
        context.strokePath()
        context.restoreGState()
    }

    private static func clipRounded(_ rect: CGRect, radius: CGFloat, context: CGContext, draw: () -> Void) {
        context.saveGState()
        context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
        context.clip()
        draw()
        context.restoreGState()
    }

    private static func fill(_ color: NSColor, rect: CGRect, context: CGContext) {
        context.setFillColor(color.cgColor)
        context.fill(rect)
    }

    private static func fillPath(_ path: CGPath, color: NSColor, context: CGContext) {
        context.setFillColor(color.cgColor)
        context.addPath(path)
        context.fillPath()
    }

    private static func configure(_ context: CGContext) {
        context.setAllowsAntialiasing(true)
        context.setShouldAntialias(true)
        context.setShouldSmoothFonts(true)
        context.textMatrix = .identity
    }

    private static func format<T: BinaryFloatingPoint>(_ value: T) -> String {
        let double = Double(value)
        if abs(double.rounded() - double) < 0.01 { return String(Int(double.rounded())) }
        return String(format: "%.1f", double)
    }
}

private enum Palette {
    static let inkColor = NSColor(calibratedWhite: 0.050, alpha: 1)
    static let paperColor = NSColor(calibratedRed: 0.965, green: 0.952, blue: 0.925, alpha: 1)
    static let canvas = NSColor(calibratedWhite: 0.020, alpha: 1)
    static let empty = NSColor(calibratedWhite: 0.10, alpha: 1)
    static let emptyText = NSColor(calibratedWhite: 0.48, alpha: 1)
    static let blue = NSColor(calibratedRed: 0.25, green: 0.56, blue: 1.00, alpha: 1)
    static let green = NSColor(calibratedRed: 0.22, green: 0.76, blue: 0.46, alpha: 1)
    static let orange = NSColor(calibratedRed: 1.00, green: 0.55, blue: 0.20, alpha: 1)
    static let red = NSColor(calibratedRed: 0.95, green: 0.30, blue: 0.34, alpha: 1)
    static let paperMutedColor = NSColor(calibratedRed: 0.74, green: 0.72, blue: 0.68, alpha: 1)

    static let ink = inkColor.cgColor
    static let paper = paperColor.cgColor
    static let inkMuted = NSColor(calibratedWhite: 0.28, alpha: 1).cgColor
    static let paperMuted = paperMutedColor.cgColor
    static let guide = NSColor.white.withAlphaComponent(0.13).cgColor
}
