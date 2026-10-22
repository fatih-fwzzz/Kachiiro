import KachiiroCore
import SwiftUI

struct DashboardView: View {
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        VStack(spacing: 6) {
            Text("Kachiiro 勝色").font(AppTheme.Fonts.ui(.largeTitle, weight: .bold))
            Text("\(environment.seed.words.count) words · \(environment.seed.patterns.count) patterns · \(environment.seed.kanji.count) kanji")
                .foregroundStyle(AppTheme.secondaryInk)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.canvas)
        .navigationTitle("Dashboard")
    }
}
