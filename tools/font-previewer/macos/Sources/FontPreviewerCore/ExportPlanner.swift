import Foundation

public enum StudyExportFormat: String, Codable, CaseIterable, Identifiable, Sendable {
    case png
    case pdf
    case json
    case markdown

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .png: return "PNG boards"
        case .pdf: return "PDF contact sheet"
        case .json: return "JSON manifest"
        case .markdown: return "Markdown handoff"
        }
    }
}

public enum CanvasPreset: String, Codable, CaseIterable, Identifiable, Sendable {
    case slideHD
    case cinema
    case fourK
    case retinaCinema

    public var id: String { rawValue }

    public var width: Int {
        switch self {
        case .slideHD: return 1_920
        case .cinema: return 2_576
        case .fourK: return 3_840
        case .retinaCinema: return 5_152
        }
    }

    public var height: Int {
        switch self {
        case .slideHD, .fourK: return width * 9 / 16
        case .cinema, .retinaCinema: return width * 1_080 / 2_576
        }
    }

    public var label: String {
        switch self {
        case .slideHD: return "16:9 · 1920 × 1080"
        case .cinema: return "Cinema · 2576 × 1080"
        case .fourK: return "4K · 3840 × 2160"
        case .retinaCinema: return "Cinema 2× · 5152 × 2160"
        }
    }
}

public struct StudyExportSelection: Codable, Hashable, Sendable {
    public var statuses: Set<ReviewStatus>
    public var includeFontCopies: Bool
    public var includeAbsoluteSourcePaths: Bool

    public init(
        statuses: Set<ReviewStatus> = [.keep, .maybe],
        includeFontCopies: Bool = false,
        includeAbsoluteSourcePaths: Bool = false
    ) {
        self.statuses = statuses
        self.includeFontCopies = includeFontCopies
        self.includeAbsoluteSourcePaths = includeAbsoluteSourcePaths
    }
}

public struct StudyExportPage: Hashable, Identifiable, Sendable {
    public var index: Int
    public var records: [FontFaceRecord]

    public var id: Int { index }

    public init(index: Int, records: [FontFaceRecord]) {
        self.index = index
        self.records = records
    }
}

public enum StudyExportPlanner {
    public static func selectedRecords(from study: FontStudy, selection: StudyExportSelection) -> [FontFaceRecord] {
        study.records.filter { selection.statuses.contains($0.status) }
    }

    public static func pages(for records: [FontFaceRecord], mode: PreviewMode) -> [StudyExportPage] {
        let pageSize = mode == .compare ? 4 : 1
        guard !records.isEmpty else { return [] }
        return stride(from: 0, to: records.count, by: pageSize).enumerated().map { offset, start in
            let end = min(start + pageSize, records.count)
            return StudyExportPage(index: offset + 1, records: Array(records[start..<end]))
        }
    }

    public static func slug(_ value: String, fallback: String = "font-study") -> String {
        let folded = value.folding(
            options: [.diacriticInsensitive, .caseInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
        let allowed = CharacterSet.alphanumerics
        var result = ""
        var pendingDash = false

        for scalar in folded.unicodeScalars {
            if allowed.contains(scalar) {
                if pendingDash && !result.isEmpty { result.append("-") }
                result.append(contentsOf: String(scalar).lowercased())
                pendingDash = false
            } else {
                pendingDash = true
            }
        }
        return result.isEmpty ? fallback : result
    }

    public static func boardFileName(
        studyTitle: String,
        pageIndex: Int,
        extension fileExtension: String
    ) -> String {
        let suffix = String(format: "%03d", pageIndex)
        let ext = fileExtension.trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased()
        return "\(slug(studyTitle))-\(suffix).\(ext.isEmpty ? "dat" : ext)"
    }

    public static func exportFolderName(studyTitle: String) -> String {
        "\(slug(studyTitle))-font-review"
    }

    public static func uniqueURL(for desiredURL: URL, fileManager: FileManager = .default) -> URL {
        guard fileManager.fileExists(atPath: desiredURL.path) else { return desiredURL }

        let directory = desiredURL.deletingLastPathComponent()
        let fileExtension = desiredURL.pathExtension
        let base = desiredURL.deletingPathExtension().lastPathComponent
        var index = 2

        while true {
            let candidateName = fileExtension.isEmpty
                ? "\(base)-\(index)"
                : "\(base)-\(index).\(fileExtension)"
            let candidate = directory.appendingPathComponent(candidateName)
            if !fileManager.fileExists(atPath: candidate.path) { return candidate }
            index += 1
        }
    }
}
