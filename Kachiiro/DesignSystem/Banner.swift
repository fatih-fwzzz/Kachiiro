import SwiftUI

/// The one component for every problem or notice: what happened, what still works, one way forward.
struct Banner: View {
    enum Kind { case warning, info }

    struct Action {
        let title: String
        let perform: () -> Void
    }

    let kind: Kind
    let title: String
    var message: String?
    var action: Action?
    var secondary: Action?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: kind == .warning ? "exclamationmark.triangle.fill" : "info.circle.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(kind == .warning ? Color.white : AppTheme.accentText)
                .frame(width: 32, height: 32)
                .background(kind == .warning ? AppTheme.ember : AppTheme.accentSoftFill,
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(AppTheme.Fonts.ui(.subheadline, weight: .heavy))
                if let message {
                    Text(message)
                        .font(AppTheme.Fonts.ui(.footnote))
                        .foregroundStyle(kind == .warning ? AppTheme.emberText : AppTheme.secondaryInk)
                }
                if action != nil || secondary != nil {
                    HStack(spacing: 8) {
                        if let action {
                            Button(action.title, action: action.perform)
                                .font(AppTheme.Fonts.ui(.footnote, weight: .heavy))
                                .foregroundStyle(kind == .warning ? Color.white : AppTheme.accentText)
                                .padding(.horizontal, 12)
                                .frame(minHeight: 32)
                                .background(kind == .warning ? AppTheme.accent : AppTheme.accentSoftFill,
                                            in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        if let secondary {
                            Button(secondary.title, action: secondary.perform)
                                .font(AppTheme.Fonts.ui(.footnote, weight: .bold))
                                .foregroundStyle(AppTheme.secondaryInk)
                                .frame(minHeight: 32)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 6)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(kind == .warning ? AppTheme.emberDeepText : AppTheme.primaryInk)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(kind == .warning ? AppTheme.emberSoftFill : AppTheme.cardSurface,
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(kind == .warning ? AppTheme.ember.opacity(0.45) : AppTheme.hairlineBorder, lineWidth: 1.5)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(spacing: 12) {
        Banner(kind: .warning, title: "Couldn’t check this answer", message: "Your answer is saved.",
               action: .init(title: "Try again") {}, secondary: .init(title: "Skip") {})
        Banner(kind: .info, title: "Using offline checks", message: "Gemini isn’t reachable.")
    }
    .padding()
    .background(AppTheme.canvas)
}
