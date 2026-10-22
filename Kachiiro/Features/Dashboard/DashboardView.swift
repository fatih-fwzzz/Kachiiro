import SwiftUI
import KachiiroCore

struct DashboardView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: DashboardViewModel
    @State private var showSettings: Bool
    private let openReview: () -> Void

    init(viewModel: DashboardViewModel, showSettings: Bool = false, openReview: @escaping () -> Void = {}) {
        _viewModel = State(initialValue: viewModel)
        _showSettings = State(initialValue: showSettings)
        self.openReview = openReview
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    countdownCard
                    goalCard
                }
                dueCard
                accuracyCard
            }
            .padding()
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(AppTheme.canvas)
        .navigationTitle("Dashboard")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showSettings = true } label: { Image(systemName: "gearshape") }
                    .accessibilityLabel("Settings")
            }
        }
        .sheet(isPresented: $showSettings, onDismiss: { viewModel.refresh() }) {
            NavigationStack { SettingsView(viewModel: environment.makeSettingsViewModel()) }
        }
        .onAppear { viewModel.refresh() }
    }

    private var countdownCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Exam", systemImage: "calendar").font(.footnote.weight(.semibold)).foregroundStyle(AppTheme.secondaryInk)
            if let text = viewModel.countdownText {
                Text(text).font(AppTheme.Fonts.ui(.title2, weight: .bold)).minimumScaleFactor(0.7)
            } else {
                Button("Set exam date") { showSettings = true }.buttonStyle(.borderedProminent)
            }
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                Image(systemName: "flame.fill").foregroundStyle(viewModel.streak > 0 ? AppTheme.accent : AppTheme.tertiaryInk)
                Text(viewModel.streak == 1 ? "1 day streak" : "\(viewModel.streak) day streak").font(.footnote)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 130, alignment: .leading)
        .quizCard()
    }

    private var goalCard: some View {
        VStack(spacing: 8) {
            Label("Today", systemImage: "target").font(.footnote.weight(.semibold)).foregroundStyle(AppTheme.secondaryInk)
            ZStack {
                Circle().stroke(AppTheme.accentSoftFill, lineWidth: 10)
                Circle()
                    .trim(from: 0, to: viewModel.goalProgress)
                    .stroke(AppTheme.accent, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(viewModel.answeredToday)").font(AppTheme.Fonts.ui(.title3, weight: .bold))
                    Text("/ \(viewModel.dailyGoal)").font(.caption2).foregroundStyle(AppTheme.secondaryInk)
                }
            }
            .frame(width: 84, height: 84)
        }
        .frame(maxWidth: .infinity, minHeight: 130)
        .quizCard()
    }

    private var dueCard: some View {
        Button(action: openReview) {
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath").font(.title3).foregroundStyle(AppTheme.accent)
                VStack(alignment: .leading) {
                    Text("\(viewModel.dueCount) due for review").font(AppTheme.Fonts.ui(.headline))
                    Text("Weak and overdue items").font(.caption).foregroundStyle(AppTheme.secondaryInk)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.footnote).foregroundStyle(AppTheme.tertiaryInk)
            }
            .foregroundStyle(AppTheme.primaryInk)
            .frame(maxWidth: .infinity)
            .quizCard()
        }
        .buttonStyle(.plain)
    }

    private var accuracyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Accuracy · last 7 days").font(AppTheme.Fonts.ui(.headline))
            ForEach(viewModel.accuracy) { row in
                HStack(spacing: 12) {
                    Text(row.pillar.title).font(.subheadline).frame(width: 130, alignment: .leading)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(AppTheme.accentSoftFill)
                            Capsule().fill(AppTheme.accent)
                                .frame(width: geo.size.width * CGFloat(row.percent ?? 0) / 100)
                        }
                    }
                    .frame(height: 8)
                    Text(row.percent.map { "\($0)%" } ?? "—")
                        .font(.subheadline.monospacedDigit()).frame(width: 44, alignment: .trailing)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .quizCard()
    }
}
