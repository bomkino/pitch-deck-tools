import Foundation

public struct StudyFilter: Equatable, Sendable {
    public var query: String
    public var statuses: Set<ReviewStatus>

    public init(query: String = "", statuses: Set<ReviewStatus> = Set(ReviewStatus.allCases)) {
        self.query = query
        self.statuses = statuses
    }

    public func matches(_ record: FontFaceRecord) -> Bool {
        guard statuses.contains(record.status) else { return false }
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: .current
        )
        guard !needle.isEmpty else { return true }

        let searchable = [
            record.displayName,
            record.familyName,
            record.styleName,
            record.postScriptName,
            record.fileName,
            record.format,
            record.tags.joined(separator: " "),
            record.notes,
        ].joined(separator: " ").folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: .current
        )
        return searchable.contains(needle)
    }

    public func apply(to records: [FontFaceRecord]) -> [FontFaceRecord] {
        records.filter(matches)
    }
}

public enum StudyLogic {
    public static func counts(in records: [FontFaceRecord]) -> [ReviewStatus: Int] {
        Dictionary(grouping: records, by: \ .status).mapValues(\.count)
    }

    public static func move(recordID: UUID, before destinationID: UUID, in records: inout [FontFaceRecord]) {
        guard recordID != destinationID,
              let source = records.firstIndex(where: { $0.id == recordID }),
              let destination = records.firstIndex(where: { $0.id == destinationID })
        else { return }

        let value = records.remove(at: source)
        let adjusted = source < destination ? destination - 1 : destination
        records.insert(value, at: max(0, min(adjusted, records.count)))
    }

    public static func originalDisplayID(for recordID: UUID, in records: [FontFaceRecord]) -> String? {
        guard let index = records.firstIndex(where: { $0.id == recordID }) else { return nil }
        return String(format: "%02d", index + 1)
    }

    public static func duplicateIdentityGroups(in records: [FontFaceRecord]) -> [[FontFaceRecord]] {
        let groups = Dictionary(grouping: records, by: FontIdentity.key)
        return groups.values.filter { $0.count > 1 }.sorted {
            ($0.first?.fileName ?? "") < ($1.first?.fileName ?? "")
        }
    }
}
