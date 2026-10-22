import SwiftUI
import KachiiroCore

/// The stimulus card shared by quiz sessions and the mock exam.
struct QuestionCard: View {
    let question: QuizQuestion
    var hasSpeech = false
    var speechUnavailable = false
    var onPlay: (_ slow: Bool) -> Void = { _ in }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                AppleBadge(text: question.promptTitle, icon: nil, style: .tintedBlue)
                Spacer()
                if hasSpeech {
                    Button { onPlay(false) } label: { Image(systemName: "speaker.wave.2.fill") }
                        .accessibilityLabel("Play")
                    Button { onPlay(true) } label: { Image(systemName: "tortoise.fill") }
                        .accessibilityLabel("Play slowly")
                }
            }
            if speechUnavailable {
                Label(QuizSessionViewModel.missingVoiceMessage, systemImage: "speaker.slash")
                    .font(.footnote).foregroundStyle(.orange)
            }
            Spacer(minLength: 0)
            Text(question.promptBody)
                .font(AppTheme.Fonts.ui(.largeTitle, weight: .bold))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.5)
            if let reading = question.promptReading, !reading.isEmpty {
                // The pitch drill hides the accent until the answer is shown in the feedback banner.
                if question.pitch != nil, question.drill != .pitch {
                    PitchAccentView(pitch: question.pitch, reading: reading)
                } else {
                    Text(reading).font(AppTheme.Fonts.ui(.title3)).foregroundStyle(AppTheme.secondaryInk)
                }
            }
            Spacer(minLength: 0)
        }
        .quizCard()
    }
}
