import Foundation

public struct CoverageProbe: Hashable, Sendable {
    public var name: String
    public var text: String

    public init(name: String, text: String) {
        self.name = name
        self.text = text
    }
}

public enum PresetLibrary {
    public static func text(for preset: SamplePreset) -> String {
        switch preset {
        case .custom:
            return "Your headline goes here"
        case .titleSlide:
            return "The Future Was Already Here"
        case .logline:
            return "When a quiet coastal town loses power for one impossible night, a sceptical archivist discovers the blackout is erasing more than memory."
        case .oneLinePromise:
            return "A sharper way to see the story before anyone turns the page."
        case .problemStatement:
            return "Most decks ask readers to imagine the film before the typography has earned their attention."
        case .quote:
            return "The image arrives first. Meaning catches up."
        case .teamBio:
            return "A writer-director building intimate, visually exact stories about family, ambition, and the systems that shape both."
        case .paragraph:
            return "A pitch deck has to carry atmosphere and evidence at once. The type must remain legible under pressure, hold a long thought without fatigue, and still make a title feel inevitable."
        case .dataLabel:
            return "84% audience retention · 12 markets · $4.8M projected gross"
        case .numerals:
            return "0123456789  1,234.56  $ ₹ € £ ¥  18%  24/7  +42  −09"
        case .caption:
            return "Reference: sodium-vapour streets, wet asphalt, 2.39:1 frame."
        case .legal:
            return "CONFIDENTIAL · FOR DISCUSSION PURPOSES ONLY · © 2026"
        case .glyphStress:
            return "Aa Bb Cc Dd Ee Ff Gg Rr 0123456789 $ ₹ € £ ¥ % & @ # ! ? * — – • © ™ ( ) [ ] { } / \\"
        case .multilingual:
            return "Typography travels. Αθήνα · Київ · القاهرة · ירושלים · नमस्ते · กรุงเทพฯ · 東京 · 서울"
        }
    }

    public static func kind(for preset: SamplePreset) -> SpecimenKind {
        switch preset {
        case .logline, .problemStatement, .quote, .teamBio, .paragraph, .multilingual:
            return .paragraph
        case .dataLabel, .numerals:
            return .data
        case .caption, .legal:
            return .micro
        default:
            return .display
        }
    }

    public static func recommendedPointSize(for kind: SpecimenKind) -> Double {
        switch kind {
        case .display: return 92
        case .paragraph: return 36
        case .data: return 44
        case .micro: return 18
        }
    }

    public static let waterfallSizes: [Double] = [12, 16, 20, 24, 32, 44, 64, 88, 120, 168]

    public static let coverageProbes: [CoverageProbe] = [
        .init(name: "Latin", text: "Hamburgefontsiv 0123456789 ÀÉÑØßæœ"),
        .init(name: "Greek", text: "Αθήνα ελληνικά Ωμέγα"),
        .init(name: "Cyrillic", text: "Київ Москва България"),
        .init(name: "Arabic", text: "العربية القاهرة كتاب"),
        .init(name: "Hebrew", text: "עברית ירושלים ספר"),
        .init(name: "Devanagari", text: "नमस्ते भारत कहानी"),
        .init(name: "Thai", text: "ภาษาไทย กรุงเทพฯ"),
        .init(name: "Japanese", text: "日本語 東京 物語"),
        .init(name: "Korean", text: "한국어 서울 이야기"),
    ]

    public static var glyphGridText: String {
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789ÀÁÂÄÅÆÇÈÉÊËÌÍÎÏÑÒÓÔÖØŒÙÚÛÜÝßæœ$₹€£¥%&@#!?*—–•©™()[]{}<>/\\"
    }
}
