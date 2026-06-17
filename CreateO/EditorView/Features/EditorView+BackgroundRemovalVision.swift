import CoreImage
import ImageIO
import UIKit
import Vision

enum BackgroundRemovalError: LocalizedError {
    case unsupportedIOS
    case invalidImage
    case noSubjectFound
    case failedToRenderImage

    var errorDescription: String? {
        switch self {
        case .unsupportedIOS:
            return "This feature needs iOS 17 or later."
        case .invalidImage:
            return "Invalid image. Try another JPG or PNG image."
        case .noSubjectFound:
            return "No clear foreground subject detected."
        case .failedToRenderImage:
            return "Could not create final transparent image."
        }
    }
}

final class BackgroundRemover {
    static let shared = BackgroundRemover()

    private let context = CIContext()

    private init() {}

    func removeBackground(from image: UIImage) async throws -> UIImage {
        try await Task.detached(priority: .userInitiated) {
            guard #available(iOS 17.0, *) else {
                throw BackgroundRemovalError.unsupportedIOS
            }

            guard let cgImage = image.cgImage else {
                throw BackgroundRemovalError.invalidImage
            }

            let orientation = CGImagePropertyOrientation(image.imageOrientation)
            let request = VNGenerateForegroundInstanceMaskRequest()
            let handler = VNImageRequestHandler(
                cgImage: cgImage,
                orientation: orientation,
                options: [:]
            )

            try handler.perform([request])

            guard let result = request.results?.first,
                  !result.allInstances.isEmpty else {
                throw BackgroundRemovalError.noSubjectFound
            }

            let outputPixelBuffer = try result.generateMaskedImage(
                ofInstances: result.allInstances,
                from: handler,
                croppedToInstancesExtent: false
            )

            let outputCIImage = CIImage(cvPixelBuffer: outputPixelBuffer)
            guard let outputCGImage = self.context.createCGImage(
                outputCIImage,
                from: outputCIImage.extent
            ) else {
                throw BackgroundRemovalError.failedToRenderImage
            }

            return UIImage(
                cgImage: outputCGImage,
                scale: image.scale,
                orientation: .up
            )
        }
        .value
    }
}

extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up:
            self = .up
        case .upMirrored:
            self = .upMirrored
        case .down:
            self = .down
        case .downMirrored:
            self = .downMirrored
        case .left:
            self = .left
        case .leftMirrored:
            self = .leftMirrored
        case .right:
            self = .right
        case .rightMirrored:
            self = .rightMirrored
        @unknown default:
            self = .up
        }
    }
}
