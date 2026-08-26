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
        let needle = normalized(query)
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
        ].joined(separator: " ")
        return normalized(searchable).contains(needle)
    }

    public func apply(to records: [FontFaceRecord]) -> [FontFaceRecord] {
        records.filter { matches($0) }
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: .current
        )
    }
}

public enum StudyLogic {
    public static func counts(in records: [FontFaceRecord]) -> [ReviewStatus: Int] {
        var result: [ReviewStatus: Int] = [:]
        for record in records {
            result[record.status, default: 0] += 1
        }
        return result
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
        var groups: [String: [FontFaceRecord]] = [:]
        for record in records {
            groups[FontIdentity.key(for: record), default: []].append(record)
        }
        return groups.values
            .filter { $0.count > 1 }
            .sorted { ($0.first?.fileName ?? "") < ($1.first?.fileName ?? "") }
    }
}
