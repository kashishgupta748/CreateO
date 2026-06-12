import SwiftUI
import Foundation
import AVFoundation
import UIKit

struct SavedStoryVideo {
    let storyName: String
    let videoPath: String
    let thumbnailPath: String
    let projectPath: String
    let renderSize: CGSizeInt
}

struct CGSizeInt {
    let width: Int
    let height: Int
}

struct SavedStoryProjectFile: Codable {
    let storyName: String
    let pageDesignIDs: [UUID]
    let gapTransitions: [Int: String]
    let duration: Double
    let createdAt: Date
}

enum StoryVideoExportError: LocalizedError {
    case missingPageImage
    case writerUnavailable
    case writerFailed

    var errorDescription: String? {
        switch self {
        case .missingPageImage:
            return "One of the story designs couldn’t be loaded for export."
        case .writerUnavailable:
            return "The video writer couldn’t be prepared."
        case .writerFailed:
            return "The story video couldn’t be written."
        }
    }
}
