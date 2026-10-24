import SwiftUI

struct QuizCardStyle: ViewModifier {
    var tint: Color?
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(tint ?? AppTheme.cardSurface, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
                    .strokeBorder(AppTheme.hairlineBorder, lineWidth: 1)
            }
    }
}

extension View {
    func quizCard(tint: Color? = nil, padding: CGFloat = 16) -> some View {
        modifier(QuizCardStyle(tint: tint, padding: padding))
    }
}
