import PhotosUI
import SwiftUI
import UIKit

extension EditorView {
    func replaceImage(_ image: UIImage, for imageID: UUID) {
        guard let index = canvasImages.firstIndex(where: { $0.element.id == imageID }) else { return }

        performHistoryChange {
            canvasImages[index].image = image
        }
    }

    func applyCropImage(_ croppedImage: UIImage) {
        guard let imageActionTargetID else { return }
        replaceImage(croppedImage, for: imageActionTargetID)
    }

    func clampedImageActionMenuPosition(for point: CGPoint) -> CGPoint {
        let menuWidth: CGFloat = 292
        let menuHeight: CGFloat = 250
        let horizontalPadding: CGFloat = 18
        let verticalPadding: CGFloat = 18

        return CGPoint(
            x: min(max(point.x, menuWidth / 2 + horizontalPadding), currentCanvasSize.width - menuWidth / 2 - horizontalPadding),
            y: min(max(point.y, menuHeight / 2 + verticalPadding), currentCanvasSize.height - menuHeight / 2 - verticalPadding)
        )
    }

    func addCanvasImages(_ images: [UIImage], shouldRecordHistory: Bool = true) {
        guard !images.isEmpty else { return }

        let addImages = {
            for image in images {
                let defaultWidth = max(currentCanvasSize.width * 0.82, 220)
                let defaultHeight = max(currentCanvasSize.height * 0.82, 260)
                let element = Element(
                    id: UUID(),
                    elementType: .image,
                    x: 0,
                    y: 0,
                    scale: 1.0,
                    rotation: 0,
                    height: defaultHeight,
                    width: defaultWidth,
                    elementPath: "temp",
                    elementFilter: .original,
                    zIndex: nextAvailableLayerZIndex()
                )

                canvasImages.append(
                    CanvasImage(
                        image: image,
                        element: element,
                        lastPosition: CGSize(width: element.position.x, height: element.position.y),
                        lastScale: CGFloat(element.scale),
                        lastRotation: Angle(radians: element.rotation)
                    )
                )
            }
        }

        if shouldRecordHistory {
            performHistoryChange(addImages)
        } else {
            addImages()
        }

        guideManager.advance(from: .uploadPhoto)
    }

    func handleSelectedItems(_ newItems: [PhotosPickerItem]) {
        for item in newItems {
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    let canvasImage = image.downscaledForCanvas() ?? image.normalizedForEditing() ?? image
                    await MainActor.run {
                        addCanvasImages([canvasImage])
                    }
                }
            }
        }
    }
}
