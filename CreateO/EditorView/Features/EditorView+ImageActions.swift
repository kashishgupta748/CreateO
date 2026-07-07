import SwiftUI

extension EditorView {
    func presentImageActions(for imageID: UUID, at point: CGPoint) {
        selectedImageID = imageID
        selectedTextID = nil
        focusedTextID = nil
        imageActionTargetID = imageID
        isBrushActive = false
        isFilterActive = false
        imageActionMenuPosition = clampedImageActionMenuPosition(for: point)
        showImageActionMenu = true
    }

    func openImageFilters() {
        guard let image = selectedCanvasImage else { return }
        dismissImageActions()
        selectedImageID = image.element.id
        selectedFilter = image.element.elementFilter ?? .original
        isFilterActive = true
    }

    func openCropSheet() {
        guard selectedCanvasImage != nil else { return }
        dismissImageActions()
        showCropSheet = true
    }

    func duplicateSelectedImage() {
        guard let image = selectedCanvasImage else { return }

        performHistoryChange {
            dismissImageActions()

            let duplicatedElement = Element(
                id: UUID(),
                elementType: image.element.elementType,
                x: image.element.position.x + 24,
                y: image.element.position.y + 24,
                scale: image.element.scale,
                rotation: image.element.rotation,
                height: image.element.height,
                width: image.element.width,
                elementPath: image.element.elementPath,
                elementFilter: image.element.elementFilter,
                zIndex: nextAvailableLayerZIndex()
            )

            let duplicatedImage = CanvasImage(
                image: image.image,
                element: duplicatedElement,
                isVisible: image.isVisible,
                lastPosition: CGSize(width: duplicatedElement.position.x, height: duplicatedElement.position.y),
                lastScale: CGFloat(duplicatedElement.scale),
                lastRotation: Angle(radians: duplicatedElement.rotation)
            )

            canvasImages.append(duplicatedImage)
            selectedImageID = duplicatedElement.id
            normalizeImageLayerOrder()
        }
    }

    func deleteSelectedImage() {
        guard let imageActionTargetID else { return }
        performHistoryChange {
            dismissImageActions()
            canvasImages.removeAll { $0.element.id == imageActionTargetID }
            normalizeImageLayerOrder()
            if selectedImageID == imageActionTargetID {
                selectedImageID = nil
            }
            self.imageActionTargetID = nil
            isFilterActive = false
        }
    }

    func duplicateLayer(_ imageID: UUID) {
        imageActionTargetID = imageID
        duplicateSelectedImage()
    }

    func deleteLayer(_ imageID: UUID) {
        imageActionTargetID = imageID
        deleteSelectedImage()
    }

    func toggleLayerVisibility(_ imageID: UUID) {
        guard let index = canvasImages.firstIndex(where: { $0.element.id == imageID }) else { return }

        performHistoryChange {
            canvasImages[index].isVisible.toggle()

            if !canvasImages[index].isVisible {
                if selectedImageID == imageID {
                    selectedImageID = nil
                }
                if imageActionTargetID == imageID {
                    dismissImageActions()
                    imageActionTargetID = nil
                }
            }
        }
    }

    func selectLayer(_ imageID: UUID) {
        guard canvasImages.contains(where: { $0.element.id == imageID && $0.isVisible }) else { return }
        dismissImageActions()
        selectedTextID = nil
        focusedTextID = nil
        selectedImageID = imageID
    }

    func duplicateTextLayer(_ textID: UUID) {
        textActionTargetID = textID
        duplicateSelectedText()
    }

    func deleteTextLayer(_ textID: UUID) {
        textActionTargetID = textID
        deleteSelectedText()
    }

    func dismissImageActions() {
        showImageActionMenu = false
        imageActionMenuPosition = .zero
    }
}
