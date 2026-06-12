import SwiftUI
import Foundation
import AVFoundation
import UIKit

struct StoryBoard: View {
    static let pageHoldDurationStatic: Double = 2.0
    static let transitionDurationStatic: Double = 2.0

    let initialDraft: StoryBoardDraft?

    @Environment(DataStore.self) var designStore
    @Environment(\.dismiss) var dismiss
    @AppStorage("creato.selectedTab") var selectedTab = CreatoTab.design.rawValue
    @AppStorage("creato.storySavedNotificationID") var storySavedNotificationID = ""

    @State var storyPages: [StoryPage] = []
    @State var currentPageIndex = 0

    @State var transitionDraft: StoryTransition = .none
    @State var gapTransitions: [Int: StoryTransition] = [:]
    @State var animationApplyMode: StoryAnimationApplyMode = .allPages

    @State var showAlbumPicker = false
    @State var showAudioAlert = false
    @State var showAnimateSheet = false
    @State var showInsertOptions = false
    @State var showSaveSheet = false

    @State var pendingInsertionIndex = 0
    @State var isPlaying = false
    @State var playbackElapsed: Double = 0
    @State var transitioningPageIndex: Int?
    @State var transitionProgress: CGFloat = 0
    @State var playbackTask: Task<Void, Never>?
    @State var scrubAnchorOffsetX: CGFloat?

    @State var undoStack: [StoryBoardSnapshot] = []
    @State var redoStack: [StoryBoardSnapshot] = []
    @State var storyName = ""
    @State var selectedSaveAlbumID: UUID?
    @State var newAlbumName = ""
    @State var isSavingStory = false
    @State var saveErrorMessage: String?
    @State var hasLoadedInitialDraft = false

    init(initialDraft: StoryBoardDraft? = nil) {
        self.initialDraft = initialDraft
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let horizontalPadding: CGFloat = 14
                let availableWidth = geo.size.width - (horizontalPadding * 2)
                let canvasWidth = max(min(availableWidth - 18, 334), 220)
                let idealCanvasHeight = canvasWidth / EditorView.canvasAspectRatio
                let canvasHeightCap = geo.size.height * (storyPages.isEmpty ? 0.66 : 0.60)
                let canvasHeight = min(
                    idealCanvasHeight + (storyPages.isEmpty ? 96 : 86),
                    canvasHeightCap
                )

                VStack(spacing: 10) {
                    previewSection(
                        canvasWidth: canvasWidth,
                        canvasHeight: canvasHeight
                    )

                    if !storyPages.isEmpty {
                        playerBar
                        timelineBar
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.top, storyPages.isEmpty ? -42 : -24)
                .padding(.bottom, 92)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(Color(.systemGroupedBackground))
            }
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .tabBar)
            .toolbar { toolbarUI }
        }
        .sheet(isPresented: $showAlbumPicker) {
            StoryAlbumPickerView { selected in
                insert(designs: selected, at: pendingInsertionIndex)
            }
            .environment(designStore)
        }
        .sheet(isPresented: $showAnimateSheet) {
            animateSheet
                .presentationDetents([animateSheetDetent])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(34)
                .presentationBackground(.regularMaterial)
        }
        .sheet(isPresented: $showSaveSheet) {
            saveSheet
        }
        .alert("Audio editor coming soon", isPresented: $showAudioAlert) {
            Button("OK", role: .cancel) { }
        }
        .alert(
            "Couldn’t Save Story",
            isPresented: Binding(
                get: { saveErrorMessage != nil },
                set: { if !$0 { saveErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(saveErrorMessage ?? "")
        }
        .confirmationDialog(
            "Insert between pages",
            isPresented: $showInsertOptions,
            titleVisibility: .visible
        ) {
            Button("Add Design") {
                openAlbumPicker(insertAt: pendingInsertionIndex)
            }

            if canInsertAnimationAtPendingIndex {
                Button("Add Animation") {
                    openAnimationSheet(mode: .singleGap(pendingInsertionIndex))
                }
            }

            Button("Cancel", role: .cancel) { }
        }
        .onDisappear {
            stopPlayback(resetProgress: false)
        }
        .onAppear {
            loadInitialDraftIfNeeded()
        }
        .fullScreenCover(isPresented: $isSavingStory) {
            savingOverlay
                .interactiveDismissDisabled(true)
                .presentationBackground(.clear)
        }
    }
}
