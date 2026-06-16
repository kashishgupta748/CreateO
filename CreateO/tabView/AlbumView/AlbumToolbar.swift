import SwiftUI

struct AlbumToolbar: View {
    let album: Album
    @Environment(DataStore.self) var AlbumStore
    @Binding var showDeleteAlert: Bool
    @Binding var showRenameSheet: Bool
    @Binding var selectedAlbum: Album?
    
    var body: some View {
        Group {
            ShareLink(
                item: URL(string: "https://albunshare.com/design/\(album.id)")!,
                preview: SharePreview(
                    album.albumName,
                    image: Image(
                        uiImage: DesignImageLoader.image(for: album.thumbnailPath) ?? UIImage()
                    )
                )
            ) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            
            Button {
                selectedAlbum = album
                showRenameSheet = true
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            
            Button(role: .destructive) {
                selectedAlbum = album
                showDeleteAlert = true
            } label: {
                Label("Delete Album", systemImage: "trash")
            }
        }
    }
}
