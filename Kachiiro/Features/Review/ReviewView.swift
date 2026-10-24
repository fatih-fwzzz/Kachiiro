import SwiftUI
import KachiiroCore

/// The spaced-repetition queue made visible: what's ready, how strong your memory is, and why each card is here.
struct ReviewView: View {
    enum Filter: String, CaseIterable { case all = "All", due = "Due", weak = "Weak" }

    @State private var viewModel: ReviewViewModel
    @State private var session: QuizSessionViewModel?
    @State private var filter: Filter = .all

    init(viewModel: ReviewViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.totalCount > 0 {
                    readyCard
                } else {
                    caughtUpCard
                }
                if viewModel.strength.total > 0 { strengthCard }
                if viewModel.totalCount > 0 {
                    filterChips
                    itemList
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(AppTheme.canvas)
        .navigationTitle("Review")
        .drillSession($session)
        .onAppear { viewModel.refresh() }
    }

    private var readyCard: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                SectionCaps(text: "Ready now", color: .white.opacity(0.85))
                Text(viewModel.totalCount == 1 ? "1 card" : "\(viewModel.totalCount) cards")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                Text(readySubtitle)
                    .font(AppTheme.Fonts.ui(.subheadline, weight: .semibold))
                    .opacity(0.85)
            }
            Spacer(minLength: 8)
            Button("Start") { session = viewModel.makeSession() }
                .font(AppTheme.Fonts.ui(.headline, weight: .heavy))
                .foregroundStyle(AppTheme.accent)
                .padding(.horizontal, 22)
                .frame(minHeight: 52)
                .background(.white, in: RoundedRectangle(cornerRadius: AppTheme.Radius.control, style: .continuous))
                .buttonStyle(PressableStyle())
        }
        .foregroundStyle(.white)
        .padding(20)
        .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    /// Weak cards that are also due are counted once, as due.
    private var readySubtitle: String {
        let weakOnly = viewModel.totalCount - viewModel.due.count
        let parts = [viewModel.due.isEmpty ? nil : "\(viewModel.due.count) due", weakOnly > 0 ? "\(weakOnly) weak" : nil]
        return (["about \(viewModel.estimatedMinutes) min"] + parts.compactMap { $0 }).joined(separator: " · ")
    }

    private var caughtUpCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark")
                .font(.system(size: 30, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 72, height: 72)
                .background(AppTheme.accent, in: Circle())
                .padding(12)
                .background(AppTheme.accentSoftFill, in: Circle())
                .accessibilityHidden(true)
            Text("All caught up").font(AppTheme.Fonts.ui(.title2, weight: .heavy))
            Text("Every card you’ve seen is fresh in memory. Answered questions come back here when they are due or weak.")
                .font(AppTheme.Fonts.ui(.subheadline))
                .foregroundStyle(AppTheme.secondaryInk)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(AppTheme.primaryInk)
        .padding(.horizontal, 20)
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity)
        .background(AppTheme.cardSurface, in: RoundedRectangle(cornerRadius: AppTheme.Radius.hero, style: .continuous))
    }

    private var strengthCard: some View {
        let counts = viewModel.strength.counts
        let maxCount = max(counts.max() ?? 1, 1)
        let fills: [Color] = [AppTheme.ember, Color(hex: 0xFFB547), AppTheme.accentMediumFill,
                              Color(hex: 0x5AA2F0), AppTheme.accent, AppTheme.kachiiro]
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Memory strength").font(AppTheme.Fonts.ui(.callout, weight: .heavy))
                Spacer()
                Text("\(viewModel.strength.total) items seen")
                    .font(AppTheme.Fonts.ui(.footnote))
                    .foregroundStyle(AppTheme.secondaryInk)
            }
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(counts.indices, id: \.self) { box in
                    VStack(spacing: 4) {
                        Text("\(counts[box])").font(AppTheme.Fonts.ui(.footnote, weight: .heavy)).monospacedDigit()
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(fills[box])
                            .frame(height: max(6, 80 * CGFloat(counts[box]) / CGFloat(maxCount)))
                        Text(ReviewViewModel.Strength.labels[box])
                            .font(AppTheme.Fonts.ui(.caption2, weight: .bold))
                            .foregroundStyle(AppTheme.secondaryInk)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(ReviewViewModel.Strength.labels[box]): \(counts[box])")
                }
            }
            .frame(height: 120, alignment: .bottom)
        }
        .foregroundStyle(AppTheme.primaryInk)
        .padding(16)
        .background(AppTheme.cardSurface, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
    }

    private var filterChips: some View {
        HStack(spacing: 8) {
            ForEach(Filter.allCases, id: \.self) { option in
                let count = items(for: option).count
                Button { filter = option } label: {
                    Text("\(option.rawValue) \(count)")
                        .font(AppTheme.Fonts.ui(.subheadline, weight: .bold))
                        .foregroundStyle(filter == option ? Color.white : AppTheme.primaryInk)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 36)
                        .background(filter == option ? AppTheme.kachiiro : AppTheme.cardSurface, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(filter == option ? .isSelected : [])
            }
            Spacer()
        }
    }

    private func items(for filter: Filter) -> [ReviewViewModel.Item] {
        switch filter {
        case .all:
            var seen = Set<ItemKey>()
            return (viewModel.due + viewModel.weak).filter { seen.insert($0.key).inserted }
        case .due: return viewModel.due
        case .weak: return viewModel.weak
        }
    }

    private var itemList: some View {
        let items = items(for: filter)
        return LazyVStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                HStack(spacing: 12) {
                    GlyphTile(glyph: item.pillar?.glyph ?? "？", size: 36)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.title).font(AppTheme.Fonts.ui(.callout, weight: .bold)).lineLimit(2)
                        Text(item.reason.isEmpty ? item.subtitle : item.reason)
                            .font(AppTheme.Fonts.ui(.caption, weight: .semibold))
                            .foregroundStyle(item.reason.hasPrefix("Due now · missed") || item.reason.hasPrefix("Weak")
                                             ? AppTheme.emberText : AppTheme.secondaryInk)
                    }
                    Spacer(minLength: 8)
                    Button { viewModel.toggleBookmark(item.key) } label: {
                        Image(systemName: item.isBookmarked ? "star.fill" : "star")
                            .foregroundStyle(item.isBookmarked ? AppTheme.ember : AppTheme.tertiaryInk)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.isBookmarked ? "Remove bookmark" : "Bookmark")
                }
                .foregroundStyle(AppTheme.primaryInk)
                .padding(.vertical, 6)
                if index < items.count - 1 { Divider().overlay(AppTheme.hairlineBorder) }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background(AppTheme.cardSurface, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
    }
}
