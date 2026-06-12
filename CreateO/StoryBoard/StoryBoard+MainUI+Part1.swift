import SwiftUI
import Foundation
import AVFoundation
import UIKit

extension StoryBoard {


    func loadInitialDraftIfNeeded() {
        guard !hasLoadedInitialDraft else { return }
        hasLoadedInitialDraft = true

        guard let initialDraft else { return }

        let designLookup = Dictionary(
            uniqueKeysWithValues: designStore.designs.map { ($0.id, $0) }
        )
        let loadedPages = initialDraft.pageDesignIDs.compactMap { id in
            designLookup[id].map { StoryPage(design: $0) }
        }

        guard !loadedPages.isEmpty else { return }

        storyPages = loadedPages
        storyName = initialDraft.storyName
        gapTransitions = initialDraft.gapTransitions
        currentPageIndex = min(currentPageIndex, max(loadedPages.count - 1, 0))
        playbackElapsed = 0
        transitionDraft = .none
        transitioningPageIndex = nil
        transitionProgress = 0
    }

    var timelineThumbWidth: CGFloat { 82 }

    var timelineThumbHeight: CGFloat { 98 }

    var timelineGapSpacing: CGFloat { 18 }

    var timelineTrailingPlusWidth: CGFloat { 36 }

    var timelineCardHeight: CGFloat { 136 }

    var timelinePlusBridgeSize: CGFloat { 32 }

    var timelineTransitionBridgeWidth: CGFloat { 32 }

    var timelineTransitionBridgeHeight: CGFloat { 32 }

    var timelinePlusBridgeOffsetY: CGFloat {
        max((timelineCardHeight - timelinePlusBridgeSize) / 2, 0)
    }

    var timelineTransitionBridgeOffsetY: CGFloat {
        max((timelineCardHeight - timelineTransitionBridgeHeight) / 2, 0)
    }

    var timelinePlayheadYOffset: CGFloat {
        max((timelineCardHeight - (timelineThumbHeight + 26)) / 2 - 1, 0)
    }

    var currentPage: StoryPage? {
        guard storyPages.indices.contains(currentPageIndex) else { return nil }
        return storyPages[currentPageIndex]
    }

    var upcomingPage: StoryPage? {
        guard let transitioningPageIndex, storyPages.indices.contains(transitioningPageIndex) else {
            return nil
        }
        return storyPages[transitioningPageIndex]
    }

    var previewTransition: StoryTransition {
        transitionForGap(currentPageIndex + 1)
    }

    var saveSheet: some View {
        EditorSaveSheet(
            designName: $storyName,
            albums: designStore.albums,
            selectedAlbumID: $selectedSaveAlbumID,
            newAlbumName: $newAlbumName
        ) { destination in
            saveStory(destination: destination)
        }
    }

    var savingOverlay: some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                ProgressView()
                    .controlSize(.large)
                    .tint(.primary)

                Text("Saving story")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.primary)

                Text("Creating your video...")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 24)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.18), radius: 24, y: 12)
        }
        .allowsHitTesting(true)
    }

    @ViewBuilder
    func previewSection(
        canvasWidth: CGFloat,
        canvasHeight: CGFloat
    ) -> some View {
        VStack(spacing: 6) {
            if let page = currentPage {
                canvasView(
                    page: page,
                    width: canvasWidth,
                    height: canvasHeight
                )
            } else {
                emptyCanvas(
                    width: canvasWidth,
                    height: canvasHeight
                )
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 0)
        .padding(.bottom, 8)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.black.opacity(0.045), lineWidth: 0.8)
        )
        .shadow(color: .black.opacity(0.05), radius: 14, y: 8)
    }

    func canvasView(
        page: StoryPage,
        width: CGFloat,
        height: CGFloat
    ) -> some View {
        StoryPlaybackCanvas(
            currentPage: page,
            nextPage: upcomingPage,
            transition: previewTransition,
            progress: transitionProgress,
            width: width,
            height: height
        )
    }
}
