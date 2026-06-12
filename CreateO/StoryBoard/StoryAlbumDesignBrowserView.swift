import SwiftUI
import Foundation
import AVFoundation
import UIKit

struct StoryAlbumDesignBrowserView: View {


    @Environment(DataStore.self) var designStore
    @Environment(\.dismiss) var dismiss

    let album: Album

    let onComplete: ([Design]) -> Void

    @State var isSelecting = false
    @State var selectedIDs: Set<UUID> = []

    let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var albumDesigns: [Design] {
        designStore.designs.filter {
            album.albumDesignIDs.contains($0.id)
        }
    }

    var allSelected: Bool {
        !albumDesigns.isEmpty && selectedIDs.count == albumDesigns.count
    }
}
