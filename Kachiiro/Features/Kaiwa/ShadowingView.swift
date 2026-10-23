import SwiftUI
import KachiiroCore

struct ShadowingView: View {
    @State private var model: ShadowingViewModel
    @State private var started = false
    @Environment(AppEnvironment.self) private var environment

    init(viewModel: ShadowingViewModel) {
        _model = State(initialValue: viewModel)
    }

    private var voice: VoiceInputModel { environment.voiceInput }

    var body: some View {
        VStack(spacing: 12) {
            if model.isLoading {
                ProgressView("Generating phrases…").frame(maxHeight: .infinity)
            } else if let line = model.current {
                ScrollView {
                    VStack(spacing: 12) {
                        lineCard(line)
                        playButtons
                        if let result = model.result { resultCard(result) }
                        if voice.state == .listening, !voice.transcript.isEmpty {
                            Text(voice.transcript).font(.callout).foregroundStyle(AppTheme.secondaryInk)
                        }
                        VoiceStatusCaption(voice: voice)
                        if let error = model.errorMessage {
                            Text(error).font(.caption).foregroundStyle(AppTheme.secondaryInk)
                        }
                    }
                    .padding(16)
                }
                controls
            } else {
                ContentUnavailableView("No phrases", systemImage: "text.bubble")
            }
        }
        .background(AppTheme.canvas)
        .navigationTitle("Shadowing")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard !started else { return }
            started = true
            await model.load()
            #if DEBUG
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "-ui-autoanswer"), args.indices.contains(i + 1) {
                model.submit(args[i + 1])
            }
            #endif
        }
        .onChange(of: model.index) { voice.cancel() }
        .onDisappear { voice.cancel() }
    }

    private func lineCard(_ line: ShadowingLine) -> some View {
        VStack(spacing: 10) {
            Text(line.text)
                .font(AppTheme.Fonts.ui(.title, weight: .bold))
                .multilineTextAlignment(.center)
            if let reading = line.reading, !reading.isEmpty {
                if line.pitch != nil {
                    PitchAccentView(pitch: line.pitch, reading: reading)
                } else {
                    Text(reading).font(.title3).foregroundStyle(AppTheme.secondaryInk)
                }
            }
            Text(line.meaning).font(.callout).foregroundStyle(AppTheme.secondaryInk)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .quizCard()
    }

    private var playButtons: some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                Button { model.play(slow: false) } label: { Label("Play", systemImage: "speaker.wave.2.fill") }
                Button { model.play(slow: true) } label: { Label("Slow", systemImage: "tortoise.fill") }
            }
            .buttonStyle(.bordered)
            .disabled(!model.hasVoice)
            if !model.hasVoice {
                Text(QuizSessionViewModel.missingVoiceMessage)
                    .font(.caption).foregroundStyle(AppTheme.secondaryInk)
            }
        }
    }

    private func resultCard(_ result: ShadowingResult) -> some View {
        VStack(spacing: 8) {
            Text(diffText(result.segments)).font(AppTheme.Fonts.ui(.title2, weight: .medium))
            Text("\(Int((result.score * 100).rounded())) %")
                .font(AppTheme.Fonts.ui(.headline))
            Label(result.passed ? "Natural!" : "Try again",
                  systemImage: result.passed ? "checkmark.circle.fill" : "arrow.counterclockwise")
                .foregroundStyle(result.passed ? .green : .orange)
        }
        .frame(maxWidth: .infinity)
        .quizCard(tint: AppTheme.accentSoftFill)
    }

    private func diffText(_ segments: [DiffSegment]) -> AttributedString {
        var out = AttributedString()
        for segment in segments {
            var run = AttributedString(segment.text)
            switch segment.kind {
            case .match:
                run.foregroundColor = .primary
            case .missing:
                run.foregroundColor = .red
                run.strikethroughStyle = .single
            case .extra:
                run.foregroundColor = .orange
                run.underlineStyle = .single
            }
            out += run
        }
        return out
    }

    private var controls: some View {
        VStack(spacing: 10) {
            MicButton(voice: voice, diameter: 64, onStop: { model.submit($0) })
                .padding(.top, 4)
            HStack {
                Button { model.previous() } label: { Label("Prev", systemImage: "chevron.left") }
                    .disabled(model.index == 0)
                Spacer()
                Text("\(model.index + 1) / \(model.count)")
                    .font(.footnote.monospacedDigit()).foregroundStyle(AppTheme.secondaryInk)
                Spacer()
                Button { model.next() } label: { Label("Next", systemImage: "chevron.right").labelStyle(.titleAndIcon) }
                    .disabled(model.index + 1 >= model.count)
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
}
