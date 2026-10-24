import SwiftUI
import KachiiroCore

/// The end of a session is what you remember (peak-end rule): celebrate it, show the streak and goal,
/// and make fixing the mistakes the next step while they are fresh.
struct QuizSummaryView: View {
    let model: QuizSessionViewModel
    let onRetry: (QuizSessionViewModel) -> Void
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var dashboard: DashboardViewModel?

    private var wrong: [QuizQuestion] { model.wrongQuestions }
    private var isPerfect: Bool { model.total > 0 && wrong.isEmpty }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                hero
                VStack(spacing: 12) {
                    if let dashboard { streakCard(dashboard) }
                    if !wrong.isEmpty { missesCard }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 16)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .ignoresSafeArea(edges: .top)
        .background(AppTheme.canvas)
        .safeAreaInset(edge: .bottom) { actions }
        .onAppear { dashboard = environment.makeDashboardViewModel() }
    }

    private var hero: some View {
        VStack(spacing: 12) {
            Text(isPerfect ? "満" : "勝")
                .font(.system(size: 42, weight: .black, design: .serif))
                .foregroundStyle(.white)
                .frame(width: 78, height: 78)
                .overlay(Circle().strokeBorder(.white.opacity(0.55), lineWidth: 2))
                .padding(7)
                .background(AppTheme.accent, in: Circle())
                .accessibilityHidden(true)
            SectionCaps(text: isPerfect ? "Perfect round" : "Session complete", color: AppTheme.onKachiiroLabel)
                .frame(maxWidth: .infinity, alignment: .center)
                .fixedSize()
            Text("\(model.score) / \(model.total) correct")
                .font(.system(size: 38, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: 8) {
                StatTile(value: accuracyText, label: "Accuracy")
                StatTile(value: "×\(model.bestCombo)", label: "Best combo")
                StatTile(value: durationText, label: "Time")
            }
            .padding(.top, 4)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.top, 72)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity)
        .background(AppTheme.kachiiro, in: UnevenRoundedRectangle(bottomLeadingRadius: 32, bottomTrailingRadius: 32, style: .continuous))
    }

    private var accuracyText: String {
        model.total == 0 ? "—" : "\(Int((Double(model.score) / Double(model.total) * 100).rounded()))%"
    }

    private var durationText: String {
        guard let seconds = model.duration.map({ Int($0.rounded()) }) else { return "—" }
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private func streakCard(_ dashboard: DashboardViewModel) -> some View {
        let remaining = max(0, dashboard.dailyGoal - dashboard.answeredToday)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "flame.fill").font(.title2).foregroundStyle(AppTheme.ember)
                Text(dashboard.streak == 1 ? "Today counts: 1-day streak" : "Today counts: \(dashboard.streak)-day streak")
                    .font(AppTheme.Fonts.ui(.callout, weight: .heavy))
            }
            HStack(spacing: 10) {
                LinearProgress(value: dashboard.goalProgress)
                Text("\(dashboard.answeredToday) / \(dashboard.dailyGoal)")
                    .font(AppTheme.Fonts.ui(.footnote, weight: .bold))
                    .foregroundStyle(AppTheme.secondaryInk)
                    .monospacedDigit()
            }
            Text(remaining > 0 ? "\(remaining) more answers to hit today’s goal" : "Daily goal reached")
                .font(AppTheme.Fonts.ui(.footnote))
                .foregroundStyle(AppTheme.secondaryInk)
        }
        .foregroundStyle(AppTheme.primaryInk)
        .padding(16)
        .background(AppTheme.cardSurface, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var missesCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionCaps(text: "\(wrong.count) to fix", color: AppTheme.emberText).padding(.vertical, 10)
            ForEach(Array(wrong.enumerated()), id: \.offset) { index, question in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Circle().fill(AppTheme.ember).frame(width: 8, height: 8).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(question.promptBody)
                            .font(AppTheme.Fonts.ui(.callout, weight: .bold))
                            .lineLimit(2)
                        Text("Answer: \(question.correctChoice) · \(question.promptTitle)")
                            .font(AppTheme.Fonts.ui(.footnote))
                            .foregroundStyle(AppTheme.secondaryInk)
                            .lineLimit(2)
                    }
                }
                .padding(.vertical, 10)
                .accessibilityElement(children: .combine)
                if index < wrong.count - 1 { Divider().overlay(AppTheme.hairlineBorder) }
            }
        }
        .foregroundStyle(AppTheme.primaryInk)
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
        .background(AppTheme.cardSurface, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
    }

    private var actions: some View {
        VStack(spacing: 4) {
            if let retry = model.makeRetrySession() {
                Button(retry.total == 1 ? "Fix 1 mistake now" : "Fix \(retry.total) mistakes now") { onRetry(retry) }
                    .buttonStyle(.primary)
                Button("Done") { dismiss() }.buttonStyle(.quiet)
            } else {
                Button("Done") { dismiss() }.buttonStyle(.primary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity)
        .background(AppTheme.canvas)
    }
}

private struct StatTile: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(AppTheme.Fonts.ui(.title3, weight: .heavy)).monospacedDigit()
            Text(label).font(AppTheme.Fonts.ui(.caption, weight: .semibold)).foregroundStyle(AppTheme.onKachiiroSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(AppTheme.onKachiiroFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
