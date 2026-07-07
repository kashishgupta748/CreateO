import SwiftUI

struct AlbumPreviewView: View {
    @Environment(DataStore.self) var designStore
    @Environment(\.dismiss) var dismiss
    
    let album: Album

    private let gridSpacing: CGFloat = 10
    private let horizontalPadding: CGFloat = 16
    private let baselineCardWidth: CGFloat = 180
    private let baselineCardHeight: CGFloat = 252

    // State for Design Picker (Add designs)
    @State private var showDesignPicker = false
    @State private var selectedDesignIDsForAdd: [UUID] = []

    // State for Selection Mode
    @State private var isSelectionMode = false
    @State private var selectedDesignIDs: Set<UUID> = []
    @State private var showDeleteConfirmation = false

    private var cardWidth: CGFloat {
        let availableWidth = max(UIScreen.main.bounds.width - (horizontalPadding * 2), 1)
        return max((availableWidth - gridSpacing) / 2, 1)
    }

    private var cardSize: CGSize {
        CGSize(
            width: cardWidth,
            height: cardWidth * (baselineCardHeight / baselineCardWidth)
        )
    }

    private var columns: [GridItem] {
        [
            GridItem(.fixed(cardSize.width), spacing: gridSpacing),
            GridItem(.fixed(cardSize.width), spacing: gridSpacing)
        ]
    }

    var currentAlbum: Album {
        designStore.albums.first(where: { $0.id == album.id }) ?? album
    }

    var albumDesigns: [Design] {
        designStore.designs.filter {
            currentAlbum.albumDesignIDs.contains($0.id)
        }
    }

    var body: some View {
        ZStack {
            ScrollView {
                if albumDesigns.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No designs in this album")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 100)
                } else {
                    LazyVGrid(columns: columns, spacing: gridSpacing) {
                        ForEach(albumDesigns) { design in
                            let currentDesign = designStore.designs.first(where: { $0.id == design.id }) ?? design
                            
                            if isSelectionMode {
                                let isSelected = selectedDesignIDs.contains(design.id)
                                Button {
                                    toggleSelection(design.id)
                                } label: {
                                    ZStack(alignment: .topTrailing) {
                                        DesignImageView(path: currentDesign.thumbnailPath)
                                            .scaledToFill()
                                            .frame(width: cardSize.width, height: cardSize.height)
                                            .clipped()
                                            .clipShape(RoundedRectangle(cornerRadius: 20))
                                            .overlay {
                                                RoundedRectangle(cornerRadius: 20)
                                                    .fill(isSelected ? Color.black.opacity(0.16) : .clear)
                                            }
                                            .overlay {
                                                RoundedRectangle(cornerRadius: 20)
                                                    .stroke(isSelected ? Color.accentColor : Color.black.opacity(0.08), lineWidth: isSelected ? 3 : 1)
                                            }

                                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 24, weight: .semibold))
                                            .foregroundStyle(isSelected ? .white : .white.opacity(0.95), isSelected ? Color.accentColor : Color.black.opacity(0.20))
                                            .padding(10)
                                    }
                                }
                                .buttonStyle(.plain)
                            } else {
                                NavigationLink {
                                    PreviewView(design: currentDesign)
                                } label: {
                                    DesignImageView(path: currentDesign.thumbnailPath)
                                        .scaledToFill()
                                        .frame(width: cardSize.width, height: cardSize.height)
                                        .clipped()
                                        .clipShape(RoundedRectangle(cornerRadius: 20))
                                }
                            }
                        }
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.vertical, 12)
                }
            }
            .scrollIndicators(.visible)
        }
        .navigationTitle(currentAlbum.albumName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isSelectionMode)
        .toolbar {
            if isSelectionMode {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        withAnimation(.snappy(duration: 0.25)) {
                            isSelectionMode = false
                            selectedDesignIDs.removeAll()
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    let allSelected = selectedDesignIDs.count == albumDesigns.count
                    Button(allSelected ? "Deselect All" : "Select All") {
                        withAnimation(.snappy(duration: 0.25)) {
                            if allSelected {
                                selectedDesignIDs.removeAll()
                            } else {
                                selectedDesignIDs = Set(albumDesigns.map { $0.id })
                            }
                        }
                    }
                }

                ToolbarItem(placement: .bottomBar) {
                    Button {
                        removeFromAlbum()
                    } label: {
                        Image(systemName: "folder.badge.minus")
                    }
                    .disabled(selectedDesignIDs.isEmpty)
                }

                ToolbarItem(placement: .bottomBar) {
                    Spacer()
                }

                ToolbarItem(placement: .bottomBar) {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(selectedDesignIDs.isEmpty)
                }
            } else {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        selectedDesignIDsForAdd = currentAlbum.albumDesignIDs
                        showDesignPicker = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Select") {
                        withAnimation(.snappy(duration: 0.25)) {
                            isSelectionMode = true
                            selectedDesignIDs.removeAll()
                        }
                    }
                }
            }
        }
        .toolbar(isSelectionMode ? .hidden : .visible, for: .tabBar)
        .toolbar(isSelectionMode ? .visible : .hidden, for: .bottomBar)
        .sheet(isPresented: $showDesignPicker) {
            DesignPickerView(selectedDesignId: $selectedDesignIDsForAdd) { updatedIDs in
                designStore.updateAlbumDesigns(albumID: album.id, designIDs: updatedIDs)
            }
            .presentationDetents([.large])
        }
        .alert("Delete Designs?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                deleteSelectedDesigns()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete the selected designs from your device.")
        }
    }

    private func toggleSelection(_ id: UUID) {
        if selectedDesignIDs.contains(id) {
            selectedDesignIDs.remove(id)
        } else {
            selectedDesignIDs.insert(id)
        }
    }

    private func removeFromAlbum() {
        let remainingIDs = currentAlbum.albumDesignIDs.filter { !selectedDesignIDs.contains($0) }
        designStore.updateAlbumDesigns(albumID: album.id, designIDs: remainingIDs)
        selectedDesignIDs.removeAll()
        isSelectionMode = false
    }

    private func deleteSelectedDesigns() {
        let designsToDelete = designStore.designs.filter { selectedDesignIDs.contains($0.id) }
        for design in designsToDelete {
            designStore.deleteDesign(design: design)
        }
        selectedDesignIDs.removeAll()
        isSelectionMode = false
    }
}
