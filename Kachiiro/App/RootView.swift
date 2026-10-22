import SwiftUI
import KachiiroCore

enum AppTab: Hashable {
    case dashboard, practice, mock, review

    init(route: LaunchRoute?) {
        switch route {
        case .practice, .audio, .cando, .drill: self = .practice
        case .mock: self = .mock
        case .review: self = .review
        case .dashboard, .settings, nil: self = .dashboard
        }
    }
}

struct RootView: View {
    @State private var selection: AppTab

    init(route: LaunchRoute? = LaunchRoute.fromProcess()) {
        _selection = State(initialValue: AppTab(route: route))
    }

    var body: some View {
        TabView(selection: $selection) {
            Tab("Dashboard", systemImage: "gauge.with.dots.needle.33percent", value: AppTab.dashboard) {
                NavigationStack { DashboardView() }
            }
            Tab("Practice", systemImage: "square.grid.2x2", value: AppTab.practice) {
                NavigationStack { PracticeView() }
            }
            Tab("Mock Exam", systemImage: "timer", value: AppTab.mock) {
                NavigationStack { MockExamView() }
            }
            Tab("Review", systemImage: "arrow.triangle.2.circlepath", value: AppTab.review) {
                NavigationStack { ReviewView() }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }
}

#Preview {
    RootView()
        .environment(AppEnvironment(seed: SeedData(words: [], patterns: [], kanji: [])))
}
