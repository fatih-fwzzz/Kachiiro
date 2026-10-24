import SwiftUI
import KachiiroCore

enum AppTab: Hashable {
    case dashboard, practice, mock, review

    init(route: LaunchRoute?) {
        switch route {
        case .practice, .audio, .cando, .drill, .roleplay, .shadowing: self = .practice
        case .mock: self = .mock
        case .review: self = .review
        case .dashboard, .settings, .setup, nil: self = .dashboard
        }
    }
}

struct RootView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var selection: AppTab
    @State private var showSetup = false
    /// Bumped after setup so Today rebuilds with the new goal and exam date.
    @State private var setupGeneration = 0
    private let route: LaunchRoute?

    init(route: LaunchRoute? = LaunchRoute.fromProcess()) {
        self.route = route
        _selection = State(initialValue: AppTab(route: route))
    }

    var body: some View {
        TabView(selection: $selection) {
            Tab("Today", systemImage: "sun.max", value: AppTab.dashboard) {
                NavigationStack {
                    TodayView(viewModel: environment.makeDashboardViewModel(), showSettings: route == .settings)
                }
            }
            Tab("Practice", systemImage: "square.grid.2x2", value: AppTab.practice) {
                NavigationStack {
                    PracticeView(viewModel: environment.makePracticeViewModel(), launchRoute: route)
                }
            }
            Tab("Review", systemImage: "arrow.triangle.2.circlepath", value: AppTab.review) {
                NavigationStack { ReviewView(viewModel: environment.makeReviewViewModel()) }
            }
            Tab("Exam", systemImage: "flag.checkered", value: AppTab.mock) {
                NavigationStack { MockExamView(viewModel: environment.makeMockExamViewModel()) }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabViewSidebarHeader { SidebarBrand() }
        .tabViewSidebarBottomBar { SidebarExamCard() }
        .id(setupGeneration)
        .fullScreenCover(isPresented: $showSetup, onDismiss: { setupGeneration += 1 }) {
            SetupView(model: SetupViewModel(settings: environment.settings))
        }
        .onAppear {
            // Smoke routes skip first-run setup so screenshots land on the requested screen.
            showSetup = route == .setup
                || (route == nil && SetupViewModel.isNeeded(settings: environment.settings, repository: environment.repository))
        }
    }
}

#Preview {
    RootView()
        .environment(AppEnvironment.preview())
}

/// iPad sidebar header: the 勝 seal and the app name.
private struct SidebarBrand: View {
    var body: some View {
        HStack(spacing: 10) {
            Text("勝")
                .font(.system(size: 18, weight: .black, design: .serif))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(AppTheme.accent, in: Circle())
                .accessibilityHidden(true)
            Text("Kachiiro").font(AppTheme.Fonts.ui(.title3, weight: .heavy))
        }
        .padding(.vertical, 6)
    }
}

/// iPad sidebar footer: days to the exam and this week's accuracy, always in view.
private struct SidebarExamCard: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var dashboard: DashboardViewModel?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let dashboard {
                SectionCaps(text: dashboard.daysLeft.map { $0 > 0 ? "Exam in \($0) days" : "Exam" } ?? "No exam date",
                            color: AppTheme.onKachiiroLabel)
                LinearProgress(value: Double(dashboard.weekAccuracy ?? 0) / 100,
                               tint: Color(hex: 0x0A84FF), track: .white.opacity(0.14), height: 6)
                Text(dashboard.weekAccuracy.map { "7-day accuracy \($0)%" } ?? "Answer a few questions to start")
                    .font(AppTheme.Fonts.ui(.caption, weight: .semibold))
                    .foregroundStyle(AppTheme.onKachiiroSecondary)
            }
        }
        .foregroundStyle(.white)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.kachiiro, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onAppear {
            if dashboard == nil { dashboard = environment.makeDashboardViewModel() }
            dashboard?.refresh()
        }
    }
}
