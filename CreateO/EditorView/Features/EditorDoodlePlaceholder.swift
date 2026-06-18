
import CoreImage
import Metal
import UIKit
import Vision


final class LineArtConverter {

    static let shared = LineArtConverter()

    private enum SketchTuning {
        static let contourMaxDimension: CGFloat = 1400
        static let contourMinimumPointCount = 10
        static let contourMinimumArea: CGFloat = 0.00005
        static let lineOverlayThreshold: CGFloat = 0.02
        static let lineOverlayContrast: CGFloat = 80
        static let lineOverlayNR: CGFloat = 0.06
        static let lineOverlaySharpness: CGFloat = 1.6
    }

    let context: CIContext
    let device: MTLDevice?
    let commandQueue: MTLCommandQueue?
    let sobelPipelineState: MTLComputePipelineState?

    private init() {
        let metalDevice = MTLCreateSystemDefaultDevice()
        device = metalDevice

        if let metalDevice {
            context = CIContext(
                mtlDevice: metalDevice,
                options: [
                    .cacheIntermediates: false,
                    .workingColorSpace: NSNull(),
                    .outputColorSpace: NSNull()
                ]
            )
        } else {
            context = CIContext(
                options: [
                    .cacheIntermediates: false,
                    .workingColorSpace: NSNull(),
                    .outputColorSpace: NSNull()
                ]
            )
        }

        commandQueue = metalDevice?.makeCommandQueue()
        sobelPipelineState = Self.makeSobelPipelineState(device: metalDevice)
    }

    func convert(image: UIImage, completion: @escaping (UIImage?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let result = self.process(image: image)
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    func convertSynchronously(image: UIImage) -> UIImage? {
        process(image: image)
    }

    private func process(image: UIImage) -> UIImage? {
        guard let fixed = image.fixedOrientation(),
              let cgImage = fixed.cgImage else {
            return nil
        }

        let extent = CGRect(origin: .zero, size: CGSize(width: cgImage.width, height: cgImage.height))
        let prepared = prepareImage(CIImage(cgImage: cgImage), extent: extent)

        let pixelEdges = makePixelEdges(prepared, extent: extent)
        let contourOverlay = makeContourOverlay(from: prepared, extent: extent)

        let combined: CIImage
        if let contourOverlay {
            combined = pixelEdges
                .applyingFilter(
                    "CIMinimumCompositing",
                    parameters: [kCIInputBackgroundImageKey: contourOverlay]
                )
                .cropped(to: extent)
        } else {
            combined = pixelEdges
        }

        let finalImage = cleanupLineArt(combined, extent: extent)

        guard let outputCGImage = context.createCGImage(finalImage, from: extent) else {
            return nil
        }

        return UIImage(cgImage: outputCGImage, scale: fixed.scale, orientation: .up)
    }

    private func prepareImage(_ image: CIImage, extent: CGRect) -> CIImage {
        image
            .applyingFilter(
                "CIColorControls",
                parameters: [
                    kCIInputSaturationKey: 0.0,
                    kCIInputContrastKey: 1.85,
                    kCIInputBrightnessKey: 0.01
                ]
            )
            .applyingFilter(
                "CINoiseReduction",
                parameters: [
                    "inputNoiseLevel": 0.02,
                    "inputSharpness": 0.55
                ]
            )
            .applyingFilter(
                "CIUnsharpMask",
                parameters: [
                    kCIInputRadiusKey: 1.0,
                    kCIInputIntensityKey: 1.35
                ]
            )
            .cropped(to: extent)
    }

    private func makePixelEdges(_ image: CIImage, extent: CGRect) -> CIImage {
        let sobelEdges = runSobelShader(on: image, extent: extent)
            ?? image
            .applyingFilter("CIEdges", parameters: [kCIInputIntensityKey: 5.4])
            .applyingFilter("CIColorInvert", parameters: [:])
            .cropped(to: extent)

        let lineOverlay = image
            .applyingFilter(
                "CILineOverlay",
                parameters: [
                    "inputNRNoiseLevel": SketchTuning.lineOverlayNR,
                    "inputNRSharpness": SketchTuning.lineOverlaySharpness,
                    "inputEdgeIntensity": 1.9,
                    "inputThreshold": SketchTuning.lineOverlayThreshold,
                    "inputContrast": SketchTuning.lineOverlayContrast
                ]
            )
            .cropped(to: extent)

        return sobelEdges
            .applyingFilter(
                "CIMinimumCompositing",
                parameters: [kCIInputBackgroundImageKey: lineOverlay]
            )
            .cropped(to: extent)
    }

    private func makeContourOverlay(from image: CIImage, extent: CGRect) -> CIImage? {
        let contourImage = imageForContourDetection(from: image, extent: extent)

        guard let preparedCGImage = context.createCGImage(contourImage, from: contourImage.extent) else {
            return nil
        }

        let request = VNDetectContoursRequest()
        request.contrastAdjustment = 1.25
        request.detectsDarkOnLight = false
        request.maximumImageDimension = Int(SketchTuning.contourMaxDimension)

        let handler = VNImageRequestHandler(cgImage: preparedCGImage, options: [:])

        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let observation = request.results?.first else { return nil }

        let size = extent.size
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { rendererContext in
            let cg = rendererContext.cgContext
            cg.setFillColor(UIColor.white.cgColor)
            cg.fill(CGRect(origin: .zero, size: size))

            cg.translateBy(x: 0, y: size.height)
            cg.scaleBy(x: size.width, y: -size.height)

            cg.setStrokeColor(UIColor.black.cgColor)
            cg.setLineJoin(.round)
            cg.setLineCap(.round)
            cg.setLineWidth(contourLineWidth(for: size))

            Self.strokeContours(
                observation.topLevelContours,
                in: cg,
                minimumPointCount: SketchTuning.contourMinimumPointCount,
                minimumArea: SketchTuning.contourMinimumArea
            )
        }

        return CIImage(image: image)?.cropped(to: CGRect(origin: .zero, size: size))
    }

    private func cleanupLineArt(_ image: CIImage, extent: CGRect) -> CIImage {
        image
            .applyingFilter(
                "CIMorphologyMinimum",
                parameters: ["inputRadius": 0.5]
            )
            .applyingFilter(
                "CIColorControls",
                parameters: [
                    kCIInputSaturationKey: 0.0,
                    kCIInputContrastKey: 5.0,
                    kCIInputBrightnessKey: 0.01
                ]
            )
            .applyingFilter(
                "CIColorPosterize",
                parameters: ["inputLevels": 2.4]
            )
            .cropped(to: extent)
    }

    private func imageForContourDetection(from image: CIImage, extent: CGRect) -> CIImage {
        let maxDimension = max(extent.width, extent.height)
        guard maxDimension > SketchTuning.contourMaxDimension else { return image }

        let scale = SketchTuning.contourMaxDimension / maxDimension
        return image
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            .cropped(to: CGRect(
                x: 0,
                y: 0,
                width: extent.width * scale,
                height: extent.height * scale
            ))
    }

    private func contourLineWidth(for size: CGSize) -> CGFloat {
        let shortest = min(size.width, size.height)
        let normalized = max(shortest / 900, 1)
        return 1.15 / normalized
    }
}
