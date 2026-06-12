import SwiftUI
import Foundation
import AVFoundation
import UIKit

extension StoryVideoExporter {
    static func appendFrame(
        _ image: UIImage,
        at frameIndex: Int64,
        fps: Int32,
        renderSize: CGSizeInt,
        adaptor: AVAssetWriterInputPixelBufferAdaptor,
        input: AVAssetWriterInput
    ) throws {
        let presentationTime = CMTime(value: frameIndex, timescale: fps)

        while !input.isReadyForMoreMediaData {
            Thread.sleep(forTimeInterval: 0.01)
        }

        guard let pixelBufferPool = adaptor.pixelBufferPool else {
            throw StoryVideoExportError.writerUnavailable
        }

        var maybePixelBuffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferPool, &maybePixelBuffer)
        guard let pixelBuffer = maybePixelBuffer else {
            throw StoryVideoExportError.writerUnavailable
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: renderSize.width,
            height: renderSize.height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else {
            throw StoryVideoExportError.writerUnavailable
        }

        context.clear(CGRect(x: 0, y: 0, width: renderSize.width, height: renderSize.height))
        context.interpolationQuality = .high

        if let cgImage = image.cgImage {
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: renderSize.width, height: renderSize.height))
        } else {
            UIGraphicsPushContext(context)
            image.draw(in: CGRect(x: 0, y: 0, width: renderSize.width, height: renderSize.height))
            UIGraphicsPopContext()
        }

        guard adaptor.append(pixelBuffer, withPresentationTime: presentationTime) else {
            throw StoryVideoExportError.writerFailed
        }
    }

    static func makeFrameImage(
        current: UIImage,
        next: UIImage?,
        transition: StoryTransition,
        progress: CGFloat,
        renderSize: CGSizeInt
    ) -> UIImage {
        let size = CGSize(width: renderSize.width, height: renderSize.height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            context.cgContext.interpolationQuality = .high
            context.cgContext.setFillColor(UIColor.white.cgColor)
            context.cgContext.fill(rect)

            switch transition {
            case .none:
                drawFitted(current, in: rect)
            case .dissolve:
                drawFitted(current, in: rect, alpha: 1 - progress)
                if let next {
                    drawFitted(next, in: rect, alpha: progress)
                }
            case .circleWipe:
                drawFitted(current, in: rect)
                if let next {
                    let cg = context.cgContext
                    cg.saveGState()
                    let radius = max(size.width, size.height) * 0.9 * max(progress, 0.001)
                    let circleRect = CGRect(
                        x: rect.midX - radius,
                        y: rect.midY - radius,
                        width: radius * 2,
                        height: radius * 2
                    )
                    cg.addEllipse(in: circleRect)
                    cg.clip()
                    drawFitted(next, in: rect)
                    cg.restoreGState()
                }
            case .slide:
                drawFitted(current, in: rect, xOffset: -rect.width * 0.18 * progress)
                if let next {
                    drawFitted(next, in: rect, xOffset: rect.width * (1 - progress))
                }
            case .colorWipe, .lineWipe:
                drawFitted(current, in: rect)
                if let next {
                    let cg = context.cgContext
                    cg.saveGState()
                    cg.clip(to: CGRect(x: 0, y: 0, width: max(rect.width * progress, 1), height: rect.height))
                    drawFitted(next, in: rect)
                    cg.restoreGState()
                }
                let stripeRect = CGRect(
                    x: (rect.width * progress) - (transition == .lineWipe ? 2 : 10),
                    y: 0,
                    width: transition == .lineWipe ? 4 : 20,
                    height: rect.height
                )
                let stripeColor = transition == .lineWipe
                    ? UIColor.white.withAlphaComponent(0.9)
                    : UIColor(Color.accentColor).withAlphaComponent(0.24)
                context.cgContext.setFillColor(stripeColor.cgColor)
                context.cgContext.fill(stripeRect)
            case .matchAndMove:
                drawFitted(current, in: rect, alpha: 1 - (progress * 0.45), scale: 1 - (progress * 0.06))
                if let next {
                    drawFitted(next, in: rect, alpha: progress, scale: 0.92 + (progress * 0.08), yOffset: 22 * (1 - progress))
                }
            case .flow:
                drawFitted(current, in: rect, alpha: 1 - (progress * 0.5), xOffset: -28 * progress)
                if let next {
                    drawFitted(next, in: rect, alpha: progress, xOffset: 38 * (1 - progress))
                }
            case .stack:
                drawFitted(current, in: rect, scale: 1 - (progress * 0.04), yOffset: -12 * progress)
                if let next {
                    drawFitted(next, in: rect, alpha: progress, scale: 0.90 + (progress * 0.10), yOffset: rect.height * 0.24 * (1 - progress))
                }
            case .chop:
                drawFitted(current, in: rect)
                if let next {
                    let cg = context.cgContext
                    cg.saveGState()
                    cg.clip(to: CGRect(x: 0, y: 0, width: max(rect.width * progress, 1), height: rect.height))
                    drawFitted(next, in: rect, alpha: progress)
                    cg.restoreGState()
                }
            }
        }
    }

    static func drawFitted(
        _ image: UIImage,
        in rect: CGRect,
        alpha: CGFloat = 1,
        scale: CGFloat = 1,
        xOffset: CGFloat = 0,
        yOffset: CGFloat = 0
    ) {
        let fittedRect = aspectFitRect(for: image.size, in: rect)
        let scaledSize = CGSize(width: fittedRect.width * scale, height: fittedRect.height * scale)
        let drawRect = CGRect(
            x: fittedRect.midX - (scaledSize.width / 2) + xOffset,
            y: fittedRect.midY - (scaledSize.height / 2) + yOffset,
            width: scaledSize.width,
            height: scaledSize.height
        )
        image.draw(in: drawRect, blendMode: .normal, alpha: alpha)
    }
}
