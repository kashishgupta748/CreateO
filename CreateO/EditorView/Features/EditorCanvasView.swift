import PencilKit
import SwiftUI

struct EditorCanvasView: View {
    @Environment(FirstDesignGuideManager.self) private var guideManager

    @Binding var canvasImages: [CanvasImage]
    @Binding var canvasTexts: [CanvasText]
    @Binding var canvasColor: Color
    @Binding var selectedImageID: UUID?
    @Binding var activeImageInteractionID: UUID?
    @Binding var backgroundRemovalImageID: UUID?
    @Binding var selectedTextID: UUID?
    @Binding var focusedTextID: UUID?
    @Binding var drawingCanvas: PKCanvasView
    @Binding var toolPicker: PKToolPicker
    @Binding var brushHasContent: Bool
    @Binding var currentCanvasSize: CGSize

    let isBrushActive: Bool
    let isBrushLayerVisible: Bool
    let brushLayerZIndex: Int
    let availableSize: CGSize
    let horizontalSizeClass: UserInterfaceSizeClass?
    let verticalSizeClass: UserInterfaceSizeClass?
    let adaptiveCanvasSize: (CGSize, UserInterfaceSizeClass?, UserInterfaceSizeClass?) -> CGSize
    let clearSelection: () -> Void
    let presentImageActions: (UUID, CGPoint) -> Void
    let bringLayerToFront: (UUID) -> Void
    let dismissImageActions: () -> Void
    let presentTextActions: (UUID) -> Void
    let removeTextLayerIfEmpty: (UUID) -> Void
    let presentBrushActions: () -> Void
    let brushDrawingUsedForGuide: () -> Void
    let openLayerSheet: () -> Void
    let beginHistoryTransaction: () -> Void
    let endHistoryTransaction: () -> Void

    @FocusState private var canvasFocusedTextID: UUID?

    var body: some View {
        let canvasSize = adaptiveCanvasSize(
            availableSize,
            horizontalSizeClass,
            verticalSizeClass
        )

        ZStack {
            canvasColor
            imageLayers(for: canvasSize)
            textLayers(for: canvasSize)
            drawingLayer
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color(uiColor: .separator), lineWidth: 1)
        }
        .overlay(alignment: .bottomTrailing) {
            EditorLayerButton(action: openLayerSheet)
                .padding(.trailing, 14)
                .padding(.bottom, 14)
        }
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onTapGesture {
            clearSelection()
            canvasFocusedTextID = nil
        }
        .onAppear {
            currentCanvasSize = canvasSize
            canvasFocusedTextID = focusedTextID
        }
        .onChange(of: canvasSize) { _, newSize in
            currentCanvasSize = newSize
        }
        .onChange(of: focusedTextID) { _, newValue in
            if canvasFocusedTextID != newValue {
                canvasFocusedTextID = newValue
            }
        }
        .onChange(of: canvasFocusedTextID) { _, newValue in
            if focusedTextID != newValue {
                focusedTextID = newValue
            }
        }
        .shadow(radius: 5)
        .guideHighlight(
            .editorCanvas,
            isActive: guideManager.currentStep?.anchor == .editorCanvas
        )
    }

    private func imageLayers(for canvasSize: CGSize) -> some View {
        ForEach($canvasImages) { $item in
            if item.isVisible {
                DraggableImageView(
                    item: $item,
                    selectedFilter: .constant(.original),
                    selectedImageID: $selectedImageID,
                    activeInteractionImageID: $activeImageInteractionID,
                    backgroundRemovalImageID: $backgroundRemovalImageID,
                    canvasSize: canvasSize,
                    onLongPress: { point in
                        presentImageActions(item.element.id, point)
                    },
                    onInteractionStart: {
                        bringLayerToFront(item.element.id)
                        if selectedImageID == item.element.id {
                            dismissImageActions()
                        }
                    },
                    onInteractionBegan: beginHistoryTransaction,
                    onInteractionEnded: endHistoryTransaction
                )
                .allowsHitTesting(!isBrushActive)
            }
        }
    }

    private func textLayers(for canvasSize: CGSize) -> some View {
        ForEach($canvasTexts) { $item in
            if item.isVisible {
                DraggableTextView(
                    item: $item,
                    selectedTextID: $selectedTextID,
                    focusedTextID: $canvasFocusedTextID,
                    canvasSize: canvasSize,
                    onLongPress: { presentTextActions(item.id) },
                    onInteractionBegan: beginHistoryTransaction,
                    onInteractionEnded: endHistoryTransaction
                )
                .zIndex(Double(item.zIndex))
                .allowsHitTesting(!isBrushActive)
            }
        }
    }

    private var drawingLayer: some View {
        PencilKitCanvasRepresentable(
            canvasView: $drawingCanvas,
            toolPicker: $toolPicker,
            hasDrawing: $brushHasContent,
            isDrawingEnabled: isBrushActive,
            onLongPress: presentBrushActions,
            onDrawingBegan: beginHistoryTransaction,
            onDrawingEnded: {
                endHistoryTransaction()
                brushDrawingUsedForGuide()
            }
        )
        .opacity(isBrushLayerVisible ? 1 : 0)
        .allowsHitTesting(isBrushActive)
        .zIndex(isBrushActive ? 100_000 : Double(brushLayerZIndex))
    }
}
