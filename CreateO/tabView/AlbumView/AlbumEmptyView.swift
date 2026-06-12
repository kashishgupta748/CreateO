
import SwiftUI

struct AlbumEmptyView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled.fill")
                .resizable()
                .frame(width: 100, height: 80)
                .opacity(0.3)

            Text("No Album Available")
                .font(.headline)

            Text("Create your album by tapping + above")
                .font(.subheadline)
                .opacity(0.3)
        }
    }
}

#Preview {
    AlbumEmptyView()
}

