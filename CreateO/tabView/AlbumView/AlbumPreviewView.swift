import SwiftUI
import UIKit

struct AlbumPreviewView: View {
    @Environment(DataStore.self) var designStore
    
    let album: Album

    @State private var showRenameSheet = false
    @State private var renameDraft = ""
    @State private var showDeleteAlert = false
    @Environment(\.dismiss) private var dismiss

    // Selection Mode
    @State private var isSelecting = false
    @State private var selectedIDs: Set<UUID> = []
    @State private var showDeleteConfirmation = false

    // Design Picker
    @State private var showDesignPicker = false
    @State private var selectedDesignIDs: [UUID] = []

    private var currentAlbum: Album {
        designStore.albums.first(where: { $0.id == album.id }) ?? album
    }

    private let gridSpacing: CGFloat = 10
    private let horizontalPadding: CGFloat = 16
    private let baselineCardWidth: CGFloat = 180
    private let baselineCardHeight: CGFloat = 252

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

    var albumDesigns: [Design] {
        designStore.designs.filter {
            currentAlbum.albumDesignIDs.contains($0.id)
        }
    }

    var body: some View {
        ScrollView {
            if albumDesigns.isEmpty {
                Text("No designs in this album")
                    .padding()
            } else {
                LazyVGrid(columns: columns, spacing: gridSpacing) {
                    ForEach(albumDesigns) { design in
                        let currentDesign = designStore.designs.first(where: { $0.id == design.id }) ?? design
                        
                        if isSelecting {
                            Button {
                                if selectedIDs.contains(currentDesign.id) {
                                    selectedIDs.remove(currentDesign.id)
                                } else {
                                    selectedIDs.insert(currentDesign.id)
                                }
                            } label: {
                                cellContent(for: currentDesign)
                            }
                            .buttonStyle(.plain)
                        } else {
                            NavigationLink {
                                PreviewView(design: currentDesign)
                            } label: {
                                cellContent(for: currentDesign)
                            }
                        }
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, 12)
            }
        }
        .scrollIndicators(.visible)
        .navigationTitle(currentAlbum.albumName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isSelecting)
        .toolbar {
            if isSelecting {
                ToolbarItem(placement: .topBarLeading) {
                    Button(selectedIDs.count == albumDesigns.count ? "Clear" : "Select All") {
                        if selectedIDs.count == albumDesigns.count {
                            selectedIDs.removeAll()
                        } else {
                            selectedIDs = Set(albumDesigns.map(\.id))
                        }
                    }
                }
            } else {
                ToolbarItem {
                    Button {
                        selectedDesignIDs = currentAlbum.albumDesignIDs
                        showDesignPicker = true
                    } label: {
                        Label("Add Designs", systemImage: "plus")
                    }
                }
                
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation {
                        isSelecting.toggle()
                        if !isSelecting {
                            selectedIDs.removeAll()
                        }
                    }
                } label: {
                    Text(isSelecting ? "Cancel" : "Select")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isSelecting {
                selectionFooter
            }
        }
        .alert("Delete Album?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                designStore.deleteAlbum(album: currentAlbum)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this album? This action cannot be undone.")
        }
        .alert("Delete Designs?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                let designsToDelete = albumDesigns.filter { selectedIDs.contains($0.id) }
                for design in designsToDelete {
                    designStore.deleteDesign(design: design)
                }
                isSelecting = false
                selectedIDs.removeAll()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to permanently delete these \(selectedIDs.count) designs? This action cannot be undone.")
        }
        .sheet(isPresented: $showRenameSheet) {
            NavigationStack {
                Form {
                    Section {
                        TextField("Album name", text: $renameDraft)
                    }

                    Section {
                        Button("Save") {
                            let trimmed = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }

                            designStore.renameAlbum(id: currentAlbum.id, newName: trimmed)
                            showRenameSheet = false
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .navigationTitle("Rename")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            showRenameSheet = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showDesignPicker, onDismiss: {
            designStore.updateAlbumDesigns(albumID: currentAlbum.id, designIDs: selectedDesignIDs)
        }) {
            DesignPickerView(selectedDesignId: $selectedDesignIDs)
                .presentationDetents([.large])
        }
    }

    @ViewBuilder
    private func cellContent(for design: Design) -> some View {
        ZStack(alignment: .topTrailing) {
            DesignImageView(path: design.thumbnailPath)
                .scaledToFill()
                .frame(width: cardSize.width, height: cardSize.height)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay {
                    if isSelecting && selectedIDs.contains(design.id) {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.black.opacity(0.25))
                    }
                }
            
            if isSelecting {
                Image(systemName: selectedIDs.contains(design.id) ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(
                        selectedIDs.contains(design.id) ? .white : .white.opacity(0.85),
                        selectedIDs.contains(design.id) ? Color.accentColor : Color.black.opacity(0.35)
                    )
                    .padding(10)
            }
        }
    }

    private var selectionFooter: some View {
       
        HStack {
        
            Button {
                shareSelectedDesigns()
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(.primary)
                    .frame(width: 54, height: 54)
                    .background(Color(.systemBackground))
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(selectedIDs.isEmpty)
            .opacity(selectedIDs.isEmpty ? 0.4 : 1.0)

            Spacer()

            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(.primary)
                    .frame(width: 54, height: 54)
                    .background(Color(.systemBackground))
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(selectedIDs.isEmpty)
            .opacity(selectedIDs.isEmpty ? 0.4 : 1.0)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 24)
        
        .overlay(alignment: .top) {
           
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func shareSelectedDesigns() {
        let selectedDesigns = albumDesigns.filter { selectedIDs.contains($0.id) }
        let images = selectedDesigns.compactMap { design in
            DesignImageLoader.image(for: design.thumbnailPath)
        }
        guard !images.isEmpty else { return }
        
        let activityVC = UIActivityViewController(activityItems: images, applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            if let popoverController = activityVC.popoverPresentationController {
                popoverController.sourceView = rootVC.view
                popoverController.sourceRect = CGRect(x: rootVC.view.bounds.midX, y: rootVC.view.bounds.midY, width: 0, height: 0)
                popoverController.permittedArrowDirections = []
            }
            rootVC.present(activityVC, animated: true, completion: nil)
        }
    }
}
