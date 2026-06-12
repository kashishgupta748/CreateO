import SwiftUI
import Foundation
import AVFoundation
import UIKit

extension StoryBoard {


    var durationText: String {
        timeText(totalPlaybackDuration)
    }

    var playbackTimeText: String {
        timeText(playbackElapsed)
    }

    var totalPlaybackDuration: Double {
        guard !storyPages.isEmpty else { return 0 }
        let holdTotal = Double(storyPages.count) * pageHoldDuration
        let transitionTotal = Double(appliedTransitionCount) * transitionDuration
        return holdTotal + transitionTotal
    }

    var playbackFraction: CGFloat {
        guard totalPlaybackDuration > 0 else { return 0 }
        return min(max(CGFloat(playbackElapsed / totalPlaybackDuration), 0), 1)
    }

    var pageHoldDuration: Double {
        Self.pageHoldDurationStatic
    }

    var transitionDuration: Double {
        Self.transitionDurationStatic
    }

    var appliedTransitionCount: Int {
        gapTransitions.keys.filter { transitionForGap($0) != .none }.count
    }

    func pageStartTime(
        for pageIndex: Int
    ) -> Double {
        guard pageIndex > 0 else { return 0 }

        var elapsed: Double = 0
        for index in 0..<pageIndex {
            elapsed += pageHoldDuration
            if hasAppliedTransition(afterPage: index) {
                elapsed += transitionDuration
            }
        }
        return elapsed
    }

    func transitionStartTime(
        for gapIndex: Int
    ) -> Double {
        pageStartTime(for: gapIndex - 1) + pageHoldDuration
    }

    func hasAppliedTransition(
        afterPage index: Int
    ) -> Bool {
        let gapIndex = index + 1
        guard gapIndex > 0, gapIndex < storyPages.count else { return false }
        return transitionForGap(gapIndex) != .none
    }

    func transitionForGap(
        _ gapIndex: Int
    ) -> StoryTransition {
        guard gapIndex > 0, gapIndex < storyPages.count else { return .none }
        return gapTransitions[gapIndex] ?? .none
    }

    func setTransition(
        _ transition: StoryTransition,
        forGap gapIndex: Int
    ) {
        guard gapIndex > 0, gapIndex < storyPages.count else { return }

        if transition == .none {
            gapTransitions.removeValue(forKey: gapIndex)
        } else {
            gapTransitions[gapIndex] = transition
        }
    }

    func draftTransition(
        for mode: StoryAnimationApplyMode
    ) -> StoryTransition {
        switch mode {
        case .allPages:
            guard storyPages.count > 1 else { return .none }
            let applied = (1..<storyPages.count).map { transitionForGap($0) }
            guard let first = applied.first else { return .none }
            return applied.dropFirst().allSatisfy({ $0 == first }) ? first : .none
        case .singleGap(let gapIndex):
            return transitionForGap(gapIndex)
        }
    }

    func remappedTransitionsAfterInsert(
        _ existing: [Int: StoryTransition],
        insertIndex: Int,
        insertedCount: Int
    ) -> [Int: StoryTransition] {
        guard insertedCount > 0 else { return existing }

        var remapped: [Int: StoryTransition] = [:]

        for (gapIndex, transition) in existing {
            if gapIndex < insertIndex {
                remapped[gapIndex] = transition
            } else if gapIndex > insertIndex {
                remapped[gapIndex + insertedCount] = transition
            }
        }

        return remapped
    }

    func remappedTransitionsAfterDelete(
        _ existing: [Int: StoryTransition],
        deleteIndex: Int,
        remainingPageCount: Int
    ) -> [Int: StoryTransition] {
        guard remainingPageCount > 1 else { return [:] }

        var remapped: [Int: StoryTransition] = [:]

        for (gapIndex, transition) in existing {
            if deleteIndex == 0 {
                if gapIndex > 1 {
                    remapped[gapIndex - 1] = transition
                }
                continue
            }

            if gapIndex < deleteIndex {
                remapped[gapIndex] = transition
            } else if gapIndex > deleteIndex + 1 {
                remapped[gapIndex - 1] = transition
            }
        }

        return remapped.filter { $0.key > 0 && $0.key < remainingPageCount }
    }

    func openAlbumPicker(
        insertAt index: Int
    ) {
        stopPlayback()
        pendingInsertionIndex = max(0, min(index, storyPages.count))
        showInsertOptions = false
        showAnimateSheet = false
        showAlbumPicker = true
    }

    func openInsertOptions(
        insertAt index: Int
    ) {
        stopPlayback()
        pendingInsertionIndex = max(0, min(index, storyPages.count))
        showAnimateSheet = false
        showInsertOptions = true
    }

    func openAnimationSheet(
        mode: StoryAnimationApplyMode
    ) {
        stopPlayback()
        showInsertOptions = false
        animationApplyMode = mode
        transitionDraft = draftTransition(for: mode)
        showAnimateSheet = true
    }
}
