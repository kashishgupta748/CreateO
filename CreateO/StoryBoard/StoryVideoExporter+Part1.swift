import SwiftUI
import Foundation
import AVFoundation
import UIKit

extension StoryVideoExporter {

    static func export(
        pages: [StoryPage],
        gapTransitions: [Int: StoryTransition],
        storyName: String
    ) throws -> SavedStoryVideo {
        guard let firstPage = pages.first else {
            throw StoryVideoExportError.missingPageImage
        }

        let exportDirectory = try exportDirectoryURL()
        if !FileManager.default.fileExists(atPath: exportDirectory.path) {
            try FileManager.default.createDirectory(
                at: exportDirectory,
                withIntermediateDirectories: true
            )
        }

        let safeName = sanitizedFilename(storyName)
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let videoURL = exportDirectory.appendingPathComponent("\(safeName)-\(stamp).mov")
        let projectURL = exportDirectory.appendingPathComponent("\(safeName)-\(stamp).json")

        let renderSize = normalizedRenderSize(for: firstPage.design)

        try renderVideo(
            pages: pages,
            gapTransitions: gapTransitions,
            to: videoURL,
            renderSize: renderSize
        )

        let project = SavedStoryProjectFile(
            storyName: storyName,
            pageDesignIDs: pages.map(\.design.id),
            gapTransitions: gapTransitions.mapValues(\.rawValue),
            duration: totalDuration(pageCount: pages.count, transitions: gapTransitions),
            createdAt: Date()
        )
        let projectData = try JSONEncoder().encode(project)
        try projectData.write(to: projectURL, options: .atomic)

        return SavedStoryVideo(
            storyName: storyName,
            videoPath: videoURL.path,
            thumbnailPath: firstPage.design.thumbnailPath.isEmpty ? firstPage.design.designPath : firstPage.design.thumbnailPath,
            projectPath: projectURL.path,
            renderSize: renderSize
        )
    }

    static func renderVideo(
        pages: [StoryPage],
        gapTransitions: [Int: StoryTransition],
        to outputURL: URL,
        renderSize: CGSizeInt
    ) throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: outputURL.path) {
            try fileManager.removeItem(at: outputURL)
        }

        guard let writer = try? AVAssetWriter(outputURL: outputURL, fileType: .mov) else {
            throw StoryVideoExportError.writerUnavailable
        }

        let input = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: renderSize.width,
                AVVideoHeightKey: renderSize.height,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: 12_000_000,
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
                ]
            ]
        )
        input.expectsMediaDataInRealTime = false

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
                kCVPixelBufferWidthKey as String: renderSize.width,
                kCVPixelBufferHeightKey as String: renderSize.height
            ]
        )

        guard writer.canAdd(input) else {
            throw StoryVideoExportError.writerUnavailable
        }

        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let fps: Int32 = 30
        let holdFrames = Int(StoryBoard.pageHoldDurationStatic * Double(fps))
        let transitionFrames = Int(StoryBoard.transitionDurationStatic * Double(fps))
        var frameIndex: Int64 = 0

        for index in pages.indices {
            let currentImage = try loadImage(for: pages[index])
            for _ in 0..<holdFrames {
                try autoreleasepool {
                    let holdFrame = makeFrameImage(
                        current: currentImage,
                        next: nil,
                        transition: .none,
                        progress: 0,
                        renderSize: renderSize
                    )
                    try appendFrame(
                        holdFrame,
                        at: frameIndex,
                        fps: fps,
                        renderSize: renderSize,
                        adaptor: adaptor,
                        input: input
                    )
                }
                frameIndex += 1
            }

            let nextIndex = index + 1
            guard nextIndex < pages.count else { continue }

            let transition = gapTransitions[nextIndex] ?? .none
            guard transition != .none else { continue }

            let nextImage = try loadImage(for: pages[nextIndex])
            let totalTransitionFrames = max(transitionFrames, 1)

            for step in 0..<totalTransitionFrames {
                try autoreleasepool {
                    let progress = CGFloat(step) / CGFloat(max(totalTransitionFrames - 1, 1))
                    let frame = makeFrameImage(
                        current: currentImage,
                        next: nextImage,
                        transition: transition,
                        progress: progress,
                        renderSize: renderSize
                    )
                    try appendFrame(
                        frame,
                        at: frameIndex,
                        fps: fps,
                        renderSize: renderSize,
                        adaptor: adaptor,
                        input: input
                    )
                }
                frameIndex += 1
            }
        }

        input.markAsFinished()

        let semaphore = DispatchSemaphore(value: 0)
        writer.finishWriting {
            semaphore.signal()
        }
        semaphore.wait()

        guard writer.status == .completed else {
            throw writer.error ?? StoryVideoExportError.writerFailed
        }
    }
}
