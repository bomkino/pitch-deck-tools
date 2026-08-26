import AppKit
import FontPreviewerCore
import FontPreviewerMacKit
import Foundation
import ImageIO

@main
struct FontPreviewerSmoke {
    static func main() async throws {
        let output = outputDirectory()
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: output)
        try fileManager.createDirectory(at: output, withIntermediateDirectories: true)

        let roots = [
            URL(fileURLWithPath: "/System/Library/Fonts", isDirectory: true),
            URL(fileURLWithPath: "/Library/Fonts", isDirectory: true),
        ]
        let candidates = Array(FontCatalog.fontURLs(from: roots, maximumFiles: 80).prefix(16))
        guard !candidates.isEmpty else { throw SmokeError.noSystemFonts }
        let imported = FontCatalog.importFaces(from: candidates, projectURL: nil, maximumFiles: 16)
        guard imported.records.count >= 2 else { throw SmokeError.insufficientFaces(imported.failures.map(\.reason)) }

        var records = Array(imported.records.prefix(4))
        for index in records.indices {
            records[index].status = .keep
            records[index].role = index == 0 ? .display : (index == 1 ? .body : .accent)
        }
        let selectedIDs = Set(records.map(\.id))
        let runtimes = imported.runtimes.filter { selectedIDs.contains($0.key) }

        var study = FontStudy(
            title: "Native macOS smoke",
            sampleText: "The Future Was Already Here",
            samplePreset: .titleSlide,
            specimenKind: .display,
            background: .split,
            layout: .compare,
            alignment: .leading,
            tracking: -0.018,
            lineHeight: 1.08,
            comparisonIDs: records.map(\.id),
            pairingHeadingID: records[0].id,
            pairingBodyID: records[1].id,
            records: records
        )

        let full = try await BoardExporter.export(
            study: study,
            projectURL: nil,
            runtimeFonts: runtimes,
            options: .init(
                destinationDirectory: output,
                canvasPreset: .cinema,
                formats: [.png, .pdf, .json, .markdown],
                selection: .init(statuses: [.keep]),
                acknowledgesFontCopyingPermission: false
            )
        )
        try verifyFullExport(full.folderURL)

        for mode in [PreviewMode.waterfall, .metrics, .glyphs, .pairing] {
            study.layout = mode
            study.title = "Smoke \(mode.label)"
            let result = try await BoardExporter.export(
                study: study,
                projectURL: nil,
                runtimeFonts: runtimes,
                options: .init(
                    destinationDirectory: output,
                    canvasPreset: .slideHD,
                    formats: [.png],
                    selection: .init(statuses: [.keep])
                )
            )
            guard firstFile(withExtension: "png", under: result.folderURL) != nil else {
                throw SmokeError.missingOutput("PNG for \(mode.label)")
            }
        }

        print("FONT_PREVIEWER_SMOKE_OK \(output.path)")
    }

    private static func outputDirectory() -> URL {
        let arguments = CommandLine.arguments
        if let index = arguments.firstIndex(of: "--output"), arguments.indices.contains(index + 1) {
            return URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        }
        return FileManager.default.temporaryDirectory.appendingPathComponent("font-previewer-smoke", isDirectory: true)
    }

    private static func verifyFullExport(_ folder: URL) throws {
        guard let png = firstFile(withExtension: "png", under: folder) else {
            throw SmokeError.missingOutput("PNG board")
        }
        guard let source = CGImageSourceCreateWithURL(png as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width == 2_576,
              height == 1_080
        else { throw SmokeError.invalidPNGDimensions }

        guard let pdf = firstFile(withExtension: "pdf", under: folder),
              (try? pdf.resourceValues(forKeys: [.fileSizeKey]).fileSize).map({ $0 > 2_000 }) == true
        else { throw SmokeError.missingOutput("non-empty PDF") }

        let manifestURL = folder.appendingPathComponent("font-review.json")
        guard let manifest = try? String(contentsOf: manifestURL, encoding: .utf8) else {
            throw SmokeError.missingOutput("JSON handoff")
        }
        if manifest.contains("/System/Library/Fonts") || manifest.contains("/Library/Fonts") {
            throw SmokeError.pathLeak
        }
        guard FileManager.default.fileExists(atPath: folder.appendingPathComponent("FONT-REVIEW.md").path) else {
            throw SmokeError.missingOutput("Markdown handoff")
        }
    }

    private static func firstFile(withExtension fileExtension: String, under root: URL) -> URL? {
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else { return nil }
        for case let url as URL in enumerator where url.pathExtension.lowercased() == fileExtension.lowercased() {
            return url
        }
        return nil
    }
}

enum SmokeError: LocalizedError {
    case noSystemFonts
    case insufficientFaces([String])
    case missingOutput(String)
    case invalidPNGDimensions
    case pathLeak

    var errorDescription: String? {
        switch self {
        case .noSystemFonts: return "No supported macOS system fonts were found."
        case .insufficientFaces(let failures): return "Fewer than two system font faces loaded. \(failures.prefix(4).joined(separator: "; "))"
        case .missingOutput(let name): return "Smoke test did not produce \(name)."
        case .invalidPNGDimensions: return "Smoke PNG was not 2576 × 1080."
        case .pathLeak: return "Privacy-default manifest leaked a system font path."
        }
    }
}
