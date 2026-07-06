import SwiftUI

struct AlbumView: View {
    
    @State private var showAlbumSheet = false
    @Environment(DataStore.self) var AlbumStore

   
    @State private var showDeleteAlert = false
    @State private var selectedAlbum: Album?
    @State private var showRenameSheet = false
    @State private var renameDraft = ""
    
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

    var body: some View {
        NavigationStack {
            Group {
                if AlbumStore.albums.isEmpty {
                    AlbumEmptyView()
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(AlbumStore.albums) { album in
                                
                                let albumDesigns = AlbumStore.designs.filter {
                                    album.albumDesignIDs.contains($0.id)
                                }
                                
                                let thumbnail = albumDesigns.first?.thumbnailPath ?? "photo"
                                
                                NavigationLink {
                                    AlbumPreviewView(album: album)
                                        .toolbar(.hidden, for: .tabBar)
                                } label: {
                                    ZStack(alignment: .bottomLeading) {
                                        DesignImageView(path: thumbnail)
                                            .scaledToFill()
                                            .frame(width: cardSize.width, height: cardSize.height)

                                        HStack {
                                            Text(album.albumName)
                                                .font(.headline)
                                                .fontWeight(.semibold)
                                                .foregroundStyle(.white)
                                                .lineLimit(1)
                                            Spacer()
                                        }
                                        .padding(12)
                                        .background(
                                            LinearGradient(
                                                colors: [.clear, .black.opacity(0.6)],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                    }
                                    .frame(width: cardSize.width, height: cardSize.height)
                                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                                    .shadow(radius: 5)
                                }
                                .contextMenu {
                                    AlbumToolbar(
                                        album: album,
                                        showDeleteAlert: $showDeleteAlert,
                                        selectedAlbum: $selectedAlbum,
                                        showRenameSheet: $showRenameSheet,
                                        renameDraft: $renameDraft
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .scrollIndicators(.visible)
                    }
                }
            }
            .navigationTitle("Albums")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showAlbumSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        
        .sheet(isPresented: $showAlbumSheet) {
            AlbumCreateSheet()
        }
        
        .alert("Delete Album?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let album = selectedAlbum {
                    AlbumStore.deleteAlbum(album: album)
                }
            }
            
            Button("Cancel", role: .cancel) { }
            
        } message: {
            Text("Are you sure you want to delete this album? This action cannot be undone.")
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

                            if let album = selectedAlbum {
                                AlbumStore.renameAlbum(id: album.id, newName: trimmed)
                            }
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
    }
}

#Preview {
    AlbumView()
        .environment(DataStore())
}
