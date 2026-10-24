import SwiftUI

struct AppleBadge: View {
    enum Style { case solidBlue, tintedBlue, outlinedBlue, neutral }

    let text: String
    var icon: String?
    var style: Style = .tintedBlue

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon).font(.system(size: 11, weight: .semibold))
            }
            Text(text).font(.system(size: 12, weight: .semibold, design: .rounded))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .foregroundStyle(foreground)
        .background {
            switch style {
            case .solidBlue: Capsule().fill(AppTheme.accent)
            case .tintedBlue: Capsule().fill(AppTheme.accentSoftFill)
            case .outlinedBlue: Capsule().strokeBorder(AppTheme.accentBorder, lineWidth: 1)
            case .neutral: Capsule().fill(Color(.quaternarySystemFill))
            }
        }
    }

    private var foreground: Color {
        switch style {
        case .solidBlue: .white
        case .neutral: AppTheme.secondaryInk
        default: AppTheme.accentText
        }
    }
}
