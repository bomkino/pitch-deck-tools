import Foundation

public enum PresetLibrary {
    public static func text(for preset: SamplePreset) -> String {
        switch preset {
        case .custom:
            return "Your headline goes here"
        case .titleSlide:
            return "A Very Motherly Christmas"
        case .logline:
            return "When a meticulous daughter brings her chaotic family home for Christmas, one immaculate holiday plan begins to unravel."
        case .oneLinePromise:
            return "A sharper way to see the story before anyone turns the page."
        case .problemStatement:
            return "The deck is often the first version of the film anyone can actually see."
        case .quote:
            return "The image arrives first. Meaning catches up."
        case .teamBio:
            return "A writer-director building intimate, visually exact stories about family, ambition, and the systems that shape both."
        case .dataLabel:
            return "84% audience retention · 12 markets · $4.8M projected gross"
        case .caption:
            return "Reference: sodium-vapour streets, wet asphalt, 2.39:1 frame."
        case .legal:
            return "CONFIDENTIAL · FOR DISCUSSION PURPOSES ONLY · © 2026"
        case .glyphStress:
            return "Aa Ee Rr Gg 0123456789 $ ₹ € £ ¥ % & @ # ! ? * — – • © ™ ( ) [ ] { } / \\"
        }
    }

    public static func kind(for preset: SamplePreset) -> SpecimenKind {
        switch preset {
        case .logline, .problemStatement, .quote, .teamBio:
            return .paragraph
        case .dataLabel:
            return .data
        case .caption, .legal:
            return .micro
        default:
            return .display
        }
    }

    public static func recommendedPointSize(for kind: SpecimenKind) -> Double {
        switch kind {
        case .display: return 86
        case .paragraph: return 34
        case .data: return 42
        case .micro: return 18
        }
    }
}
