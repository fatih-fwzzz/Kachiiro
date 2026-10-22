import SwiftUI
import KachiiroCore

struct QuizView: View {
    @State private var model: QuizSessionViewModel
    @State private var typed = ""
    @State private var selectedChoice: String?
    @FocusState private var typingFocused: Bool

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

    private func session(_ q: QuizQuestion) -> some View {
        GeometryReader { geo in
            VStack(spacing: 12) {
                modePicker
                stimulus(q)
                    .frame(maxWidth: .infinity)
                    .frame(height: geo.size.height * 0.34)
                ScrollView {
                    VStack(spacing: 10) {
                        answerArea(q)
                        if let result = model.result { feedback(result, q) }
                    }
                    .padding(.bottom, 8)
                }
                .scrollDismissesKeyboard(.never)
                bottomBar
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .toolbar {
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
            focusIfTyping()
        }
        .onChange(of: model.activeMode) { focusIfTyping() }
        .onAppear { focusIfTyping() }
    }

    private func focusIfTyping() {
        typingFocused = model.activeMode == .typing && model.result == nil
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
        VStack(spacing: 10) {
            HStack {
                AppleBadge(text: q.promptTitle, icon: nil, style: .tintedBlue)
                Spacer()
                if model.hasSpeech {
                    Button { model.playPrompt(slow: false) } label: {
                        Image(systemName: "speaker.wave.2.fill")
                    }
                    .accessibilityLabel("Play")
                    Button { model.playPrompt(slow: true) } label: {
                        Image(systemName: "tortoise.fill")
                    }
                    .accessibilityLabel("Play slowly")
                }
            }
            Spacer(minLength: 0)
            Text(q.promptBody)
                .font(AppTheme.Fonts.ui(.largeTitle, weight: .bold))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.5)
            if let reading = q.promptReading, !reading.isEmpty {
                if q.pitch != nil {
                    PitchAccentView(pitch: q.pitch, reading: reading)
                } else {
                    Text(reading).font(AppTheme.Fonts.ui(.title3)).foregroundStyle(AppTheme.secondaryInk)
                }
            }
            Spacer(minLength: 0)
        }
        .quizCard()
    }

    @ViewBuilder
    private func answerArea(_ q: QuizQuestion) -> some View {
        if model.activeMode == .choice {
            ForEach(q.choices, id: \.self) { choice in
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
            }
        } else {
            HStack(spacing: 10) {
                TextField("Type your answer", text: $typed)
                    .focused($typingFocused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .font(AppTheme.Fonts.ui(.title3))
                    .disabled(model.result != nil)
                    .onSubmit(submitTyped)
                    .onChange(of: typingFocused) {
                        if !typingFocused, model.activeMode == .typing, model.result == nil { typingFocused = true }
                    }
                Button("Submit", action: submitTyped)
                    .buttonStyle(.borderedProminent)
                    .disabled(model.result != nil || typed.trimmingCharacters(in: .whitespaces).isEmpty)
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
        VStack(alignment: .leading, spacing: 6) {
            switch result {
            case .correct:
                Label("Correct", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            case .wrong(let answer):
                Label("Answer: \(answer)", systemImage: "xmark.circle.fill").foregroundStyle(.red)
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
            model.next()
        } label: {
            Text(model.index + 1 == model.total ? "Finish" : "Next")
                .frame(maxWidth: .infinity)
        }
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
