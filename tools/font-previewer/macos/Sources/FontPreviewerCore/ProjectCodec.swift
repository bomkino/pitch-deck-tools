import Foundation

public enum ProjectCodecError: LocalizedError, Equatable {
    case unsupportedSchema(Int)
    case invalidProject

    public var errorDescription: String? {
        switch self {
        case .unsupportedSchema(let version):
            return "This font study uses schema version \(version), newer than this app supports."
        case .invalidProject:
            return "The selected file is not a valid Font Previewer study."
        }
    }
}

public enum ProjectCodec {
    public static func encode(_ study: FontStudy) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(DateCodec.string(from: date))
        }
        return try encoder.encode(study)
    }

    public static func decode(_ data: Data) throws -> FontStudy {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            guard let date = DateCodec.date(from: raw) else {
                throw ProjectCodecError.invalidProject
            }
            return date
        }

        let study: FontStudy
        do {
            study = try decoder.decode(FontStudy.self, from: data)
        } catch let error as ProjectCodecError {
            throw error
        } catch {
            throw ProjectCodecError.invalidProject
        }

        guard study.schemaVersion <= FontStudy.currentSchemaVersion else {
            throw ProjectCodecError.unsupportedSchema(study.schemaVersion)
        }

        var migrated = study
        migrated.schemaVersion = FontStudy.currentSchemaVersion
        migrated.records = FontIdentity.removingDuplicates(migrated.records)
        return migrated
    }

    public static func load(from url: URL) throws -> FontStudy {
        try decode(Data(contentsOf: url))
    }

    @discardableResult
    public static func save(_ study: FontStudy, to url: URL) throws -> FontStudy {
        var stamped = study
        stamped.schemaVersion = FontStudy.currentSchemaVersion
        stamped.updatedAt = Date()
        let data = try encode(stamped)

        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: url, options: [.atomic])
        return stamped
    }
}

private enum DateCodec {
    static func string(from date: Date) -> String {
        fractional.string(from: date)
    }

    static func date(from value: String) -> Date? {
        fractional.date(from: value) ?? plain.date(from: value)
    }

    private static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let plain: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
