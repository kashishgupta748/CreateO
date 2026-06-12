
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

    private let context: CIContext
    private let device: MTLDevice?
    private let commandQueue: MTLCommandQueue?
    private let sobelPipelineState: MTLComputePipelineState?

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

    private func runSobelShader(on image: CIImage, extent: CGRect) -> CIImage? {
        guard let device,
              let commandQueue,
              let sobelPipelineState,
              let inputTexture = makeTexture(device: device, width: Int(extent.width), height: Int(extent.height)),
              let outputTexture = makeTexture(device: device, width: Int(extent.width), height: Int(extent.height)) else {
            return nil
        }

        context.render(
            image,
            to: inputTexture,
            commandBuffer: nil,
            bounds: extent,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            return nil
        }

        var threshold: Float = 0.145
        var darkBoost: Float = 1.55

        encoder.setComputePipelineState(sobelPipelineState)
        encoder.setTexture(inputTexture, index: 0)
        encoder.setTexture(outputTexture, index: 1)
        encoder.setBytes(&threshold, length: MemoryLayout<Float>.stride, index: 0)
        encoder.setBytes(&darkBoost, length: MemoryLayout<Float>.stride, index: 1)

        let threadWidth = sobelPipelineState.threadExecutionWidth
        let threadHeight = max(1, sobelPipelineState.maxTotalThreadsPerThreadgroup / threadWidth)
        let threadsPerThreadgroup = MTLSize(width: threadWidth, height: threadHeight, depth: 1)
        let threadsPerGrid = MTLSize(width: inputTexture.width, height: inputTexture.height, depth: 1)

        encoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        encoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        return CIImage(
            mtlTexture: outputTexture,
            options: [CIImageOption.colorSpace: CGColorSpaceCreateDeviceRGB()]
        )?.cropped(to: extent)
    }

    private func makeTexture(device: MTLDevice, width: Int, height: Int) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        descriptor.storageMode = .private
        return device.makeTexture(descriptor: descriptor)
    }

    private static func makeSobelPipelineState(device: MTLDevice?) -> MTLComputePipelineState? {
        guard let device else { return nil }

        let source = """
        #include <metal_stdlib>
        using namespace metal;

        float luminance(float3 color) {
            return dot(color, float3(0.2126, 0.7152, 0.0722));
        }

        kernel void sobelOutline(
            texture2d<float, access::read> inputTexture [[texture(0)]],
            texture2d<float, access::write> outputTexture [[texture(1)]],
            constant float &threshold [[buffer(0)]],
            constant float &darkBoost [[buffer(1)]],
            uint2 gid [[thread_position_in_grid]]
        ) {
            if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
                return;
            }

            constexpr sampler s(address::clamp_to_edge, filter::nearest);
            float2 size = float2(inputTexture.get_width(), inputTexture.get_height());
            float2 uv = (float2(gid) + 0.5) / size;

            float tl = luminance(inputTexture.sample(s, uv + float2(-1.0, -1.0) / size).rgb);
            float tc = luminance(inputTexture.sample(s, uv + float2( 0.0, -1.0) / size).rgb);
            float tr = luminance(inputTexture.sample(s, uv + float2( 1.0, -1.0) / size).rgb);
            float ml = luminance(inputTexture.sample(s, uv + float2(-1.0,  0.0) / size).rgb);
            float mc = luminance(inputTexture.sample(s, uv).rgb);
            float mr = luminance(inputTexture.sample(s, uv + float2( 1.0,  0.0) / size).rgb);
            float bl = luminance(inputTexture.sample(s, uv + float2(-1.0,  1.0) / size).rgb);
            float bc = luminance(inputTexture.sample(s, uv + float2( 0.0,  1.0) / size).rgb);
            float br = luminance(inputTexture.sample(s, uv + float2( 1.0,  1.0) / size).rgb);

            float gx = -tl + tr - 2.0 * ml + 2.0 * mr - bl + br;
            float gy = -tl - 2.0 * tc - tr + bl + 2.0 * bc + br;
            float sobel = length(float2(gx, gy));

            float localMin = min(mc, min(min(tl, tc), min(tr, min(min(ml, mr), min(bl, min(bc, br))))));
            float localMax = max(mc, max(max(tl, tc), max(tr, max(max(ml, mr), max(bl, max(bc, br))))));
            float localContrast = localMax - localMin;

            float darkness = (1.0 - mc) * darkBoost;
            float edgeStrength = sobel * 0.85 + localContrast * 1.35 + darkness * 0.22;
            float ink = edgeStrength > threshold ? 0.0 : 1.0;

            outputTexture.write(float4(ink, ink, ink, 1.0), gid);
        }
        """

        do {
            let library = try device.makeLibrary(source: source, options: nil)
            guard let function = library.makeFunction(name: "sobelOutline") else {
                return nil
            }
            return try device.makeComputePipelineState(function: function)
        } catch {
            return nil
        }
    }

    private static func strokeContours(
        _ contours: [VNContour],
        in context: CGContext,
        minimumPointCount: Int,
        minimumArea: CGFloat
    ) {
        for contour in contours {
            let bounds = contour.normalizedPath.boundingBox
            let area = bounds.width * bounds.height

            if contour.pointCount >= minimumPointCount && area >= minimumArea {
                context.addPath(contour.normalizedPath)
                context.strokePath()
            }

            if !contour.childContours.isEmpty {
                strokeContours(
                    contour.childContours,
                    in: context,
                    minimumPointCount: minimumPointCount,
                    minimumArea: minimumArea
                )
            }
        }
    }
}

extension UIImage {
    func fixedOrientation() -> UIImage? {
        if imageOrientation == .up { return self }

        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let fixed = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return fixed
    }
}
