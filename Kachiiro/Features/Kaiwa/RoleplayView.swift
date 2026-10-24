import SwiftUI
import KachiiroCore

/// A conversation, not a quiz: the brief up top, bubbles with verdicts attached to your lines,
/// and a microphone-first input. A live Gemini call turns the screen into a call (navy, status orb, end button).
struct RoleplayView: View {
    @State private var model: RoleplayViewModel
    @State private var typed = ""
    @State private var showModelAnswer = false
    @State private var showHint = false
    @State private var showKeyboard = false
    @State private var started = false
    @Environment(AppEnvironment.self) private var environment

    init(viewModel: RoleplayViewModel) {
        _model = State(initialValue: viewModel)
    }

    private var voice: VoiceInputModel { environment.voiceInput }
    private var live: Bool { model.isLiveMode }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 12) {
                        brief
                        ForEach(model.lines) { line in
                            bubble(line).id(line.id)
                        }
                        if live {
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
                    .frame(maxWidth: 720)
                    .frame(maxWidth: .infinity)
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
                if live { liveBar } else { inputBar }
            }
        }
        .background(live ? AppTheme.kachiiro : AppTheme.canvas)
        .toolbar(.hidden, for: .tabBar)
        .toolbarColorScheme(live ? .dark : nil, for: .navigationBar)
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

    // MARK: Brief

    private var brief: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(model.scenario.setting).font(AppTheme.Fonts.ui(.subheadline))
            HStack(spacing: 8) {
                rolePill("You", model.scenario.userRole)
                rolePill("Partner", model.scenario.partnerRole)
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "target").foregroundStyle(live ? AppTheme.onKachiiroLabel : AppTheme.accentText)
                Text(model.scenario.goal).font(AppTheme.Fonts.ui(.subheadline, weight: .bold))
            }
            if live {
                Label("Live voice call · AI partner", systemImage: "waveform")
                    .font(AppTheme.Fonts.ui(.footnote, weight: .bold))
                    .foregroundStyle(AppTheme.onKachiiroLabel)
            } else if model.isFreeMode {
                Label("AI conversation", systemImage: "sparkles")
                    .font(AppTheme.Fonts.ui(.footnote, weight: .bold))
                    .foregroundStyle(AppTheme.accentText)
            }
            if let notice = environment.aiResolver.notice(for: .checking) {
                Banner(kind: .info, title: "Using offline checks", message: notice)
            }
        }
        .foregroundStyle(live ? Color.white : AppTheme.primaryInk)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(live ? AppTheme.onKachiiroFill : AppTheme.cardSurface,
                    in: RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
    }

    private func rolePill(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label.uppercased())
                .font(AppTheme.Fonts.ui(.caption2, weight: .heavy))
                .foregroundStyle(live ? AppTheme.onKachiiroLabel : AppTheme.secondaryInk)
            Text(value).font(AppTheme.Fonts.ui(.footnote, weight: .bold)).lineLimit(2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(live ? AppTheme.onKachiiroFill : AppTheme.elevatedField,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: Bubbles

    @ViewBuilder
    private func bubble(_ line: RoleplayViewModel.Line) -> some View {
        switch line.speaker {
        case .partner:
            HStack(alignment: .bottom, spacing: 8) {
                Text(line.text)
                    .font(AppTheme.Fonts.ui(.title3))
                    .foregroundStyle(live ? Color.white : AppTheme.primaryInk)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(live ? AppTheme.onKachiiroFill : AppTheme.cardSurface,
                                in: UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: 6,
                                                           bottomTrailingRadius: 18, topTrailingRadius: 18, style: .continuous))
                if !live {
                    Button { model.replay(line) } label: {
                        Image(systemName: "play.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 36, height: 36)
                            .background(AppTheme.accentSoftFill, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Play line")
                }
                Spacer(minLength: 24)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .user:
            let failed = line.verdict?.isFailure == true
            VStack(alignment: .trailing, spacing: 6) {
                Text(line.text)
                    .font(AppTheme.Fonts.ui(.title3))
                    .foregroundStyle(failed ? AppTheme.emberDeepText : .white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background {
                        let shape = UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: 18,
                                                           bottomTrailingRadius: 6, topTrailingRadius: 18, style: .continuous)
                        if failed {
                            shape.fill(AppTheme.emberSoftFill).overlay(shape.stroke(AppTheme.ember, lineWidth: 2))
                        } else {
                            shape.fill(AppTheme.accent)
                        }
                    }
                if let verdict = line.verdict { verdictView(verdict) }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.leading, 40)
        }
    }

    /// Speech transcribed so far in a live call, dashed until it becomes a line.
    private func draftBubble(_ text: String, speaker: RoleplayViewModel.Speaker) -> some View {
        Text(text)
            .font(AppTheme.Fonts.ui(.title3))
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(.white.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            }
            .frame(maxWidth: .infinity, alignment: speaker == .user ? .trailing : .leading)
            .padding(speaker == .user ? .leading : .trailing, 40)
    }

    @ViewBuilder
    private func verdictView(_ verdict: RoleplayViewModel.Verdict) -> some View {
        switch verdict {
        case .passed(let note):
            naturalChip(note)
        case .reviewed(true, let corrected, let explanation):
            naturalChip([corrected.isEmpty ? nil : "Also: \(corrected)", explanation].compactMap { $0 }.joined(separator: " "))
        case .failed(let modelAnswer, let note):
            tryThisCard(better: modelAnswer, note: note)
        case .reviewed(false, let corrected, let explanation):
            tryThisCard(better: corrected, note: explanation)
        }
    }

    private func naturalChip(_ note: String) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Label("Natural", systemImage: "checkmark")
                .font(AppTheme.Fonts.ui(.caption, weight: .heavy))
                .foregroundStyle(live ? AppTheme.onKachiiroLabel : AppTheme.accentText)
            if !note.isEmpty {
                Text(note)
                    .font(AppTheme.Fonts.ui(.caption))
                    .foregroundStyle(live ? AppTheme.onKachiiroSecondary : AppTheme.secondaryInk)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private func tryThisCard(better: String, note: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("TRY THIS").font(AppTheme.Fonts.ui(.caption2, weight: .heavy)).foregroundStyle(AppTheme.emberText)
            if !better.isEmpty {
                Text(better).font(AppTheme.Fonts.ui(.callout, weight: .bold)).foregroundStyle(AppTheme.primaryInk)
            }
            if !note.isEmpty {
                Text(note).font(AppTheme.Fonts.ui(.caption)).foregroundStyle(AppTheme.secondaryInk)
            }
        }
        .padding(12)
        .frame(maxWidth: 300, alignment: .leading)
        .background(AppTheme.cardSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var finishedCard: some View {
        VStack(spacing: 12) {
            Text("\(model.passedCount) of \(model.userTurnCount) turns sounded natural")
                .font(AppTheme.Fonts.ui(.headline, weight: .heavy))
                .foregroundStyle(live ? Color.white : AppTheme.primaryInk)
                .multilineTextAlignment(.center)
            LinearProgress(value: Double(model.passedCount) / Double(max(model.userTurnCount, 1)),
                           track: live ? .white.opacity(0.14) : AppTheme.track)
            Button("Try again") {
                typed = ""
                showModelAnswer = false
                Task { await model.start() }
            }
            .buttonStyle(.primary)
        }
        .padding(16)
        .background(live ? AppTheme.onKachiiroFill : AppTheme.cardSurface,
                    in: RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
    }

    // MARK: Chat input

    private var inputBar: some View {
        VStack(spacing: 10) {
            if showHint, let hint = model.currentHint {
                Label(hint, systemImage: "lightbulb.fill")
                    .font(AppTheme.Fonts.ui(.footnote))
                    .foregroundStyle(AppTheme.primaryInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if showModelAnswer, let answer = model.modelAnswer {
                Text(answer)
                    .font(AppTheme.Fonts.ui(.callout, weight: .bold))
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.accentSoftFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            if model.currentHint != nil || model.modelAnswer != nil {
                HStack(spacing: 8) {
                    if model.currentHint != nil {
                        chip(showHint ? "Hide hint" : "Hint", icon: "lightbulb") { showHint.toggle() }
                    }
                    if model.modelAnswer != nil {
                        chip(showModelAnswer ? "Hide answer" : "Show model answer", icon: "text.bubble") { showModelAnswer.toggle() }
                    }
                    Spacer()
                }
            }
            if model.isWaiting {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Your partner is replying…").font(AppTheme.Fonts.ui(.footnote))
                }
                .foregroundStyle(AppTheme.secondaryInk)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            errorBanner
            HStack(spacing: 10) {
                TextField("Speak or type your reply", text: $typed)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.send)
                    .onSubmit { send(typed) }
                    .disabled(model.isWaiting)
                    .font(AppTheme.Fonts.ui(.body))
                    .padding(.horizontal, 14)
                    .frame(minHeight: 48)
                    .background(AppTheme.elevatedField, in: RoundedRectangle(cornerRadius: AppTheme.Radius.control, style: .continuous))
                if !typed.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button { send(typed) } label: {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundStyle(.white)
                            .frame(width: 48, height: 48)
                            .background(AppTheme.accent, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(model.isWaiting)
                    .accessibilityLabel("Send")
                } else {
                    MicButton(voice: voice, diameter: 56, onStop: { text in
                        typed = text
                        send(text)
                    })
                    .background(AppTheme.accentSoftFill, in: Circle())
                }
            }
            VoiceStatusCaption(voice: voice)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppTheme.cardSurface.shadow(.drop(color: .black.opacity(0.06), radius: 8, y: -2)))
        .onChange(of: voice.transcript) {
            if voice.state == .listening { typed = voice.transcript }
        }
        .onChange(of: model.lines.count) {
            showModelAnswer = false
            showHint = false
        }
    }

    private func chip(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(AppTheme.Fonts.ui(.footnote, weight: .bold))
                .foregroundStyle(AppTheme.primaryInk)
                .padding(.horizontal, 12)
                .frame(minHeight: 34)
                .background(AppTheme.elevatedField, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var errorBanner: some View {
        if let error = model.errorMessage {
            Banner(kind: .warning, title: "That turn didn’t go through", message: error,
                   action: model.canRetry ? .init(title: "Retry") { Task { await model.retryLast() } } : nil)
        }
    }

    // MARK: Live call

    private var liveBar: some View {
        let typingDisabled = model.liveStatus == .connecting || model.liveSession == nil
        return VStack(spacing: 14) {
            errorBanner
            HStack(spacing: 16) {
                statusOrb
                VStack(alignment: .leading, spacing: 2) {
                    Text(statusTitle).font(AppTheme.Fonts.ui(.headline, weight: .heavy))
                    Text(statusHint).font(AppTheme.Fonts.ui(.footnote)).foregroundStyle(AppTheme.onKachiiroSecondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.updatesFrequently)
                Spacer(minLength: 8)
                Button { showKeyboard.toggle() } label: {
                    Image(systemName: "keyboard")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 52, height: 52)
                        .background(.white.opacity(showKeyboard ? 0.25 : 0.12), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(showKeyboard ? "Hide keyboard" : "Type a reply")
                Button { model.hangUp() } label: {
                    Image(systemName: "phone.down.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .frame(width: 52, height: 52)
                        .background(Color.red, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("End call")
            }
            if showKeyboard {
                HStack(spacing: 10) {
                    TextField("Type a reply", text: $typed)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.send)
                        .onSubmit { send(typed) }
                        .disabled(typingDisabled)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 48)
                        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: AppTheme.Radius.control, style: .continuous))
                    Button { send(typed) } label: {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 18, weight: .heavy))
                            .frame(width: 48, height: 48)
                            .background(AppTheme.accent, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(typingDisabled || typed.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityLabel("Send")
                }
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.black.opacity(0.18))
    }

    private var statusOrb: some View {
        let active = model.liveStatus == .listening && model.isMicrophoneOn
        let speaking = model.liveStatus == .partnerSpeaking
        return ZStack {
            Circle().fill((active || speaking) ? Color(hex: 0x0A84FF).opacity(0.25) : .white.opacity(0.06))
                .frame(width: 64, height: 64)
            Circle().fill(active ? AppTheme.accent : Color(hex: 0x2B3170)).frame(width: 48, height: 48)
            if model.liveStatus == .connecting {
                ProgressView().tint(.white)
            } else {
                Image(systemName: speaking ? "waveform" : (active ? "mic.fill" : "mic.slash.fill"))
                    .font(.system(size: 18, weight: .bold))
                    .symbolEffect(.variableColor.iterative, isActive: speaking)
            }
        }
        .accessibilityHidden(true)
    }

    private var statusTitle: String {
        switch model.liveStatus {
        case .connecting: "Connecting…"
        case .listening where model.isMicrophoneOn: "Your turn: just speak"
        case .listening: "Mic off"
        case .partnerSpeaking: "Partner speaking"
        case .idle: "Call ended"
        }
    }

    private var statusHint: String {
        switch model.liveStatus {
        case .connecting: "Setting up the call"
        case .listening where model.isMicrophoneOn: "Pause for a moment when you finish"
        case .listening: "Type your reply instead"
        case .partnerSpeaking: "Start talking to interrupt"
        case .idle: ""
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

private extension RoleplayViewModel.Verdict {
    var isFailure: Bool {
        switch self {
        case .failed: true
        case .reviewed(let acceptable, _, _): !acceptable
        case .passed: false
        }
    }
}
