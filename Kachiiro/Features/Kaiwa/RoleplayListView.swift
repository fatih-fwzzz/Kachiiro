import SwiftUI
import KachiiroCore

struct RoleplayListView: View {
    let scenarios: [RoleplayScenario]
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        List(scenarios) { scenario in
            NavigationLink {
                RoleplayView(viewModel: environment.makeRoleplayViewModel(scenario))
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(scenario.titleJa).font(AppTheme.Fonts.ui(.headline))
                        if scenario.branches {
                            Image(systemName: "arrow.triangle.branch")
                                .font(.footnote)
                                .foregroundStyle(AppTheme.accent)
                                .accessibilityLabel("Branching conversation")
                        }
                    }
                    Text(scenario.title).font(.subheadline).foregroundStyle(AppTheme.primaryInk)
                    Text("\(scenario.userRole) ↔ \(scenario.partnerRole)")
                        .font(.caption).foregroundStyle(AppTheme.secondaryInk)
                }
                .padding(.vertical, 2)
            }
        }
        .navigationTitle("Roleplay")
    }
}
