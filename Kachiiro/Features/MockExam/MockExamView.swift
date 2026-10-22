import SwiftUI

struct MockExamView: View {
    var body: some View {
        Text("Mock Exam")
            .font(AppTheme.Fonts.ui(.title2, weight: .semibold))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.canvas)
            .navigationTitle("Mock Exam")
    }
}
