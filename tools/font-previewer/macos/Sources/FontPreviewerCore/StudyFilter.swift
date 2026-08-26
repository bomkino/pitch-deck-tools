import Foundation

public struct StudyFilter: Equatable, Sendable {
    public var query: String
    public var statuses: Set<ReviewStatus>
    public var roles: Set<FontRole>
    public var formats: Set<String>
    public var variableOnly: Bool
    public var missingSourceOnly: Bool
    public var sort: StudySort

    public init(
        query: String = "",
        statuses: Set<ReviewStatus> = Set(ReviewStatus.allCases),
        roles: Set<FontRole> = Set(FontRole.allCases),
        formats: Set<String> = [],
        variableOnly: Bool = false,
        missingSourceOnly: Bool = false,
        sort: StudySort = .manual
    ) {
        self.query = query
        self.statuses = statuses
        self.roles = roles
        self.formats = Set(formats.map { $0.uppercased() })
        self.variableOnly = variableOnly
        self.missingSourceOnly = missingSourceOnly
        self.sort = sort
    }

    public func matches(
        _ record: FontFaceRecord,
        sourceExists: (FontFaceRecord) -> Bool = { _ in true }
    ) -> Bool {
        guard statuses.contains(record.status), roles.contains(record.role) else { return false }
        if !formats.isEmpty && !formats.contains(record.format.uppercased()) { return false }
        if variableOnly && !record.isVariable { return false }
        if missingSourceOnly && sourceExists(record) { return false }

        let tokens = queryTokens(query)
        guard !tokens.isEmpty else { return true }
        return tokens.allSatisfy { token in tokenMatches(token, record: record, sourceExists: sourceExists) }
    }

    public func apply(
        to records: [FontFaceRecord],
        sourceExists: (FontFaceRecord) -> Bool = { _ in true }
    ) -> [FontFaceRecord] {
        let filtered = records.filter { matches($0, sourceExists: sourceExists) }
        guard sort != .manual else { return filtered }
        return filtered.sorted { lhs, rhs in
            switch sort {
            case .manual:
                return false
            case .family:
                return compare(lhs.displayName, rhs.displayName)
            case .status:
                if lhs.status.rank != rhs.status.rank { return lhs.status.rank < rhs.status.rank }
                return compare(lhs.displayName, rhs.displayName)
            case .role:
                if lhs.role.rawValue != rhs.role.rawValue { return compare(lhs.role.rawValue, rhs.role.rawValue) }
                return compare(lhs.displayName, rhs.displayName)
            case .format:
                if lhs.format != rhs.format { return compare(lhs.format, rhs.format) }
                return compare(lhs.displayName, rhs.displayName)
            case .modified:
                let left = lhs.sourceModifiedAt ?? .distantPast
                let right = rhs.sourceModifiedAt ?? .distantPast
                if left != right { return left > right }
                return compare(lhs.displayName, rhs.displayName)
            }
        }
    }

    private func tokenMatches(
        _ token: String,
        record: FontFaceRecord,
        sourceExists: (FontFaceRecord) -> Bool
    ) -> Bool {
        let parts = token.split(separator: ":", maxSplits: 1).map(String.init)
        if parts.count == 2 {
            let field = normalized(parts[0])
            let value = normalized(parts[1])
            switch field {
            case "status": return normalized(record.status.rawValue).contains(value)
            case "role": return normalized(record.role.rawValue).contains(value)
            case "tag": return record.normalizedTags.contains { normalized($0).contains(value) }
            case "format": return normalized(record.format).contains(value)
            case "family": return normalized(record.familyName).contains(value)
            case "style": return normalized(record.styleName).contains(value)
            case "file": return normalized(record.fileName).contains(value)
            case "variable": return boolean(value) == record.isVariable
            case "missing": return boolean(value) == !sourceExists(record)
            case "script":
                return record.coverage.scriptRatios.contains { key, ratio in
                    normalized(key).contains(value) && ratio > 0
                }
            default: break
            }
        }

        let searchable = [
            record.displayName,
            record.familyName,
            record.styleName,
            record.postScriptName,
            record.fileName,
            record.format,
            record.role.label,
            record.status.label,
            record.tags.joined(separator: " "),
            record.notes,
            record.axes.map(\.tag).joined(separator: " "),
            record.coverage.scriptRatios.keys.joined(separator: " "),
        ].joined(separator: " ")
        return normalized(searchable).contains(normalized(token))
    }

    private func queryTokens(_ value: String) -> [String] {
        value.split(whereSeparator: { $0.isWhitespace }).map(String.init).filter { !$0.isEmpty }
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
    }

    private func boolean(_ value: String) -> Bool {
        ["1", "true", "yes", "y", "on"].contains(value.lowercased())
    }

    private func compare(_ lhs: String, _ rhs: String) -> Bool {
        lhs.localizedStandardCompare(rhs) == .orderedAscending
    }
}

public enum StudyLogic {
    public static func counts(in records: [FontFaceRecord]) -> [ReviewStatus: Int] {
        var result: [ReviewStatus: Int] = [:]
        for record in records { result[record.status, default: 0] += 1 }
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

    public static func move(recordID: UUID, offset: Int, in records: inout [FontFaceRecord]) {
        guard offset != 0, let source = records.firstIndex(where: { $0.id == recordID }) else { return }
        let destination = max(0, min(records.count - 1, source + offset))
        guard source != destination else { return }
        let value = records.remove(at: source)
        records.insert(value, at: destination)
    }

    public static func originalDisplayID(for recordID: UUID, in records: [FontFaceRecord]) -> String? {
        guard let index = records.firstIndex(where: { $0.id == recordID }) else { return nil }
        return String(format: "%02d", index + 1)
    }

    public static func comparisonRecords(in study: FontStudy, maximum: Int = 4) -> [FontFaceRecord] {
        let indexed = Dictionary(uniqueKeysWithValues: study.records.map { ($0.id, $0) })
        var records = study.comparisonIDs.compactMap { indexed[$0] }
        if records.isEmpty {
            records = Array(study.records.filter { $0.status != .reject }.prefix(maximum))
        }
        return Array(records.prefix(maximum))
    }

    public static func pairingRecords(in study: FontStudy) -> (heading: FontFaceRecord?, body: FontFaceRecord?) {
        let heading = study.pairingHeadingID.flatMap { id in study.records.first { $0.id == id } }
            ?? study.records.first { $0.role == .display && $0.status != .reject }
            ?? study.records.first { $0.status == .keep }
        let body = study.pairingBodyID.flatMap { id in study.records.first { $0.id == id } }
            ?? study.records.first { $0.role == .body && $0.status != .reject }
            ?? study.records.first { $0.id != heading?.id && $0.status != .reject }
        return (heading, body)
    }

    public static func duplicateIdentityGroups(
        in records: [FontFaceRecord],
        projectURL: URL? = nil
    ) -> [[FontFaceRecord]] {
        var groups: [String: [FontFaceRecord]] = [:]
        for record in records {
            groups[FontIdentity.key(for: record, projectURL: projectURL), default: []].append(record)
        }
        return groups.values
            .filter { $0.count > 1 }
            .sorted { ($0.first?.fileName ?? "") < ($1.first?.fileName ?? "") }
    }
}
