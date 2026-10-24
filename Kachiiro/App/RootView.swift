import SwiftUI
import KachiiroCore

enum AppTab: Hashable {
    case dashboard, practice, mock, review

    init(route: LaunchRoute?) {
        switch route {
        case .practice, .audio, .cando, .drill, .roleplay, .shadowing: self = .practice
        case .mock: self = .mock
        case .review: self = .review
        case .dashboard, .settings, nil: self = .dashboard
        }
    }
}

struct RootView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var selection: AppTab
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
            Tab("Mock Exam", systemImage: "timer", value: AppTab.mock) {
                NavigationStack { MockExamView(viewModel: environment.makeMockExamViewModel()) }
            }
            Tab("Review", systemImage: "arrow.triangle.2.circlepath", value: AppTab.review) {
                NavigationStack { ReviewView(viewModel: environment.makeReviewViewModel()) }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }
}

#Preview {
    RootView()
        .environment(AppEnvironment.preview())
}
