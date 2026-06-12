import SwiftUI
import Foundation
import AVFoundation
import UIKit

extension StoryBoard {
    func timelineCenterX(
        forPlaybackElapsed elapsed: Double
    ) -> CGFloat {
        guard !storyPages.isEmpty else { return 0 }

        let clampedElapsed = min(max(elapsed, 0), totalPlaybackDuration)
        for index in storyPages.indices {
            let pageStart = pageStartTime(for: index)
            let holdEnd = pageStart + pageHoldDuration
            let thumbStartX = thumbnailProgressStartX(for: index)
            let thumbEndX = thumbnailProgressEndX(for: index)

            if clampedElapsed < holdEnd || index == storyPages.count - 1 {
                let progress = CGFloat(
                    min(
                        max((clampedElapsed - pageStart) / max(pageHoldDuration, 0.001), 0),
                        1
                    )
                )
                return thumbStartX + ((thumbEndX - thumbStartX) * progress)
            }

            let gapIndex = index + 1
            guard gapIndex < storyPages.count else { continue }

            let transition = transitionForGap(gapIndex)
            if transition == .none {
                continue
            }

            let transitionEnd = holdEnd + transitionDuration
            if clampedElapsed < transitionEnd {
                let nextThumbStartX = thumbnailProgressStartX(for: gapIndex)
                let progress = CGFloat(
                    min(
                        max((clampedElapsed - holdEnd) / max(transitionDuration, 0.001), 0),
                        1
                    )
                )
                return thumbEndX + ((nextThumbStartX - thumbEndX) * progress)
            }
        }

        return thumbnailProgressEndX(for: storyPages.count - 1)
    }

    func playbackElapsed(
        forTimelineCenterX centerX: CGFloat
    ) -> Double {
        guard !storyPages.isEmpty else { return 0 }

        for index in storyPages.indices {
            let thumbStartX = thumbnailProgressStartX(for: index)
            let thumbEndX = thumbnailProgressEndX(for: index)

            if centerX <= thumbEndX || index == storyPages.count - 1 {
                let progress = min(
                    max((centerX - thumbStartX) / max(thumbEndX - thumbStartX, 0.001), 0),
                    1
                )
                return min(
                    pageStartTime(for: index) + (Double(progress) * pageHoldDuration),
                    totalPlaybackDuration
                )
            }

            guard index < storyPages.count - 1 else { continue }

            let nextThumbStartX = thumbnailProgressStartX(for: index + 1)
            if centerX < nextThumbStartX {
                let gapIndex = index + 1
                let transition = transitionForGap(gapIndex)
                if transition == .none {
                    return min(pageStartTime(for: gapIndex), totalPlaybackDuration)
                }

                let progress = min(
                    max((centerX - thumbEndX) / max(nextThumbStartX - thumbEndX, 0.001), 0),
                    1
                )
                return min(
                    transitionStartTime(for: gapIndex) + (Double(progress) * transitionDuration),
                    totalPlaybackDuration
                )
            }
        }

        return totalPlaybackDuration
    }

    func applyPlaybackPreview(
        for elapsed: Double
    ) {
        guard !storyPages.isEmpty else { return }

        let clampedElapsed = min(max(elapsed, 0), totalPlaybackDuration)

        for index in storyPages.indices {
            let pageStart = pageStartTime(for: index)
            let holdEnd = pageStart + pageHoldDuration

            if clampedElapsed < holdEnd || index == storyPages.count - 1 {
                currentPageIndex = index
                transitioningPageIndex = nil
                transitionProgress = 0
                return
            }

            let gapIndex = index + 1
            guard gapIndex < storyPages.count else { continue }

            let transition = transitionForGap(gapIndex)
            if transition == .none {
                continue
            }

            let transitionEnd = holdEnd + transitionDuration
            if clampedElapsed < transitionEnd {
                currentPageIndex = index
                transitioningPageIndex = gapIndex
                transitionProgress = min(
                    max((clampedElapsed - holdEnd) / max(transitionDuration, 0.001), 0),
                    1
                )
                return
            }
        }

        currentPageIndex = storyPages.count - 1
        transitioningPageIndex = nil
        transitionProgress = 0
    }
}
