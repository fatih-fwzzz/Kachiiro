import SwiftUI
import KachiiroCore

struct QuizView: View {
    @State private var model: QuizSessionViewModel
    @State private var typed = ""
    @State private var selectedChoice: String?
    @State private var showScratchpad = QuizView.scratchpadOpenAtLaunch
    @FocusState private var typingFocused: Bool
    @State private var voiceEngaged = false
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(AppEnvironment.self) private var environment

    init(model: QuizSessionViewModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        Group {
            if model.isFinished {
                QuizSummaryView(model: model) { retry in
                    model = retry
                    typed = ""
                    selectedChoice = nil
                }
            } else if let question = model.currentQuestion {
                session(question)
            }
        }
        .background(AppTheme.canvas)
        .toolbar(.hidden, for: .tabBar)
        .toolbar(model.isFinished ? .hidden : .automatic, for: .navigationBar)
        .navigationTitle(model.isFinished ? "Summary" : "\(model.index + 1) / \(model.total)")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var isRegular: Bool { sizeClass == .regular }

    /// Reference content shown beside the quiz on iPad, by drill.
    private var referenceContent: ConjugationReferenceView.Content? {
        switch model.questions.first?.drill {
        case .verbForms: .verbChart
        case .inflectionMatrix, .registerShift: .matrix
        default: nil
        }
    }

    private func session(_ q: QuizQuestion) -> some View {
        Group {
            if isRegular {
                HStack(alignment: .top, spacing: 16) {
                    if let reference = referenceContent {
                        ConjugationReferenceView(content: reference)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay { RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(AppTheme.hairlineBorder) }
                            .frame(maxWidth: .infinity)
                    }
                    VStack(spacing: 12) {
                        quizColumn(q)
                        if showScratchpad { ScratchpadPanel().id(model.index) }
                    }
                    .frame(maxWidth: referenceContent == nil ? 760 : .infinity)
                }
                .padding(16)
            } else {
                quizColumn(q)
            }
        }
        .toolbar {
            if isRegular {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { withAnimation { showScratchpad.toggle() } } label: {
                        Image(systemName: showScratchpad ? "pencil.and.scribble" : "pencil.tip.crop.circle")
                    }
                    .accessibilityLabel(showScratchpad ? "Hide scratchpad" : "Show scratchpad")
                }
            }
        }
        .onChange(of: model.index) {
            typed = ""
            selectedChoice = nil
            voice.cancel()
            focusIfTyping()
        }
        .onChange(of: model.activeMode) { focusIfTyping() }
        .onChange(of: voice.transcript) {
            if voice.state == .listening { typed = voice.transcript }
        }
        .onChange(of: voice.state) {
            guard voice.state != .listening else { return }
            voiceEngaged = false
            focusIfTyping()
        }
        .onAppear {
            focusIfTyping()
            #if DEBUG
            applyDebugAutoAnswer()
            applyDebugListen(q)
            #endif
        }
        .onDisappear { voice.cancel() }
    }

    private func quizColumn(_ q: QuizQuestion) -> some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                VStack(spacing: 12) {
                    modePicker
                    stimulus(q)
                        .frame(maxWidth: .infinity)
                        .frame(height: geo.size.height * (showScratchpad ? 0.42 : 0.4))
                    ScrollView {
                        answerArea(q).padding(.bottom, 8)
                    }
                    .scrollDismissesKeyboard(.never)
                }
                .padding(.horizontal, isRegular ? 0 : 16)
                .padding(.top, isRegular ? 0 : 8)
            }
            if model.isJudging {
                CheckingSheet(title: "Checking your keigo")
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if let result = model.result {
                feedback(result, q)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: model.result != nil)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: model.isJudging)
    }

    #if DEBUG
    /// `-ui-scratchpad` opens the scratchpad panel at launch (screenshot smoke tests only).
    static var scratchpadOpenAtLaunch: Bool { ProcessInfo.processInfo.arguments.contains("-ui-scratchpad") }
    #else
    static var scratchpadOpenAtLaunch: Bool { false }
    #endif

    #if DEBUG
    /// `-ui-autoanswer <text>` answers the first question at launch (screenshot smoke tests only).
    /// `-ui-autofinish` answers every choice question (every third one wrongly) to reach the summary.
    private func applyDebugAutoAnswer() {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-ui-autofinish"), model.index == 0, model.result == nil {
            for (i, question) in model.questions.enumerated() {
                model.submitChoice(i % 3 == 2 ? "-" : question.correctChoice)
                guard model.result != nil else { return }
                model.next()
            }
            return
        }
        guard model.index == 0, model.result == nil, let i = args.firstIndex(of: "-ui-autoanswer"),
              args.indices.contains(i + 1) else { return }
        if model.activeMode == .typing {
            typed = args[i + 1]
            model.submitText(args[i + 1])
        } else {
            selectedChoice = args[i + 1]
            model.submitChoice(args[i + 1])
        }
    }

    /// `-ui-listen` starts the microphone at launch to prove the permission prompts (screenshot smoke tests only).
    private func applyDebugListen(_ q: QuizQuestion) {
        guard ProcessInfo.processInfo.arguments.contains("-ui-listen"), q.isSpeakable,
              model.activeMode == .typing else { return }
        voiceEngaged = true
        Task { await voice.start() }
    }
    #endif

    private var voice: VoiceInputModel { environment.voiceInput }

    private func focusIfTyping() {
        typingFocused = model.activeMode == .typing && model.result == nil && !voiceEngaged
    }

    private var modePicker: some View {
        Picker("Mode", selection: Binding(get: { model.activeMode }, set: { model.setMode($0) })) {
            Text("4-Choice").tag(InputMode.choice)
            Text("Typing").tag(InputMode.typing)
        }
        .pickerStyle(.segmented)
        .disabled(!(model.canType && model.canChoose))
    }

    private func stimulus(_ q: QuizQuestion) -> some View {
        QuestionCard(
            question: q, hasSpeech: model.hasSpeech, speechUnavailable: model.speechUnavailable,
            onPlay: { model.playPrompt(slow: $0) }
        )
    }

    @ViewBuilder
    private func answerArea(_ q: QuizQuestion) -> some View {
        if model.activeMode == .choice {
            ForEach(Array(q.choices.enumerated()), id: \.element) { index, choice in
                let look = choiceLook(choice, q)
                Button {
                    selectedChoice = choice
                    model.submitChoice(choice)
                } label: {
                    HStack(spacing: 14) {
                        Text("\(index + 1)")
                            .font(AppTheme.Fonts.ui(.footnote, weight: .heavy))
                            .foregroundStyle(look.keyInk)
                            .frame(width: 28, height: 28)
                            .background(look.keyFill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .accessibilityHidden(true)
                        Text(choice)
                            .font(AppTheme.Fonts.ui(.title3, weight: .semibold))
                            .foregroundStyle(look.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 60)
                    .background(look.fill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(look.border, lineWidth: 1.5)
                    }
                    .opacity(look.dimmed ? 0.45 : 1)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
                .disabled(model.result != nil)
                .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: [])
            }
        } else {
            VStack(spacing: 6) {
                HStack(spacing: 10) {
                    if q.isSpeakable {
                        MicButton(voice: voice, onStart: {
                            voiceEngaged = true
                            typingFocused = false
                        }, onStop: { text in
                            typed = text
                            if !text.trimmingCharacters(in: .whitespaces).isEmpty { model.submitText(text) }
                        })
                        .disabled(model.result != nil)
                    }
                    TextField(q.isSpeakable ? "Speak or type your answer" : "Type your answer", text: $typed)
                        .focused($typingFocused)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .font(AppTheme.Fonts.ui(.title3))
                        .disabled(model.result != nil)
                        .onSubmit(submitTyped)
                        .onChange(of: typingFocused) {
                            if !typingFocused, model.activeMode == .typing, model.result == nil,
                               !voiceEngaged, voice.state != .listening { typingFocused = true }
                        }
                    Button("Submit", action: submitTyped)
                        .keyboardShortcut(.return, modifiers: [])
                        .buttonStyle(.borderedProminent)
                        .disabled(model.result != nil || typed.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                if q.isSpeakable { VoiceStatusCaption(voice: voice) }
            }
            .quizCard(tint: AppTheme.elevatedField)
        }
    }

    private func submitTyped() {
        model.submitText(typed)
    }

    private struct ChoiceLook {
        var fill = AppTheme.cardSurface
        var ink = AppTheme.primaryInk
        var border = AppTheme.hairlineBorder
        var keyFill = AppTheme.elevatedField
        var keyInk = AppTheme.secondaryInk
        var dimmed = false
    }

    /// Blue for the right answer, ember for a wrong pick, the rest faded: never green and red.
    private func choiceLook(_ choice: String, _ q: QuizQuestion) -> ChoiceLook {
        guard model.result != nil else { return ChoiceLook() }
        if choice == q.correctChoice {
            return ChoiceLook(fill: AppTheme.accent, ink: .white, border: .clear,
                              keyFill: .white.opacity(0.22), keyInk: .white)
        }
        if choice == selectedChoice {
            return ChoiceLook(fill: AppTheme.emberSoftFill, ink: AppTheme.emberDeepText, border: AppTheme.ember,
                              keyFill: AppTheme.ember, keyInk: .white)
        }
        return ChoiceLook(dimmed: true)
    }

    private func feedback(_ result: QuizSessionViewModel.AnswerResult, _ q: QuizQuestion) -> some View {
        let isCorrect: Bool
        let detail: String?
        switch result {
        case .correct:
            isCorrect = true
            detail = nil
        case .wrong(let answer):
            isCorrect = false
            detail = "Answer: \(answer)"
        }
        var notes: [String] = []
        if let judgement = model.judgement {
            notes.append(judgement.explanation)
            if !judgement.corrected.isEmpty { notes.append("Better: \(judgement.corrected)") }
        }
        if let judgeError = model.judgeError { notes.append(judgeError) }
        notes.append(q.explanation)
        let isLast = model.index + 1 == model.total
        return FeedbackSheet(
            verdict: isCorrect ? .correct : .wrong,
            headline: isCorrect ? "正解！" : "Not quite",
            detail: detail,
            notes: notes,
            continueTitle: isLast ? "Finish" : (isCorrect ? "Continue" : "Got it"),
            isBookmarked: model.isCurrentBookmarked,
            onBookmark: { model.toggleBookmark() },
            onContinue: {
                voice.cancel()
                model.next()
            }
        ) {
            if q.drill == .pitch, let pitch = q.pitch, let reading = q.promptReading {
                // The pitch lines are blue, so they sit on a card rather than on the blue sheet.
                PitchAccentView(pitch: pitch, reading: reading)
                    .foregroundStyle(AppTheme.primaryInk)
                    .padding(10)
                    .background(AppTheme.cardSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }
}

#Preview {
    let questions = [
        QuizQuestion(
            id: ItemKey("vocab:1:m2w"), drill: .vocab, promptTitle: "て形 / te-form", promptBody: "食べる",
            promptReading: "たべる", choices: ["食べて", "食べって", "食べんで", "食べいて"], correctChoice: "食べて",
            explanation: "Group 2: drop る + て"
        ),
    ]
    NavigationStack {
        QuizView(model: QuizSessionViewModel(questions: questions, initialMode: .choice, repository: InMemoryProgressRepository()))
    }
}
