import Foundation

public enum TextTransform {
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
            return transformWords(in: text) { word, _, _ in titleWord(word) }
        case .apTitle:
            return apTitleCase(text)
        }
    }

    public static func apTitleCase(_ text: String) -> String {
        let ranges = wordRanges(in: text)
        guard let first = ranges.first, let last = ranges.last else { return text }

        var output = text
        for range in ranges.reversed() {
            let raw = String(text[range])
            let core = normalizedCore(raw)
            let isEdge = range == first || range == last
            let replacement: String
            if !isEdge && apMinorWords.contains(core.lowercased()) {
                replacement = replaceCore(in: raw, with: core.lowercased())
            } else {
                replacement = replaceCore(in: raw, with: titleWord(core))
            }
            output.replaceSubrange(range, with: replacement)
        }
        return output
    }

    private static func transformWords(
        in text: String,
        transform: (_ word: String, _ index: Int, _ count: Int) -> String
    ) -> String {
        let ranges = wordRanges(in: text)
        var output = text
        for (reverseIndex, range) in ranges.reversed().enumerated() {
            let index = ranges.count - 1 - reverseIndex
            let raw = String(text[range])
            let core = normalizedCore(raw)
            let replacement = replaceCore(in: raw, with: transform(core, index, ranges.count))
            output.replaceSubrange(range, with: replacement)
        }
        return output
    }

    private static func wordRanges(in text: String) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        var start: String.Index?
        var index = text.startIndex

        while index < text.endIndex {
            let character = text[index]
            if character.isWhitespace {
                if let start {
                    ranges.append(start..<index)
                    selfReset(&start)
                }
            } else if start == nil {
                start = index
            }
            index = text.index(after: index)
        }
        if let start { ranges.append(start..<text.endIndex) }
        return ranges
    }

    private static func selfReset(_ value: inout String.Index?) {
        value = nil
    }

    private static func normalizedCore(_ raw: String) -> String {
        raw.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    }

    private static func replaceCore(in raw: String, with replacement: String) -> String {
        guard !raw.isEmpty else { return raw }
        guard let start = raw.firstIndex(where: { $0.isLetter || $0.isNumber }) else { return raw }
        guard let endCharacter = raw.lastIndex(where: { $0.isLetter || $0.isNumber }) else { return raw }
        let end = raw.index(after: endCharacter)
        var result = raw
        result.replaceSubrange(start..<end, with: replacement)
        return result
    }

    private static func titleWord(_ word: String) -> String {
        guard let first = word.first else { return word }
        return String(first).uppercased() + word.dropFirst().lowercased()
    }
}
