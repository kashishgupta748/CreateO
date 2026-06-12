import SwiftUI
import Vision

extension ImageCropSheet {
    func defaultCropRect(for side: CGFloat) -> CGRect {
        suggestedCropRect(for: side) ?? CGRect(x: 40, y: 40, width: side - 80, height: side - 80)
    }

    func croppedImage() -> UIImage? {
        guard let workingImage = transformedImageForCropping(),
              let cgImage = workingImage.cgImage else { return nil }

        let displayRect = displayedImageRect(for: workingImage.size, in: CGSize(width: canvasSide, height: canvasSide))
        let visibleCrop = cropRect.intersection(displayRect).integral
        guard visibleCrop.width > 1, visibleCrop.height > 1 else { return nil }

        let normalizedCrop = CGRect(
            x: (visibleCrop.minX - displayRect.minX) / displayRect.width,
            y: (visibleCrop.minY - displayRect.minY) / displayRect.height,
            width: visibleCrop.width / displayRect.width,
            height: visibleCrop.height / displayRect.height
        )

        let pixelCrop = CGRect(
            x: normalizedCrop.minX * CGFloat(cgImage.width),
            y: normalizedCrop.minY * CGFloat(cgImage.height),
            width: normalizedCrop.width * CGFloat(cgImage.width),
            height: normalizedCrop.height * CGFloat(cgImage.height)
        ).integral

        let boundedCrop = clampedPixelCrop(pixelCrop, within: cgImage)

        guard boundedCrop.width > 1,
              boundedCrop.height > 1,
              let cropped = cgImage.cropping(to: boundedCrop) else { return nil }

        return UIImage(cgImage: cropped, scale: workingImage.scale, orientation: .up)
    }

    func reset() {
        initialCropRect = .zero
        rotationDegrees = 0
        isMirrored = false
        cropRect = defaultCropRect(for: canvasSide)
    }

    func configureIfNeeded(side: CGFloat) {
        let previousSide = canvasSide
        canvasSide = side

        if !didConfigure {
            cropRect = defaultCropRect(for: side)
            initialCropRect = .zero
            didConfigure = true
            return
        }

        if abs(previousSide - side) > 0.5 {
            cropRect = defaultCropRect(for: side)
            initialCropRect = .zero
        }
    }

    func clampedPixelCrop(_ rect: CGRect, within cgImage: CGImage) -> CGRect {
        let imageBounds = CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height)
        return rect.intersection(imageBounds).integral
    }

    func displayedImageRect(for imageSize: CGSize, in canvasSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return CGRect(origin: .zero, size: canvasSize)
        }

        let scale = min(canvasSize.width / imageSize.width, canvasSize.height / imageSize.height)
        let fittedSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)

        return CGRect(
            x: (canvasSize.width - fittedSize.width) / 2,
            y: (canvasSize.height - fittedSize.height) / 2,
            width: fittedSize.width,
            height: fittedSize.height
        )
    }

    func transformedImageForCropping() -> UIImage? {
        guard let normalized = image.normalizedForEditing() else { return nil }

        let quarterTurns = Int(rotationDegrees / 90).quotientAndRemainder(dividingBy: 4).remainder
        let normalizedTurns = (quarterTurns + 4) % 4
        let rotatesOddNumberOfTurns = normalizedTurns == 1 || normalizedTurns == 3
        let outputSize = rotatesOddNumberOfTurns
            ? CGSize(width: normalized.size.height, height: normalized.size.width)
            : normalized.size

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = normalized.scale

        return UIGraphicsImageRenderer(size: outputSize, format: format).image { _ in
            guard let context = UIGraphicsGetCurrentContext() else { return }
            context.translateBy(x: outputSize.width / 2, y: outputSize.height / 2)
            context.rotate(by: CGFloat(rotationDegrees) * (.pi / 180))
            context.scaleBy(x: isMirrored ? -1 : 1, y: 1)
            let drawRect = CGRect(origin: CGPoint(x: -normalized.size.width / 2, y: -normalized.size.height / 2), size: normalized.size)
            normalized.draw(in: drawRect)
        }
    }

    func suggestedCropRect(for side: CGFloat) -> CGRect? {
        guard let workingImage = transformedImageForCropping(),
              let normalizedRect = visionSuggestedNormalizedCropRect(for: workingImage) else {
            return nil
        }

        let displayRect = displayedImageRect(for: workingImage.size, in: CGSize(width: side, height: side))
        let padding: CGFloat = 8

        let suggested = CGRect(
            x: displayRect.minX + normalizedRect.minX * displayRect.width,
            y: displayRect.minY + normalizedRect.minY * displayRect.height,
            width: normalizedRect.width * displayRect.width,
            height: normalizedRect.height * displayRect.height
        ).insetBy(dx: -padding, dy: -padding)

        let bounded = suggested.intersection(CGRect(origin: .zero, size: CGSize(width: side, height: side)))
        guard bounded.width >= minSize, bounded.height >= minSize else { return nil }
        return bounded
    }

    func visionSuggestedNormalizedCropRect(for image: UIImage) -> CGRect? {
        guard let cgImage = image.cgImage else { return nil }

        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        if let foregroundRect = detectForegroundRect(using: requestHandler) {
            return foregroundRect
        }

        return detectSaliencyRect(using: requestHandler)
    }

    func detectForegroundRect(using requestHandler: VNImageRequestHandler) -> CGRect? {
        let request = VNGenerateForegroundInstanceMaskRequest()

        do {
            try requestHandler.perform([request])
            guard let observation = request.results?.first else { return nil }
            return normalizedCropRect(from: observation.allInstances, in: observation, requestHandler: requestHandler)
        } catch {
            return nil
        }
    }

    func normalizedCropRect(
        from instances: IndexSet,
        in observation: VNInstanceMaskObservation,
        requestHandler: VNImageRequestHandler
    ) -> CGRect? {
        guard let maskBuffer = try? observation.generateScaledMaskForImage(
            forInstances: instances,
            from: requestHandler
        ) else {
            return nil
        }

        CVPixelBufferLockBaseAddress(maskBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(maskBuffer, .readOnly) }

        let width = CVPixelBufferGetWidth(maskBuffer)
        let height = CVPixelBufferGetHeight(maskBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(maskBuffer)
        guard let baseAddress = CVPixelBufferGetBaseAddress(maskBuffer)?
            .assumingMemoryBound(to: UInt8.self) else {
            return nil
        }

        var minX = width
        var minY = height
        var maxX = -1
        var maxY = -1

        for y in 0..<height {
            let row = baseAddress.advanced(by: y * bytesPerRow)
            for x in 0..<width where row[x] > 0 {
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }

        guard maxX >= minX, maxY >= minY else { return nil }

        let rect = CGRect(
            x: CGFloat(minX) / CGFloat(width),
            y: CGFloat(minY) / CGFloat(height),
            width: CGFloat(maxX - minX + 1) / CGFloat(width),
            height: CGFloat(maxY - minY + 1) / CGFloat(height)
        )

        return expandedNormalizedRect(rect)
    }

    func detectSaliencyRect(using requestHandler: VNImageRequestHandler) -> CGRect? {
        let request = VNGenerateAttentionBasedSaliencyImageRequest()

        do {
            try requestHandler.perform([request])
            guard let observation = request.results?.first,
                  let salientObject = observation.salientObjects?.max(by: { $0.confidence < $1.confidence }) else {
                return nil
            }

            let converted = CGRect(
                x: salientObject.boundingBox.minX,
                y: 1 - salientObject.boundingBox.maxY,
                width: salientObject.boundingBox.width,
                height: salientObject.boundingBox.height
            )

            return expandedNormalizedRect(converted)
        } catch {
            return nil
        }
    }

    func expandedNormalizedRect(_ rect: CGRect) -> CGRect {
        let inset: CGFloat = -0.08
        let expanded = rect.insetBy(dx: inset, dy: inset)
        return expanded.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
    }
}

enum CropHandle {
    case topLeft, topRight, bottomLeft, bottomRight
}

extension UIImage {
    func normalizedForEditing() -> UIImage? {
        guard imageOrientation == .up else {
            let renderer = UIGraphicsImageRenderer(size: size)
            return renderer.image { _ in
                draw(in: CGRect(origin: .zero, size: size))
            }
        }
        return self
    }

    func downscaledForCanvas(maxDimension: CGFloat = 3072) -> UIImage? {
        guard let normalized = normalizedForEditing() else { return nil }
        guard normalized.size.width > 0, normalized.size.height > 0 else { return nil }

        let longestSide = max(normalized.size.width, normalized.size.height)
        guard longestSide > maxDimension else { return normalized }

        let scaleRatio = maxDimension / longestSide
        let targetSize = CGSize(
            width: floor(normalized.size.width * scaleRatio),
            height: floor(normalized.size.height * scaleRatio)
        )

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false

        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            normalized.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    func downscaledForProcessing(maxDimension: CGFloat = 2048) -> UIImage? {
        guard size.width > 0, size.height > 0 else { return nil }

        let longestSide = max(size.width, size.height)
        guard longestSide > maxDimension else { return self }

        let scaleRatio = maxDimension / longestSide
        let targetSize = CGSize(
            width: floor(size.width * scaleRatio),
            height: floor(size.height * scaleRatio)
        )

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false

        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
