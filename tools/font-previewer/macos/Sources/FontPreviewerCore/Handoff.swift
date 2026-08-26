import Foundation

public struct HandoffAxisValue: Codable, Hashable, Sendable {
    public var tag: String
    public var value: Double

    public init(tag: String, value: Double) {
        self.tag = tag
        self.value = value
    }
}

public struct HandoffFontRecord: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var sequence: Int
    public var family: String
    public var style: String
    public var postScriptName: String
    public var fileName: String
    public var sourcePath: String?
    public var faceIndex: Int
    public var format: String
    public var status: ReviewStatus
    public var role: FontRole
    public var casing: TextCasing
    public var axes: [HandoffAxisValue]
    public var enabledFeatures: [String]
    public var tags: [String]
    public var notes: String
    public var metrics: FontMetricsSnapshot
    public var coverage: FontCoverageSnapshot
}

public struct FontStudyHandoff: Codable, Hashable, Sendable {
    public var generator: String
    public var schemaVersion: Int
    public var exportedAt: Date
    public var studyTitle: String
    public var sampleText: String
    public var samplePreset: SamplePreset
    public var specimenKind: SpecimenKind
    public var background: PreviewBackground
    public var mode: PreviewMode
    public var alignment: TextAlignment
    public var tracking: Double
    public var lineHeight: Double
    public var fonts: [HandoffFontRecord]

    public init(
        generator: String = "pitch.dog Font Previewer",
        schemaVersion: Int = 1,
        exportedAt: Date = Date(),
        studyTitle: String,
        sampleText: String,
        samplePreset: SamplePreset,
        specimenKind: SpecimenKind,
        background: PreviewBackground,
        mode: PreviewMode,
        alignment: TextAlignment,
        tracking: Double,
        lineHeight: Double,
        fonts: [HandoffFontRecord]
    ) {
        self.generator = generator
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.studyTitle = studyTitle
        self.sampleText = sampleText
        self.samplePreset = samplePreset
        self.specimenKind = specimenKind
        self.background = background
        self.mode = mode
        self.alignment = alignment
        self.tracking = tracking
        self.lineHeight = lineHeight
        self.fonts = fonts
    }
}

public enum HandoffBuilder {
    public static func manifest(
        study: FontStudy,
        records: [FontFaceRecord],
        projectURL: URL?,
        includeAbsoluteSourcePaths: Bool
    ) -> FontStudyHandoff {
        let fonts = records.enumerated().map { offset, record in
            HandoffFontRecord(
                id: record.id,
                sequence: offset + 1,
                family: record.familyName,
                style: record.styleName,
                postScriptName: record.postScriptName,
                fileName: record.fileName,
                sourcePath: includeAbsoluteSourcePaths
                    ? StudyPathResolver.resolvedURL(for: record.sourcePath, projectURL: projectURL).path
                    : nil,
                faceIndex: record.faceIndex,
                format: record.format,
                status: record.status,
                role: record.role,
                casing: record.casing,
                axes: record.axes.compactMap { axis in
                    guard let value = record.axisValues[axis.identifier] else { return nil }
                    return HandoffAxisValue(tag: axis.tag, value: value)
                },
                enabledFeatures: record.featureGroups.compactMap { group in
                    guard let selected = record.featureSelections[group.typeIdentifier],
                          let option = group.options.first(where: { $0.selectorIdentifier == selected })
                    else { return nil }
                    return "\(group.name): \(option.name)"
                },
                tags: record.normalizedTags,
                notes: record.notes,
                metrics: record.metrics,
                coverage: record.coverage
            )
        }
        return FontStudyHandoff(
            studyTitle: study.title,
            sampleText: study.sampleText,
            samplePreset: study.samplePreset,
            specimenKind: study.specimenKind,
            background: study.background,
            mode: study.layout,
            alignment: study.alignment,
            tracking: study.tracking,
            lineHeight: study.lineHeight,
            fonts: fonts
        )
    }

    public static func encodeJSON(_ manifest: FontStudyHandoff) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(manifest)
    }

    public static func markdown(_ manifest: FontStudyHandoff) -> String {
        var lines: [String] = [
            "# \(manifest.studyTitle)",
            "",
            "Generated by \(manifest.generator).",
            "",
            "## Specimen",
            "",
            "- Mode: \(manifest.mode.label)",
            "- Background: \(manifest.background.label)",
            "- Alignment: \(manifest.alignment.label)",
            "- Tracking: \(format(manifest.tracking)) em",
            "- Line height: \(format(manifest.lineHeight))×",
            "",
            "> \(manifest.sampleText.replacingOccurrences(of: "\n", with: "\n> "))",
            "",
            "## Fonts",
            "",
        ]

        for font in manifest.fonts {
            lines += [
                "### \(String(format: "%02d", font.sequence)) · \(font.family) — \(font.style)",
                "",
                "- Decision: \(font.status.label)",
                "- Role: \(font.role.label)",
                "- Source: `\(font.fileName)` · face \(font.faceIndex) · \(font.format)",
            ]
            if !font.axes.isEmpty {
                lines.append("- Axes: " + font.axes.map { "\($0.tag) \(format($0.value))" }.joined(separator: ", "))
            }
            if !font.enabledFeatures.isEmpty {
                lines.append("- Features: " + font.enabledFeatures.joined(separator: ", "))
            }
            if !font.tags.isEmpty { lines.append("- Tags: " + font.tags.joined(separator: ", ")) }
            if !font.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                lines += ["", font.notes, ""]
            } else {
                lines.append("")
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func format(_ value: Double) -> String {
        if abs(value.rounded() - value) < 0.0001 { return String(Int(value.rounded())) }
        return String(format: "%.3f", value).replacingOccurrences(of: #"0+$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\.$"#, with: "", options: .regularExpression)
    }
}
