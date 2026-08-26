import AppKit
import CoreGraphics
import Foundation
import FontPreviewerCore
import ImageIO
import UniformTypeIdentifiers

public struct ExportOptions: Sendable {
    public var destinationDirectory: URL
    public var canvasPreset: CanvasPreset
    public var formats: Set<StudyExportFormat>
    public var selection: StudyExportSelection
    public var acknowledgesFontCopyingPermission: Bool

    public init(
        destinationDirectory: URL,
        canvasPreset: CanvasPreset = .cinema,
        formats: Set<StudyExportFormat> = [.png, .pdf, .json, .markdown],
        selection: StudyExportSelection = .init(),
        acknowledgesFontCopyingPermission: Bool = false
    ) {
        self.destinationDirectory = destinationDirectory
        self.canvasPreset = canvasPreset
        self.formats = formats
        self.selection = selection
        self.acknowledgesFontCopyingPermission = acknowledgesFontCopyingPermission
    }
}

public struct ExportProgress: Equatable, Sendable {
    public var completed: Int
    public var total: Int
    public var message: String

    public init(completed: Int, total: Int, message: String) {
        self.completed = completed
        self.total = total
        self.message = message
    }

    public var fraction: Double {
        guard total > 0 else { return 0 }
        return min(1, max(0, Double(completed) / Double(total)))
    }
}

public struct ExportResult: Sendable {
    public var folderURL: URL
    public var pageCount: Int
    public var recordCount: Int

    public init(folderURL: URL, pageCount: Int, recordCount: Int) {
        self.folderURL = folderURL
        self.pageCount = pageCount
        self.recordCount = recordCount
    }
}

public enum BoardExporterError: LocalizedError {
    case noSelectedFonts
    case missingRuntime(String)
    case sourceFontMissing(String)
    case fontCopyPermissionRequired
    case couldNotCreateBitmap
    case couldNotCreateImage
    case couldNotCreateDestination
    case couldNotCreatePDF

    public var errorDescription: String? {
        switch self {
        case .noSelectedFonts:
            return "No fonts match the selected review states."
        case .missingRuntime(let name):
            return "\(name) is not currently renderable. Relink or reload its source before exporting."
        case .sourceFontMissing(let name):
            return "The source file for \(name) is missing."
        case .fontCopyPermissionRequired:
            return "Confirm that you have permission to copy the selected source font files."
        case .couldNotCreateBitmap:
            return "The app could not allocate a bitmap for the requested export size."
        case .couldNotCreateImage:
            return "The rendered board could not be converted into an image."
        case .couldNotCreateDestination:
            return "The PNG destination could not be created."
        case .couldNotCreatePDF:
            return "The PDF destination could not be created."
        }
    }
}

public enum BoardExporter {
    public static func export(
        study: FontStudy,
        projectURL: URL?,
        runtimeFonts: [UUID: RuntimeFontFace],
        options: ExportOptions,
        progress: @escaping @Sendable (ExportProgress) -> Void = { _ in }
    ) async throws -> ExportResult {
        let fileManager = FileManager.default
        let records = StudyExportPlanner.selectedRecords(from: study, selection: options.selection)
        guard !records.isEmpty else { throw BoardExporterError.noSelectedFonts }
        if options.selection.includeFontCopies && !options.acknowledgesFontCopyingPermission {
            throw BoardExporterError.fontCopyPermissionRequired
        }
        for record in records {
            guard runtimeFonts[record.id] != nil else { throw BoardExporterError.missingRuntime(record.displayName) }
            if options.selection.includeFontCopies {
                let source = StudyPathResolver.resolvedURL(for: record.sourcePath, projectURL: projectURL)
                guard fileManager.fileExists(atPath: source.path) else {
                    throw BoardExporterError.sourceFontMissing(record.displayName)
                }
            }
        }

        let pages: [StudyExportPage]
        if study.layout == .pairing {
            pages = [StudyExportPage(index: 1, records: records)]
        } else {
            pages = StudyExportPlanner.pages(for: records, mode: study.layout)
        }
        let destinationDirectory = options.destinationDirectory.standardizedFileURL
        try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
        let finalURL = StudyExportPlanner.uniqueURL(
            for: destinationDirectory.appendingPathComponent(
                StudyExportPlanner.exportFolderName(studyTitle: study.title),
                isDirectory: true
            )
        )
        let stagingURL = destinationDirectory.appendingPathComponent(
            ".font-previewer-export-\(UUID().uuidString)",
            isDirectory: true
        )
        try fileManager.createDirectory(at: stagingURL, withIntermediateDirectories: true)
        var committed = false
        defer {
            if !committed { try? fileManager.removeItem(at: stagingURL) }
        }

        let total = max(1,
            (options.formats.contains(.png) ? pages.count : 0)
            + (options.formats.contains(.pdf) ? pages.count : 0)
            + (options.formats.contains(.json) ? 1 : 0)
            + (options.formats.contains(.markdown) ? 1 : 0)
            + (options.selection.includeFontCopies ? Set(records.map(\.sourcePath)).count : 0)
        )
        var completed = 0
        progress(.init(completed: completed, total: total, message: "Preparing export"))
        let size = CGSize(width: options.canvasPreset.width, height: options.canvasPreset.height)

        if options.formats.contains(.png) {
            let boardsURL = stagingURL.appendingPathComponent("Boards", isDirectory: true)
            try fileManager.createDirectory(at: boardsURL, withIntermediateDirectories: true)
            for page in pages {
                try Task<Never, Never>.checkCancellation()
                let url = boardsURL.appendingPathComponent(
                    StudyExportPlanner.boardFileName(
                        studyTitle: study.title,
                        pageIndex: page.index,
                        extension: "png"
                    )
                )
                try renderPNG(
                    to: url,
                    study: study,
                    page: page,
                    runtimeFonts: runtimeFonts,
                    size: size
                )
                completed += 1
                progress(.init(completed: completed, total: total, message: "Rendered PNG \(page.index) of \(pages.count)"))
            }
        }

        if options.formats.contains(.pdf) {
            let pdfURL = stagingURL.appendingPathComponent("\(StudyExportPlanner.slug(study.title))-boards.pdf")
            try renderPDF(
                to: pdfURL,
                study: study,
                pages: pages,
                runtimeFonts: runtimeFonts,
                size: size,
                onPage: { index in
                    completed += 1
                    progress(.init(completed: completed, total: total, message: "Rendered PDF page \(index) of \(pages.count)"))
                }
            )
        }

        let manifest = HandoffBuilder.manifest(
            study: study,
            records: records,
            projectURL: projectURL,
            includeAbsoluteSourcePaths: options.selection.includeAbsoluteSourcePaths
        )
        if options.formats.contains(.json) {
            try Task<Never, Never>.checkCancellation()
            try HandoffBuilder.encodeJSON(manifest).write(
                to: stagingURL.appendingPathComponent("font-review.json"),
                options: [.atomic]
            )
            completed += 1
            progress(.init(completed: completed, total: total, message: "Wrote JSON handoff"))
        }
        if options.formats.contains(.markdown) {
            try Task<Never, Never>.checkCancellation()
            try HandoffBuilder.markdown(manifest).write(
                to: stagingURL.appendingPathComponent("FONT-REVIEW.md"),
                atomically: true,
                encoding: .utf8
            )
            completed += 1
            progress(.init(completed: completed, total: total, message: "Wrote Markdown handoff"))
        }

        if options.selection.includeFontCopies {
            let fontsURL = stagingURL.appendingPathComponent("Source Fonts", isDirectory: true)
            try fileManager.createDirectory(at: fontsURL, withIntermediateDirectories: true)
            var copied: Set<String> = []
            for record in records {
                try Task<Never, Never>.checkCancellation()
                let source = StudyPathResolver.resolvedURL(for: record.sourcePath, projectURL: projectURL)
                    .standardizedFileURL
                    .resolvingSymlinksInPath()
                guard copied.insert(source.path).inserted else { continue }
                let target = StudyExportPlanner.uniqueURL(for: fontsURL.appendingPathComponent(source.lastPathComponent))
                try fileManager.copyItem(at: source, to: target)
                completed += 1
                progress(.init(completed: completed, total: total, message: "Copied \(source.lastPathComponent)"))
            }
        }

        try Task<Never, Never>.checkCancellation()
        try fileManager.moveItem(at: stagingURL, to: finalURL)
        committed = true
        progress(.init(completed: total, total: total, message: "Export complete"))
        return ExportResult(folderURL: finalURL, pageCount: pages.count, recordCount: records.count)
    }

    private static func renderPNG(
        to url: URL,
        study: FontStudy,
        page: StudyExportPage,
        runtimeFonts: [UUID: RuntimeFontFace],
        size: CGSize
    ) throws {
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
        else { throw BoardExporterError.couldNotCreateBitmap }
        BoardRenderer.drawBoard(
            study: study,
            records: page.records,
            runtimeFonts: runtimeFonts,
            pageIndex: page.index,
            size: size,
            context: context
        )
        guard let image = context.makeImage() else { throw BoardExporterError.couldNotCreateImage }
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else { throw BoardExporterError.couldNotCreateDestination }
        CGImageDestinationAddImage(destination, image, [kCGImagePropertyDPIWidth: 144, kCGImagePropertyDPIHeight: 144] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw BoardExporterError.couldNotCreateDestination }
    }

    private static func renderPDF(
        to url: URL,
        study: FontStudy,
        pages: [StudyExportPage],
        runtimeFonts: [UUID: RuntimeFontFace],
        size: CGSize,
        onPage: (Int) -> Void
    ) throws {
        var mediaBox = CGRect(origin: .zero, size: size)
        guard let context = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else {
            throw BoardExporterError.couldNotCreatePDF
        }
        for page in pages {
            try Task<Never, Never>.checkCancellation()
            context.beginPDFPage(nil)
            BoardRenderer.drawBoard(
                study: study,
                records: page.records,
                runtimeFonts: runtimeFonts,
                pageIndex: page.index,
                size: size,
                context: context
            )
            context.endPDFPage()
            onPage(page.index)
        }
        context.closePDF()
    }
}
