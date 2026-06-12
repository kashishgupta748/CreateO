import SwiftUI
import Foundation
import AVFoundation
import UIKit

extension StoryBoard {
    func trailingPlusBridge(
        leadingInset: CGFloat
    ) -> some View {
        Button {
            openAlbumPicker(insertAt: storyPages.count)
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 32, height: 32)
                .background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        }
        .buttonStyle(.plain)
        .offset(
            x: bridgeOffsetX(
                for: storyPages.count,
                itemWidth: timelinePlusBridgeSize,
                leadingInset: leadingInset
            ),
            y: timelinePlusBridgeOffsetY
        )
    }

    var transitionLabelText: String {
        previewTransition == .none ? "No animation" : previewTransition.title
    }

    var transitionValueText: String {
        previewTransition == .none ? "None" : previewTransition.title
    }

    var canInsertAnimationAtPendingIndex: Bool {
        pendingInsertionIndex > 0 && pendingInsertionIndex < storyPages.count
    }

    var playheadHitWidth: CGFloat { 32 }

    var timelineProgressInset: CGFloat { 0 }

    var timelineContentStartX: CGFloat {
        storyPages.isEmpty ? 0 : timelineGapSpacing
    }

    func timelineAnchorID(
        _ index: Int
    ) -> String {
        "timeline-page-\(index)"
    }

    func timelineLeadingInset(
        for viewportWidth: CGFloat
    ) -> CGFloat {
        0
    }

    func thumbnailLeadingX(
        for index: Int
    ) -> CGFloat {
        timelineContentStartX + (CGFloat(index) * (timelineThumbWidth + timelineGapSpacing))
    }

    func thumbnailProgressStartX(
        for index: Int
    ) -> CGFloat {
        thumbnailLeadingX(for: index) + timelineProgressInset
    }

    func thumbnailProgressEndX(
        for index: Int
    ) -> CGFloat {
        thumbnailLeadingX(for: index) + timelineThumbWidth - timelineProgressInset
    }

    var playheadOffsetX: CGFloat {
        timelineCenterX(forPlaybackElapsed: playbackElapsed) - (playheadHitWidth / 2)
    }

    func bridgeOffsetX(
        for index: Int,
        itemWidth: CGFloat = 32,
        leadingInset: CGFloat = 0
    ) -> CGFloat {
        let leftThumbTrailing = thumbnailLeadingX(for: max(index - 1, 0)) + timelineThumbWidth
        let rightThumbLeading = index < storyPages.count
            ? thumbnailLeadingX(for: index)
            : leftThumbTrailing + timelineGapSpacing
        let bridgeCenter = (leftThumbTrailing + rightThumbLeading) / 2
        return leadingInset + bridgeCenter - (itemWidth / 2)
    }

    func scrollTimeline(
        to index: Int,
        with proxy: ScrollViewProxy,
        animation: Animation? = .easeInOut(duration: 0.24)
    ) {
        guard storyPages.indices.contains(index) else { return }

        if let animation {
            withAnimation(animation) {
                proxy.scrollTo(timelineAnchorID(index), anchor: .center)
            }
        } else {
            proxy.scrollTo(timelineAnchorID(index), anchor: .center)
        }
    }

    func handlePlayheadDragChanged(
        translation: CGFloat,
        leadingInset: CGFloat
    ) {
        let visualPlayheadOffset = leadingInset + playheadOffsetX
        let baseOffset = scrubAnchorOffsetX ?? visualPlayheadOffset
        if scrubAnchorOffsetX == nil {
            scrubAnchorOffsetX = visualPlayheadOffset
        }

        scrubPlayback(
            toTimelineOffset: baseOffset + translation,
            leadingInset: leadingInset
        )
    }

    func scrubPlayback(
        toTimelineOffset offset: CGFloat,
        leadingInset: CGFloat = 0
    ) {
        guard !storyPages.isEmpty else { return }

        stopPlayback(resetProgress: false)

        if storyPages.count == 1 {
            currentPageIndex = 0
            playbackElapsed = 0
            transitioningPageIndex = nil
            transitionProgress = 0
            return
        }

        let lineCenterX = (offset + (playheadHitWidth / 2)) - leadingInset
        let resolvedElapsed = playbackElapsed(forTimelineCenterX: lineCenterX)
        playbackElapsed = resolvedElapsed
        applyPlaybackPreview(for: resolvedElapsed)
    }
}
