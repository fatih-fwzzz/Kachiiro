import SwiftUI

/// Monochromatic Apple-blue theme built on native adaptive system surfaces.
enum AppTheme {
    static let canvas = Color(.systemGroupedBackground)
    static let cardSurface = Color(.secondarySystemGroupedBackground)
    static let elevatedField = Color(.tertiarySystemGroupedBackground)
    static let hairlineBorder = Color(.separator).opacity(0.45)

    static let primaryInk = Color(.label)
    static let secondaryInk = Color(.secondaryLabel)
    static let tertiaryInk = Color(.tertiaryLabel)

    static let accent = Color.blue
    static let accentSoftFill = Color.blue.opacity(0.12)
    static let accentMediumFill = Color.blue.opacity(0.22)
    static let accentBorder = Color.blue.opacity(0.35)

    static func levelOpacity(_ level: String) -> Double {
        switch level.uppercased() {
        case "N5", "A1", "入門": 0.40
        case "N4", "A2", "A2-1", "A2-2", "初級1", "初級2": 0.60
        case "N3", "B1": 0.75
        case "N2", "B2": 0.90
        case "N1", "C1": 1.00
        default: 0.75
        }
    }

    static func posIcon(_ pos: String) -> String {
        if pos.contains("V［1］") { return "1.circle.fill" }
        if pos.contains("V［2］") { return "2.circle" }
        if pos.contains("V［3］") { return "sparkles" }
        if pos.contains("イA") { return "a.circle.fill" }
        if pos.contains("ナA") { return "n.circle" }
        return "textformat"
    }

    /// System fonts only; Japanese glyphs fall back to Hiragino automatically.
    enum Fonts {
        static func ui(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
            .system(style, design: .rounded, weight: weight)
        }

        /// Serif face for exam-style passages.
        static func examSerif(_ style: Font.TextStyle) -> Font {
            .system(style, design: .serif)
        }
    }
}
