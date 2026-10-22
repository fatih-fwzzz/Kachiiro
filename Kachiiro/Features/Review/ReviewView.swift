import SwiftUI

struct ReviewView: View {
    var body: some View {
        Text("Review")
            .font(AppTheme.Fonts.ui(.title2, weight: .semibold))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.canvas)
            .navigationTitle("Review")
    }
}
