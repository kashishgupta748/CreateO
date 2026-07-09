import PencilKit
import SwiftUI

extension EditorView {
    func bringLayerToFront(_ imageID: UUID) {
        moveLayer(layerIdentifier(forImageID: imageID), topLayerIdentifier(), shouldRecordHistory: false)
        selectedImageID = imageID
    }

    func bringTextLayerToFront(_ textID: UUID) {
        moveLayer(layerIdentifier(forTextID: textID), topLayerIdentifier(), shouldRecordHistory: false)
        selectedTextID = textID
    }

    func nextAvailableLayerZIndex() -> Int {
        let imageMax = canvasImages.map(\.element.zIndex).max() ?? -1
        let textMax = canvasTexts.map(\.zIndex).max() ?? -1
        let brushMax = brushHasContent ? brushLayerZIndex : -1
        return max(imageMax, textMax, brushMax) + 1
    }

    func normalizeImageLayerOrder() {
        let orderedKeys = allLayerIdentifiersSortedTopToBottom().reversed()
        for (index, key) in orderedKeys.enumerated() {
            setZIndex(index, for: key)
        }
    }

    func layerIdentifier(forImageID imageID: UUID) -> String { "image:\(imageID.uuidString)" }
    func layerIdentifier(forTextID textID: UUID) -> String { "text:\(textID.uuidString)" }
    func brushLayerIdentifier() -> String { "brush" }

    func topLayerIdentifier() -> String {
        allLayerIdentifiersSortedTopToBottom().first ?? brushLayerIdentifier()
    }

    func allLayerIdentifiersSortedTopToBottom() -> [String] {
        let imageKeys = canvasImages.map { (layerIdentifier(forImageID: $0.element.id), $0.element.zIndex) }
        let textKeys = canvasTexts.map { (layerIdentifier(forTextID: $0.id), $0.zIndex) }
        let brushKeys = brushHasContent ? [(brushLayerIdentifier(), brushLayerZIndex)] : []
        return (imageKeys + textKeys + brushKeys)
            .sorted { $0.1 > $1.1 }
            .map(\.0)
    }

    func setZIndex(_ zIndex: Int, for identifier: String) {
        if identifier == brushLayerIdentifier() {
            brushLayerZIndex = zIndex
            return
        }

        if let uuidString = identifier.split(separator: ":").last,
           let uuid = UUID(uuidString: String(uuidString)) {
            if identifier.hasPrefix("image:"), let index = canvasImages.firstIndex(where: { $0.element.id == uuid }) {
                canvasImages[index].element.zIndex = zIndex
            } else if identifier.hasPrefix("text:"), let index = canvasTexts.firstIndex(where: { $0.id == uuid }) {
                canvasTexts[index].zIndex = zIndex
            }
        }
    }

    func moveLayer(_ draggedKey: String, _ targetKey: String, shouldRecordHistory: Bool = true) {
        let move = {
            guard draggedKey != targetKey else { return }
            var orderedKeys = allLayerIdentifiersSortedTopToBottom()
            guard let fromIndex = orderedKeys.firstIndex(of: draggedKey),
                  let toIndex = orderedKeys.firstIndex(of: targetKey) else { return }
            let movedKey = orderedKeys.remove(at: fromIndex)
            orderedKeys.insert(movedKey, at: toIndex)

            for (offset, key) in orderedKeys.reversed().enumerated() {
                setZIndex(offset, for: key)
            }
        }

        if shouldRecordHistory {
            performHistoryChange(move)
        } else {
            move()
        }
    }

    func presentBrushActions() {
        guard brushHasContent, !isBrushActive else { return }
        dismissImageActions()
        selectedImageID = nil
        showBrushActionMenu = true
    }

    func deleteBrushDrawing() {
        performHistoryChange {
            drawingCanvas.drawing = PKDrawing()
            brushHasContent = false
            showBrushActionMenu = false
        }
    }

    func selectBrushLayer() {
        guard brushHasContent, isBrushLayerVisible else { return }
        dismissImageActions()
        selectedImageID = nil
        selectedTextID = nil
    }

    func toggleBrushLayerVisibility() {
        guard brushHasContent else { return }
        performHistoryChange {
            isBrushLayerVisible.toggle()
        }
    }

    func duplicateBrushDrawing() {
        performHistoryChange {
            let duplicated = drawingCanvas.drawing.transformed(using: CGAffineTransform(translationX: 18, y: 18))
            drawingCanvas.drawing = PKDrawing(strokes: drawingCanvas.drawing.strokes + duplicated.strokes)
            brushHasContent = !drawingCanvas.drawing.strokes.isEmpty
            showBrushActionMenu = false
        }
    }
}
