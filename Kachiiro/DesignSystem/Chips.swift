import SwiftUI
import KachiiroCore

extension Pillar {
    /// The kanji shown on the pillar's tile.
    var glyph: String {
        switch self {
        case .katsuyou: "活"
        case .goi: "語"
        case .bunpou: "文"
        case .choukai: "聴"
        case .kaiwa: "会"
        }
    }

    /// The romaji name without the kanji ("Katsuyou").
    var shortName: String {
        String(title.split(separator: " ").first ?? Substring(title))
    }
}

/// A square kanji tile: navy for a pillar, blue for the current focus, sky for a quiet item.
struct GlyphTile: View {
    enum Style { case kachiiro, accent, soft }

    let glyph: String
    var style: Style = .kachiiro
    var size: CGFloat = 40

    var body: some View {
        Text(glyph)
            .font(.system(size: size * 0.45, weight: .bold))
            .foregroundStyle(style == .soft ? AppTheme.accentText : Color.white)
            .frame(width: size, height: size)
            .background(background, in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
            .accessibilityHidden(true)
    }

    private var background: Color {
        switch style {
        case .kachiiro: AppTheme.kachiiro
        case .accent: AppTheme.accent
        case .soft: AppTheme.accentSoftFill
        }
    }
}

/// Flame plus day count. On a kachiiro surface the flame glows on a translucent ember pill.
struct StreakChip: View {
    let days: Int
    var onKachiiro = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill").foregroundStyle(days > 0 ? AppTheme.ember : AppTheme.tertiaryInk)
            Text(days == 1 ? "1-day streak" : "\(days)-day streak")
                .monospacedDigit()
        }
        .font(AppTheme.Fonts.ui(.subheadline, weight: .bold))
        .foregroundStyle(onKachiiro ? Color(hex: 0xFFB547) : AppTheme.emberText)
        .padding(.horizontal, 12)
        .frame(minHeight: 34)
        .background(onKachiiro ? AppTheme.ember.opacity(0.16) : AppTheme.emberSoftFill, in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

/// Uppercase section label.
struct SectionCaps: View {
    let text: String
    var color: Color = AppTheme.secondaryInk

    var body: some View {
        Text(text.uppercased())
            .font(AppTheme.Fonts.caps)
            .tracking(0.8)
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}
