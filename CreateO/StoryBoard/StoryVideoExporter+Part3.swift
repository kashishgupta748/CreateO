import SwiftUI
import Foundation
import AVFoundation
import UIKit

extension StoryVideoExporter {
    static func aspectFitRect(
        for imageSize: CGSize,
        in bounds: CGRect
    ) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return bounds }

        let imageRatio = imageSize.width / imageSize.height
        let boundsRatio = bounds.width / bounds.height

        if imageRatio > boundsRatio {
            let height = bounds.width / imageRatio
            return CGRect(
                x: bounds.minX,
                y: bounds.midY - (height / 2),
                width: bounds.width,
                height: height
            )
        } else {
            let width = bounds.height * imageRatio
            return CGRect(
                x: bounds.midX - (width / 2),
                y: bounds.minY,
                width: width,
                height: bounds.height
            )
        }
    }

    static func loadImage(
        for page: StoryPage
    ) throws -> UIImage {
        if let image = DesignImageLoader.image(for: page.design.designPath) {
            return image
        }
        if let image = DesignImageLoader.image(for: page.design.thumbnailPath) {
            return image
        }
        throw StoryVideoExportError.missingPageImage
    }

    static func exportDirectoryURL() throws -> URL {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw StoryVideoExportError.writerUnavailable
        }
        return documents.appendingPathComponent("StoryExports", isDirectory: true)
    }

    static func normalizedRenderSize(
        for design: Design
    ) -> CGSizeInt {
        let fallback = CGSizeInt(width: 1080, height: 1920)
        let sourceWidth = max(design.designWidth, 1)
        let sourceHeight = max(design.designHeight, 1)
        guard sourceWidth > 1, sourceHeight > 1 else { return fallback }

        let maxWidth = 1080
        let maxHeight = 1920
        let scale = min(
            Double(maxWidth) / Double(sourceWidth),
            Double(maxHeight) / Double(sourceHeight),
            max(Double(maxWidth) / Double(sourceWidth), Double(maxHeight) / Double(sourceHeight))
        )
        let scaledWidth = max(2, Int((Double(sourceWidth) * scale).rounded()))
        let scaledHeight = max(2, Int((Double(sourceHeight) * scale).rounded()))

        return CGSizeInt(
            width: evenDimension(scaledWidth),
            height: evenDimension(scaledHeight)
        )
    }

    static func evenDimension(
        _ value: Int
    ) -> Int {
        let clamped = max(value, 2)
        return clamped.isMultiple(of: 2) ? clamped : clamped - 1
    }

    static func sanitizedFilename(
        _ name: String
    ) -> String {
        let invalid = CharacterSet.alphanumerics.inverted
        let cleaned = name
            .components(separatedBy: invalid)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        return cleaned.isEmpty ? "story" : cleaned.lowercased()
    }

    static func totalDuration(
        pageCount: Int,
        transitions: [Int: StoryTransition]
    ) -> Double {
        let holdTotal = Double(pageCount) * StoryBoard.pageHoldDurationStatic
        let transitionTotal = Double(transitions.values.filter { $0 != .none }.count) * StoryBoard.transitionDurationStatic
        return holdTotal + transitionTotal
    }
}
