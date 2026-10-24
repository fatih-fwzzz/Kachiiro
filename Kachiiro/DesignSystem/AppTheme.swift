import SwiftUI
import UIKit

/// 勝色 × Apple blue: a deep-indigo stage, one blue for every action, one warm ember for streaks and gentle mistakes.
/// Every token adapts to dark mode.
enum AppTheme {
    // MARK: Surfaces
    static let canvas = dynamic(light: 0xF3F5F9, dark: 0x0B0D1F)
    static let cardSurface = dynamic(light: 0xFFFFFF, dark: 0x171A30)
    static let elevatedField = dynamic(light: 0xF3F5F9, dark: 0x22264A)
    static let hairlineBorder = dynamic(light: 0xE3E6EF, dark: 0x2A2E4A)
    /// Empty part of progress bars and rings.
    static let track = dynamic(light: 0xDCE1EC, dark: 0x2A2E4A)

    /// 勝色: hero cards, celebration headers, pillar glyph tiles.
    static let kachiiro = dynamic(light: 0x161A3A, dark: 0x1E2350)
    /// Secondary text on a kachiiro surface.
    static let onKachiiroSecondary = Color(hex: 0xC9CFEA)
    /// Small caps labels on a kachiiro surface.
    static let onKachiiroLabel = Color(hex: 0x9FB4FF)
    /// Translucent fill for chips and tiles on a kachiiro surface.
    static let onKachiiroFill = Color.white.opacity(0.08)

    // MARK: Ink
    static let primaryInk = dynamic(light: 0x0B0D1F, dark: 0xF2F3F8)
    static let secondaryInk = dynamic(light: 0x5A5F7A, dark: 0xA3A8C3)
    static let tertiaryInk = dynamic(light: 0x8A90A8, dark: 0x6E7390)

    // MARK: Action blue
    /// Fill for primary actions, correct answers and progress. White text on it passes 4.5:1.
    static let accent = dynamic(light: 0x0071E3, dark: 0x0A84FF)
    /// Blue for small text and icons on light surfaces (5.6:1 on white).
    static let accentText = dynamic(light: 0x0066CC, dark: 0x5EA8FF)
    /// Sky: selected and secondary fills.
    static let accentSoftFill = dynamic(light: 0xE8F1FD, dark: 0x13284A)
    static let accentMediumFill = dynamic(light: 0x9CC3F5, dark: 0x1F4C86)
    static let accentBorder = accent.opacity(0.35)

    // MARK: Ember
    /// Streak flame and gentle "not quite": never red, so mistakes feel safe.
    static let ember = Color(hex: 0xFF9500)
    static let emberText = dynamic(light: 0xB25000, dark: 0xFFB547)
    static let emberDeepText = dynamic(light: 0x5C2900, dark: 0xFFD9A3)
    static let emberSoftFill = dynamic(light: 0xFFF4E5, dark: 0x3A2410)

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

        /// Small uppercase section label ("TODAY’S PLAN").
        static let caps = Font.system(.footnote, design: .rounded, weight: .heavy)
    }

    enum Radius {
        static let card: CGFloat = 22
        static let hero: CGFloat = 28
        static let control: CGFloat = 16
    }

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1
        )
    }
}

extension Color {
    init(hex: UInt32) { self.init(uiColor: UIColor(hex: hex)) }
}
