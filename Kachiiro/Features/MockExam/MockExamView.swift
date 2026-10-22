import Combine
import SwiftUI
import KachiiroCore

struct MockExamView: View {
    @State private var viewModel: MockExamViewModel
    @State private var retry: QuizSessionViewModel?
    @State private var isRetrying = false

    init(viewModel: MockExamViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        Group {
            switch viewModel.phase {
            case .notStarted: MockExamStartView(viewModel: viewModel)
            case .running: MockExamSessionView(viewModel: viewModel)
            case .finished: MockExamResultView(viewModel: viewModel) { session in
                retry = session
                isRetrying = true
            }
            }
        }
        .background(AppTheme.canvas)
        .navigationTitle("Mock Exam")
        .navigationBarTitleDisplayMode(viewModel.phase == .notStarted ? .large : .inline)
        .navigationDestination(isPresented: $isRetrying) {
            if let retry { QuizView(model: retry) }
        }
        .onAppear {
            #if DEBUG
            applyDebugAutostart()
            #endif
        }
    }

    #if DEBUG
    /// `-ui-autostart start|submit` starts the exam (and submits it unanswered) at launch for screenshots.
    private func applyDebugAutostart() {
        let args = ProcessInfo.processInfo.arguments
        guard viewModel.phase == .notStarted, let i = args.firstIndex(of: "-ui-autostart"), args.indices.contains(i + 1) else { return }
        viewModel.start()
        if args[i + 1] == "submit" { viewModel.submit() }
    }
    #endif
}

private struct MockExamStartView: View {
    let viewModel: MockExamViewModel

    var body: some View {
        List {
            Section("Rules") {
                Label("\(MockExamViewModel.questionCount) questions, \(Int(MockExamViewModel.timeLimit / 60)) minutes", systemImage: "timer")
                Label("No feedback while you answer", systemImage: "eye.slash")
                Label("You cannot go back to a question", systemImage: "arrow.forward")
                Label("Unanswered questions count as wrong", systemImage: "xmark.circle")
            }
            Section("Questions") {
                ForEach(Pillar.allCases.filter { p in MockExamViewModel.allocation.contains { $0.drill.pillar == p } }, id: \.self) { pillar in
                    HStack {
                        Text(pillar.title)
                        Spacer()
                        Text("\(MockExamViewModel.allocation.filter { $0.drill.pillar == pillar }.reduce(0) { $0 + $1.count })")
                            .foregroundStyle(AppTheme.secondaryInk)
                    }
                }
            }
            Section {
                Label("The exam uses your current study scope (Settings). A narrow scope can shrink the exam.", systemImage: "scope")
                    .font(.footnote).foregroundStyle(AppTheme.secondaryInk)
                if let note = viewModel.note {
                    Label(note, systemImage: "exclamationmark.triangle").font(.footnote).foregroundStyle(.orange)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button { viewModel.start() } label: {
                Text("Start exam").frame(maxWidth: .infinity).font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding()
            .background(.regularMaterial)
        }
    }
}

private struct MockExamSessionView: View {
    let viewModel: MockExamViewModel
    @State private var typed = ""
    @State private var selected: String?
    @FocusState private var typingFocused: Bool
    @State private var confirmSubmit = false
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        if let q = viewModel.currentQuestion {
            GeometryReader { geo in
                VStack(spacing: 12) {
                    header
                    Picker("Mode", selection: Binding(get: { viewModel.activeMode }, set: { viewModel.setMode($0) })) {
                        Text("4-Choice").tag(InputMode.choice)
                        Text("Typing").tag(InputMode.typing)
                    }
                    .pickerStyle(.segmented)
                    .disabled(!(viewModel.canType && viewModel.canChoose))
                    QuestionCard(
                        question: q, hasSpeech: viewModel.hasSpeech, speechUnavailable: viewModel.speechUnavailable,
                        onPlay: { viewModel.playPrompt(slow: $0) }
                    )
                    .frame(height: geo.size.height * 0.34)
                    ScrollView { answerArea(q) }
                    HStack {
                        Button("Submit exam", role: .destructive) { confirmSubmit = true }
                        Spacer()
                        Button(viewModel.isLastQuestion ? "Finish" : "Next") { viewModel.next() }
                            .buttonStyle(.borderedProminent)
                    }
                    .padding(.bottom, 8)
                }
                .padding(.horizontal, 16)
            }
            .onReceive(ticker) { _ in viewModel.tick() }
            .onChange(of: viewModel.index) {
                typed = ""
                selected = viewModel.currentAnswer
                typingFocused = viewModel.activeMode == .typing
            }
            .onAppear {
                selected = viewModel.currentAnswer
                typingFocused = viewModel.activeMode == .typing
            }
            .confirmationDialog("Submit the exam now?", isPresented: $confirmSubmit, titleVisibility: .visible) {
                Button("Submit", role: .destructive) { viewModel.submit() }
            } message: {
                Text("\(viewModel.questions.count - viewModel.answeredCount) unanswered questions will count as wrong.")
            }
        }
    }

    private var header: some View {
        HStack {
            Text("\(viewModel.index + 1) / \(viewModel.questions.count)").font(.headline.monospacedDigit())
            Spacer()
            Label(timeString(viewModel.remaining), systemImage: "timer")
                .font(.headline.monospacedDigit())
                .foregroundStyle(viewModel.remaining < 120 ? .red : AppTheme.accent)
        }
        .padding(.top, 8)
    }

    private func timeString(_ t: TimeInterval) -> String {
        let s = Int(t.rounded(.up))
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    @ViewBuilder
    private func answerArea(_ q: QuizQuestion) -> some View {
        if viewModel.activeMode == .choice {
            VStack(spacing: 10) {
                ForEach(q.choices, id: \.self) { choice in
                    Button {
                        selected = choice
                        viewModel.answerChoice(choice)
                    } label: {
                        Text(choice)
                            .font(AppTheme.Fonts.ui(.title3, weight: .medium))
                            .foregroundStyle(AppTheme.primaryInk)
                            .frame(maxWidth: .infinity, minHeight: 24)
                            .quizCard(tint: selected == choice ? AppTheme.accentMediumFill : nil, padding: 12)
                    }
                    .buttonStyle(.plain)
                }
            }
        } else {
            TextField("Type your answer", text: $typed)
                .focused($typingFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(AppTheme.Fonts.ui(.title3))
                .onChange(of: typed) { viewModel.answerText(typed) }
                .quizCard(tint: AppTheme.elevatedField)
        }
    }
}

private struct MockExamResultView: View {
    let viewModel: MockExamViewModel
    let onRetry: (QuizSessionViewModel) -> Void

    var body: some View {
        if let r = viewModel.result {
            List {
                Section {
                    VStack(spacing: 4) {
                        Text("\(r.correct) / \(r.total)").font(AppTheme.Fonts.ui(.largeTitle, weight: .bold))
                        Text("\(Int((Double(r.correct) / Double(max(r.total, 1)) * 100).rounded()))% · \(durationString(r.duration)) · \(r.unanswered) unanswered")
                            .font(.footnote).foregroundStyle(AppTheme.secondaryInk)
                    }
                    .frame(maxWidth: .infinity)
                }
                Section("By pillar") {
                    ForEach(r.byPillar) { score in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(score.pillar.title)
                                Spacer()
                                Text("\(score.correct) / \(score.total)").monospacedDigit()
                            }
                            ProgressView(value: Double(score.correct), total: Double(max(score.total, 1)))
                        }
                    }
                }
                if !r.wrongQuestions.isEmpty {
                    Section("Wrong or unanswered (\(r.wrongQuestions.count))") {
                        ForEach(r.wrongQuestions) { q in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(q.promptBody).lineLimit(2)
                                Text(q.correctChoice).font(.caption).foregroundStyle(AppTheme.secondaryInk)
                            }
                        }
                        if let session = viewModel.makeRetrySession() {
                            Button("Retry wrong") { onRetry(session) }
                        }
                    }
                }
                Section {
                    Button("New exam") { viewModel.reset() }
                }
            }
        }
    }

    private func durationString(_ t: TimeInterval) -> String {
        let s = Int(t.rounded())
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
