import SwiftUI
import PencilKit

/// Free-hand scratch area (Apple Pencil, finger or mouse) with the system tool picker.
struct ScratchpadView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawingPolicy = .anyInput
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.tool = PKInkingTool(.pen, color: .label, width: 4)
        context.coordinator.attach(canvas)
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {}

    static func dismantleUIView(_ canvas: PKCanvasView, coordinator: Coordinator) {
        coordinator.detach(canvas)
    }

    @MainActor
    final class Coordinator {
        private let toolPicker = PKToolPicker()

        func attach(_ canvas: PKCanvasView) {
            toolPicker.addObserver(canvas)
            // The canvas must be in a window before it can become first responder.
            DispatchQueue.main.async { [toolPicker] in
                toolPicker.setVisible(true, forFirstResponder: canvas)
                canvas.becomeFirstResponder()
            }
        }

        func detach(_ canvas: PKCanvasView) {
            toolPicker.setVisible(false, forFirstResponder: canvas)
            toolPicker.removeObserver(canvas)
        }
    }
}

/// The desk's right-hand column: a title, Clear, and the canvas. A new canvas is created per question via `.id`.
struct ScratchpadPanel: View {
    @State private var generation = 0

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Scratchpad").font(AppTheme.Fonts.ui(.headline, weight: .heavy))
                Spacer()
                Button("Clear") { generation += 1 }
                    .font(AppTheme.Fonts.ui(.subheadline, weight: .bold))
                    .foregroundStyle(AppTheme.accentText)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 32)
                    .background(AppTheme.cardSurface, in: Capsule())
                    .buttonStyle(.plain)
            }
            ScratchpadView()
                .id(generation)
                .background(AppTheme.cardSurface)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
                .overlay(alignment: .center) {
                    Text("Write with Apple Pencil or a finger")
                        .font(AppTheme.Fonts.ui(.footnote))
                        .foregroundStyle(AppTheme.tertiaryInk)
                        .allowsHitTesting(false)
                        .opacity(0.8)
                        .padding(.top, 120)
                        .accessibilityHidden(true)
                }
        }
    }
}
