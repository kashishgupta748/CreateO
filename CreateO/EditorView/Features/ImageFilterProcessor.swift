//
//  ImageFilterProcessor.swift
//  creato
//
//  Created by GU on 24/04/26.
//

import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

actor ImageFilterProcessor {

    private static let context = CIContext(options: [.useSoftwareRenderer: false])

    // MARK: - Public (actor-isolated, async)

    func apply(_ filter: Filter, to image: CGImage) -> CGImage {
        Self.run(filter, on: image)
    }

    // MARK: - Public (nonisolated — for synchronous export path)

    nonisolated static func applySynchronously(_ filter: Filter, to image: CGImage) -> CGImage {
        run(filter, on: image)
    }

    // MARK: - Dispatcher

    private static func run(_ filter: Filter, on image: CGImage) -> CGImage {
        switch filter {
        case .original:
            return image
        case .doodle:
            return applyDoodleStyle(to: image) ?? image
        case .smooth:
            return applyGhibliStyle(to: image) ?? image
        case .animeStyle:
            let preSmoothed = applyPreSmooth(to: image) ?? image
            return applyGhibliStyle(to: preSmoothed) ?? preSmoothed
        case .sketch:
            return applySketchStyle(to: image) ?? image
        case .watercolor:
            return applyWatercolorStyle(to: image) ?? image
        case .pencilcolor:
            return applyPencilColorStyle(to: image) ?? image
        case .crayon:
            return applyCrayonStyle(to: image) ?? image
        }
    }

    // MARK: - Doodle

    private static func applyDoodleStyle(to cgImage: CGImage) -> CGImage? {
        let input = CIImage(cgImage: cgImage)
        let extent = input.extent

        let mono = CIFilter.photoEffectMono()
        mono.inputImage = input
        guard let grayscale = mono.outputImage?.cropped(to: extent) else { return nil }

        let contrastBoost = CIFilter.colorControls()
        contrastBoost.inputImage = grayscale
        contrastBoost.saturation = 0
        contrastBoost.contrast = 2.1
        contrastBoost.brightness = 0.02
        guard let contrasted = contrastBoost.outputImage?.cropped(to: extent) else { return nil }

        let sharpen = CIFilter.unsharpMask()
        sharpen.inputImage = contrasted
        sharpen.radius = 1.2
        sharpen.intensity = 1.5
        guard let sharpened = sharpen.outputImage?.cropped(to: extent) else { return nil }

        let edges = CIFilter.edges()
        edges.inputImage = sharpened
        edges.intensity = 5.2
        guard let rawEdges = edges.outputImage?.cropped(to: extent) else { return nil }

        let blur = CIFilter.gaussianBlur()
        blur.inputImage = rawEdges
        blur.radius = 0.55
        guard let softenedEdges = blur.outputImage?.cropped(to: extent) else { return nil }

        let invert = CIFilter.colorInvert()
        invert.inputImage = softenedEdges
        guard let inverted = invert.outputImage?.cropped(to: extent) else { return nil }

        let cleanup = CIFilter.colorControls()
        cleanup.inputImage = inverted
        cleanup.saturation = 0
        cleanup.contrast = 4.1
        cleanup.brightness = 0.04
        guard let highContrast = cleanup.outputImage?.cropped(to: extent) else { return nil }

        let posterize = CIFilter.colorPosterize()
        posterize.inputImage = highContrast
        posterize.levels = 3
        guard let posterized = posterize.outputImage?.cropped(to: extent) else { return nil }

        let clamp = CIFilter.colorClamp()
        clamp.inputImage = posterized
        clamp.minComponents = CIVector(x: 0, y: 0, z: 0, w: 1)
        clamp.maxComponents = CIVector(x: 1, y: 1, z: 1, w: 1)
        guard let finalCI = clamp.outputImage?.cropped(to: extent) else { return nil }

        return context.createCGImage(finalCI, from: extent)
    }

    // MARK: - Pre-smooth (light gaussian + noise reduction used by animeStyle)

    private static func applyPreSmooth(to cgImage: CGImage) -> CGImage? {
        let input = CIImage(cgImage: cgImage)
        let extent = input.extent

        let blur = CIFilter.gaussianBlur()
        blur.inputImage = input
        blur.radius = 1.4
        guard let blurred = blur.outputImage?.cropped(to: extent) else { return nil }

        let noise = CIFilter.noiseReduction()
        noise.inputImage = blurred
        noise.noiseLevel = 0.05
        noise.sharpness = 0.4
        guard let smoothed = noise.outputImage?.cropped(to: extent) else { return nil }

        return context.createCGImage(smoothed, from: extent)
    }

    // MARK: - Ghibli (Smooth filter + AnimeStyle pre-pass)

    /// Full Studio Ghibli-like artistic pipeline from GhibliContentView.
    private static func applyGhibliStyle(to cgImage: CGImage) -> CGImage? {
        let input = CIImage(cgImage: cgImage)
        let extent = input.extent

        let median = CIFilter.median()
        median.inputImage = input
        guard let medianOut = median.outputImage?.cropped(to: extent) else { return nil }

        let blur2 = CIFilter.gaussianBlur()
        blur2.inputImage = medianOut
        blur2.radius = 1.0
        guard let blurred2 = blur2.outputImage?.cropped(to: extent) else { return nil }

        let noise2 = CIFilter.noiseReduction()
        noise2.inputImage = blurred2
        noise2.noiseLevel = 0.05
        noise2.sharpness = 0.2
        guard let softBase = noise2.outputImage?.cropped(to: extent) else { return nil }

        let colorCtrl = CIFilter.colorControls()
        colorCtrl.inputImage = softBase
        colorCtrl.saturation = 1.35
        colorCtrl.brightness = 0.04
        colorCtrl.contrast = 1.12
        guard let richColor = colorCtrl.outputImage?.cropped(to: extent) else { return nil }

        let posterize = CIFilter.colorPosterize()
        posterize.inputImage = richColor
        posterize.levels = 22
        guard let posterized = posterize.outputImage?.cropped(to: extent) else { return nil }

        let bloom = CIFilter.bloom()
        bloom.inputImage = posterized
        bloom.intensity = 0.28
        bloom.radius = 5.0
        guard let glowy = bloom.outputImage?.cropped(to: extent) else { return nil }

        let edges = CIFilter.edges()
        edges.inputImage = glowy
        edges.intensity = 2.2
        guard let rawEdges = edges.outputImage?.cropped(to: extent) else { return nil }

        let edgeBlur = CIFilter.gaussianBlur()
        edgeBlur.inputImage = rawEdges
        edgeBlur.radius = 0.8
        guard let blurredEdges = edgeBlur.outputImage?.cropped(to: extent) else { return nil }

        let invert = CIFilter.colorInvert()
        invert.inputImage = blurredEdges
        guard let invertedEdges = invert.outputImage?.cropped(to: extent) else { return nil }

        let lineCtrl = CIFilter.colorControls()
        lineCtrl.inputImage = invertedEdges
        lineCtrl.saturation = 0
        lineCtrl.contrast = 1.8
        lineCtrl.brightness = -0.02
        guard let monoEdges = lineCtrl.outputImage?.cropped(to: extent) else { return nil }

        let multiply = CIFilter.multiplyCompositing()
        multiply.inputImage = monoEdges
        multiply.backgroundImage = glowy
        guard let lined = multiply.outputImage?.cropped(to: extent) else { return nil }

        let temp = CIFilter.temperatureAndTint()
        temp.inputImage = lined
        temp.neutral = CIVector(x: 6500, y: 0)
        temp.targetNeutral = CIVector(x: 5800, y: 8)
        guard let finalCI = temp.outputImage?.cropped(to: extent) else { return nil }

        return context.createCGImage(finalCI, from: extent)
    }

    // MARK: - Sketch

    private static func applySketchStyle(to cgImage: CGImage) -> CGImage? {
        let input = CIImage(cgImage: cgImage)
        let extent = input.extent

        let mono = CIFilter.photoEffectMono()
        mono.inputImage = input
        guard let gray = mono.outputImage?.cropped(to: extent) else { return nil }

        let edges = CIFilter.edges()
        edges.inputImage = gray
        edges.intensity = 6.0
        guard let rawEdges = edges.outputImage?.cropped(to: extent) else { return nil }

        let invert = CIFilter.colorInvert()
        invert.inputImage = rawEdges
        guard let inverted = invert.outputImage?.cropped(to: extent) else { return nil }

        let blur = CIFilter.gaussianBlur()
        blur.inputImage = inverted
        blur.radius = 0.6
        guard let softened = blur.outputImage?.cropped(to: extent) else { return nil }

        let contrast = CIFilter.colorControls()
        contrast.inputImage = softened
        contrast.saturation = 0
        contrast.contrast = 2.4
        contrast.brightness = 0.02
        guard let lineArt = contrast.outputImage?.cropped(to: extent) else { return nil }

        let posterize = CIFilter.colorPosterize()
        posterize.inputImage = lineArt
        posterize.levels = 6
        guard let sketchBase = posterize.outputImage?.cropped(to: extent) else { return nil }

        let finalMono = CIFilter.colorControls()
        finalMono.inputImage = sketchBase
        finalMono.saturation = 0
        finalMono.contrast = 1.9
        finalMono.brightness = 0.04
        guard let finalCI = finalMono.outputImage?.cropped(to: extent) else { return nil }

        return context.createCGImage(finalCI, from: extent)
    }

    // MARK: - Watercolor

    private static func applyWatercolorStyle(to cgImage: CGImage) -> CGImage? {
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

    private static func applyPencilColorStyle(to cgImage: CGImage) -> CGImage? {
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

    private static func applyCrayonStyle(to cgImage: CGImage) -> CGImage? {
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
