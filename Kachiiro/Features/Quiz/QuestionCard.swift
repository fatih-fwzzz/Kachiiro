import SwiftUI
import KachiiroCore

/// The stimulus card shared by quiz sessions and the mock exam: Japanese is always the largest thing on screen.
struct QuestionCard: View {
    let question: QuizQuestion
    var hasSpeech = false
    var speechUnavailable = false
    var onPlay: (_ slow: Bool) -> Void = { _ in }

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .top) {
                AppleBadge(text: question.promptTitle, icon: nil, style: .tintedBlue)
                Spacer(minLength: 8)
                if hasSpeech {
                    HStack(spacing: 8) {
                        Button { onPlay(false) } label: {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(AppTheme.accent, in: Circle())
                        }
                        .accessibilityLabel("Play")
                        Button { onPlay(true) } label: {
                            Text("Slow")
                                .font(AppTheme.Fonts.ui(.footnote, weight: .heavy))
                                .foregroundStyle(AppTheme.accentText)
                                .frame(width: 44, height: 44)
                                .background(AppTheme.accentSoftFill, in: Circle())
                        }
                        .accessibilityLabel("Play slowly")
                    }
                    .buttonStyle(.plain)
                }
            }
            if speechUnavailable {
                Label("No Japanese voice yet. Add one in Settings › Accessibility › Spoken Content › Voices.",
                      systemImage: "speaker.slash")
                    .font(AppTheme.Fonts.ui(.caption, weight: .semibold))
                    .foregroundStyle(AppTheme.emberText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer(minLength: 0)
            Text(question.promptBody)
                .font(.system(size: 52, weight: .bold))
                .foregroundStyle(AppTheme.primaryInk)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.4)
            if let reading = question.promptReading, !reading.isEmpty {
                // The pitch drill hides the accent until the answer is shown in the feedback sheet.
                if question.pitch != nil, question.drill != .pitch {
                    PitchAccentView(pitch: question.pitch, reading: reading)
                } else {
                    Text(reading).font(AppTheme.Fonts.ui(.title3)).foregroundStyle(AppTheme.secondaryInk)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(AppTheme.cardSurface, in: RoundedRectangle(cornerRadius: AppTheme.Radius.hero, style: .continuous))
    }
}
