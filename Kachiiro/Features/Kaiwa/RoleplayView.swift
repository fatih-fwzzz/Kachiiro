import SwiftUI
import KachiiroCore

struct RoleplayView: View {
    @State private var model: RoleplayViewModel
    @State private var typed = ""
    @State private var showModelAnswer = false
    @State private var started = false
    @Environment(AppEnvironment.self) private var environment

    init(viewModel: RoleplayViewModel) {
        _model = State(initialValue: viewModel)
    }

    private var voice: VoiceInputModel { environment.voiceInput }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 12) {
                        header
                        ForEach(model.lines) { line in
                            bubble(line).id(line.id)
                        }
                        if model.isFinished { finishedCard }
                    }
                    .padding(16)
                }
                .onChange(of: model.lines.count) {
                    if let last = model.lines.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
            if !model.isFinished { inputBar }
        }
        .background(AppTheme.canvas)
        .navigationTitle(model.scenario.titleJa)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard !started else { return }
            started = true
            model.start()
            #if DEBUG
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "-ui-autoanswer"), args.indices.contains(i + 1) {
                await model.submit(args[i + 1])
            }
            #endif
        }
        .onDisappear { voice.cancel() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(model.scenario.setting).font(.callout)
            Text("You: \(model.scenario.userRole) · Partner: \(model.scenario.partnerRole)")
                .font(.footnote).foregroundStyle(AppTheme.secondaryInk)
            Label(model.scenario.goal, systemImage: "target").font(.footnote.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .quizCard(tint: AppTheme.accentSoftFill)
    }

    @ViewBuilder
    private func bubble(_ line: RoleplayViewModel.Line) -> some View {
        switch line.speaker {
        case .partner:
            HStack(alignment: .top, spacing: 8) {
                Text(line.text)
                    .font(AppTheme.Fonts.ui(.title3))
                    .quizCard(tint: AppTheme.cardSurface, padding: 12)
                Button { model.replay(line) } label: {
                    Image(systemName: "speaker.wave.2.fill").padding(8)
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.accent)
                .accessibilityLabel("Play line")
                Spacer(minLength: 24)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .user:
            VStack(alignment: .trailing, spacing: 6) {
                Text(line.text)
                    .font(AppTheme.Fonts.ui(.title3))
                    .quizCard(tint: AppTheme.accentSoftFill, padding: 12)
                if let verdict = line.verdict { verdictChip(verdict) }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.leading, 40)
        }
    }

    @ViewBuilder
    private func verdictChip(_ verdict: RoleplayViewModel.Verdict) -> some View {
        switch verdict {
        case .passed(let note):
            VStack(alignment: .trailing, spacing: 2) {
                Label("Natural", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                Text(note).foregroundStyle(AppTheme.secondaryInk)
            }
            .font(.caption)
        case .failed(let modelAnswer, let note):
            VStack(alignment: .trailing, spacing: 2) {
                Label("Model answer: \(modelAnswer)", systemImage: "xmark.circle.fill").foregroundStyle(.red)
                Text(note).foregroundStyle(AppTheme.secondaryInk)
            }
            .font(.caption)
            .multilineTextAlignment(.trailing)
        }
    }

    private var finishedCard: some View {
        VStack(spacing: 10) {
            Text("\(model.passedCount) / \(model.userTurnCount) turns natural")
                .font(AppTheme.Fonts.ui(.headline))
            Button("Try again") {
                typed = ""
                showModelAnswer = false
                model.start()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .quizCard()
    }

    private var inputBar: some View {
        VStack(spacing: 8) {
            if let hint = model.currentHint {
                VStack(alignment: .leading, spacing: 4) {
                    Label(hint, systemImage: "lightbulb").font(.footnote)
                    if let answer = model.modelAnswer {
                        DisclosureGroup("Show model answer", isExpanded: $showModelAnswer) {
                            Text(answer).font(AppTheme.Fonts.ui(.callout))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .font(.footnote)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: 10) {
                MicButton(voice: voice, diameter: 52, onStop: { text in
                    typed = text
                    send(text)
                })
                TextField("Speak or type your reply", text: $typed)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.send)
                    .onSubmit { send(typed) }
                    .disabled(model.isWaiting)
                Button("Send") { send(typed) }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.isWaiting || typed.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            VoiceStatusCaption(voice: voice)
        }
        .padding(12)
        .background(AppTheme.cardSurface)
        .onChange(of: voice.transcript) {
            if voice.state == .listening { typed = voice.transcript }
        }
        .onChange(of: model.lines.count) { showModelAnswer = false }
    }

    private func send(_ text: String) {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        typed = ""
        voice.cancel()
        Task { await model.submit(input) }
    }
}
