import SwiftUI
import KachiiroCore

/// Listen → speak → compare. Only what was missed is coloured, and the mic is the obvious action.
struct ShadowingView: View {
    @State private var model: ShadowingViewModel
    @State private var started = false
    @Environment(AppEnvironment.self) private var environment

    init(viewModel: ShadowingViewModel) {
        _model = State(initialValue: viewModel)
    }

    private var voice: VoiceInputModel { environment.voiceInput }

    private enum Step: Int { case listen, speak, compare }

    private var step: Step {
        if model.result != nil { return .compare }
        return voice.state == .listening ? .speak : .listen
    }

    var body: some View {
        VStack(spacing: 0) {
            if model.isLoading {
                VStack(spacing: 10) {
                    ProgressView().controlSize(.large)
                    Text("Writing fresh phrases…").font(AppTheme.Fonts.ui(.headline, weight: .heavy))
                }
                .frame(maxHeight: .infinity)
            } else if let line = model.current {
                ScrollView {
                    VStack(spacing: 14) {
                        stepBar
                        lineCard(line)
                        if let result = model.result { resultCard(result) }
                        if voice.state == .listening, !voice.transcript.isEmpty {
                            Text(voice.transcript)
                                .font(AppTheme.Fonts.ui(.title3, weight: .semibold))
                                .foregroundStyle(AppTheme.accentText)
                                .frame(maxWidth: .infinity)
                        }
                        VoiceStatusCaption(voice: voice)
                        if let error = model.errorMessage {
                            Banner(kind: .info, title: "Showing built-in phrases", message: error)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .frame(maxWidth: 640)
                    .frame(maxWidth: .infinity)
                }
                controls
            } else {
                ContentUnavailableView("No phrases", systemImage: "text.bubble",
                                       description: Text("Shadowing phrases couldn’t be loaded."))
            }
        }
        .background(AppTheme.canvas)
        .toolbar(.hidden, for: .tabBar)
        .navigationTitle("Shadowing")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if model.count > 0 {
                    Text("\(model.index + 1) / \(model.count)")
                        .font(AppTheme.Fonts.ui(.subheadline, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(AppTheme.secondaryInk)
                }
            }
        }
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

    private var stepBar: some View {
        HStack(spacing: 6) {
            ForEach([(Step.listen, "1 Listen"), (.speak, "2 Speak"), (.compare, "3 Compare")], id: \.0) { item, label in
                let reached = item.rawValue <= step.rawValue
                let missed = item == .compare && model.result?.passed == false
                VStack(spacing: 6) {
                    Capsule()
                        .fill(missed ? AppTheme.ember : (reached ? AppTheme.accent : AppTheme.track))
                        .frame(height: 6)
                    Text(label)
                        .font(AppTheme.Fonts.ui(.caption, weight: .bold))
                        .foregroundStyle(missed ? AppTheme.emberText : (reached ? AppTheme.accentText : AppTheme.secondaryInk))
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(step.rawValue + 1) of 3")
    }

    private func lineCard(_ line: ShadowingLine) -> some View {
        VStack(spacing: 10) {
            Text(line.text)
                .font(.system(size: 34, weight: .bold))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
            if let reading = line.reading, !reading.isEmpty {
                if line.pitch != nil {
                    PitchAccentView(pitch: line.pitch, reading: reading)
                } else {
                    Text(reading).font(AppTheme.Fonts.ui(.title3)).foregroundStyle(AppTheme.secondaryInk)
                }
            }
            Text(line.meaning)
                .font(AppTheme.Fonts.ui(.subheadline))
                .foregroundStyle(AppTheme.secondaryInk)
                .multilineTextAlignment(.center)
            HStack(spacing: 10) {
                Button { model.play(slow: false) } label: {
                    Label("Listen", systemImage: "play.fill").padding(.horizontal, 18)
                }
                .buttonStyle(SecondaryButtonStyle(height: 44))
                .fixedSize()
                Button { model.play(slow: true) } label: { Label("Slow", systemImage: "tortoise.fill").padding(.horizontal, 16) }
                    .buttonStyle(SecondaryButtonStyle(height: 44))
                    .fixedSize()
                    .accessibilityLabel("Listen slowly")
            }
            .disabled(!model.hasVoice)
            .padding(.top, 4)
            if !model.hasVoice {
                Text(QuizSessionViewModel.missingVoiceMessage)
                    .font(AppTheme.Fonts.ui(.caption))
                    .foregroundStyle(AppTheme.emberText)
                    .multilineTextAlignment(.center)
            }
        }
        .foregroundStyle(AppTheme.primaryInk)
        .padding(.horizontal, 18)
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity)
        .background(AppTheme.cardSurface, in: RoundedRectangle(cornerRadius: AppTheme.Radius.hero, style: .continuous))
    }

    private func resultCard(_ result: ShadowingResult) -> some View {
        let tint = result.passed ? AppTheme.accent : AppTheme.ember
        return HStack(spacing: 14) {
            ProgressRing(value: result.score, lineWidth: 7, tint: tint,
                         track: result.passed ? AppTheme.accentSoftFill : AppTheme.ember.opacity(0.2)) {
                Text("\(Int((result.score * 100).rounded()))")
                    .font(AppTheme.Fonts.ui(.headline, weight: .heavy))
                    .monospacedDigit()
            }
            .frame(width: 58, height: 58)
            VStack(alignment: .leading, spacing: 4) {
                Text(diffText(result.segments)).font(AppTheme.Fonts.ui(.title3, weight: .bold))
                Text(result.passed ? "Natural! On to the next phrase." : "Almost. Say the coloured part once more.")
                    .font(AppTheme.Fonts.ui(.footnote))
                    .foregroundStyle(result.passed ? AppTheme.accentText : AppTheme.emberText)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(AppTheme.primaryInk)
        .padding(16)
        .background(result.passed ? AppTheme.accentSoftFill : AppTheme.emberSoftFill,
                    in: RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous).strokeBorder(tint, lineWidth: 2)
        }
        .accessibilityElement(children: .combine)
    }

    /// Missing sounds are underlined in ember, extra ones struck through; matches stay plain.
    private func diffText(_ segments: [DiffSegment]) -> AttributedString {
        var out = AttributedString()
        for segment in segments {
            var run = AttributedString(segment.text)
            switch segment.kind {
            case .match:
                break
            case .missing:
                run.foregroundColor = UIColor(hex: 0xB25000)
                run.underlineStyle = .thick
            case .extra:
                run.foregroundColor = UIColor(hex: 0x8A90A8)
                run.strikethroughStyle = .single
            }
            out += run
        }
        return out
    }

    private var controls: some View {
        HStack {
            Button { model.previous() } label: {
                Image(systemName: "chevron.left").font(.system(size: 18, weight: .bold)).frame(width: 52, height: 52)
                    .background(AppTheme.cardSurface, in: Circle())
            }
            .disabled(model.index == 0)
            .accessibilityLabel("Previous phrase")
            Spacer()
            VStack(spacing: 6) {
                MicButton(voice: voice, diameter: 84, onStop: { model.submit($0) })
                    .background(AppTheme.accentSoftFill, in: Circle())
                Text(voice.state == .listening ? "Tap to stop" : "Tap and repeat")
                    .font(AppTheme.Fonts.ui(.footnote, weight: .bold))
                    .foregroundStyle(AppTheme.secondaryInk)
            }
            Spacer()
            Button { model.next() } label: {
                Image(systemName: "chevron.right").font(.system(size: 18, weight: .bold)).frame(width: 52, height: 52)
                    .background(AppTheme.cardSurface, in: Circle())
            }
            .disabled(model.index + 1 >= model.count)
            .accessibilityLabel("Next phrase")
        }
        .buttonStyle(.plain)
        .foregroundStyle(AppTheme.accentText)
        .padding(.horizontal, 28)
        .padding(.vertical, 12)
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity)
    }
}
