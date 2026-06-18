import SwiftUI

struct AlbumPreviewView: View {
    @Environment(DataStore.self) var designStore
    
    let album: Album

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
            album.albumDesignIDs.contains($0.id)
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
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, 12)
            }
        }
        .scrollIndicators(.visible)
        .navigationTitle(album.albumName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem {
                Menu {
                    Button {
                    } label: {
                        Label("Add Designs", systemImage: "plus")
                    }
                    Button {
                        
                    } label: {
                        Label("Rename Album", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        

                    } label: {
                        Label("Delete Album", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                } label: {
                    Text("Select")
                }
            }
        }
       
    }
}
