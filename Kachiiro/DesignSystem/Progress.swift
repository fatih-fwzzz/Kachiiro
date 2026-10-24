import SwiftUI

/// One segment per question: answered right, answered wrong, current, or still to come.
struct SegmentedProgressBar: View {
    enum Segment: Equatable { case correct, wrong, current, upcoming }

    let segments: [Segment]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                Capsule().fill(color(segment)).frame(height: 8)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Question \((segments.firstIndex(of: .current) ?? segments.count) + 1) of \(segments.count)")
    }

    private func color(_ segment: Segment) -> Color {
        switch segment {
        case .correct: AppTheme.accent
        case .wrong: AppTheme.ember
        case .current: AppTheme.accentMediumFill
        case .upcoming: AppTheme.track
        }
    }
}

/// A rounded bar with an optional target marker (the pass line).
struct LinearProgress: View {
    let value: Double
    var tint: Color = AppTheme.accent
    var track: Color = AppTheme.track
    var marker: Double?
    var markerColor: Color = AppTheme.primaryInk
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule().fill(tint).frame(width: geo.size.width * min(max(value, 0), 1))
                if let marker {
                    Capsule().fill(markerColor)
                        .frame(width: 2, height: height + 6)
                        .offset(x: geo.size.width * marker - 1)
                }
            }
        }
        .frame(height: height)
    }
}

struct ProgressRing<Label: View>: View {
    let value: Double
    var lineWidth: CGFloat = 10
    var tint: Color = AppTheme.accent
    var track: Color = AppTheme.track
    @ViewBuilder var label: Label

    var body: some View {
        ZStack {
            Circle().stroke(track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(value, 0), 1))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            label
        }
    }
}
