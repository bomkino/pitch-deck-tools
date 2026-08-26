import AppKit
import Foundation
import Darwin

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    fputs("Usage: make_icon.swift <AppIcon.iconset>\n", stderr)
    exit(64)
}

let output = URL(fileURLWithPath: arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

let pointSizes = [16, 32, 128, 256, 512]
for points in pointSizes {
    for scale in [1, 2] {
        let pixels = points * scale
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixels,
            pixelsHigh: pixels,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { throw IconError.bitmap }
        bitmap.size = NSSize(width: pixels, height: pixels)

        NSGraphicsContext.saveGraphicsState()
        guard let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else { throw IconError.context }
        NSGraphicsContext.current = graphics
        graphics.imageInterpolation = .high

        let bounds = NSRect(x: 0, y: 0, width: pixels, height: pixels)
        let radius = CGFloat(pixels) * 0.22
        let shape = NSBezierPath(roundedRect: bounds.insetBy(dx: CGFloat(pixels) * 0.025, dy: CGFloat(pixels) * 0.025), xRadius: radius, yRadius: radius)
        let gradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.055, green: 0.058, blue: 0.075, alpha: 1),
            NSColor(calibratedRed: 0.015, green: 0.016, blue: 0.022, alpha: 1),
        ])!
        gradient.draw(in: shape, angle: -58)

        NSGraphicsContext.saveGraphicsState()
        shape.addClip()
        let line = NSBezierPath()
        line.lineWidth = max(1, CGFloat(pixels) * 0.006)
        NSColor.white.withAlphaComponent(0.08).setStroke()
        for fraction in [0.25, 0.5, 0.75] {
            let value = CGFloat(pixels) * fraction
            line.move(to: NSPoint(x: value, y: CGFloat(pixels) * 0.08))
            line.line(to: NSPoint(x: value, y: CGFloat(pixels) * 0.92))
            line.move(to: NSPoint(x: CGFloat(pixels) * 0.08, y: value))
            line.line(to: NSPoint(x: CGFloat(pixels) * 0.92, y: value))
        }
        line.stroke()
        NSGraphicsContext.restoreGraphicsState()

        let font = NSFont.systemFont(ofSize: CGFloat(pixels) * 0.48, weight: .semibold)
        let text = "Aa" as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(calibratedRed: 0.965, green: 0.952, blue: 0.925, alpha: 1),
            .kern: CGFloat(pixels) * -0.02,
        ]
        let size = text.size(withAttributes: attributes)
        text.draw(
            at: NSPoint(x: (CGFloat(pixels) - size.width) / 2, y: (CGFloat(pixels) - size.height) / 2 + CGFloat(pixels) * 0.015),
            withAttributes: attributes
        )

        let dotRect = NSRect(
            x: CGFloat(pixels) * 0.76,
            y: CGFloat(pixels) * 0.76,
            width: CGFloat(pixels) * 0.095,
            height: CGFloat(pixels) * 0.095
        )
        NSColor(calibratedRed: 0.25, green: 0.80, blue: 0.50, alpha: 1).setFill()
        NSBezierPath(ovalIn: dotRect).fill()

        graphics.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()

        guard let data = bitmap.representation(using: .png, properties: [:]) else { throw IconError.png }
        let suffix = scale == 2 ? "@2x" : ""
        try data.write(to: output.appendingPathComponent("icon_\(points)x\(points)\(suffix).png"))
    }
}

enum IconError: Error { case bitmap, context, png }
