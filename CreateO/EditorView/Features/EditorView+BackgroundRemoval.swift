import UIKit

extension EditorView {
    @MainActor
    func removeBackgroundFromSelectedImage() {
        guard let imageActionTargetID else { return }
        removeBackground(for: imageActionTargetID)
    }

    @MainActor
    func removeBackground(for imageID: UUID) {
        guard let sourceItem = canvasImages.first(where: { $0.element.id == imageID }) else { return }
        let sourceImage = sourceItem.image
        let targetImageID = imageID

        backgroundRemovalImageID = targetImageID
        selectedImageID = targetImageID
        dismissImageActions()

        Task { @MainActor in
            let liftedImage = await Self.backgroundRemovedImage(from: sourceImage)
            guard let liftedImage else {
                backgroundRemovalImageID = nil
                selectedImageID = targetImageID
                showBackgroundRemovalFailedAlert = true
                print("Background removal failed: no foreground subject was found.")
                return
            }

            replaceBackgroundRemovedImage(liftedImage, for: targetImageID)
            selectedImageID = targetImageID
            backgroundRemovalImageID = nil
        }
    }

    @MainActor
    static func backgroundRemovedImage(from image: UIImage) async -> UIImage? {
        do {
            return try await BackgroundRemover.shared.removeBackground(from: image)
        } catch {
            print("Background removal failed: \(error.localizedDescription)")
            return nil
        }
    }

    @MainActor
    func replaceBackgroundRemovedImage(_ image: UIImage, for imageID: UUID) {
        guard let index = canvasImages.firstIndex(where: { $0.element.id == imageID }) else { return }
        guard let crop = image.visibleAlphaCrop(padding: CGFloat(canvasImages[index].element.borderWidth)) else {
            replaceImage(image, for: imageID)
            return
        }

        let item = canvasImages[index]
        let originalDisplaySize = displayedImageSize(
            for: image.size,
            in: CGSize(width: item.element.width, height: item.element.height)
        )
        let originalPixelSize = crop.originalPixelSize
        guard originalPixelSize.width > 0, originalPixelSize.height > 0 else {
            replaceImage(crop.image, for: imageID)
            return
        }

        let cropRect = crop.cropRectInPixels
        let widthRatio = cropRect.width / originalPixelSize.width
        let heightRatio = cropRect.height / originalPixelSize.height
        let localOffset = CGSize(
            width: ((cropRect.midX / originalPixelSize.width) - 0.5) * originalDisplaySize.width,
            height: ((cropRect.midY / originalPixelSize.height) - 0.5) * originalDisplaySize.height
        )
        let scale = CGFloat(item.element.scale)
        let rotation = CGFloat(item.element.rotation)
        let cosAngle = cos(rotation)
        let sinAngle = sin(rotation)
        let rotatedOffset = CGSize(
            width: ((localOffset.width * cosAngle) - (localOffset.height * sinAngle)) * scale,
            height: ((localOffset.width * sinAngle) + (localOffset.height * cosAngle)) * scale
        )
        let newSize = CGSize(
            width: max(originalDisplaySize.width * widthRatio, 1),
            height: max(originalDisplaySize.height * heightRatio, 1)
        )

        performHistoryChange {
            canvasImages[index].image = crop.image
            canvasImages[index].element.width = newSize.width
            canvasImages[index].element.height = newSize.height
            canvasImages[index].element.position = CGPoint(
                x: item.element.position.x + rotatedOffset.width,
                y: item.element.position.y + rotatedOffset.height
            )
            canvasImages[index].lastPosition = CGSize(
                width: canvasImages[index].element.position.x,
                height: canvasImages[index].element.position.y
            )
        }
    }
}
