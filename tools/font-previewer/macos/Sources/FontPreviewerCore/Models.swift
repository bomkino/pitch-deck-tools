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

    public var rank: Int {
        switch self {
        case .keep: return 0
        case .maybe: return 1
        case .reject: return 2
        }
    }
}

public enum FontRole: String, Codable, CaseIterable, Identifiable, Sendable {
    case unassigned
    case display
    case body
    case accent
    case data
    case micro

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .unassigned: return "Unassigned"
        case .display: return "Display"
        case .body: return "Body"
        case .accent: return "Accent"
        case .data: return "Data"
        case .micro: return "Micro"
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

public enum TextAlignment: String, Codable, CaseIterable, Identifiable, Sendable {
    case leading
    case center
    case trailing
    case justified

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .leading: return "Left"
        case .center: return "Centre"
        case .trailing: return "Right"
        case .justified: return "Justified"
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

/// Raw values preserve compatibility with the browser-era study schema.
public enum PreviewMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case review = "grid"
    case waterfall = "compact"
    case compare = "fourUp"
    case focus
    case metrics
    case glyphs
    case pairing

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .review: return "Review"
        case .focus: return "Focus"
        case .compare: return "Compare"
        case .waterfall: return "Waterfall"
        case .metrics: return "Metrics"
        case .glyphs: return "Glyphs"
        case .pairing: return "Pairing"
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
    case paragraph
    case dataLabel
    case numerals
    case caption
    case legal
    case glyphStress
    case multilingual

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
        case .paragraph: return "Body paragraph"
        case .dataLabel: return "Data label"
        case .numerals: return "Numerals"
        case .caption: return "Caption"
        case .legal: return "Legal / footer"
        case .glyphStress: return "Glyph stress"
        case .multilingual: return "Multilingual"
        }
    }
}

public enum SpecimenKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case display
    case paragraph
    case data
    case micro

    public var id: String { rawValue }

    public var label: String { rawValue.capitalized }
}

public enum StudySort: String, Codable, CaseIterable, Identifiable, Sendable {
    case manual
    case family
    case status
    case role
    case format
    case modified

    public var id: String { rawValue }

    public var label: String { rawValue.capitalized }
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

public struct FontFeatureOption: Codable, Hashable, Identifiable, Sendable {
    public var typeIdentifier: Int
    public var selectorIdentifier: Int
    public var name: String
    public var isDefault: Bool

    public var id: String { "\(typeIdentifier):\(selectorIdentifier)" }

    public init(
        typeIdentifier: Int,
        selectorIdentifier: Int,
        name: String,
        isDefault: Bool = false
    ) {
        self.typeIdentifier = typeIdentifier
        self.selectorIdentifier = selectorIdentifier
        self.name = name
        self.isDefault = isDefault
    }
}

public struct FontFeatureGroup: Codable, Hashable, Identifiable, Sendable {
    public var typeIdentifier: Int
    public var name: String
    public var isExclusive: Bool
    public var options: [FontFeatureOption]

    public var id: Int { typeIdentifier }

    public init(
        typeIdentifier: Int,
        name: String,
        isExclusive: Bool,
        options: [FontFeatureOption]
    ) {
        self.typeIdentifier = typeIdentifier
        self.name = name
        self.isExclusive = isExclusive
        self.options = options
    }
}

public struct FontMetricsSnapshot: Codable, Hashable, Sendable {
    public var unitsPerEm: Int
    public var glyphCount: Int
    public var ascent: Double
    public var descent: Double
    public var leading: Double
    public var capHeight: Double
    public var xHeight: Double
    public var slantAngle: Double
    public var weightTrait: Double
    public var widthTrait: Double
    public var symbolicTraits: [String]

    public init(
        unitsPerEm: Int = 0,
        glyphCount: Int = 0,
        ascent: Double = 0,
        descent: Double = 0,
        leading: Double = 0,
        capHeight: Double = 0,
        xHeight: Double = 0,
        slantAngle: Double = 0,
        weightTrait: Double = 0,
        widthTrait: Double = 0,
        symbolicTraits: [String] = []
    ) {
        self.unitsPerEm = unitsPerEm
        self.glyphCount = glyphCount
        self.ascent = ascent
        self.descent = descent
        self.leading = leading
        self.capHeight = capHeight
        self.xHeight = xHeight
        self.slantAngle = slantAngle
        self.weightTrait = weightTrait
        self.widthTrait = widthTrait
        self.symbolicTraits = symbolicTraits
    }
}

public struct FontCoverageSnapshot: Codable, Hashable, Sendable {
    public var supportedScalarCount: Int
    public var scriptRatios: [String: Double]

    public init(supportedScalarCount: Int = 0, scriptRatios: [String: Double] = [:]) {
        self.supportedScalarCount = supportedScalarCount
        self.scriptRatios = scriptRatios
    }

    public var completeScripts: [String] {
        scriptRatios.filter { $0.value >= 0.999 }.keys.sorted()
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
    public var metrics: FontMetricsSnapshot
    public var coverage: FontCoverageSnapshot
    public var axes: [FontAxis]
    public var axisValues: [UInt32: Double]
    public var featureGroups: [FontFeatureGroup]
    public var featureSelections: [Int: Int]
    public var casing: TextCasing
    public var status: ReviewStatus
    public var role: FontRole
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
        metrics: FontMetricsSnapshot = .init(),
        coverage: FontCoverageSnapshot = .init(),
        axes: [FontAxis] = [],
        axisValues: [UInt32: Double] = [:],
        featureGroups: [FontFeatureGroup] = [],
        featureSelections: [Int: Int] = [:],
        casing: TextCasing = .exact,
        status: ReviewStatus = .maybe,
        role: FontRole = .unassigned,
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
        self.metrics = metrics
        self.coverage = coverage
        self.axes = axes
        self.axisValues = axisValues
        self.featureGroups = featureGroups
        self.featureSelections = featureSelections
        self.casing = casing
        self.status = status
        self.role = role
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

    public var isVariable: Bool { !axes.isEmpty }

    public var normalizedTags: [String] {
        Array(Set(tags.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }.filter { !$0.isEmpty })).sorted()
    }

    private enum CodingKeys: String, CodingKey {
        case id, sourcePath, faceIndex, fileName, familyName, styleName, postScriptName
        case format, fileSize, metrics, coverage, axes, axisValues, featureGroups
        case featureSelections, casing, status, role, tags, notes, sourceModifiedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        sourcePath = try container.decodeIfPresent(String.self, forKey: .sourcePath) ?? ""
        faceIndex = try container.decodeIfPresent(Int.self, forKey: .faceIndex) ?? 0
        fileName = try container.decodeIfPresent(String.self, forKey: .fileName) ?? "Unknown font"
        familyName = try container.decodeIfPresent(String.self, forKey: .familyName) ?? ""
        styleName = try container.decodeIfPresent(String.self, forKey: .styleName) ?? "Regular"
        postScriptName = try container.decodeIfPresent(String.self, forKey: .postScriptName) ?? ""
        format = try container.decodeIfPresent(String.self, forKey: .format) ?? "FONT"
        fileSize = try container.decodeIfPresent(Int64.self, forKey: .fileSize) ?? 0
        metrics = try container.decodeIfPresent(FontMetricsSnapshot.self, forKey: .metrics) ?? .init()
        coverage = try container.decodeIfPresent(FontCoverageSnapshot.self, forKey: .coverage) ?? .init()
        axes = try container.decodeIfPresent([FontAxis].self, forKey: .axes) ?? []
        if let numericValues = try? container.decode([UInt32: Double].self, forKey: .axisValues) {
            axisValues = numericValues
        } else if let stringValues = try? container.decode([String: Double].self, forKey: .axisValues) {
            axisValues = Dictionary(uniqueKeysWithValues: stringValues.compactMap { key, value in
                UInt32(key).map { ($0, value) }
            })
        } else {
            axisValues = [:]
        }
        featureGroups = try container.decodeIfPresent([FontFeatureGroup].self, forKey: .featureGroups) ?? []
        featureSelections = try container.decodeIfPresent([Int: Int].self, forKey: .featureSelections) ?? [:]
        casing = try container.decodeIfPresent(TextCasing.self, forKey: .casing) ?? .exact
        status = try container.decodeIfPresent(ReviewStatus.self, forKey: .status) ?? .maybe
        role = try container.decodeIfPresent(FontRole.self, forKey: .role) ?? .unassigned
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        sourceModifiedAt = try container.decodeIfPresent(Date.self, forKey: .sourceModifiedAt)
    }
}

public struct FontStudy: Codable, Hashable, Sendable {
    public static let currentSchemaVersion = 3

    public var schemaVersion: Int
    public var id: UUID
    public var title: String
    public var sampleText: String
    public var samplePreset: SamplePreset
    public var specimenKind: SpecimenKind
    public var background: PreviewBackground
    public var layout: PreviewMode
    public var alignment: TextAlignment
    /// Tracking in em units. -0.02 means -2% of point size.
    public var tracking: Double
    /// Line-height multiplier.
    public var lineHeight: Double
    public var showMetadata: Bool
    public var showGuides: Bool
    public var comparisonIDs: [UUID]
    public var pairingHeadingID: UUID?
    public var pairingBodyID: UUID?
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
        layout: PreviewMode = .review,
        alignment: TextAlignment = .leading,
        tracking: Double = -0.015,
        lineHeight: Double = 1.08,
        showMetadata: Bool = true,
        showGuides: Bool = false,
        comparisonIDs: [UUID] = [],
        pairingHeadingID: UUID? = nil,
        pairingBodyID: UUID? = nil,
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
        self.alignment = alignment
        self.tracking = tracking
        self.lineHeight = lineHeight
        self.showMetadata = showMetadata
        self.showGuides = showGuides
        self.comparisonIDs = comparisonIDs
        self.pairingHeadingID = pairingHeadingID
        self.pairingBodyID = pairingBodyID
        self.records = records
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public static func blank() -> FontStudy { FontStudy() }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, id, title, sampleText, samplePreset, specimenKind, background
        case layout, alignment, tracking, lineHeight, showMetadata, showGuides
        case comparisonIDs, pairingHeadingID, pairingBodyID, records, createdAt, updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Untitled font study"
        sampleText = try container.decodeIfPresent(String.self, forKey: .sampleText)
            ?? PresetLibrary.text(for: .titleSlide)
        samplePreset = try container.decodeIfPresent(SamplePreset.self, forKey: .samplePreset) ?? .custom
        specimenKind = try container.decodeIfPresent(SpecimenKind.self, forKey: .specimenKind)
            ?? PresetLibrary.kind(for: samplePreset)
        background = try container.decodeIfPresent(PreviewBackground.self, forKey: .background) ?? .split
        layout = try container.decodeIfPresent(PreviewMode.self, forKey: .layout) ?? .review
        alignment = try container.decodeIfPresent(TextAlignment.self, forKey: .alignment) ?? .leading
        tracking = try container.decodeIfPresent(Double.self, forKey: .tracking) ?? -0.015
        lineHeight = try container.decodeIfPresent(Double.self, forKey: .lineHeight) ?? 1.08
        showMetadata = try container.decodeIfPresent(Bool.self, forKey: .showMetadata) ?? true
        showGuides = try container.decodeIfPresent(Bool.self, forKey: .showGuides) ?? false
        comparisonIDs = try container.decodeIfPresent([UUID].self, forKey: .comparisonIDs) ?? []
        pairingHeadingID = try container.decodeIfPresent(UUID.self, forKey: .pairingHeadingID)
        pairingBodyID = try container.decodeIfPresent(UUID.self, forKey: .pairingBodyID)
        records = try container.decodeIfPresent([FontFaceRecord].self, forKey: .records) ?? []
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
    }
}

public struct StudySemanticSnapshot: Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var sampleText: String
    public var samplePreset: SamplePreset
    public var specimenKind: SpecimenKind
    public var background: PreviewBackground
    public var layout: PreviewMode
    public var alignment: TextAlignment
    public var tracking: Double
    public var lineHeight: Double
    public var showMetadata: Bool
    public var showGuides: Bool
    public var comparisonIDs: [UUID]
    public var pairingHeadingID: UUID?
    public var pairingBodyID: UUID?
    public var records: [FontFaceRecord]

    public init(_ study: FontStudy) {
        id = study.id
        title = study.title
        sampleText = study.sampleText
        samplePreset = study.samplePreset
        specimenKind = study.specimenKind
        background = study.background
        layout = study.layout
        alignment = study.alignment
        tracking = study.tracking
        lineHeight = study.lineHeight
        showMetadata = study.showMetadata
        showGuides = study.showGuides
        comparisonIDs = study.comparisonIDs
        pairingHeadingID = study.pairingHeadingID
        pairingBodyID = study.pairingBodyID
        records = study.records
    }
}
