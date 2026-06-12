import SwiftUI

extension EditorView {
    func addToRecent(_ image: UIImage) {
        recentStickers.removeAll { $0.pngData() == image.pngData() }
        recentStickers.insert(image, at: 0)

        if recentStickers.count > 20 {
            recentStickers.removeLast()
        }
    }

    func addSelectedStickerToCanvas() {
        guard let image = selectedSticker else { return }

        performHistoryChange {
            let stickerSize: Double = 150
            let element = Element(
                id: UUID(),
                elementType: .sticker,
                x: 0,
                y: 0,
                height: stickerSize,
                width: stickerSize,
                elementPath: "",
                elementFilter: .original,
                zIndex: nextAvailableLayerZIndex()
            )

            canvasImages.append(CanvasImage(image: image, element: element))
            selectedImageID = element.id
            addToRecent(image)
            showSheet = false
            selectedSticker = nil
            guideManager.advance(from: .editorStickers)
        }
    }

    func activateFilterMode() {
        if isBorderActive {
            commitBorderEditing()
        }
        isBrushActive = false
        isBorderActive = false
        isDoodleActive = false
        dismissImageActions()
        isFilterActive = true
    }

    func previewBorderChanges() {
        guard let borderEditingImageID,
              let index = canvasImages.firstIndex(where: { $0.element.id == borderEditingImageID }) else { return }

        canvasImages[index].element.borderWidth = borderDraftWidth
        canvasImages[index].element.borderColor = borderDraftColor

        if guideManager.currentStep == .addBorder,
           borderDraftWidth > 0 || borderDraftColor != borderOriginalColor {
            guideManager.advance(from: .addBorder)
        }
    }

    func openBorderEditor() {
        guard let image = selectedCanvasImage else { return }

        isFilterActive = false
        isBrushActive = false
        isDoodleActive = false
        dismissImageActions()
        selectedImageID = image.element.id
        borderEditingImageID = image.element.id
        borderOriginalWidth = image.element.borderWidth
        borderOriginalColor = image.element.borderColor
        borderDraftWidth = image.element.borderWidth
        borderDraftColor = image.element.borderColor
        isBorderActive = true
    }

    func cancelBorderEditing() {
        guard let borderEditingImageID,
              let index = canvasImages.firstIndex(where: { $0.element.id == borderEditingImageID }) else {
            isBorderActive = false
            return
        }

        canvasImages[index].element.borderWidth = borderOriginalWidth
        canvasImages[index].element.borderColor = borderOriginalColor
        isBorderActive = false
        self.borderEditingImageID = nil
    }

    func commitBorderEditing() {
        guard let borderEditingImageID,
              let index = canvasImages.firstIndex(where: { $0.element.id == borderEditingImageID }) else {
            isBorderActive = false
            return
        }

        let draftWidth = borderDraftWidth
        let draftColor = borderDraftColor

        canvasImages[index].element.borderWidth = borderOriginalWidth
        canvasImages[index].element.borderColor = borderOriginalColor

        performHistoryChange {
            canvasImages[index].element.borderWidth = draftWidth
            canvasImages[index].element.borderColor = draftColor
        }

        isBorderActive = false
        self.borderEditingImageID = nil
    }

    func toggleDoodleMode() {
        if isBorderActive {
            commitBorderEditing()
        }
        isFilterActive = false
        isBorderActive = false
        isBrushActive = false
        isDoodleActive.toggle()
        if isDoodleActive {
            applyFilterSelection(.doodle)
        }
        dismissImageActions()
    }

    func toggleBrushMode() {
        if isBorderActive {
            commitBorderEditing()
        }
        isFilterActive = false
        isBorderActive = false
        dismissImageActions()
        isBrushActive.toggle()
        isDoodleActive = false
        if isBrushActive {
            showBrushActionMenu = false
            selectedImageID = nil
            selectedTextID = nil
            focusedTextID = nil
            brushLayerZIndex = nextAvailableLayerZIndex()
        }
    }

    func openStickerSheet() {
        if isBorderActive {
            commitBorderEditing()
        }
        isFilterActive = false
        isBorderActive = false
        isBrushActive = false
        isDoodleActive = false
        dismissImageActions()
        showSheet = true
    }

    func openTemplateSheet() {
        if isBorderActive {
            commitBorderEditing()
        }
        isFilterActive = false
        isBorderActive = false
        isBrushActive = false
        isDoodleActive = false
        dismissImageActions()
        showTemplateSheet = true
    }

    func closeActiveEditorMode() {
        if focusedTextID != nil {
            focusedTextID = nil
        }
        selectedTextID = nil
        if isBorderActive {
            cancelBorderEditing()
        }
        isBrushActive = false
        isFilterActive = false
        isDoodleActive = false
        dismissImageActions()
    }

    func completeActiveEditorMode() {
        if focusedTextID != nil {
            focusedTextID = nil
            guideManager.advance(from: .editorText)
            return
        }
        if isBrushActive {
            isBrushActive = false
            dismissImageActions()
            guideManager.advance(from: .editorAdjustments)
            return
        }
        if isBorderActive {
            commitBorderEditing()
            guideManager.advance(from: .addBorder)
            return
        }
        if isFilterActive {
            isFilterActive = false
            guideManager.advance(from: .editorFilters)
            return
        }
        if isDoodleActive {
            isDoodleActive = false
            guideManager.advance(from: .editorDoodle)
        }
    }

    func applyCanvasColorTemplate(_ color: Color) {
        performHistoryChange {
            canvasColor = color
        }
    }

    func applyFilterSelection(_ filter: Filter) {
        guard !isRestoringHistory else { return }

        performHistoryChange {
            selectedFilter = filter
            applyFilter(filter)
        }

        if guideManager.currentStep == .editorFilters, filter != .original {
            isFilterActive = false
            guideManager.advance(from: .editorFilters)
        } else if guideManager.currentStep == .editorDoodle, filter == .doodle {
            isDoodleActive = false
            guideManager.advance(from: .editorDoodle)
        }
    }

    func brushDrawingUsedForGuide() {
        guard guideManager.currentStep == .editorAdjustments else { return }
        isBrushActive = false
        dismissImageActions()
        guideManager.advance(from: .editorAdjustments)
    }

    func applyFilter(_ filter: Filter) {
        if selectedImageID == nil {
            for index in canvasImages.indices {
                canvasImages[index].element.elementFilter = filter
            }
        } else if let id = selectedImageID,
                  let index = canvasImages.firstIndex(where: { $0.element.id == id }) {
            canvasImages[index].element.elementFilter = filter
        }
    }
}
