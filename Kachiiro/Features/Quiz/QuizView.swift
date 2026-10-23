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
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    model.toggleBookmark()
                } label: {
                    Image(systemName: model.isCurrentBookmarked ? "star.fill" : "star")
                }
                .accessibilityLabel("Bookmark")
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
        GeometryReader { geo in
            VStack(spacing: 12) {
                modePicker
                stimulus(q)
                    .frame(maxWidth: .infinity)
                    .frame(height: geo.size.height * (showScratchpad ? 0.42 : 0.34))
                ScrollView {
                    VStack(spacing: 10) {
                        answerArea(q)
                        if model.isJudging {
                            ProgressView("Checking your keigo…").padding(.vertical, 8)
                        } else if let result = model.result {
                            feedback(result, q)
                        }
                    }
                    .padding(.bottom, 8)
                }
                .scrollDismissesKeyboard(.never)
                bottomBar
            }
            .padding(.horizontal, isRegular ? 0 : 16)
            .padding(.top, isRegular ? 0 : 8)
        }
    }

    #if DEBUG
    /// `-ui-scratchpad` opens the scratchpad panel at launch (screenshot smoke tests only).
    static var scratchpadOpenAtLaunch: Bool { ProcessInfo.processInfo.arguments.contains("-ui-scratchpad") }
    #else
    static var scratchpadOpenAtLaunch: Bool { false }
    #endif

    #if DEBUG
    /// `-ui-autoanswer <text>` answers the first question at launch (screenshot smoke tests only).
    private func applyDebugAutoAnswer() {
        let args = ProcessInfo.processInfo.arguments
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
                Button {
                    selectedChoice = choice
                    model.submitChoice(choice)
                } label: {
                    Text(choice)
                        .font(AppTheme.Fonts.ui(.title3, weight: .medium))
                        .foregroundStyle(AppTheme.primaryInk)
                        .frame(maxWidth: .infinity, minHeight: 24)
                        .quizCard(tint: choiceTint(choice, q), padding: 12)
                }
                .buttonStyle(.plain)
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

    private func choiceTint(_ choice: String, _ q: QuizQuestion) -> Color? {
        guard model.result != nil else { return nil }
        if choice == q.correctChoice { return Color.green.opacity(0.22) }
        if choice == selectedChoice { return Color.red.opacity(0.2) }
        return nil
    }

    private func feedback(_ result: QuizSessionViewModel.AnswerResult, _ q: QuizQuestion) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            switch result {
            case .correct:
                Label("Correct", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            case .wrong(let answer):
                Label("Answer: \(answer)", systemImage: "xmark.circle.fill").foregroundStyle(.red)
            }
            if let judgement = model.judgement {
                if !judgement.explanation.isEmpty {
                    Text(judgement.explanation).font(.callout).foregroundStyle(AppTheme.secondaryInk)
                }
                if !judgement.corrected.isEmpty {
                    Text("Better: \(judgement.corrected)").font(.callout)
                }
            }
            if let judgeError = model.judgeError {
                Text(judgeError).font(.callout).foregroundStyle(AppTheme.secondaryInk)
            }
            if !q.explanation.isEmpty {
                Text(q.explanation).font(.callout).foregroundStyle(AppTheme.secondaryInk)
            }
            if q.drill == .pitch, let pitch = q.pitch, let reading = q.promptReading {
                PitchAccentView(pitch: pitch, reading: reading)
            }
        }
        .font(AppTheme.Fonts.ui(.headline))
        .frame(maxWidth: .infinity, alignment: .leading)
        .quizCard(tint: AppTheme.accentSoftFill)
    }

    private var bottomBar: some View {
        Button {
            voice.cancel()
            model.next()
        } label: {
            Text(model.index + 1 == model.total ? "Finish" : "Next")
                .frame(maxWidth: .infinity)
        }
        .keyboardShortcut(.return, modifiers: [])
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(model.result == nil)
        .padding(.bottom, 8)
    }
}

struct QuizSummaryView: View {
    let model: QuizSessionViewModel
    let onRetry: (QuizSessionViewModel) -> Void

    var body: some View {
        List {
            Section {
                VStack(spacing: 4) {
                    Text("\(model.score) / \(model.total)")
                        .font(AppTheme.Fonts.ui(.largeTitle, weight: .bold))
                    Text("correct").foregroundStyle(AppTheme.secondaryInk)
                }
                .frame(maxWidth: .infinity)
                if let retry = model.makeRetrySession() {
                    Button("Retry wrong (\(retry.total))") { onRetry(retry) }
                }
            }
            Section("Questions") {
                ForEach(Array(zip(model.questions, model.answers).enumerated()), id: \.offset) { _, pair in
                    let (question, answer) = pair
                    HStack {
                        Image(systemName: answer.correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(answer.correct ? .green : .red)
                        VStack(alignment: .leading) {
                            Text(question.promptBody).lineLimit(2)
                            Text(question.correctChoice).font(.caption).foregroundStyle(AppTheme.secondaryInk)
                        }
                    }
                }
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
