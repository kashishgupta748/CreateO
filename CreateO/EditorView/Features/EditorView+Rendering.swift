import PencilKit
import SwiftUI

extension EditorView {
    func renderCanvasImage() -> UIImage? {
        let canvasSize = currentCanvasSize
        let hasVisibleBrushLayer = isBrushLayerVisible && !drawingCanvas.drawing.strokes.isEmpty
        let displayScale = canvasDisplayScale()
        let brushImage = hasVisibleBrushLayer
            ? drawBrushImage(on: CGRect(origin: .zero, size: canvasSize))
            : nil

        let renderView = CanvasExportView(
            canvasImages: canvasImages,
            canvasTexts: canvasTexts,
            brushImage: brushImage,
            brushLayerZIndex: brushLayerZIndex,
            canvasColor: canvasColor,
            canvasSize: canvasSize
        )
        .frame(width: canvasSize.width, height: canvasSize.height)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

        let renderer = ImageRenderer(content: renderView)
        renderer.proposedSize = ProposedViewSize(canvasSize)
        renderer.scale = displayScale

        return renderer.uiImage
    }

    func persist(image: UIImage, id: UUID) -> String {
        let fileName = "design-\(id.uuidString).png"
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let fileURL = directory.appendingPathComponent(fileName)

        if let data = image.pngData() {
            try? data.write(to: fileURL, options: .atomic)
        }

        return fileURL.path
    }

    func displayedImageSize(for imageSize: CGSize, in bounds: CGSize) -> CGSize {
        guard imageSize.width > 0, imageSize.height > 0 else { return bounds }

        let widthRatio = bounds.width / imageSize.width
        let heightRatio = bounds.height / imageSize.height
        let scale = min(widthRatio, heightRatio)

        return CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }

    func drawBrushImage(on rect: CGRect) -> UIImage {
        drawingCanvas.drawing.image(from: rect, scale: canvasDisplayScale())
    }

    func canvasDisplayScale() -> CGFloat {
        let traitScale = drawingCanvas.traitCollection.displayScale
        if traitScale > 0 {
            return traitScale
        }

        if let windowScale = drawingCanvas.window?.windowScene?.screen.scale, windowScale > 0 {
            return windowScale
        }

        return 1
    }
}

private struct CanvasExportView: View {
    let canvasImages: [CanvasImage]
    let canvasTexts: [CanvasText]
    let brushImage: UIImage?
    let brushLayerZIndex: Int
    let canvasColor: Color
    let canvasSize: CGSize

    private var orderedLayers: [CanvasExportLayer] {
        let imageLayers = canvasImages
            .filter(\.isVisible)
            .map(CanvasExportLayer.image)
        let textLayers = canvasTexts
            .filter { $0.isVisible && !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map(CanvasExportLayer.text)
        let brushLayers = brushImage.map { [CanvasExportLayer.brush($0, zIndex: brushLayerZIndex)] } ?? []

        return (imageLayers + textLayers + brushLayers).sorted { $0.zIndex < $1.zIndex }
    }

    var body: some View {
        ZStack {
            canvasColor

            ForEach(Array(orderedLayers.enumerated()), id: \.offset) { _, layer in
                switch layer {
                case .image(let item):
                    ExportImageLayer(item: item, canvasSize: canvasSize)
                case .text(let item):
                    ExportTextLayer(item: item, canvasSize: canvasSize)
                case .brush(let image, _):
                    ExportBrushLayer(image: image, canvasSize: canvasSize)
                }
            }
        }
    }
}

private enum CanvasExportLayer {
    case image(CanvasImage)
    case text(CanvasText)
    case brush(UIImage, zIndex: Int)

    var zIndex: Int {
        switch self {
        case .image(let item):
            return item.element.zIndex
        case .text(let item):
            return item.zIndex
        case .brush(_, let zIndex):
            return zIndex
        }
    }
}

private struct ExportImageLayer: View {
    let item: CanvasImage
    let canvasSize: CGSize

    private var displayedImageSize: CGSize {
        let bounds = CGSize(width: item.element.width, height: item.element.height)
        guard item.image.size.width > 0, item.image.size.height > 0 else { return bounds }

        let widthRatio = bounds.width / item.image.size.width
        let heightRatio = bounds.height / item.image.size.height
        let scale = min(widthRatio, heightRatio)

        return CGSize(
            width: item.image.size.width * scale,
            height: item.image.size.height * scale
        )
    }
    
    private var processedImage: UIImage {
        if let cached = item.cachedFilteredImage {
            return cached
        }
        let filter = item.element.elementFilter ?? .original
        guard filter != .original,
              let sourceCG = item.image.cgImage else { return item.image }
        let resultCG = ImageFilterProcessor.applySynchronously(filter, to: sourceCG)
        return UIImage(cgImage: resultCG)
    }

    var body: some View {
        ZStack {
            if item.element.borderWidth > 0 {
                SubjectBorderView(
                    image: item.image,
                    size: displayedImageSize,
                    color: item.element.borderColor.color,
                    lineWidth: CGFloat(item.element.borderWidth)
                )
            }

            Image(uiImage: processedImage)
                .resizable()
                .frame(width: displayedImageSize.width, height: displayedImageSize.height)
        }
        .scaleEffect(CGFloat(item.element.scale))
        .rotationEffect(Angle(radians: item.element.rotation))
        .position(
            x: canvasSize.width / 2 + item.element.position.x,
            y: canvasSize.height / 2 + item.element.position.y
        )
    }
}

private struct ExportTextLayer: View {
    let item: CanvasText
    let canvasSize: CGSize

    var body: some View {
        Text(item.text)
            .font(Font(item.uiFont))
            .foregroundStyle(item.textColor)
            .underline(item.isUnderlined, color: item.textColor)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .rotationEffect(item.rotation)
            .position(
                x: canvasSize.width / 2 + item.position.width,
                y: canvasSize.height / 2 + item.position.height
            )
    }
}

private struct ExportBrushLayer: View {
    let image: UIImage
    let canvasSize: CGSize

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .frame(width: canvasSize.width, height: canvasSize.height)
    }
}
