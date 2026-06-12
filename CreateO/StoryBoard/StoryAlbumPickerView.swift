import SwiftUI
import Foundation
import AVFoundation
import UIKit

struct StoryAlbumPickerView: View {

    @Environment(DataStore.self) var designStore
    @Environment(\.dismiss) var dismiss

    let onImport: ([Design]) -> Void

    @State var selectedAlbum: Album?

    let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                if designStore.albums.isEmpty {
                    emptyAlbumsState
                        .padding(.top, 70)
                        .padding(.horizontal, 24)
                } else {
                    LazyVGrid(columns: columns, spacing: 18) {
                        ForEach(designStore.albums) { album in
                            albumCard(album)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 30)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Albums")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                }
            }
            .navigationDestination(
                isPresented: Binding(
                    get: { selectedAlbum != nil },
                    set: { if !$0 { selectedAlbum = nil } }
                )
            ) {
                if let selectedAlbum {
                    StoryAlbumDesignBrowserView(album: selectedAlbum) { imported in
                        onImport(imported)
                        dismiss()
                    }
                    .environment(designStore)
                }
            }
        }
    }

    var emptyAlbumsState: some View {
        VStack(spacing: 14) {
            Image(systemName: "square.stack.3d.up.slash")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.secondary)

            Text("No albums yet")
                .font(.system(size: 20, weight: .bold))

            Text("Create an album first, then come back here to build your story from saved designs.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    func albumCard(
        _ album: Album
    ) -> some View {
        let albumDesigns = designStore.designs.filter {
            album.albumDesignIDs.contains($0.id)
        }
        let previewPaths = Array(albumDesigns.prefix(4).map(\.thumbnailPath))

        return Button {
            selectedAlbum = album
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                albumPreview(previewPaths: previewPaths, fallbackPath: album.thumbnailPath)

                VStack(alignment: .leading, spacing: 4) {
                    Text(album.albumName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text("\(album.albumDesignIDs.count) designs")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.white)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    func albumPreview(
        previewPaths: [String],
        fallbackPath: String
    ) -> some View {
        if previewPaths.isEmpty {
            DesignImageView(path: fallbackPath)
                .scaledToFill()
                .frame(height: 184)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        } else {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Array(previewPaths.enumerated()), id: \.offset) { _, path in
                    DesignImageView(path: path)
                        .scaledToFill()
                        .frame(height: 88)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .frame(height: 184)
        }
    }
}
