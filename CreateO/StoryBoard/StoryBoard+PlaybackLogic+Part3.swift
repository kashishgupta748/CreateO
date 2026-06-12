import SwiftUI
import Foundation
import AVFoundation
import UIKit

extension StoryBoard {
    func syncPlaybackClock() {
        let seconds = pageStartTime(for: max(currentPageIndex, 0))
        playbackElapsed = min(seconds, totalPlaybackDuration)
    }

    func previewAppliedTransition(
        for gapIndex: Int?
    ) {
        stopPlayback(resetProgress: true)
        guard storyPages.count > 1 else { return }

        let resolvedGapIndex = min(
            max(gapIndex ?? (currentPageIndex + 1), 1),
            storyPages.count - 1
        )
        let fromIndex = resolvedGapIndex - 1
        let nextIndex = resolvedGapIndex
        let transition = transitionForGap(resolvedGapIndex)

        guard nextIndex != fromIndex else { return }

        currentPageIndex = fromIndex
        playbackElapsed = min(transitionStartTime(for: resolvedGapIndex), totalPlaybackDuration)
        transitioningPageIndex = nextIndex
        transitionProgress = 0
        withAnimation(transition.animation(duration: transitionDuration)) {
            transitionProgress = 1
        }

        Task {
            try? await Task.sleep(nanoseconds: UInt64(transitionDuration * 1_000_000_000))
            await MainActor.run {
                transitioningPageIndex = nil
                transitionProgress = 0
            }
        }
    }

    func runPlaybackLoop() async {
        while !Task.isCancelled {
            let pageCount = await MainActor.run { storyPages.count }
            guard pageCount > 0 else {
                break
            }

            let currentIndex = await MainActor.run { currentPageIndex }
            let nextIndex = (currentIndex + 1) % pageCount
            let pageStart = await MainActor.run { pageStartTime(for: currentIndex) }

            await tickPlayback(
                from: pageStart,
                to: pageStart + pageHoldDuration,
                duration: pageHoldDuration
            )

            if Task.isCancelled {
                break
            }

            let transition = await MainActor.run {
                nextIndex == 0 ? .none : transitionForGap(nextIndex)
            }
            if transition == .none {
                await MainActor.run {
                    currentPageIndex = nextIndex
                    syncPlaybackClock()
                }
                continue
            }

            await MainActor.run {
                transitioningPageIndex = nextIndex
                transitionProgress = 0
                withAnimation(transition.animation(duration: transitionDuration)) {
                    transitionProgress = 1
                }
            }

            await tickPlayback(
                from: pageStart + pageHoldDuration,
                to: pageStart + pageHoldDuration + transitionDuration,
                duration: transitionDuration
            )

            if Task.isCancelled {
                break
            }

            await MainActor.run {
                currentPageIndex = nextIndex
                transitioningPageIndex = nil
                transitionProgress = 0
                syncPlaybackClock()
            }
        }

        await MainActor.run {
            playbackTask = nil
            isPlaying = false
            transitioningPageIndex = nil
            transitionProgress = 0
            syncPlaybackClock()
        }
    }

    func tickPlayback(
        from start: Double,
        to end: Double,
        duration: Double
    ) async {
        let totalSteps = max(Int(duration / 0.05), 1)

        for step in 0...totalSteps {
            if Task.isCancelled {
                return
            }

            let progress = Double(step) / Double(totalSteps)
            let value = start + ((end - start) * progress)
            await MainActor.run {
                playbackElapsed = min(value, totalPlaybackDuration)
            }

            if step < totalSteps {
                try? await Task.sleep(nanoseconds: UInt64((duration / Double(totalSteps)) * 1_000_000_000))
            }
        }
    }

    func timeText(
        _ seconds: Double
    ) -> String {
        let wholeSeconds = Int(seconds.rounded(.down))
        return String(format: "%d:%02d", wholeSeconds / 60, wholeSeconds % 60)
    }
}
