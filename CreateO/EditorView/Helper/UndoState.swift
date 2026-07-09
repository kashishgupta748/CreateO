import PencilKit
import SwiftUI

struct EditorHistorySnapshot {
    var canvasImages: [CanvasImage]
    var canvasTexts: [CanvasText]
    var canvasColor: SavedColor
    var selectedFilter: Filter
    var drawingData: Data
    var brushLayerZIndex: Int
    var isBrushLayerVisible: Bool
    var brushHasContent: Bool
}

extension EditorView {
    var canUndo: Bool {
        !undoStack.isEmpty
    }

    var canRedo: Bool {
        !redoStack.isEmpty
    }

    func makeHistorySnapshot() -> EditorHistorySnapshot {
        EditorHistorySnapshot(
            canvasImages: canvasImages,
            canvasTexts: canvasTexts,
            canvasColor: SavedColor(canvasColor),
            selectedFilter: selectedFilter,
            drawingData: drawingCanvas.drawing.dataRepresentation(),
            brushLayerZIndex: brushLayerZIndex,
            isBrushLayerVisible: isBrushLayerVisible,
            brushHasContent: brushHasContent
        )
    }

    func performHistoryChange(_ change: () -> Void) {
        guard !isRestoringHistory else {
            change()
            return
        }

        let before = makeHistorySnapshot()
        change()
        pushUndoSnapshot(before)
    }

    func beginHistoryTransaction() {
        guard !isRestoringHistory, activeHistorySnapshot == nil else { return }
        activeHistorySnapshot = makeHistorySnapshot()
    }

    func endHistoryTransaction() {
        guard let snapshot = activeHistorySnapshot else { return }
        activeHistorySnapshot = nil
        pushUndoSnapshot(snapshot)
    }

    func undo() {
        guard let snapshot = undoStack.last else { return }
        let current = makeHistorySnapshot()
        undoStack.removeLast()
        redoStack.append(current)
        restoreHistorySnapshot(snapshot)
    }

    func redo() {
        guard let snapshot = redoStack.last else { return }
        let current = makeHistorySnapshot()
        redoStack.removeLast()
        undoStack.append(current)
        restoreHistorySnapshot(snapshot)
    }

    func resetHistory() {
        undoStack.removeAll()
        redoStack.removeAll()
        activeHistorySnapshot = nil
    }

    private func pushUndoSnapshot(_ snapshot: EditorHistorySnapshot) {
        let current = makeHistorySnapshot()
        guard !historySnapshotsMatch(snapshot, current) else { return }
        undoStack.append(snapshot)
        if undoStack.count > 100 {
            undoStack.removeFirst(undoStack.count - 100)
        }
        redoStack.removeAll()
    }

    private func restoreHistorySnapshot(_ snapshot: EditorHistorySnapshot) {
        isRestoringHistory = true

        canvasImages = snapshot.canvasImages
        canvasTexts = snapshot.canvasTexts
        canvasColor = snapshot.canvasColor.color
        selectedFilter = snapshot.selectedFilter
        drawingCanvas.drawing = (try? PKDrawing(data: snapshot.drawingData)) ?? PKDrawing()
        brushLayerZIndex = snapshot.brushLayerZIndex
        isBrushLayerVisible = snapshot.isBrushLayerVisible
        brushHasContent = snapshot.brushHasContent

        selectedImageID = nil
        selectedTextID = nil
        focusedTextID = nil
        activeImageInteractionID = nil
        imageActionTargetID = nil
        textActionTargetID = nil
        showImageActionMenu = false
        showTextActionMenu = false
        showBrushActionMenu = false
        showCropSheet = false
        isBrushActive = false
        isFilterActive = false
        isBorderActive = false
        isDoodleActive = false
        borderEditingImageID = nil

        DispatchQueue.main.async {
            self.isRestoringHistory = false
        }
    }

    private func historySnapshotsMatch(_ lhs: EditorHistorySnapshot, _ rhs: EditorHistorySnapshot) -> Bool {
        guard lhs.canvasImages.count == rhs.canvasImages.count,
              lhs.canvasTexts.count == rhs.canvasTexts.count,
              savedColorsMatch(lhs.canvasColor, rhs.canvasColor),
              lhs.selectedFilter == rhs.selectedFilter,
              lhs.drawingData == rhs.drawingData,
              lhs.brushLayerZIndex == rhs.brushLayerZIndex,
              lhs.isBrushLayerVisible == rhs.isBrushLayerVisible,
              lhs.brushHasContent == rhs.brushHasContent else {
            return false
        }

        for (left, right) in zip(lhs.canvasImages, rhs.canvasImages) {
            guard left.element == right.element,
                  left.isVisible == right.isVisible,
                  left.lastPosition == right.lastPosition,
                  left.lastScale == right.lastScale,
                  left.lastRotation == right.lastRotation,
                  left.image.pngData() == right.image.pngData() else {
                return false
            }
        }

        for (left, right) in zip(lhs.canvasTexts, rhs.canvasTexts) {
            guard left.id == right.id,
                  left.text == right.text,
                  left.fontName == right.fontName,
                  left.fontSize == right.fontSize,
                  savedColorsMatch(SavedColor(left.textColor), SavedColor(right.textColor)),
                  left.isBold == right.isBold,
                  left.isItalic == right.isItalic,
                  left.isUnderlined == right.isUnderlined,
                  left.zIndex == right.zIndex,
                  left.isVisible == right.isVisible,
                  left.position == right.position,
                  left.rotation == right.rotation,
                  left.lastPosition == right.lastPosition,
                  left.lastFontSize == right.lastFontSize,
                  left.lastRotation == right.lastRotation else {
                return false
            }
        }

        return true
    }

    private func savedColorsMatch(_ lhs: SavedColor, _ rhs: SavedColor) -> Bool {
        lhs.red == rhs.red &&
        lhs.green == rhs.green &&
        lhs.blue == rhs.blue &&
        lhs.alpha == rhs.alpha
    }
}
