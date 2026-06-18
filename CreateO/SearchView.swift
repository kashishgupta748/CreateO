import SwiftUI

struct SearchView: View {
    
    @State  var vm = SearchViewModel()
    @State private var isSearchPresented = false
    
    @State private var selectedDesign: Design?
    @State private var selectedAlbum: Album?
    
    @Environment(DataStore.self) private var store
    @Environment(\.horizontalSizeClass) private var hSize
    
    private var isPadLike: Bool { hSize == .regular }
    
    private var columns: [GridItem] {
        [
            GridItem(.adaptive(minimum: isPadLike ? 180 : 150, maximum: 280), spacing: 18)
        ]
    }
    
    private var albumCardWidth: CGFloat {
        let availableWidth = max(UIScreen.main.bounds.width - 32, 1)
        return max((availableWidth - 10) / 2, 1)
    }
    
    private var albumCardSize: CGSize {
        CGSize(
            width: albumCardWidth,
            height: albumCardWidth * (252.0 / 180.0)
        )
    }
    
    private var albumColumns: [GridItem] {
        [
            GridItem(.fixed(albumCardSize.width), spacing: 10),
            GridItem(.fixed(albumCardSize.width), spacing: 10)
        ]
    }
    
    var body: some View {
        NavigationStack {
            
            Group {
                if showEmptyState {
                    emptyView
                } else {
                    resultsList
                }
            }
            .navigationTitle("Search")
        }
        .searchable(
            text: $vm.searchText,
            isPresented: $isSearchPresented,
            prompt: "Search Designs & Albums"
        )
        .onChange(of: vm.searchText) { _, _ in
            vm.search(_:store)
        }
        .onAppear {
            Task { @MainActor in
                isSearchPresented = true
            }
        }
    }
}
extension SearchView {
    
    var resultsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if !vm.designResults.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Designs")
                            .font(.title3)
                            .bold()
                            .padding(.horizontal, 16)
                        
                        DesignGridView(
                            designs: vm.designResults,
                            layoutMode: .grid,
                            masonColumn: isPadLike ? 4 : 2,
                            columns: columns,
                            onAddTap: {},
                            showsAddCard: false
                        )
                    }
                }
                
                if !vm.albumResults.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Albums")
                            .font(.title3)
                            .bold()
                            .padding(.horizontal, 16)
                        
                        LazyVGrid(columns: albumColumns, spacing: 10) {
                            ForEach(vm.albumResults) { album in
                                let albumDesigns = store.designs.filter {
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
                                            .frame(width: albumCardSize.width, height: albumCardSize.height)

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
                                    .frame(width: albumCardSize.width, height: albumCardSize.height)
                                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                                    .shadow(radius: 5)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground))
    }
}
extension SearchView {
    
    var showEmptyState: Bool {
        vm.searchText.isEmpty ||
        (vm.designResults.isEmpty && vm.albumResults.isEmpty)
    }
    
    var emptyView: some View {
        ContentUnavailableView(
            vm.searchText.isEmpty ? "Start Searching" : "No Results",
            systemImage: "magnifyingglass",
            description: Text(
                vm.searchText.isEmpty
                ? "Search your designs or albums"
                : "Try a different keyword"
            )
        )
    }
}
#Preview {
    
    let store = DataStore()
    SearchView()
        .environment(store)
}
