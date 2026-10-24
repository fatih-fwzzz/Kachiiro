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
                        if model.isLiveMode {
                            if !model.liveUserDraft.isEmpty {
                                draftBubble(model.liveUserDraft, speaker: .user)
                            }
                            if !model.livePartnerDraft.isEmpty {
                                draftBubble(model.livePartnerDraft, speaker: .partner)
                            }
                            Color.clear.frame(height: 1).id("bottom")
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
                .onChange(of: model.livePartnerDraft) { proxy.scrollTo("bottom", anchor: .bottom) }
                .onChange(of: model.liveUserDraft) { proxy.scrollTo("bottom", anchor: .bottom) }
                .onChange(of: model.liveStatus) { proxy.scrollTo("bottom", anchor: .bottom) }
            }
            if !model.isFinished {
                if model.isLiveMode { liveBar } else { inputBar }
            }
        }
        .background(AppTheme.canvas)
        .navigationTitle(model.scenario.titleJa)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard !started else { return }
            started = true
            await model.start()
            #if DEBUG
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "-ui-autoanswer"), args.indices.contains(i + 1) {
                await model.submit(args[i + 1])
            }
            #endif
        }
        .onDisappear {
            voice.cancel()
            model.end()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(model.scenario.setting).font(.callout)
            Text("You: \(model.scenario.userRole) · Partner: \(model.scenario.partnerRole)")
                .font(.footnote).foregroundStyle(AppTheme.secondaryInk)
            Label(model.scenario.goal, systemImage: "target").font(.footnote.weight(.semibold))
            if model.isLiveMode {
                Label("Live voice · Gemini", systemImage: "waveform")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
            } else if model.isFreeMode {
                Label("AI conversation · \(environment.aiResolver.engineLabel)", systemImage: "sparkles")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
            }
            if let notice = environment.aiResolver.notice {
                Text(notice).font(.caption).foregroundStyle(AppTheme.secondaryInk)
            }
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
                if !model.isLiveMode {
                    Button { model.replay(line) } label: {
                        Image(systemName: "speaker.wave.2.fill").padding(8)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.accent)
                    .accessibilityLabel("Play line")
                }
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

    /// Speech transcribed so far in a live call, shown dimmed until it becomes a line.
    private func draftBubble(_ text: String, speaker: RoleplayViewModel.Speaker) -> some View {
        Text(text)
            .font(AppTheme.Fonts.ui(.title3))
            .quizCard(tint: speaker == .user ? AppTheme.accentSoftFill : AppTheme.cardSurface, padding: 12)
            .opacity(0.6)
            .frame(maxWidth: .infinity, alignment: speaker == .user ? .trailing : .leading)
            .padding(speaker == .user ? .leading : .trailing, 40)
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
        case .reviewed(let acceptable, let corrected, let explanation):
            VStack(alignment: .trailing, spacing: 2) {
                if acceptable {
                    Label("Natural", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                } else {
                    Label("Needs work", systemImage: "xmark.circle.fill").foregroundStyle(.red)
                }
                if !corrected.isEmpty { Text("Better: \(corrected)") }
                if !explanation.isEmpty { Text(explanation).foregroundStyle(AppTheme.secondaryInk) }
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
                Task { await model.start() }
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
            if model.isWaiting {
                ProgressView().frame(maxWidth: .infinity, alignment: .leading)
            }
            errorRow
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

    private var errorRow: some View {
        Group {
            if let error = model.errorMessage {
                HStack {
                    Text(error).font(.caption).foregroundStyle(AppTheme.secondaryInk)
                    if model.canRetry {
                        Button("Retry") { Task { await model.retryLast() } }
                            .font(.caption.weight(.semibold))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var liveBar: some View {
        let typingDisabled = model.liveStatus == .connecting || model.liveSession == nil
        return VStack(spacing: 8) {
            Label(model.scenario.goal, systemImage: "lightbulb")
                .font(.footnote)
                .frame(maxWidth: .infinity, alignment: .leading)
            errorRow
            HStack {
                liveStatusLabel
                Spacer()
                Button(role: .destructive) { model.hangUp() } label: {
                    Label("End", systemImage: "phone.down.fill")
                }
                .buttonStyle(.bordered)
            }
            HStack(spacing: 10) {
                TextField("Type a reply", text: $typed)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.send)
                    .onSubmit { send(typed) }
                    .disabled(typingDisabled)
                Button("Send") { send(typed) }
                    .buttonStyle(.borderedProminent)
                    .disabled(typingDisabled || typed.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(12)
        .background(AppTheme.cardSurface)
    }

    @ViewBuilder
    private var liveStatusLabel: some View {
        switch model.liveStatus {
        case .connecting:
            HStack(spacing: 6) { ProgressView(); Text("Connecting…") }
                .font(.footnote)
        case .listening where model.isMicrophoneOn:
            Label("Listening — just speak", systemImage: "waveform")
                .font(.footnote.weight(.semibold)).foregroundStyle(AppTheme.accent)
        case .listening:
            Label("Mic off — type your reply", systemImage: "mic.slash")
                .font(.footnote).foregroundStyle(AppTheme.secondaryInk)
        case .partnerSpeaking:
            Label("Partner speaking — talk to interrupt", systemImage: "speaker.wave.2.fill")
                .font(.footnote.weight(.semibold)).foregroundStyle(AppTheme.accent)
        case .idle:
            EmptyView()
        }
    }

    private func send(_ text: String) {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        typed = ""
        voice.cancel()
        Task { await model.submit(input) }
    }
}
