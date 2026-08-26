import Foundation

public enum ReviewStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case keep
    case maybe
    case reject

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .keep: return "Keep"
        case .maybe: return "Maybe"
        case .reject: return "Reject"
        }
    }
}

public enum TextCasing: String, Codable, CaseIterable, Identifiable, Sendable {
    case exact
    case uppercase
    case lowercase
    case title
    case apTitle

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .exact: return "Exact"
        case .uppercase: return "UPPER"
        case .lowercase: return "lower"
        case .title: return "Title"
        case .apTitle: return "AP Title"
        }
    }
}

public enum PreviewBackground: String, Codable, CaseIterable, Identifiable, Sendable {
    case dark
    case light
    case split

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .dark: return "Dark"
        case .light: return "Light"
        case .split: return "Split"
        }
    }
}

public enum PreviewLayout: String, Codable, CaseIterable, Identifiable, Sendable {
    case grid
    case compact
    case fourUp

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .grid: return "Grid"
        case .compact: return "Compact"
        case .fourUp: return "Four-up"
        }
    }
}

public enum SamplePreset: String, Codable, CaseIterable, Identifiable, Sendable {
    case custom
    case titleSlide
    case logline
    case oneLinePromise
    case problemStatement
    case quote
    case teamBio
    case dataLabel
    case caption
    case legal
    case glyphStress

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .custom: return "Custom"
        case .titleSlide: return "Title slide"
        case .logline: return "Logline"
        case .oneLinePromise: return "One-line promise"
        case .problemStatement: return "Problem statement"
        case .quote: return "Quote"
        case .teamBio: return "Team bio"
        case .dataLabel: return "Data label"
        case .caption: return "Caption"
        case .legal: return "Legal / footer"
        case .glyphStress: return "Glyph stress"
        }
    }
}

public enum SpecimenKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case display
    case paragraph
    case data
    case micro

    public var id: String { rawValue }
}

public struct FontAxis: Codable, Hashable, Identifiable, Sendable {
    public var identifier: UInt32
    public var tag: String
    public var name: String
    public var minimum: Double
    public var maximum: Double
    public var defaultValue: Double

    public var id: UInt32 { identifier }

    public init(
        identifier: UInt32,
        tag: String,
        name: String,
        minimum: Double,
        maximum: Double,
        defaultValue: Double
    ) {
        self.identifier = identifier
        self.tag = tag
        self.name = name
        self.minimum = minimum
        self.maximum = maximum
        self.defaultValue = defaultValue
    }
}

public struct FontFaceRecord: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var sourcePath: String
    public var faceIndex: Int
    public var fileName: String
    public var familyName: String
    public var styleName: String
    public var postScriptName: String
    public var format: String
    public var fileSize: Int64
    public var axes: [FontAxis]
    public var axisValues: [UInt32: Double]
    public var casing: TextCasing
    public var status: ReviewStatus
    public var tags: [String]
    public var notes: String
    public var sourceModifiedAt: Date?

    public init(
        id: UUID = UUID(),
        sourcePath: String,
        faceIndex: Int,
        fileName: String,
        familyName: String,
        styleName: String,
        postScriptName: String,
        format: String,
        fileSize: Int64 = 0,
        axes: [FontAxis] = [],
        axisValues: [UInt32: Double] = [:],
        casing: TextCasing = .exact,
        status: ReviewStatus = .maybe,
        tags: [String] = [],
        notes: String = "",
        sourceModifiedAt: Date? = nil
    ) {
        self.id = id
        self.sourcePath = sourcePath
        self.faceIndex = faceIndex
        self.fileName = fileName
        self.familyName = familyName
        self.styleName = styleName
        self.postScriptName = postScriptName
        self.format = format
        self.fileSize = fileSize
        self.axes = axes
        self.axisValues = axisValues
        self.casing = casing
        self.status = status
        self.tags = tags
        self.notes = notes
        self.sourceModifiedAt = sourceModifiedAt
    }

    public var displayName: String {
        if styleName.isEmpty || styleName.caseInsensitiveCompare("Regular") == .orderedSame {
            return familyName.isEmpty ? fileName : familyName
        }
        return familyName.isEmpty ? fileName : "\(familyName) — \(styleName)"
    }

    public var normalizedTags: [String] {
        Array(Set(tags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }.filter { !$0.isEmpty })).sorted()
    }
}

public struct FontStudy: Codable, Hashable, Sendable {
    public static let currentSchemaVersion = 2

    public var schemaVersion: Int
    public var id: UUID
    public var title: String
    public var sampleText: String
    public var samplePreset: SamplePreset
    public var specimenKind: SpecimenKind
    public var background: PreviewBackground
    public var layout: PreviewLayout
    public var records: [FontFaceRecord]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        schemaVersion: Int = FontStudy.currentSchemaVersion,
        id: UUID = UUID(),
        title: String = "Untitled font study",
        sampleText: String = PresetLibrary.text(for: .titleSlide),
        samplePreset: SamplePreset = .titleSlide,
        specimenKind: SpecimenKind = .display,
        background: PreviewBackground = .split,
        layout: PreviewLayout = .grid,
        records: [FontFaceRecord] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.title = title
        self.sampleText = sampleText
        self.samplePreset = samplePreset
        self.specimenKind = specimenKind
        self.background = background
        self.layout = layout
        self.records = records
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public static func blank() -> FontStudy { FontStudy() }
}

public struct StudySemanticSnapshot: Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var sampleText: String
    public var samplePreset: SamplePreset
    public var specimenKind: SpecimenKind
    public var background: PreviewBackground
    public var layout: PreviewLayout
    public var records: [FontFaceRecord]

    public init(_ study: FontStudy) {
        id = study.id
        title = study.title
        sampleText = study.sampleText
        samplePreset = study.samplePreset
        specimenKind = study.specimenKind
        background = study.background
        layout = study.layout
        records = study.records
    }
}
