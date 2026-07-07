import CoreGraphics
import Foundation
import OnnxRuntimeBindings
import UIKit

struct SketchifyModelProcessor {
    private let modelName = "model"
    private let inputSize = CGSize(width: 256, height: 256)

    func generateImage(from image: UIImage) throws -> UIImage {
        guard let modelURL = Bundle.main.url(forResource: modelName, withExtension: "onnx") else {
            throw SketchifyModelError.missingModel
        }

        let env = try ORTEnv(loggingLevel: ORTLoggingLevel.warning)
        let options = try ORTSessionOptions()
        _ = try options.setGraphOptimizationLevel(ORTGraphOptimizationLevel.all)
        let session = try ORTSession(env: env, modelPath: modelURL.path, sessionOptions: options)

        guard let inputName = try session.inputNames().first,
              let outputName = try session.outputNames().first else {
            throw SketchifyModelError.invalidModel("The Sketchify model does not expose input and output tensors.")
        }

        let inputTensor = try makeInputTensor(from: image)
        let inputValue = try ORTValue(
            tensorData: inputTensor.data,
            elementType: ORTTensorElementDataType.float,
            shape: inputTensor.shape
        )

        let outputs = try session.run(
            withInputs: [inputName: inputValue],
            outputNames: [outputName],
            runOptions: nil
        )

        guard let outputValue = outputs[outputName] else {
            throw SketchifyModelError.invalidModel("The Sketchify model did not return an output tensor.")
        }

        return try makeOutputImage(from: outputValue, targetSize: image.size)
    }

    private func makeInputTensor(from image: UIImage) throws -> (data: NSMutableData, shape: [NSNumber]) {
        let width = Int(inputSize.width)
        let height = Int(inputSize.height)
        let rgbaBytes = try makeRGBABytes(from: image, width: width, height: height)
        let planeSize = width * height
        var floats = [Float](repeating: 0, count: 3 * planeSize)

        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = y * width + x
                let byteOffset = pixelIndex * 4
                floats[pixelIndex] = Float(rgbaBytes[byteOffset]) / 255.0
                floats[planeSize + pixelIndex] = Float(rgbaBytes[byteOffset + 1]) / 255.0
                floats[2 * planeSize + pixelIndex] = Float(rgbaBytes[byteOffset + 2]) / 255.0
            }
        }

        return (
            NSMutableData(bytes: floats, length: floats.count * MemoryLayout<Float>.size),
            [1, 3, NSNumber(value: height), NSNumber(value: width)]
        )
    }

    private func makeRGBABytes(from image: UIImage, width: Int, height: Int) throws -> [UInt8] {
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: &bytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            throw SketchifyModelError.invalidImage
        }

        context.interpolationQuality = .high
        UIGraphicsPushContext(context)
        UIColor.white.setFill()
        UIRectFill(CGRect(x: 0, y: 0, width: width, height: height))
        image.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        UIGraphicsPopContext()

        return bytes
    }

    private func makeOutputImage(from outputValue: ORTValue, targetSize: CGSize) throws -> UIImage {
        let outputInfo = try outputValue.tensorTypeAndShapeInfo()
        let shape = outputInfo.shape.map { $0.intValue }
        let tensorData = try outputValue.tensorData()
        let valueCount = tensorData.length / MemoryLayout<Float>.size

        guard valueCount > 0 else {
            throw SketchifyModelError.invalidModel("The Sketchify model returned an empty output tensor.")
        }

        let values = Array(UnsafeBufferPointer(
            start: tensorData.bytes.bindMemory(to: Float.self, capacity: valueCount),
            count: valueCount
        ))
        let imageTensor = try inferImageTensor(from: shape, valueCount: values.count)
        var pixels = [UInt8](repeating: 255, count: imageTensor.width * imageTensor.height * 4)

        for y in 0..<imageTensor.height {
            for x in 0..<imageTensor.width {
                let red: Float
                let green: Float
                let blue: Float

                if imageTensor.channels >= 3 {
                    red = value(atChannel: 0, x: x, y: y, in: values, tensor: imageTensor)
                    green = value(atChannel: 1, x: x, y: y, in: values, tensor: imageTensor)
                    blue = value(atChannel: 2, x: x, y: y, in: values, tensor: imageTensor)
                } else {
                    let gray = value(atChannel: 0, x: x, y: y, in: values, tensor: imageTensor)
                    red = gray
                    green = gray
                    blue = gray
                }

                let outputOffset = (y * imageTensor.width + x) * 4
                pixels[outputOffset] = clampedByte(red)
                pixels[outputOffset + 1] = clampedByte(green)
                pixels[outputOffset + 2] = clampedByte(blue)
                pixels[outputOffset + 3] = 255
            }
        }

        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let cgImage = CGImage(
                width: imageTensor.width,
                height: imageTensor.height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: imageTensor.width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo.byteOrder32Big.union(CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)),
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
              ) else {
            throw SketchifyModelError.invalidModel("The Sketchify output could not be converted to an image.")
        }

        return UIImage(cgImage: cgImage).flippedVerticallyForSketchify().resizedForSketchify(to: targetSize)
    }

    private func inferImageTensor(from shape: [Int], valueCount: Int) throws -> SketchifyImageTensor {
        let positiveShape = shape.filter { $0 > 0 }

        if positiveShape.count == 4 {
            if [1, 3].contains(positiveShape[1]) {
                return SketchifyImageTensor(channels: positiveShape[1], height: positiveShape[2], width: positiveShape[3], layout: .nchw)
            }

            if [1, 3].contains(positiveShape[3]) {
                return SketchifyImageTensor(channels: positiveShape[3], height: positiveShape[1], width: positiveShape[2], layout: .nhwc)
            }
        }

        if positiveShape.count == 3 {
            if [1, 3].contains(positiveShape[0]) {
                return SketchifyImageTensor(channels: positiveShape[0], height: positiveShape[1], width: positiveShape[2], layout: .chw)
            }

            if [1, 3].contains(positiveShape[2]) {
                return SketchifyImageTensor(channels: positiveShape[2], height: positiveShape[0], width: positiveShape[1], layout: .hwc)
            }
        }

        if positiveShape.count == 2 {
            return SketchifyImageTensor(channels: 1, height: positiveShape[0], width: positiveShape[1], layout: .hw)
        }

        let side = Int(Double(valueCount).squareRoot())
        guard side * side == valueCount else {
            throw SketchifyModelError.invalidModel("The Sketchify model returned an unsupported output shape: \(shape).")
        }

        return SketchifyImageTensor(channels: 1, height: side, width: side, layout: .hw)
    }

    private func value(atChannel channel: Int, x: Int, y: Int, in values: [Float], tensor: SketchifyImageTensor) -> Float {
        let index: Int

        switch tensor.layout {
        case .nchw, .chw:
            index = channel * tensor.width * tensor.height + y * tensor.width + x
        case .nhwc, .hwc:
            index = (y * tensor.width + x) * tensor.channels + channel
        case .hw:
            index = y * tensor.width + x
        }

        guard values.indices.contains(index) else { return 0 }
        return values[index]
    }

    private func clampedByte(_ value: Float) -> UInt8 {
        let normalized = value < 0 ? ((value + 1.0) / 2.0) : value
        return UInt8((min(max(normalized, 0), 1) * 255).rounded())
    }
}

private struct SketchifyImageTensor {
    let channels: Int
    let height: Int
    let width: Int
    let layout: SketchifyTensorLayout
}

private enum SketchifyTensorLayout {
    case nchw
    case nhwc
    case chw
    case hwc
    case hw
}

enum SketchifyModelError: LocalizedError {
    case missingModel
    case invalidImage
    case invalidModel(String)

    var errorDescription: String? {
        switch self {
        case .missingModel:
            return "No Sketchify model file was found in the app bundle. Add `model.onnx` to this target to run Sketchify."
        case .invalidImage:
            return "The selected image could not be prepared for Sketchify."
        case let .invalidModel(message):
            return message
        }
    }
}

struct CartoonisticProcessor {
    private let modelName = "cartoonizer"
    private let maxInputSide = 720

    func generateImage(from image: UIImage) throws -> UIImage {
        guard let modelURL = Bundle.main.url(forResource: modelName, withExtension: "onnx") else {
            throw CartoonisticError.missingModel
        }

        let env = try ORTEnv(loggingLevel: ORTLoggingLevel.warning)
        let options = try ORTSessionOptions()
        _ = try options.setGraphOptimizationLevel(ORTGraphOptimizationLevel.all)
        let session = try ORTSession(env: env, modelPath: modelURL.path, sessionOptions: options)

        guard let inputName = try session.inputNames().first,
              let outputName = try session.outputNames().first else {
            throw CartoonisticError.invalidModel("The Cartoonistic model does not expose input and output tensors.")
        }

        let inputTensor = try makeInputTensor(from: image)
        let inputValue = try ORTValue(
            tensorData: inputTensor.data,
            elementType: ORTTensorElementDataType.float,
            shape: inputTensor.shape
        )

        let outputs = try session.run(
            withInputs: [inputName: inputValue],
            outputNames: [outputName],
            runOptions: nil
        )

        guard let outputValue = outputs[outputName] else {
            throw CartoonisticError.invalidModel("The Cartoonistic model did not return an output tensor.")
        }

        return try makeOutputImage(from: outputValue, targetSize: inputTensor.size, scale: image.scale)
    }

    private func makeInputTensor(from image: UIImage) throws -> (data: NSMutableData, shape: [NSNumber], size: CGSize) {
        let inputSize = cartoonInputSize(for: image.size)
        let width = Int(inputSize.width)
        let height = Int(inputSize.height)
        let rgbaBytes = try makeRGBABytes(from: image, width: width, height: height)
        var floats = [Float](repeating: 0, count: width * height * 3)

        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = y * width + x
                let rgbaOffset = pixelIndex * 4
                let tensorOffset = pixelIndex * 3

                let red = Float(rgbaBytes[rgbaOffset])
                let green = Float(rgbaBytes[rgbaOffset + 1])
                let blue = Float(rgbaBytes[rgbaOffset + 2])

                floats[tensorOffset] = blue / 127.5 - 1.0
                floats[tensorOffset + 1] = green / 127.5 - 1.0
                floats[tensorOffset + 2] = red / 127.5 - 1.0
            }
        }

        return (
            NSMutableData(bytes: floats, length: floats.count * MemoryLayout<Float>.size),
            [1, NSNumber(value: height), NSNumber(value: width), 3],
            inputSize
        )
    }

    private func cartoonInputSize(for size: CGSize) -> CGSize {
        var width = max(Int(size.width.rounded()), 8)
        var height = max(Int(size.height.rounded()), 8)
        let shortestSide = min(width, height)

        if shortestSide > maxInputSide {
            if height > width {
                height = Int(Double(maxInputSide) * Double(height) / Double(width))
                width = maxInputSide
            } else {
                width = Int(Double(maxInputSide) * Double(width) / Double(height))
                height = maxInputSide
            }
        }

        width = max((width / 8) * 8, 8)
        height = max((height / 8) * 8, 8)

        return CGSize(width: width, height: height)
    }

    private func makeRGBABytes(from image: UIImage, width: Int, height: Int) throws -> [UInt8] {
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: &bytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            throw CartoonisticError.invalidImage
        }

        context.interpolationQuality = .high
        UIGraphicsPushContext(context)
        UIColor.white.setFill()
        UIRectFill(CGRect(x: 0, y: 0, width: width, height: height))
        image.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        UIGraphicsPopContext()

        return bytes
    }

    private func makeOutputImage(from outputValue: ORTValue, targetSize: CGSize, scale: CGFloat) throws -> UIImage {
        let outputInfo = try outputValue.tensorTypeAndShapeInfo()
        let shape = outputInfo.shape.map { $0.intValue }
        let tensorData = try outputValue.tensorData()
        let valueCount = tensorData.length / MemoryLayout<Float>.size

        guard valueCount > 0 else {
            throw CartoonisticError.invalidModel("The Cartoonistic model returned an empty output tensor.")
        }

        let values = Array(UnsafeBufferPointer(
            start: tensorData.bytes.bindMemory(to: Float.self, capacity: valueCount),
            count: valueCount
        ))
        let imageTensor = try inferImageTensor(from: shape, valueCount: values.count)
        var pixels = [UInt8](repeating: 255, count: imageTensor.width * imageTensor.height * 4)

        for y in 0..<imageTensor.height {
            for x in 0..<imageTensor.width {
                let blue = value(atChannel: 0, x: x, y: y, in: values, tensor: imageTensor)
                let green = value(atChannel: 1, x: x, y: y, in: values, tensor: imageTensor)
                let red = value(atChannel: 2, x: x, y: y, in: values, tensor: imageTensor)
                let pixelOffset = (y * imageTensor.width + x) * 4

                pixels[pixelOffset] = cartoonOutputByte(red)
                pixels[pixelOffset + 1] = cartoonOutputByte(green)
                pixels[pixelOffset + 2] = cartoonOutputByte(blue)
                pixels[pixelOffset + 3] = 255
            }
        }

        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let cgImage = CGImage(
                width: imageTensor.width,
                height: imageTensor.height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: imageTensor.width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo.byteOrder32Big.union(CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)),
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
              ) else {
            throw CartoonisticError.invalidModel("The Cartoonistic output could not be converted to an image.")
        }

        return UIImage(cgImage: cgImage, scale: scale, orientation: .up).flippedVerticallyForCartoonistic().resizedForCartoonistic(to: targetSize)
    }

    private func inferImageTensor(from shape: [Int], valueCount: Int) throws -> CartoonisticImageTensor {
        let positiveShape = shape.filter { $0 > 0 }

        if positiveShape.count == 4 {
            if positiveShape[3] == 3 {
                return CartoonisticImageTensor(channels: positiveShape[3], height: positiveShape[1], width: positiveShape[2], layout: .nhwc)
            }

            if positiveShape[1] == 3 {
                return CartoonisticImageTensor(channels: positiveShape[1], height: positiveShape[2], width: positiveShape[3], layout: .nchw)
            }
        }

        let pixelCount = valueCount / 3
        let side = Int(Double(pixelCount).squareRoot())
        guard side * side == pixelCount else {
            throw CartoonisticError.invalidModel("The Cartoonistic model returned an unsupported output shape: \(shape).")
        }

        return CartoonisticImageTensor(channels: 3, height: side, width: side, layout: .nhwc)
    }

    private func value(atChannel channel: Int, x: Int, y: Int, in values: [Float], tensor: CartoonisticImageTensor) -> Float {
        let index: Int

        switch tensor.layout {
        case .nhwc:
            index = (y * tensor.width + x) * tensor.channels + channel
        case .nchw:
            index = channel * tensor.width * tensor.height + y * tensor.width + x
        }

        guard values.indices.contains(index) else { return -1 }
        return values[index]
    }

    private func cartoonOutputByte(_ value: Float) -> UInt8 {
        let byteValue = (value + 1.0) * 127.5
        return UInt8(min(max(byteValue, 0), 255).rounded())
    }
}

private struct CartoonisticImageTensor {
    let channels: Int
    let height: Int
    let width: Int
    let layout: CartoonisticTensorLayout
}

private enum CartoonisticTensorLayout {
    case nhwc
    case nchw
}

enum CartoonisticError: LocalizedError {
    case missingModel
    case invalidImage
    case invalidModel(String)

    var errorDescription: String? {
        switch self {
        case .missingModel:
            return "No Cartoonistic model file was found in the app bundle. Add `cartoonizer.onnx` to this target to run Cartoonistic."
        case .invalidImage:
            return "The selected image could not be prepared for Cartoonistic."
        case let .invalidModel(message):
            return message
        }
    }
}

private extension UIImage {
    func resizedForSketchify(to size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    func flippedVerticallyForSketchify() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            context.cgContext.translateBy(x: 0, y: size.height)
            context.cgContext.scaleBy(x: 1, y: -1)
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    func resizedForCartoonistic(to size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    func flippedVerticallyForCartoonistic() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            context.cgContext.translateBy(x: 0, y: size.height)
            context.cgContext.scaleBy(x: 1, y: -1)
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
