import Foundation

public enum SpecimenTextTransform {
    private static let apMinorWords: Set<String> = [
        "a", "an", "and", "as", "at", "but", "by", "for", "from", "if", "in", "into",
        "nor", "of", "off", "on", "onto", "or", "over", "per", "so", "the", "to", "up",
        "via", "with", "yet"
    ]

    public static func apply(_ casing: TextCasing, to text: String) -> String {
        switch casing {
        case .exact: return text
        case .uppercase: return text.uppercased()
        case .lowercase: return text.lowercased()
        case .title: return titleCase(text, apStyle: false)
        case .apTitle: return titleCase(text, apStyle: true)
        }
    }

    public static func apTitleCase(_ text: String) -> String {
        titleCase(text, apStyle: true)
    }

    private static func titleCase(_ text: String, apStyle: Bool) -> String {
        let ranges = lexicalWordRanges(in: text)
        guard !ranges.isEmpty else { return text }
        var output = text

        for offset in ranges.indices.reversed() {
            let range = ranges[offset]
            let raw = String(text[range])
            let lower = raw.lowercased()
            let edge = offset == ranges.startIndex || offset == ranges.index(before: ranges.endIndex)
            let replacement: String
            if apStyle && !edge && apMinorWords.contains(lower) {
                replacement = lower
            } else {
                replacement = capitalizeCompound(lower)
            }
            output.replaceSubrange(range, with: replacement)
        }
        return output
    }

    private static func lexicalWordRanges(in text: String) -> [Range<String.Index>] {
        var result: [Range<String.Index>] = []
        var start: String.Index?
        var cursor = text.startIndex

        while cursor < text.endIndex {
            let character = text[cursor]
            let isCore = character.isLetter || character.isNumber
            let isJoiner = (character == "-" || character == "’" || character == "'")
                && start != nil
                && text.index(after: cursor) < text.endIndex
                && (text[text.index(after: cursor)].isLetter || text[text.index(after: cursor)].isNumber)

            if isCore || isJoiner {
                if start == nil { start = cursor }
            } else if let wordStart = start {
                result.append(wordStart..<cursor)
                start = nil
            }
            cursor = text.index(after: cursor)
        }
        if let wordStart = start { result.append(wordStart..<text.endIndex) }
        return result
    }

    private static func capitalizeCompound(_ value: String) -> String {
        var output = ""
        var shouldCapitalize = true
        for character in value {
            if shouldCapitalize && character.isLetter {
                output += String(character).uppercased()
                shouldCapitalize = false
            } else {
                output.append(character)
            }
            if character == "-" { shouldCapitalize = true }
            if character == "’" || character == "'" { shouldCapitalize = false }
        }
        return output
    }
}
