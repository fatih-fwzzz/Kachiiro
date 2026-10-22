import SwiftUI
import KachiiroCore

/// Draws a word's reading with a 1.5 pt blue line over the high morae and a tick at the drop.
struct PitchAccentView: View {
    let pitch: PitchPattern?
    let reading: String
    var font: Font = .system(.title3, design: .rounded, weight: .medium)

    var body: some View {
        if let pitch {
            let morae = PitchPattern.morae(of: reading)
            HStack(alignment: .bottom, spacing: 1) {
                ForEach(Array(morae.enumerated()), id: \.offset) { index, mora in
                    Text(mora)
                        .font(font)
                        .padding(.top, 5)
                        .overlay(alignment: .top) {
                            if pitch.isHigh(index) {
                                Rectangle().frame(height: 1.5).foregroundStyle(AppTheme.accent)
                            }
                        }
                        .overlay(alignment: .topTrailing) {
                            if pitch.dropAfter == index + 1 {
                                Rectangle().frame(width: 1.5, height: 9).foregroundStyle(AppTheme.accent)
                            }
                        }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(reading), \(pitch.accentType.rawValue)")
        } else {
            Text(reading).font(font)
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        PitchAccentView(pitch: PitchPattern.parse(pitch: "あいき↓どう", reading: "あいきどう"), reading: "あいきどう")
        PitchAccentView(pitch: PitchPattern.parse(pitch: "あらう○", reading: "あらう"), reading: "あらう")
        PitchAccentView(pitch: PitchPattern.parse(pitch: "ア↓イス", reading: "アイス"), reading: "アイス")
        PitchAccentView(pitch: PitchPattern.parse(pitch: "あたま↓", reading: "あたま"), reading: "あたま")
    }
    .padding()
}
