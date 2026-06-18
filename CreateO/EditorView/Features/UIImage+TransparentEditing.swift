import UIKit

struct VisibleAlphaCrop {
    let image: UIImage
    let cropRectInPixels: CGRect
    let originalPixelSize: CGSize
}

extension UIImage {
    func preparingForTransparentEditing() -> UIImage? {
        guard size.width > 0, size.height > 0 else { return nil }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        format.opaque = false

        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    func visibleAlphaCoverage(alphaThreshold: UInt8 = 8) -> CGFloat? {
        guard let cgImage else { return nil }

        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return nil }

        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

        let didDraw = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let baseAddress = buffer.baseAddress,
                  let context = CGContext(
                    data: baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: width * 4,
                    space: colorSpace,
                    bitmapInfo: bitmapInfo
                  ) else {
                return false
            }

            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }

        guard didDraw else { return nil }

        var visiblePixels = 0
        let totalPixels = width * height
        for pixelIndex in 0..<totalPixels {
            let alpha = pixels[pixelIndex * 4 + 3]
            if alpha > alphaThreshold {
                visiblePixels += 1
            }
        }

        return CGFloat(visiblePixels) / CGFloat(totalPixels)
    }

    func croppedToVisibleAlphaBounds(alphaThreshold: UInt8 = 8, padding: CGFloat = 0) -> UIImage? {
        visibleAlphaCrop(alphaThreshold: alphaThreshold, padding: padding)?.image
    }

    func visibleAlphaCrop(alphaThreshold: UInt8 = 8, padding: CGFloat = 0) -> VisibleAlphaCrop? {
        guard let cgImage,
              let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let bytes = CFDataGetBytePtr(data) else {
            return nil
        }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = max(cgImage.bitsPerPixel / 8, 1)
        let bytesPerRow = cgImage.bytesPerRow
        let alphaInfo = cgImage.alphaInfo

        guard alphaInfo != .none,
              alphaInfo != .noneSkipFirst,
              alphaInfo != .noneSkipLast else {
            return nil
        }

        let alphaIndex: Int
        switch alphaInfo {
        case .premultipliedFirst, .first, .noneSkipFirst:
            alphaIndex = 0
        default:
            alphaIndex = min(bytesPerPixel - 1, 3)
        }

        var minX = width
        var minY = height
        var maxX = -1
        var maxY = -1

        for y in 0..<height {
            let row = bytes + (y * bytesPerRow)
            for x in 0..<width {
                let alpha = row[(x * bytesPerPixel) + alphaIndex]
                if alpha > alphaThreshold {
                    minX = min(minX, x)
                    minY = min(minY, y)
                    maxX = max(maxX, x)
                    maxY = max(maxY, y)
                }
            }
        }

        guard maxX >= minX, maxY >= minY else { return nil }

        let pixelPadding = Int(ceil(padding * scale))
        let cropMinX = max(minX - pixelPadding, 0)
        let cropMinY = max(minY - pixelPadding, 0)
        let cropMaxX = min(maxX + pixelPadding, width - 1)
        let cropMaxY = min(maxY + pixelPadding, height - 1)
        let cropRect = CGRect(
            x: cropMinX,
            y: cropMinY,
            width: cropMaxX - cropMinX + 1,
            height: cropMaxY - cropMinY + 1
        )

        guard let cropped = cgImage.cropping(to: cropRect) else { return nil }
        return VisibleAlphaCrop(
            image: UIImage(cgImage: cropped, scale: scale, orientation: .up),
            cropRectInPixels: cropRect,
            originalPixelSize: CGSize(width: width, height: height)
        )
    }
}
