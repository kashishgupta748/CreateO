import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

extension ImageFilterProcessor {
    // MARK: - Watercolor

    static func applyWatercolorStyle(to cgImage: CGImage) -> CGImage? {
        let input = CIImage(cgImage: cgImage)
        let extent = input.extent

        // Smooth texture like wet paint spreading on paper
        let noise = CIFilter.noiseReduction()
        noise.inputImage = input
        noise.noiseLevel = 0.10
        noise.sharpness = 0.0
        guard let denoised = noise.outputImage?.cropped(to: extent) else { return nil }

        // Strong blur for wash effect
        let blur = CIFilter.gaussianBlur()
        blur.inputImage = denoised
        blur.radius = 4.0
        guard let washed = blur.outputImage?.cropped(to: extent) else { return nil }

        // Boost saturation and soften contrast — watercolors are vibrant but soft
        let colorAdj = CIFilter.colorControls()
        colorAdj.inputImage = washed
        colorAdj.saturation = 1.8
        colorAdj.brightness = 0.05
        colorAdj.contrast = 0.85
        guard let colorized = colorAdj.outputImage?.cropped(to: extent) else { return nil }

        // Color blocking for flat watercolor wash areas
        let posterize = CIFilter.colorPosterize()
        posterize.inputImage = colorized
        posterize.levels = 10
        guard let poster = posterize.outputImage?.cropped(to: extent) else { return nil }

        // Bloom to simulate light scattering through wet pigment
        let bloom = CIFilter.bloom()
        bloom.inputImage = poster
        bloom.intensity = 0.35
        bloom.radius = 10.0
        guard let bloomed = bloom.outputImage?.cropped(to: extent) else { return nil }

        // Extract soft edges from denoised original (cleaner lines)
        let edges = CIFilter.edges()
        edges.inputImage = denoised
        edges.intensity = 1.0
        guard let rawEdges = edges.outputImage?.cropped(to: extent) else { return nil }

        let edgeBlur = CIFilter.gaussianBlur()
        edgeBlur.inputImage = rawEdges
        edgeBlur.radius = 1.5
        guard let softEdges = edgeBlur.outputImage?.cropped(to: extent) else { return nil }

        // Dim and desaturate edge lines for a subtle painted outline
        let edgeCtrl = CIFilter.colorControls()
        edgeCtrl.inputImage = softEdges
        edgeCtrl.saturation = 0.2
        edgeCtrl.contrast = 0.8
        edgeCtrl.brightness = -0.2
        guard let darkEdges = edgeCtrl.outputImage?.cropped(to: extent) else { return nil }

        // Multiply edge definition onto washed color
        let multiply = CIFilter.multiplyCompositing()
        multiply.inputImage = darkEdges
        multiply.backgroundImage = bloomed
        guard let result = multiply.outputImage?.cropped(to: extent) else { return nil }

        return context.createCGImage(result, from: extent)
    }

    // MARK: - Pencil Color

    static func applyPencilColorStyle(to cgImage: CGImage) -> CGImage? {
        let input = CIImage(cgImage: cgImage)
        let extent = input.extent

        // Pencils have less-saturated, slightly muted colors
        let colorAdj = CIFilter.colorControls()
        colorAdj.inputImage = input
        colorAdj.saturation = 0.75
        colorAdj.brightness = 0.02
        colorAdj.contrast = 1.1
        guard let colorized = colorAdj.outputImage?.cropped(to: extent) else { return nil }

        // Posterize for limited pencil color palette
        let posterize = CIFilter.colorPosterize()
        posterize.inputImage = colorized
        posterize.levels = 8
        guard let poster = posterize.outputImage?.cropped(to: extent) else { return nil }

        // Edge detection for pencil stroke lines
        let edges = CIFilter.edges()
        edges.inputImage = poster
        edges.intensity = 3.0
        guard let rawEdges = edges.outputImage?.cropped(to: extent) else { return nil }

        let edgeBlur = CIFilter.gaussianBlur()
        edgeBlur.inputImage = rawEdges
        edgeBlur.radius = 0.5
        guard let softEdges = edgeBlur.outputImage?.cropped(to: extent) else { return nil }

        // Invert edges to get dark lines
        let invert = CIFilter.colorInvert()
        invert.inputImage = softEdges
        guard let invertedEdges = invert.outputImage?.cropped(to: extent) else { return nil }

        // Keep strokes slightly coloured (pencils aren't pure black)
        let edgeMono = CIFilter.colorControls()
        edgeMono.inputImage = invertedEdges
        edgeMono.saturation = 0.2
        edgeMono.contrast = 1.5
        edgeMono.brightness = 0.1
        guard let monoEdges = edgeMono.outputImage?.cropped(to: extent) else { return nil }

        // Overlay pencil strokes onto posterized color base
        let multiply = CIFilter.multiplyCompositing()
        multiply.inputImage = monoEdges
        multiply.backgroundImage = poster
        guard let lined = multiply.outputImage?.cropped(to: extent) else { return nil }

        // Sharpen to give the crisp feel of pencil marks on paper
        let sharpen = CIFilter.sharpenLuminance()
        sharpen.inputImage = lined
        sharpen.sharpness = 0.7
        guard let final = sharpen.outputImage?.cropped(to: extent) else { return nil }

        return context.createCGImage(final, from: extent)
    }

    // MARK: - Crayon

    static func applyCrayonStyle(to cgImage: CGImage) -> CGImage? {
        let input = CIImage(cgImage: cgImage)
        let extent = input.extent

        // Strong posterization — crayons fill with flat, limited colors
        let posterize = CIFilter.colorPosterize()
        posterize.inputImage = input
        posterize.levels = 5
        guard let poster = posterize.outputImage?.cropped(to: extent) else { return nil }

        // Very vibrant, high-contrast crayon colors
        let colorAdj = CIFilter.colorControls()
        colorAdj.inputImage = poster
        colorAdj.saturation = 2.0
        colorAdj.brightness = 0.04
        colorAdj.contrast = 1.3
        guard let vivid = colorAdj.outputImage?.cropped(to: extent) else { return nil }

        // Bloom for the waxy crayon shine
        let bloom = CIFilter.bloom()
        bloom.inputImage = vivid
        bloom.intensity = 0.15
        bloom.radius = 3.0
        guard let waxy = bloom.outputImage?.cropped(to: extent) else { return nil }

        // Thick crayon outlines via edge detection on the vivid layer
        let edges = CIFilter.edges()
        edges.inputImage = vivid
        edges.intensity = 4.0
        guard let rawEdges = edges.outputImage?.cropped(to: extent) else { return nil }

        let edgeBlur = CIFilter.gaussianBlur()
        edgeBlur.inputImage = rawEdges
        edgeBlur.radius = 1.5
        guard let softEdges = edgeBlur.outputImage?.cropped(to: extent) else { return nil }

        let invert = CIFilter.colorInvert()
        invert.inputImage = softEdges
        guard let invertedEdges = invert.outputImage?.cropped(to: extent) else { return nil }

        // Bold mono outlines
        let edgeCtrl = CIFilter.colorControls()
        edgeCtrl.inputImage = invertedEdges
        edgeCtrl.saturation = 0
        edgeCtrl.contrast = 2.0
        edgeCtrl.brightness = 0.1
        guard let darkEdges = edgeCtrl.outputImage?.cropped(to: extent) else { return nil }

        // Multiply thick lines onto waxy color
        let multiply = CIFilter.multiplyCompositing()
        multiply.inputImage = darkEdges
        multiply.backgroundImage = waxy
        guard let result = multiply.outputImage?.cropped(to: extent) else { return nil }

        return context.createCGImage(result, from: extent)
    }
}
