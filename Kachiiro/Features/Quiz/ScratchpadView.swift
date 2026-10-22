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

/// Collapsible panel: title, Clear, and the canvas. A new canvas is created per question via `.id`.
struct ScratchpadPanel: View {
    @State private var generation = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Scratchpad", systemImage: "pencil.and.scribble").font(.subheadline.weight(.semibold))
                Spacer()
                Button("Clear") { generation += 1 }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            Divider()
            ScratchpadView().id(generation)
        }
        .frame(height: 260)
        .background(AppTheme.cardSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(AppTheme.hairlineBorder) }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
