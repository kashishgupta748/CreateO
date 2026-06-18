import SwiftUI

extension DraggableImageView {
    var imageRenderID: String {
        let cgImageID = item.image.cgImage.map {
            "\($0.width)x\($0.height)-\($0.bytesPerRow)-\($0.bitsPerPixel)-\(ObjectIdentifier($0).hashValue)"
        } ?? "\(item.image.size)-\(ObjectIdentifier(item.image).hashValue)"
        return "\(item.element.id)-\(cgImageID)"
    }

    var imageProcessingID: String {
        let filter = item.element.elementFilter?.rawValue ?? Filter.original.rawValue
        let imageID = item.image.cgImage.map { "\($0.width)x\($0.height)-\($0.bytesPerRow)-\($0.bitsPerPixel)" } ?? "\(item.image.size)"
        return "\(filter)-\(imageID)-\(ObjectIdentifier(item.image).hashValue)"
    }

    func aspectFitSize(for imageSize: CGSize, in bounds: CGSize) -> CGSize {
        guard imageSize.width > 0, imageSize.height > 0 else { return bounds }

        let widthRatio = bounds.width / imageSize.width
        let heightRatio = bounds.height / imageSize.height
        let scale = min(widthRatio, heightRatio)

        return CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )
    }

    func clampedScale(_ scale: CGFloat) -> CGFloat {
        min(max(scale, minimumImageScale), maximumImageScale)
    }

    func clampedPosition(_ position: CGPoint, scale: CGFloat) -> CGPoint {
        let visiblePadding: CGFloat = 44
        let scaledWidth = displayedImageSize.width * scale
        let scaledHeight = displayedImageSize.height * scale

        let minX = -((canvasSize.width + scaledWidth) / 2) + visiblePadding
        let maxX = ((canvasSize.width + scaledWidth) / 2) - visiblePadding
        let minY = -((canvasSize.height + scaledHeight) / 2) + visiblePadding
        let maxY = ((canvasSize.height + scaledHeight) / 2) - visiblePadding

        return CGPoint(
            x: min(max(position.x, minX), maxX),
            y: min(max(position.y, minY), maxY)
        )
    }

    var menuAnchorPoint: CGPoint {
        CGPoint(
            x: canvasSize.width / 2 + item.element.position.x,
            y: canvasSize.height / 2 + item.element.position.y + (displayedImageSize.height * CGFloat(item.element.scale) / 2) + 28
        )
    }

    var selectionCorners: some View {
        ZStack {
            cornerBullet(alignment: .topLeading)
            cornerBullet(alignment: .topTrailing)
            cornerBullet(alignment: .bottomLeading)
            cornerBullet(alignment: .bottomTrailing)
        }
    }

    var processingBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
                .frame(width: 76, height: 76)

            ProgressView()
                .tint(.primary)
        }
    }

    func cornerBullet(alignment: Alignment) -> some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 14, height: 14)

            Circle()
                .fill(Color.accentColor)
                .frame(width: 8, height: 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
        .offset(cornerOffset(for: alignment))
    }

    func cornerOffset(for alignment: Alignment) -> CGSize {
        let distance: CGFloat = 8

        switch alignment {
        case .topLeading:
            return CGSize(width: -distance, height: -distance)
        case .topTrailing:
            return CGSize(width: distance, height: -distance)
        case .bottomLeading:
            return CGSize(width: -distance, height: distance)
        case .bottomTrailing:
            return CGSize(width: distance, height: distance)
        default:
            return .zero
        }
    }
}
