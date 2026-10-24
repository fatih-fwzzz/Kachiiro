import SwiftUI
import KachiiroCore

/// Home: one obvious next step (today's session), the exam as a track you fill in, and the daily goal.
struct TodayView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: DashboardViewModel
    @State private var showSettings: Bool
    @State private var session: QuizSessionViewModel?
    @State private var isQuizActive = false
    @State private var isPreparing = false
    @State private var message: String?

    init(viewModel: DashboardViewModel, showSettings: Bool = false) {
        _viewModel = State(initialValue: viewModel)
        _showSettings = State(initialValue: showSettings)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                hero
                if let message {
                    Banner(kind: .warning, title: "Couldn’t start that step", message: message,
                           action: .init(title: "OK") { self.message = nil })
                }
                if let first = viewModel.plan.first {
                    startButton(first)
                    planCard
                }
                goalRow
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(AppTheme.canvas)
        .toolbar(.hidden, for: .navigationBar)
        .preparingOverlay(isPreparing, title: "Building your drill", message: "AI is generating fresh questions…")
        .navigationDestination(isPresented: $isQuizActive) {
            if let session { QuizView(model: session) }
        }
        .sheet(isPresented: $showSettings, onDismiss: { viewModel.refresh() }) {
            NavigationStack { SettingsView(viewModel: environment.makeSettingsViewModel()) }
        }
        .onAppear { viewModel.refresh() }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)).uppercased())
                    .font(AppTheme.Fonts.caps)
                    .tracking(0.8)
                    .foregroundStyle(AppTheme.secondaryInk)
                Text(greeting)
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppTheme.primaryInk)
                    .accessibilityAddTraits(.isHeader)
            }
            Spacer()
            Button { showSettings = true } label: {
                Image(systemName: "person.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(AppTheme.kachiiro, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
        }
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 4..<11: "おはよう！"
        case 11..<18: "こんにちは！"
        default: "こんばんは！"
        }
    }

    // MARK: Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                countdown
                Spacer()
                StreakChip(days: viewModel.streak, onKachiiro: true)
            }
            trackRow
            accuracyRow
        }
        .padding(20)
        .foregroundStyle(.white)
        .background(AppTheme.kachiiro, in: RoundedRectangle(cornerRadius: AppTheme.Radius.hero, style: .continuous))
    }

    @ViewBuilder
    private var countdown: some View {
        if let days = viewModel.daysLeft {
            VStack(alignment: .leading, spacing: 0) {
                SectionCaps(text: days > 0 ? "Exam in" : "Exam", color: AppTheme.onKachiiroLabel)
                if days > 0 {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(days)").font(.system(size: 52, weight: .heavy, design: .rounded)).monospacedDigit()
                        Text(days == 1 ? "day" : "days").font(AppTheme.Fonts.ui(.title2, weight: .bold))
                    }
                } else {
                    Text(viewModel.countdownText ?? "")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .padding(.top, 4)
                }
            }
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityElement(children: .combine)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                SectionCaps(text: "Your exam", color: AppTheme.onKachiiroLabel)
                Text("When is it?").font(AppTheme.Fonts.ui(.title2, weight: .heavy))
                Button("Set exam date") { showSettings = true }
                    .font(AppTheme.Fonts.ui(.subheadline, weight: .heavy))
                    .foregroundStyle(AppTheme.kachiiro)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 40)
                    .background(.white, in: Capsule())
                    .buttonStyle(.plain)
            }
        }
    }

    private var trackRow: some View {
        HStack(spacing: 0) {
            ForEach(viewModel.track) { day in
                TrackDot(day: day).frame(maxWidth: .infinity)
            }
        }
    }

    private var accuracyRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let accuracy = viewModel.weekAccuracy {
                Text("7-day accuracy \(accuracy)%")
                    .font(AppTheme.Fonts.ui(.footnote, weight: .semibold))
                    .foregroundStyle(AppTheme.onKachiiroSecondary)
                LinearProgress(value: Double(accuracy) / 100, tint: Color(hex: 0x0A84FF), track: .white.opacity(0.14))
            } else {
                Text("Answer a few questions to see your accuracy.")
                    .font(AppTheme.Fonts.ui(.footnote, weight: .semibold))
                    .foregroundStyle(AppTheme.onKachiiroSecondary)
            }
        }
    }

    // MARK: Plan

    private func startButton(_ first: DashboardViewModel.PlanStep) -> some View {
        Button { start(first) } label: {
            HStack(spacing: 14) {
                Image(systemName: "play.fill")
                    .font(.system(size: 20, weight: .bold))
                    .frame(width: 48, height: 48)
                    .background(.white.opacity(0.2), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Start today’s session").font(AppTheme.Fonts.ui(.title3, weight: .heavy))
                    Text("\(viewModel.plan.count) \(viewModel.plan.count == 1 ? "step" : "steps") · about \(viewModel.planMinutes) min")
                        .font(AppTheme.Fonts.ui(.subheadline, weight: .semibold))
                        .opacity(0.85)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .disabled(isPreparing)
    }

    private var planCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(viewModel.plan.enumerated()), id: \.element.id) { index, step in
                Button { start(step) } label: { planRow(step, isNext: index == 0) }
                    .buttonStyle(PressableStyle())
                    .disabled(isPreparing)
                if index < viewModel.plan.count - 1 { Divider().overlay(AppTheme.hairlineBorder) }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background(AppTheme.cardSurface, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
    }

    private func planRow(_ step: DashboardViewModel.PlanStep, isNext: Bool) -> some View {
        HStack(spacing: 12) {
            GlyphTile(glyph: glyph(step), style: isNext ? .accent : .soft)
            VStack(alignment: .leading, spacing: 1) {
                Text(title(step)).font(AppTheme.Fonts.ui(.callout, weight: .bold)).foregroundStyle(AppTheme.primaryInk)
                Text(subtitle(step)).font(AppTheme.Fonts.ui(.footnote)).foregroundStyle(AppTheme.secondaryInk)
            }
            Spacer(minLength: 8)
            Text("\(step.minutes) min")
                .font(AppTheme.Fonts.ui(.footnote, weight: .bold))
                .foregroundStyle(AppTheme.secondaryInk)
                .monospacedDigit()
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Starts this step")
    }

    private func glyph(_ step: DashboardViewModel.PlanStep) -> String {
        switch step.kind {
        case .review: "復"
        case .drill(let drill, _): drill.pillar.glyph
        }
    }

    private func title(_ step: DashboardViewModel.PlanStep) -> String {
        switch step.kind {
        case .review: "Warm-up review"
        case .drill(let drill, _): drill.title
        }
    }

    private func subtitle(_ step: DashboardViewModel.PlanStep) -> String {
        switch step.kind {
        case .review(let count): count == 1 ? "1 card due" : "\(count) cards due"
        case .drill(_, let reason): reason.text
        }
    }

    private var goalRow: some View {
        HStack(spacing: 12) {
            Text("Daily goal").font(AppTheme.Fonts.ui(.subheadline, weight: .bold))
            LinearProgress(value: viewModel.goalProgress)
            Text("\(viewModel.answeredToday) / \(viewModel.dailyGoal)")
                .font(AppTheme.Fonts.ui(.subheadline, weight: .bold))
                .foregroundStyle(AppTheme.secondaryInk)
                .monospacedDigit()
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
    }

    // MARK: Starting a step

    private func start(_ step: DashboardViewModel.PlanStep) {
        message = nil
        switch step.kind {
        case .review(let count):
            let review = environment.makeReviewViewModel()
            session = review.makeSession(keys: review.due.prefix(count).map(\.key))
            if session == nil { message = "Those review cards are no longer available." }
        case .drill(let drill, _):
            let practice = environment.makePracticeViewModel()
            if practice.usesGeneratedContent(for: drill) {
                isPreparing = true
                Task {
                    session = await practice.makeGeneratedSession(for: drill)
                    isPreparing = false
                    message = session == nil ? practice.message : nil
                    isQuizActive = session != nil
                }
                return
            }
            session = practice.makeSession(for: drill)
            if session == nil { message = practice.message }
        }
        isQuizActive = session != nil
    }
}

/// One day on the hero track: checked when studied, ringed today, 勝 on the exam day.
private struct TrackDot: View {
    let day: DashboardViewModel.TrackDay

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                switch (day.isExamDay, day.status) {
                case (true, _):
                    Circle().fill(.white)
                    Text("勝").font(.system(size: 14, weight: .heavy)).foregroundStyle(AppTheme.kachiiro)
                case (_, .studied):
                    Circle().fill(Color(hex: 0x0A84FF))
                    Image(systemName: "checkmark").font(.system(size: 13, weight: .black))
                case (_, .today):
                    Circle().strokeBorder(Color(hex: 0x0A84FF), lineWidth: 2.5)
                    dayNumber
                case (_, .missed), (_, .upcoming):
                    Circle().strokeBorder(.white.opacity(0.22), lineWidth: 1.5)
                    dayNumber.opacity(0.5)
                }
            }
            .frame(width: 34, height: 34)
            Text(label)
                .font(AppTheme.Fonts.ui(.caption2, weight: .bold))
                .foregroundStyle(day.status == .today || day.isExamDay ? .white : AppTheme.onKachiiroSecondary.opacity(0.8))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var dayNumber: some View {
        Text(day.date.formatted(.dateTime.day())).font(AppTheme.Fonts.ui(.footnote, weight: .heavy)).monospacedDigit()
    }

    private var label: String {
        if day.isExamDay { return "Exam" }
        if day.status == .today || (Calendar.current.isDateInToday(day.date)) { return "Today" }
        return day.date.formatted(.dateTime.weekday(.abbreviated))
    }

    private var accessibilityText: String {
        let date = day.date.formatted(.dateTime.weekday(.wide).day().month())
        let status = switch day.status {
        case .studied: "studied"
        case .missed: "no study"
        case .today: "today, not studied yet"
        case .upcoming: "upcoming"
        }
        return day.isExamDay ? "\(date), exam day" : "\(date), \(status)"
    }
}

#Preview {
    NavigationStack {
        TodayView(viewModel: DashboardViewModel(settings: InMemorySettingsStore(), repository: InMemoryProgressRepository()))
    }
    .environment(AppEnvironment.preview())
}
