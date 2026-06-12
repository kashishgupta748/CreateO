import SwiftUI
import Foundation
import AVFoundation
import UIKit

extension StoryBoard {
    func insert(
        designs: [Design],
        at index: Int
    ) {
        guard !designs.isEmpty else { return }

        pushUndo()

        let pages = designs.map { StoryPage(design: $0) }
        let safeIndex = max(0, min(index, storyPages.count))
        let insertedCount = pages.count
        let existingTransitions = gapTransitions

        storyPages.insert(contentsOf: pages, at: safeIndex)
        gapTransitions = remappedTransitionsAfterInsert(
            existingTransitions,
            insertIndex: safeIndex,
            insertedCount: insertedCount
        )
        currentPageIndex = safeIndex
        syncPlaybackClock()
    }

    func deleteCurrentPage() {
        guard storyPages.indices.contains(currentPageIndex) else { return }

        stopPlayback()
        pushUndo()
        let deleteIndex = currentPageIndex
        let existingTransitions = gapTransitions
        storyPages.remove(at: currentPageIndex)
        gapTransitions = remappedTransitionsAfterDelete(
            existingTransitions,
            deleteIndex: deleteIndex,
            remainingPageCount: storyPages.count
        )

        currentPageIndex = min(
            currentPageIndex,
            max(storyPages.count - 1, 0)
        )
        syncPlaybackClock()
    }

    func applyTransitionDraft(
        mode: StoryAnimationApplyMode
    ) {
        pushUndo()
        switch mode {
        case .allPages:
            for gapIndex in 1..<storyPages.count {
                setTransition(transitionDraft, forGap: gapIndex)
            }
        case .singleGap(let gapIndex):
            setTransition(transitionDraft, forGap: gapIndex)
        }
        showAnimateSheet = false
        if storyPages.count > 1 {
            previewAppliedTransition(for: mode.previewGapIndex(currentPageIndex: currentPageIndex, pageCount: storyPages.count))
        }
    }

    func applySelectedSingleGapTransition(
        _ transition: StoryTransition
    ) {
        guard case .singleGap(let gapIndex) = animationApplyMode else { return }

        pushUndo()
        setTransition(transition, forGap: gapIndex)
        showAnimateSheet = false

        if storyPages.count > 1 {
            previewAppliedTransition(for: gapIndex)
        }
    }

    func pushUndo() {
        undoStack.append(
            StoryBoardSnapshot(
                pages: storyPages,
                currentIndex: currentPageIndex,
                gapTransitions: gapTransitions
            )
        )
        redoStack.removeAll()
    }

    func undo() {
        guard let item = undoStack.popLast() else { return }

        redoStack.append(
            StoryBoardSnapshot(
                pages: storyPages,
                currentIndex: currentPageIndex,
                gapTransitions: gapTransitions
            )
        )

        restore(item)
    }

    func redo() {
        guard let item = redoStack.popLast() else { return }

        undoStack.append(
            StoryBoardSnapshot(
                pages: storyPages,
                currentIndex: currentPageIndex,
                gapTransitions: gapTransitions
            )
        )

        restore(item)
    }

    func restore(
        _ item: StoryBoardSnapshot
    ) {
        stopPlayback()
        storyPages = item.pages
        gapTransitions = item.gapTransitions

        currentPageIndex = min(
            max(item.currentIndex, 0),
            max(storyPages.count - 1, 0)
        )
        syncPlaybackClock()
    }

    func showPage(
        _ index: Int
    ) {
        guard storyPages.indices.contains(index) else { return }
        stopPlayback()
        currentPageIndex = index
        syncPlaybackClock()
    }

    func togglePlayback() {
        guard storyPages.count > 1 else { return }

        if isPlaying {
            stopPlayback(resetProgress: true)
        } else {
            startPlayback()
        }
    }

    func startPlayback() {
        stopPlayback(resetProgress: true)
        if currentPageIndex >= storyPages.count - 1 {
            currentPageIndex = 0
        }
        showAnimateSheet = false
        syncPlaybackClock()
        isPlaying = true
        playbackTask = Task {
            await runPlaybackLoop()
        }
    }

    func stopPlayback(
        resetProgress: Bool = true
    ) {
        playbackTask?.cancel()
        playbackTask = nil
        isPlaying = false
        if resetProgress {
            transitioningPageIndex = nil
            transitionProgress = 0
        }
        syncPlaybackClock()
    }
}
