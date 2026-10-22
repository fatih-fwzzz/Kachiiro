import SwiftUI

struct QuizCardStyle: ViewModifier {
    var tint: Color?

    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(tint ?? AppTheme.cardSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(AppTheme.hairlineBorder, lineWidth: 1)
            }
    }
}

extension View {
    func quizCard(tint: Color? = nil) -> some View {
        modifier(QuizCardStyle(tint: tint))
    }
}
