import SwiftUI

/// Answer feedback pinned at thumb height: the verdict, why, and the next step.
/// Correct is solid blue; wrong is warm ember, never red.
struct FeedbackSheet<Extra: View>: View {
    enum Verdict { case correct, wrong }

    let verdict: Verdict
    let headline: String
    var detail: String?
    var notes: [String] = []
    let continueTitle: String
    var isBookmarked: Bool?
    var onBookmark: () -> Void = {}
    let onContinue: () -> Void
    @ViewBuilder var extra: Extra

    private var isCorrect: Bool { verdict == .correct }
    private var ink: Color { isCorrect ? .white : AppTheme.emberDeepText }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: isCorrect ? "checkmark" : "exclamationmark")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(isCorrect ? AppTheme.accent : Color.white)
                    .frame(width: 36, height: 36)
                    .background(isCorrect ? Color.white : AppTheme.ember, in: Circle())
                    .accessibilityHidden(true)
                Text(headline)
                    .font(AppTheme.Fonts.ui(.title3, weight: .heavy))
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let isBookmarked {
                    Button(action: onBookmark) {
                        Image(systemName: isBookmarked ? "star.fill" : "star")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(width: 44, height: 44)
                            .background(isCorrect ? Color.white.opacity(0.18) : AppTheme.ember.opacity(0.16), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isBookmarked ? "Remove bookmark" : "Bookmark")
                }
            }
            if let detail, !detail.isEmpty {
                Text(detail).font(AppTheme.Fonts.ui(.body, weight: .semibold))
            }
            ForEach(notes.filter { !$0.isEmpty }, id: \.self) { note in
                Text(note).font(AppTheme.Fonts.ui(.subheadline)).opacity(0.9)
            }
            extra
            Button(continueTitle, action: onContinue)
                .buttonStyle(SheetButtonStyle(onBlue: isCorrect))
                .keyboardShortcut(.return, modifiers: [])
                .padding(.top, 4)
        }
        .foregroundStyle(ink)
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: AppTheme.Radius.hero, topTrailingRadius: AppTheme.Radius.hero, style: .continuous)
                .fill(isCorrect ? AppTheme.accent : AppTheme.emberSoftFill)
                .overlay(alignment: .top) {
                    if !isCorrect {
                        UnevenRoundedRectangle(topLeadingRadius: AppTheme.Radius.hero, topTrailingRadius: AppTheme.Radius.hero, style: .continuous)
                            .stroke(AppTheme.ember, lineWidth: 2)
                    }
                }
                .ignoresSafeArea(edges: .bottom)
        }
        .accessibilityElement(children: .contain)
    }
}

extension FeedbackSheet where Extra == EmptyView {
    init(
        verdict: Verdict, headline: String, detail: String? = nil, notes: [String] = [], continueTitle: String,
        isBookmarked: Bool? = nil, onBookmark: @escaping () -> Void = {}, onContinue: @escaping () -> Void
    ) {
        self.init(
            verdict: verdict, headline: headline, detail: detail, notes: notes, continueTitle: continueTitle,
            isBookmarked: isBookmarked, onBookmark: onBookmark, onContinue: onContinue
        ) { EmptyView() }
    }
}

/// The same sheet while an answer is being checked (AI judging): skeleton lines, a calm caption.
struct CheckingSheet: View {
    let title: String
    var caption = "Your answer is saved either way."

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ProgressView().tint(AppTheme.accent)
                Text(title).font(AppTheme.Fonts.ui(.headline, weight: .heavy))
            }
            VStack(alignment: .leading, spacing: 8) {
                Capsule().fill(AppTheme.elevatedField).frame(height: 14).frame(maxWidth: 260)
                Capsule().fill(AppTheme.elevatedField).frame(height: 14).frame(maxWidth: 190)
            }
            .accessibilityHidden(true)
            Text(caption).font(AppTheme.Fonts.ui(.footnote)).foregroundStyle(AppTheme.secondaryInk)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: AppTheme.Radius.hero, topTrailingRadius: AppTheme.Radius.hero, style: .continuous)
                .fill(AppTheme.cardSurface)
                .shadow(color: .black.opacity(0.08), radius: 12, y: -2)
                .ignoresSafeArea(edges: .bottom)
        }
        .accessibilityElement(children: .combine)
    }
}

/// White on the blue sheet, blue on the ember sheet: the next step is always the strongest button.
private struct SheetButtonStyle: ButtonStyle {
    let onBlue: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.Fonts.ui(.headline, weight: .heavy))
            .foregroundStyle(onBlue ? AppTheme.accent : Color.white)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(onBlue ? Color.white : AppTheme.accent,
                        in: RoundedRectangle(cornerRadius: AppTheme.Radius.control, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

#Preview {
    VStack(spacing: 0) {
        Spacer()
        FeedbackSheet(
            verdict: .wrong, headline: "Not quite", detail: "The answer is 食べて.",
            notes: ["Group 2 verbs drop る and add て."], continueTitle: "Got it", isBookmarked: false
        ) {}
    }
    .background(AppTheme.canvas)
}
