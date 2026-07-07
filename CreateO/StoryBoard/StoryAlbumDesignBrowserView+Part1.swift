import SwiftUI
import Foundation
import AVFoundation
import UIKit

extension StoryAlbumDesignBrowserView {
    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(albumDesigns) { design in
                    designCell(design)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, isSelecting ? 92 : 28)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarBackButtonHidden(true)
        .toolbar {
            if isSelecting {
                ToolbarItem(placement: .topBarLeading) {
                    Button(allSelected ? "Clear" : "Select All") {
                        if allSelected {
                            selectedIDs.removeAll()
                        } else {
                            selectedIDs = Set(albumDesigns.map(\.id))
                        }
                    }
                }

                ToolbarItem(placement: .principal) {
                    Text(album.albumName)
                        .font(.system(size: 18, weight: .bold))
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        isSelecting = false
                        selectedIDs.removeAll()
                    } label: {
                        Image(systemName: "xmark")
                    }

                    Button {
                        let output = albumDesigns.filter {
                            selectedIDs.contains($0.id)
                        }
                        onComplete(output)
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .disabled(selectedIDs.isEmpty)
                }
            } else {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                }

                ToolbarItem(placement: .principal) {
                    Text(album.albumName)
                        .font(.system(size: 18, weight: .bold))
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Button {
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }

                        Button(role: .destructive) {
                        } label: {
                            Label("Delete Album", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }

                    Button("Select") {
                        isSelecting = true
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isSelecting {
                selectionFooter
            }
        }
    }

    var selectionFooter: some View {
        HStack {
            Button {
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 20, weight: .medium))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Spacer()

            Text("Select designs")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.primary)

            Spacer()

            Button {
                selectedIDs.removeAll()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 20, weight: .medium))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(selectedIDs.isEmpty ? Color.secondary : Color.red)
            .disabled(selectedIDs.isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(Color(.systemGroupedBackground))
    }
}
