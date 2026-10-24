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
        .navigationTitle(viewModel.phase == .notStarted ? "Exam" : "Mock exam")
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

/// The Exam tab at rest: how ready you are per pillar, the weakest one to fix, and the mock exam itself.
private struct MockExamStartView: View {
    let viewModel: MockExamViewModel
    @Environment(AppEnvironment.self) private var environment
    @State private var dashboard: DashboardViewModel?
    @State private var session: QuizSessionViewModel?

    private var examPillars: [Pillar] {
        Pillar.allCases.filter { p in MockExamViewModel.allocation.contains { $0.drill.pillar == p } }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if let dashboard {
                    readinessCard(dashboard)
                    if let weakest = weakest(dashboard) { weakestCard(weakest) }
                }
                mockCard
                if let note = viewModel.note {
                    Banner(kind: .warning, title: "A shorter exam this time", message: note)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(AppTheme.canvas)
        .safeAreaInset(edge: .bottom) {
            Button("Start the clock") { viewModel.start() }
                .buttonStyle(.primary)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
                .background(AppTheme.canvas)
        }
        .drillSession($session)
        .onAppear { dashboard = environment.makeDashboardViewModel() }
    }

    private func readinessCard(_ dashboard: DashboardViewModel) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 18) {
                ProgressRing(value: Double(dashboard.weekAccuracy ?? 0) / 100, lineWidth: 12,
                             tint: Color(hex: 0x0A84FF), track: .white.opacity(0.14)) {
                    VStack(spacing: 0) {
                        Text(dashboard.weekAccuracy.map { "\($0)%" } ?? "—")
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                        Text("CORRECT").font(AppTheme.Fonts.ui(.caption2, weight: .heavy)).foregroundStyle(AppTheme.onKachiiroSecondary)
                    }
                }
                .frame(width: 108, height: 108)
                VStack(alignment: .leading, spacing: 4) {
                    SectionCaps(text: dashboard.daysLeft.map { $0 > 0 ? "Exam in \($0) days" : "Exam" } ?? "Your readiness",
                                color: AppTheme.onKachiiroLabel)
                    Text(dashboard.weekAccuracy == nil ? "Practise a little to see how ready you are" : "Accuracy over the last 7 days")
                        .font(AppTheme.Fonts.ui(.headline, weight: .heavy))
                }
            }
            VStack(spacing: 9) {
                ForEach(dashboard.accuracy) { row in
                    HStack(spacing: 10) {
                        Text(row.pillar.glyph).font(.system(size: 15, weight: .bold)).frame(width: 22)
                        Text(row.pillar.shortName)
                            .font(AppTheme.Fonts.ui(.footnote, weight: .semibold))
                            .foregroundStyle(AppTheme.onKachiiroSecondary)
                            .frame(width: 72, alignment: .leading)
                        LinearProgress(value: Double(row.percent ?? 0) / 100,
                                       tint: (row.percent ?? 100) < 50 ? AppTheme.ember : Color(hex: 0x0A84FF),
                                       track: .white.opacity(0.14))
                        Text(row.percent.map { "\($0)%" } ?? "—")
                            .font(AppTheme.Fonts.ui(.footnote, weight: .heavy))
                            .monospacedDigit()
                            .frame(width: 40, alignment: .trailing)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(row.pillar.shortName): \(row.percent.map { "\($0) percent" } ?? "no answers yet")")
                }
            }
        }
        .foregroundStyle(.white)
        .padding(18)
        .background(AppTheme.kachiiro, in: RoundedRectangle(cornerRadius: AppTheme.Radius.hero, style: .continuous))
    }

    private func weakest(_ dashboard: DashboardViewModel) -> (pillar: Pillar, percent: Int)? {
        dashboard.accuracy.compactMap { row in row.percent.map { (row.pillar, $0) } }
            .filter { $0.1 < 100 }
            .min { $0.1 < $1.1 }
            .map { (pillar: $0.0, percent: $0.1) }
    }

    private func weakestCard(_ weakest: (pillar: Pillar, percent: Int)) -> some View {
        HStack(spacing: 12) {
            Text(weakest.pillar.glyph)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(AppTheme.ember, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(weakest.pillar.shortName) needs you most").font(AppTheme.Fonts.ui(.callout, weight: .heavy))
                Text("\(weakest.percent)% this week · a short drill helps")
                    .font(AppTheme.Fonts.ui(.footnote))
                    .foregroundStyle(AppTheme.emberText)
            }
            Spacer(minLength: 8)
            Button("Fix") {
                Task { session = await environment.makePracticeViewModel().makeAnySession(for: weakest.pillar.planDrill) }
            }
            .font(AppTheme.Fonts.ui(.subheadline, weight: .heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .buttonStyle(PressableStyle())
        }
        .foregroundStyle(AppTheme.emberDeepText)
        .padding(14)
        .background(AppTheme.emberSoftFill, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous).strokeBorder(AppTheme.ember, lineWidth: 2)
        }
    }

    private var mockCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Mock exam").font(AppTheme.Fonts.ui(.title3, weight: .heavy))
                Text("\(MockExamViewModel.questionCount) questions · \(Int(MockExamViewModel.timeLimit / 60)) min · real exam timing")
                    .font(AppTheme.Fonts.ui(.footnote))
                    .foregroundStyle(AppTheme.secondaryInk)
            }
            HStack(spacing: 8) {
                ForEach(examPillars, id: \.self) { pillar in
                    let count = MockExamViewModel.allocation.filter { $0.drill.pillar == pillar }.reduce(0) { $0 + $1.count }
                    VStack(spacing: 2) {
                        Text(pillar.glyph).font(.system(size: 16, weight: .bold))
                        Text("\(count)").font(AppTheme.Fonts.ui(.caption, weight: .heavy)).monospacedDigit()
                    }
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(AppTheme.elevatedField, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(pillar.shortName): \(count) questions")
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                rule("No feedback until you submit, like the real test")
                rule("You can’t go back to a question")
                rule("Unanswered questions count as wrong")
                rule("Questions come from your study scope")
            }
        }
        .foregroundStyle(AppTheme.primaryInk)
        .padding(16)
        .background(AppTheme.cardSurface, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
    }

    private func rule(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Circle().fill(AppTheme.accent).frame(width: 6, height: 6).accessibilityHidden(true)
            Text(text).font(AppTheme.Fonts.ui(.subheadline))
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
