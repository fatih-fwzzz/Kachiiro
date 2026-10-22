import SwiftUI
import KachiiroCore

struct RootView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Kachiiro 勝色")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
            Text("\(Pillar.allCases.count) pillars")
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    RootView()
}
