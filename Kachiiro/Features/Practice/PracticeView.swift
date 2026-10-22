import SwiftUI

struct PracticeView: View {
    var body: some View {
        Text("Practice")
            .font(AppTheme.Fonts.ui(.title2, weight: .semibold))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.canvas)
            .navigationTitle("Practice")
    }
}
