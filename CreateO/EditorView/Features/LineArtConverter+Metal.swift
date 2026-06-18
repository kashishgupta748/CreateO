import CoreImage
import Metal
import UIKit
import Vision

extension LineArtConverter {
    func runSobelShader(on image: CIImage, extent: CGRect) -> CIImage? {
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

    func makeTexture(device: MTLDevice, width: Int, height: Int) -> MTLTexture? {
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

    static func makeSobelPipelineState(device: MTLDevice?) -> MTLComputePipelineState? {
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

    static func strokeContours(
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
