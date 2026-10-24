import SwiftUI
import KachiiroCore

/// Scenario cards: the situation in Japanese, who you talk to, and whether the conversation branches.
struct RoleplayListView: View {
    let scenarios: [RoleplayScenario]
    @Environment(AppEnvironment.self) private var environment
    @State private var isLive = false

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                modeCard
                ForEach(scenarios) { scenario in
                    NavigationLink {
                        RoleplayView(viewModel: environment.makeRoleplayViewModel(scenario))
                    } label: {
                        card(scenario)
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(AppTheme.canvas)
        .navigationTitle("Roleplay")
        .onAppear { isLive = environment.aiResolver.liveRoleplayPartner() != nil }
    }

    /// Says up front whether scenarios open as a voice call or a turn-by-turn chat.
    private var modeCard: some View {
        HStack(spacing: 12) {
            Image(systemName: isLive ? "phone.fill" : "text.bubble.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(isLive ? "Hands-free voice calls" : "Turn-by-turn chat")
                    .font(AppTheme.Fonts.ui(.callout, weight: .heavy))
                Text(isLive ? "Just speak. Gemini plays your partner."
                     : "Speak or type each reply, one turn at a time.")
                    .font(AppTheme.Fonts.ui(.footnote))
                    .foregroundStyle(AppTheme.secondaryInk)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(AppTheme.primaryInk)
        .padding(14)
        .background(AppTheme.accentSoftFill, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func card(_ scenario: RoleplayScenario) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(scenario.titleJa).font(AppTheme.Fonts.ui(.headline, weight: .heavy))
                    if scenario.branches {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(AppTheme.accentText)
                            .accessibilityLabel("Branching conversation")
                    }
                }
                Text(scenario.title).font(AppTheme.Fonts.ui(.subheadline, weight: .semibold))
                Text("You: \(scenario.userRole) · Partner: \(scenario.partnerRole)")
                    .font(AppTheme.Fonts.ui(.footnote))
                    .foregroundStyle(AppTheme.secondaryInk)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.bold))
                .foregroundStyle(AppTheme.tertiaryInk)
        }
        .foregroundStyle(AppTheme.primaryInk)
        .multilineTextAlignment(.leading)
        .padding(16)
        .background(AppTheme.cardSurface, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
