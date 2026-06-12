import SwiftUI
import Foundation
import AVFoundation
import UIKit

extension StoryBoard {


    func prepareSaveSheet() {
        if storyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let baseName = storyPages.first?.design.designName.trimmingCharacters(in: .whitespacesAndNewlines)
            storyName = (baseName?.isEmpty == false ? baseName! : "My Story") + " Story"
        }
        selectedSaveAlbumID = selectedSaveAlbumID ?? storyPages.first?.design.albumID
        showSaveSheet = true
    }

    func saveStory(
        destination: EditorSaveDestination
    ) {
        guard !storyPages.isEmpty, !isSavingStory else { return }

        let trimmedName = storyName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            saveErrorMessage = "Give your story a name before saving."
            return
        }

        isSavingStory = true
        showSaveSheet = false
        let pages = storyPages
        let transitions = gapTransitions
        let selectedDestination = destination

        Task.detached(priority: .userInitiated) {
            do {
                let savedVideo = try await StoryVideoExporter.export(
                    pages: pages,
                    gapTransitions: transitions,
                    storyName: trimmedName
                )

                await MainActor.run {
                    persistSavedVideo(savedVideo, destination: selectedDestination)
                    isSavingStory = false
                    showSaveSheet = false
                    selectedTab = CreatoTab.design.rawValue
                    storySavedNotificationID = UUID().uuidString
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSavingStory = false
                    saveErrorMessage = error.localizedDescription
                }
            }
        }
    }

    func persistSavedVideo(
        _ savedVideo: SavedStoryVideo,
        destination: EditorSaveDestination
    ) {
        let now = Date()
        var savedDesign = Design(
            id: UUID(),
            designName: savedVideo.storyName,
            createdAt: now,
            updatedAt: now,
            isFavorite: false,
            designType: .video,
            designHeight: savedVideo.renderSize.height,
            designWidth: savedVideo.renderSize.width,
            designPath: savedVideo.videoPath,
            thumbnailPath: savedVideo.thumbnailPath,
            albumID: nil,
            cloudSynced: false,
            projectPath: savedVideo.projectPath
        )

        switch destination {
        case .library:
            designStore.designs.insert(savedDesign, at: 0)
        case .existingAlbum(let albumID):
            savedDesign.albumID = albumID
            designStore.designs.insert(savedDesign, at: 0)
            designStore.addDesign(savedDesign.id, toAlbum: albumID)
        case .newAlbum(let albumName):
            let albumID = designStore.createAlbum(
                named: albumName,
                initialDesignIDs: [savedDesign.id]
            )
            savedDesign.albumID = albumID
            designStore.designs.insert(savedDesign, at: 0)
            designStore.updateDesign(design: savedDesign)
        }
    }
}
