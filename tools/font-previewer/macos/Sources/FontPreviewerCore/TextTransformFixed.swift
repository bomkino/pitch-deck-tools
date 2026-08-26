import Foundation

public enum SpecimenTextTransform {
    private static let apMinorWords: Set<String> = [
        "a", "an", "and", "as", "at", "but", "by", "for", "from", "if", "in", "into",
        "nor", "of", "off", "on", "onto", "or", "over", "per", "so", "the", "to", "up",
        "via", "with", "yet"
    ]

    public static func apply(_ casing: TextCasing, to text: String) -> String {
        switch casing {
        case .exact:
            return text
        case .uppercase:
            return text.uppercased()
        case .lowercase:
            return text.lowercased()
        case .title:
            return transformWords(in: text) { titleWord($0) }
        case .apTitle:
            return apTitleCase(text)
        }
    }

    public static func apTitleCase(_ text: String) -> String {
        let ranges = wordRanges(in: text)
        guard !ranges.isEmpty else { return text }
        var output = text

        for offset in ranges.indices.reversed() {
            let range = ranges[offset]
            let raw = String(text[range])
            let core = normalizedCore(raw)
            let edge = offset == ranges.startIndex || offset == ranges.index(before: ranges.endIndex)
            let transformed = (!edge && apMinorWords.contains(core.lowercased()))
                ? core.lowercased()
                : titleWord(core)
            output.replaceSubrange(range, with: replaceCore(in: raw, with: transformed))
        }
        return output
    }

    private static func transformWords(in text: String, transform: (String) -> String) -> String {
        let ranges = wordRanges(in: text)
        var output = text
        for range in ranges.reversed() {
            let raw = String(text[range])
            output.replaceSubrange(range, with: replaceCore(in: raw, with: transform(normalizedCore(raw))))
        }
        return output
    }

    private static func wordRanges(in text: String) -> [Range<String.Index>] {
        var result: [Range<String.Index>] = []
        var start: String.Index?
        var cursor = text.startIndex

        while cursor < text.endIndex {
            if text[cursor].isWhitespace {
                if let tokenStart = start {
                    result.append(tokenStart..<cursor)
                    start = nil
                }
            } else if start == nil {
                start = cursor
            }
            cursor = text.index(after: cursor)
        }
        if let tokenStart = start {
            result.append(tokenStart..<text.endIndex)
        }
        return result
    }

    private static func normalizedCore(_ raw: String) -> String {
        raw.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    }

    private static func replaceCore(in raw: String, with replacement: String) -> String {
        guard let first = raw.firstIndex(where: { $0.isLetter || $0.isNumber }),
              let lastCharacter = raw.lastIndex(where: { $0.isLetter || $0.isNumber })
        else { return raw }
        let last = raw.index(after: lastCharacter)
        var output = raw
        output.replaceSubrange(first..<last, with: replacement)
        return output
    }

    private static func titleWord(_ word: String) -> String {
        guard let first = word.first else { return word }
        return String(first).uppercased() + String(word.dropFirst()).lowercased()
    }
}
