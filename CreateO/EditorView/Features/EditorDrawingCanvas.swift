import SwiftUI
import PencilKit

struct PencilKitCanvasRepresentable: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    @Binding var toolPicker: PKToolPicker
    @Binding var hasDrawing: Bool
    var isDrawingEnabled: Bool
    var onLongPress: () -> Void
    var onDrawingBegan: () -> Void
    var onDrawingEnded: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onLongPress: onLongPress,
            hasDrawing: $hasDrawing,
            onDrawingBegan: onDrawingBegan,
            onDrawingEnded: onDrawingEnded
        )
    }

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.drawingPolicy = .anyInput
        canvasView.alwaysBounceVertical = false
        canvasView.alwaysBounceHorizontal = false
        canvasView.tool = PKInkingTool(.pen, color: .label, width: 3)
        let longPress = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        longPress.minimumPressDuration = 0.5
        longPress.cancelsTouchesInView = false
        canvasView.delegate = context.coordinator
        canvasView.addGestureRecognizer(longPress)
        context.coordinator.updateDrawingState(for: canvasView)
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        uiView.delegate = context.coordinator
        uiView.isUserInteractionEnabled = isDrawingEnabled
        uiView.tool = PKInkingTool(.pen, color: .label, width: 3)
        context.coordinator.toolPicker = toolPicker
        context.coordinator.updateDrawingState(for: uiView)
        toolPicker.setVisible(isDrawingEnabled, forFirstResponder: uiView)

        if isDrawingEnabled {
            if !context.coordinator.isObservingToolPicker {
                toolPicker.addObserver(uiView)
                context.coordinator.isObservingToolPicker = true
            }
            uiView.becomeFirstResponder()
        } else {
            if context.coordinator.isObservingToolPicker {
                toolPicker.removeObserver(uiView)
                context.coordinator.isObservingToolPicker = false
            }
            uiView.resignFirstResponder()
        }
    }

    static func dismantleUIView(_ uiView: PKCanvasView, coordinator: Coordinator) {
        coordinator.finishDrawingSessionIfNeeded()
        if coordinator.isObservingToolPicker {
            coordinator.toolPicker?.removeObserver(uiView)
        }
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        let onLongPress: () -> Void
        let onDrawingBegan: () -> Void
        let onDrawingEnded: () -> Void
        var hasDrawing: Binding<Bool>
        weak var toolPicker: PKToolPicker?
        var isObservingToolPicker = false
        var isDrawingSessionActive = false
        var pendingSessionEnd: DispatchWorkItem?

        init(
            onLongPress: @escaping () -> Void,
            hasDrawing: Binding<Bool>,
            onDrawingBegan: @escaping () -> Void,
            onDrawingEnded: @escaping () -> Void
        ) {
            self.onLongPress = onLongPress
            self.hasDrawing = hasDrawing
            self.onDrawingBegan = onDrawingBegan
            self.onDrawingEnded = onDrawingEnded
        }

        @objc func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
            guard recognizer.state == .began else { return }
            onLongPress()
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            if !isDrawingSessionActive {
                isDrawingSessionActive = true
                onDrawingBegan()
            }
            scheduleDrawingSessionEnd()
            updateDrawingState(for: canvasView)
        }

        func updateDrawingState(for canvasView: PKCanvasView) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                self.hasDrawing.wrappedValue = !canvasView.drawing.strokes.isEmpty
            }
        }

        func scheduleDrawingSessionEnd() {
            pendingSessionEnd?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                self?.finishDrawingSessionIfNeeded()
            }
            pendingSessionEnd = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: workItem)
        }

        func finishDrawingSessionIfNeeded() {
            pendingSessionEnd?.cancel()
            pendingSessionEnd = nil
            guard isDrawingSessionActive else { return }
            isDrawingSessionActive = false
            onDrawingEnded()
        }
    }
}
