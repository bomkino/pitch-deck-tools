import AppKit
import FontPreviewerCore
@testable import FontPreviewerMacKit
import ImageIO
import XCTest

final class MacKitTests: XCTestCase {
    func testSystemFontCatalogExtractsRenderableMetadata() throws {
        guard let url = FontCatalog.firstSystemFontURL() else { throw XCTSkip("No system font candidate") }
        let result = FontCatalog.importFaces(from: [url], projectURL: nil, maximumFiles: 1)
        let record = try XCTUnwrap(result.records.first, result.failures.map(\.reason).joined(separator: "; "))
        let runtime = try XCTUnwrap(result.runtimes[record.id])
        XCTAssertFalse(record.familyName.isEmpty)
        XCTAssertGreaterThan(record.metrics.glyphCount, 0)
        XCTAssertGreaterThan(record.metrics.unitsPerEm, 0)
        XCTAssertEqual(runtime.faceIndex, record.faceIndex)
        XCTAssertNotNil(runtime.makeFont(size: 48, variations: record.axisValues))
    }

    func testRendererCreatesNonEmptyBitmapForEveryScene() throws {
        let loaded = try loadTwoFaces()
        var study = FontStudy(
            title: "Renderer test",
            comparisonIDs: loaded.records.map(\.id),
            pairingHeadingID: loaded.records[0].id,
            pairingBodyID: loaded.records[1].id,
            records: loaded.records
        )
        for mode in PreviewMode.allCases {
            study.layout = mode
            let size = CGSize(width: 1_280, height: 540)
            guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
                  let context = CGContext(
                    data: nil,
                    width: Int(size.width),
                    height: Int(size.height),
                    bitsPerComponent: 8,
                    bytesPerRow: Int(size.width) * 4,
                    space: colorSpace,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                  )
            else { return XCTFail("Could not allocate test bitmap") }
            BoardRenderer.drawBoard(
                study: study,
                records: loaded.records,
                runtimeFonts: loaded.runtimes,
                pageIndex: 1,
                size: size,
                context: context
            )
            XCTAssertNotNil(context.makeImage(), "Missing image for \(mode)")
        }
    }

    func testExporterIsDimensionallyCorrectAndPrivateByDefault() async throws {
        let loaded = try loadTwoFaces()
        var records = loaded.records
        for index in records.indices { records[index].status = .keep }
        let study = FontStudy(
            title: "Private export",
            layout: .compare,
            comparisonIDs: records.map(\.id),
            records: records
        )
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let result = try await BoardExporter.export(
            study: study,
            projectURL: nil,
            runtimeFonts: loaded.runtimes,
            options: .init(
                destinationDirectory: root,
                canvasPreset: .cinema,
                formats: [.png, .json],
                selection: .init(statuses: [.keep])
            )
        )

        let png = try XCTUnwrap(firstFile(withExtension: "png", under: result.folderURL))
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(png as CFURL, nil))
        let properties = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        XCTAssertEqual(properties[kCGImagePropertyPixelWidth] as? Int, 2_576)
        XCTAssertEqual(properties[kCGImagePropertyPixelHeight] as? Int, 1_080)
        let json = try String(contentsOf: result.folderURL.appendingPathComponent("font-review.json"), encoding: .utf8)
        XCTAssertFalse(json.contains("/System/Library/Fonts"))
        XCTAssertFalse(json.contains("/Library/Fonts"))
    }

    func testFontCopyingRequiresExplicitAcknowledgement() async throws {
        let loaded = try loadTwoFaces()
        var records = loaded.records
        records[0].status = .keep
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        do {
            _ = try await BoardExporter.export(
                study: FontStudy(records: records),
                projectURL: nil,
                runtimeFonts: loaded.runtimes,
                options: .init(
                    destinationDirectory: root,
                    formats: [.json],
                    selection: .init(statuses: [.keep], includeFontCopies: true),
                    acknowledgesFontCopyingPermission: false
                )
            )
            XCTFail("Expected permission gate")
        } catch BoardExporterError.fontCopyPermissionRequired {
            // Expected.
        }
    }

    private func loadTwoFaces() throws -> (records: [FontFaceRecord], runtimes: [UUID: RuntimeFontFace]) {
        let roots = [URL(fileURLWithPath: "/System/Library/Fonts", isDirectory: true)]
        let urls = Array(FontCatalog.fontURLs(from: roots, maximumFiles: 80).prefix(12))
        let imported = FontCatalog.importFaces(from: urls, projectURL: nil, maximumFiles: 12)
        guard imported.records.count >= 2 else { throw XCTSkip("Fewer than two system font faces") }
        let records = Array(imported.records.prefix(2))
        let ids = Set(records.map(\.id))
        return (records, imported.runtimes.filter { ids.contains($0.key) })
    }

    private func firstFile(withExtension fileExtension: String, under root: URL) -> URL? {
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else { return nil }
        for case let url as URL in enumerator where url.pathExtension.lowercased() == fileExtension.lowercased() {
            return url
        }
        return nil
    }
}
