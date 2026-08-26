import Foundation

public enum ExportFormat: String, Codable, CaseIterable, Identifiable, Sendable {
    case png
    case pdf
    case manifest

    public var id: String { rawValue }
}

public struct ExportSelection: Codable, Hashable, Sendable {
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

public struct ExportPage: Hashable, Identifiable, Sendable {
    public var index: Int
    public var records: [FontFaceRecord]

    public var id: Int { index }

    public init(index: Int, records: [FontFaceRecord]) {
        self.index = index
        self.records = records
    }
}

public enum ExportPlanner {
    public static func selectedRecords(from study: FontStudy, selection: ExportSelection) -> [FontFaceRecord] {
        study.records.filter { selection.statuses.contains($0.status) }
    }

    public static func pages(
        for records: [FontFaceRecord],
        layout: PreviewLayout,
        oneUpPageSize: Int = 1,
        fourUpPageSize: Int = 4
    ) -> [ExportPage] {
        let size: Int
        switch layout {
        case .fourUp:
            size = max(1, fourUpPageSize)
        case .grid, .compact:
            size = max(1, oneUpPageSize)
        }

        guard !records.isEmpty else { return [] }
        return stride(from: 0, to: records.count, by: size).enumerated().map { offset, start in
            let end = min(start + size, records.count)
            return ExportPage(index: offset + 1, records: Array(records[start..<end]))
        }
    }

    public static func slug(_ value: String, fallback: String = "font-study") -> String {
        let folded = value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let allowed = CharacterSet.alphanumerics
        var result = ""
        var pendingDash = false

        for scalar in folded.unicodeScalars {
            if allowed.contains(scalar) {
                if pendingDash && !result.isEmpty { result.append("-") }
                result.append(String(scalar).lowercased())
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

    public static func uniqueURL(for desiredURL: URL, fileManager: FileManager = .default) -> URL {
        guard fileManager.fileExists(atPath: desiredURL.path) else { return desiredURL }

        let directory = desiredURL.deletingLastPathComponent()
        let ext = desiredURL.pathExtension
        let base = desiredURL.deletingPathExtension().lastPathComponent
        var index = 2

        while true {
            let candidateName = ext.isEmpty ? "\(base)-\(index)" : "\(base)-\(index).\(ext)"
            let candidate = directory.appendingPathComponent(candidateName)
            if !fileManager.fileExists(atPath: candidate.path) { return candidate }
            index += 1
        }
    }
}
