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
        .toolbar(viewModel.phase == .notStarted ? .automatic : .hidden, for: .navigationBar)
        .toolbar(viewModel.phase == .running ? .hidden : .automatic, for: .tabBar)
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

/// Exam mode looks different on purpose: a navy header with the clock tells you this counts.
private struct MockExamSessionView: View {
    let viewModel: MockExamViewModel
    @State private var typed = ""
    @State private var selected: String?
    @FocusState private var typingFocused: Bool
    @State private var confirmSubmit = false
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        if let q = viewModel.currentQuestion {
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(spacing: 12) {
                        QuestionCard(
                            question: q, hasSpeech: viewModel.hasSpeech, speechUnavailable: viewModel.speechUnavailable,
                            onPlay: { viewModel.playPrompt(slow: $0) }
                        )
                        .frame(minHeight: 220)
                        answerArea(q)
                        modeSwitch
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .frame(maxWidth: 720)
                    .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.never)
                bottomBar
            }
            .background(AppTheme.canvas)
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
            .confirmationDialog(unansweredTitle, isPresented: $confirmSubmit, titleVisibility: .visible) {
                Button("Submit anyway", role: .destructive) { viewModel.submit() }
                Button("Keep going", role: .cancel) {}
            } message: {
                Text("You still have \(timeString(viewModel.remaining)). Unanswered questions count as wrong.")
            }
        }
    }

    private var unansweredTitle: String {
        let left = viewModel.questions.count - viewModel.answeredCount
        return left == 0 ? "Submit the exam?" : (left == 1 ? "Submit with 1 unanswered?" : "Submit with \(left) unanswered?")
    }

    private var header: some View {
        let fraction = viewModel.remaining / MockExamViewModel.timeLimit
        let lowTime = viewModel.remaining < 120
        return VStack(spacing: 14) {
            HStack(spacing: 12) {
                ProgressRing(value: fraction, lineWidth: 6, tint: lowTime ? AppTheme.ember : Color(hex: 0x0A84FF),
                             track: .white.opacity(0.14)) { EmptyView() }
                    .frame(width: 48, height: 48)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 0) {
                    Text(timeString(viewModel.remaining))
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(lowTime ? Color(hex: 0xFFB547) : .white)
                    Text("left · question \(viewModel.index + 1) of \(viewModel.questions.count)")
                        .font(AppTheme.Fonts.ui(.caption, weight: .semibold))
                        .foregroundStyle(AppTheme.onKachiiroSecondary)
                }
                .accessibilityElement(children: .combine)
                Spacer()
                Text("\(viewModel.answeredCount) answered")
                    .font(AppTheme.Fonts.ui(.caption, weight: .bold))
                    .foregroundStyle(AppTheme.onKachiiroSecondary)
                    .monospacedDigit()
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 10), spacing: 5) {
                ForEach(viewModel.questions.indices, id: \.self) { i in
                    Text("\(i + 1)")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundStyle(mapInk(i))
                        .frame(maxWidth: .infinity, minHeight: 22)
                        .background(mapFill(i), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(viewModel.answeredCount) of \(viewModel.questions.count) answered")
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(AppTheme.kachiiro.ignoresSafeArea(edges: .top))
    }

    private func mapFill(_ i: Int) -> Color {
        if i == viewModel.index { return .white }
        return viewModel.isAnswered(at: i) ? Color(hex: 0x0A84FF) : .white.opacity(0.1)
    }

    private func mapInk(_ i: Int) -> Color {
        if i == viewModel.index { return AppTheme.kachiiro }
        return viewModel.isAnswered(at: i) ? .white : Color(hex: 0x8A90B5)
    }

    private func timeString(_ t: TimeInterval) -> String {
        let s = Int(t.rounded(.up))
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    @ViewBuilder
    private func answerArea(_ q: QuizQuestion) -> some View {
        if viewModel.activeMode == .choice {
            VStack(spacing: 10) {
                ForEach(Array(q.choices.enumerated()), id: \.element) { index, choice in
                    let isSelected = selected == choice
                    Button {
                        selected = choice
                        viewModel.answerChoice(choice)
                    } label: {
                        HStack(spacing: 14) {
                            Text("\(index + 1)")
                                .font(AppTheme.Fonts.ui(.footnote, weight: .heavy))
                                .foregroundStyle(isSelected ? Color.white : AppTheme.secondaryInk)
                                .frame(width: 28, height: 28)
                                .background(isSelected ? AppTheme.accent : AppTheme.elevatedField,
                                            in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .accessibilityHidden(true)
                            Text(choice)
                                .font(AppTheme.Fonts.ui(.title3, weight: .semibold))
                                .foregroundStyle(AppTheme.primaryInk)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 58)
                        .background(isSelected ? AppTheme.accentSoftFill : AppTheme.cardSurface,
                                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(isSelected ? AppTheme.accent : AppTheme.hairlineBorder, lineWidth: isSelected ? 2 : 1.5)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableStyle())
                    .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: [])
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        } else {
            TextField("Type your answer", text: $typed)
                .focused($typingFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(AppTheme.Fonts.ui(.title3))
                .onChange(of: typed) { viewModel.answerText(typed) }
                .padding(.horizontal, 16)
                .frame(minHeight: 58)
                .background(AppTheme.cardSurface, in: RoundedRectangle(cornerRadius: AppTheme.Radius.control, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.Radius.control, style: .continuous).strokeBorder(AppTheme.accent, lineWidth: 2)
                }
        }
    }

    @ViewBuilder
    private var modeSwitch: some View {
        if viewModel.canType && viewModel.canChoose {
            let toTyping = viewModel.activeMode == .choice
            Button { viewModel.setMode(toTyping ? .typing : .choice) } label: {
                Label(toTyping ? "Type instead" : "Choose instead", systemImage: toTyping ? "keyboard" : "list.number")
                    .font(AppTheme.Fonts.ui(.subheadline, weight: .bold))
                    .foregroundStyle(AppTheme.accentText)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 10) {
            Button("Submit") { confirmSubmit = true }
                .buttonStyle(SecondaryButtonStyle(height: 54))
                .frame(width: 112)
            Button(viewModel.isLastQuestion ? "Finish exam" : "Next question") { viewModel.next() }
                .buttonStyle(PrimaryButtonStyle(height: 54))
                .keyboardShortcut(.return, modifiers: [])
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .frame(maxWidth: 720)
        .frame(maxWidth: .infinity)
        .background(AppTheme.canvas)
    }
}

/// Answers "how did I do, and where" before anything else, then makes the misses the next step.
private struct MockExamResultView: View {
    let viewModel: MockExamViewModel
    let onRetry: (QuizSessionViewModel) -> Void

    var body: some View {
        if let r = viewModel.result {
            ScrollView {
                VStack(spacing: 16) {
                    hero(r)
                    VStack(spacing: 12) {
                        pillarCard(r)
                        if let lowest = r.byPillar.filter({ $0.total > 0 }).min(by: { fraction($0) < fraction($1) }),
                           fraction(lowest) < 1 {
                            Banner(kind: .info, title: "\(lowest.pillar.shortName) cost you the most",
                                   message: "\(lowest.correct) of \(lowest.total) right. A short \(lowest.pillar.planDrill.title.lowercased()) drill is the best next step.")
                        }
                        if !r.wrongQuestions.isEmpty { missesCard(r) }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 16)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .ignoresSafeArea(edges: .top)
            .background(AppTheme.canvas)
            .safeAreaInset(edge: .bottom) { actions }
        }
    }

    private func fraction(_ score: MockExamViewModel.PillarScore) -> Double {
        Double(score.correct) / Double(max(score.total, 1))
    }

    private func hero(_ r: MockExamViewModel.Result) -> some View {
        VStack(spacing: 10) {
            Text("試")
                .font(.system(size: 38, weight: .black, design: .serif))
                .frame(width: 70, height: 70)
                .overlay(Circle().strokeBorder(.white.opacity(0.55), lineWidth: 2))
                .padding(7)
                .background(AppTheme.accent, in: Circle())
                .accessibilityHidden(true)
            SectionCaps(text: "Mock exam result", color: AppTheme.onKachiiroLabel).fixedSize()
            Text("\(r.correct) / \(r.total)")
                .font(.system(size: 44, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: 8) {
                chip("\(Int((Double(r.correct) / Double(max(r.total, 1)) * 100).rounded()))%")
                chip(durationString(r.duration))
                chip(r.unanswered == 1 ? "1 unanswered" : "\(r.unanswered) unanswered")
            }
        }
        .foregroundStyle(.white)
        .padding(.top, 72)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity)
        .background(AppTheme.kachiiro, in: UnevenRoundedRectangle(bottomLeadingRadius: 32, bottomTrailingRadius: 32, style: .continuous))
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(AppTheme.Fonts.ui(.footnote, weight: .bold))
            .monospacedDigit()
            .padding(.horizontal, 12)
            .frame(minHeight: 28)
            .background(AppTheme.onKachiiroFill, in: Capsule())
    }

    private func pillarCard(_ r: MockExamViewModel.Result) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("By pillar").font(AppTheme.Fonts.ui(.callout, weight: .heavy))
            ForEach(r.byPillar) { score in
                HStack(spacing: 10) {
                    Text(score.pillar.glyph).font(.system(size: 15, weight: .bold)).frame(width: 22)
                    Text(score.pillar.shortName)
                        .font(AppTheme.Fonts.ui(.footnote, weight: .semibold))
                        .foregroundStyle(AppTheme.secondaryInk)
                        .frame(width: 72, alignment: .leading)
                    LinearProgress(value: fraction(score), tint: fraction(score) < 0.5 ? AppTheme.ember : AppTheme.accent)
                    Text("\(score.correct)/\(score.total)")
                        .font(AppTheme.Fonts.ui(.footnote, weight: .heavy))
                        .monospacedDigit()
                        .frame(width: 40, alignment: .trailing)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(score.pillar.shortName): \(score.correct) of \(score.total)")
            }
        }
        .foregroundStyle(AppTheme.primaryInk)
        .padding(16)
        .background(AppTheme.cardSurface, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
    }

    private func missesCard(_ r: MockExamViewModel.Result) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionCaps(text: "\(r.wrongQuestions.count) wrong or unanswered", color: AppTheme.emberText).padding(.vertical, 10)
            ForEach(Array(r.wrongQuestions.enumerated()), id: \.element.id) { index, q in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Circle().fill(AppTheme.ember).frame(width: 8, height: 8).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(q.promptBody).font(AppTheme.Fonts.ui(.callout, weight: .bold)).lineLimit(2)
                        Text("Answer: \(q.correctChoice)").font(AppTheme.Fonts.ui(.footnote)).foregroundStyle(AppTheme.secondaryInk)
                    }
                }
                .padding(.vertical, 10)
                .accessibilityElement(children: .combine)
                if index < r.wrongQuestions.count - 1 { Divider().overlay(AppTheme.hairlineBorder) }
            }
        }
        .foregroundStyle(AppTheme.primaryInk)
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
        .background(AppTheme.cardSurface, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
    }

    private var actions: some View {
        VStack(spacing: 4) {
            if let session = viewModel.makeRetrySession() {
                Button(session.total == 1 ? "Retry the 1 you missed" : "Retry the \(session.total) you missed") { onRetry(session) }
                    .buttonStyle(.primary)
                Button("New exam") { viewModel.reset() }.buttonStyle(.quiet)
            } else {
                Button("New exam") { viewModel.reset() }.buttonStyle(.primary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .frame(maxWidth: 720)
        .frame(maxWidth: .infinity)
        .background(AppTheme.canvas)
    }

    private func durationString(_ t: TimeInterval) -> String {
        let s = Int(t.rounded())
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
