import SwiftUI

/// Shown while a drill or session is being built, so a slow start never looks like a frozen button.
struct PreparingCard: View {
    let title: String
    var message: String?

    var body: some View {
        VStack(spacing: 10) {
            ProgressView().tint(.white).controlSize(.large)
            Text(title).font(AppTheme.Fonts.ui(.headline, weight: .heavy))
            if let message {
                Text(message)
                    .font(AppTheme.Fonts.ui(.footnote))
                    .foregroundStyle(AppTheme.onKachiiroSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .foregroundStyle(.white)
        .padding(24)
        .frame(maxWidth: 280)
        .background(AppTheme.kachiiro, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
    }
}

extension View {
    /// Dims the screen, blocks taps and shows `PreparingCard` while `active`.
    func preparingOverlay(_ active: Bool, title: String, message: String? = nil) -> some View {
        overlay {
            if active {
                ZStack {
                    Color.black.opacity(0.15).ignoresSafeArea()
                    PreparingCard(title: title, message: message)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: active)
    }
}
