import SwiftUI

struct SearchView: View {
    
    @State  var vm = SearchViewModel()
    @State private var isSearchPresented = false
    
    @State private var selectedDesign: Design?
    @State private var selectedAlbum: Album?
    
    @Environment(DataStore.self) private var store

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
                            .fontWeight(.bold)
                            .padding(.horizontal, horizontalPadding)
                        
                        LazyVGrid(columns: columns, spacing: gridSpacing) {
                            ForEach(vm.designResults) { design in
                                NavigationLink {
                                    PreviewView(design: design)
                                } label: {
                                    ZStack(alignment: .bottomLeading) {
                                        DesignImageView(path: design.thumbnailPath)
                                            .scaledToFill()
                                            .frame(width: cardSize.width, height: cardSize.height)
                                        
                                        HStack {
                                            Text(design.designName)
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
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, horizontalPadding)
                    }
                }
                
                if !vm.albumResults.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Albums")
                            .font(.title3)
                            .fontWeight(.bold)
                            .padding(.horizontal, horizontalPadding)
                        
                        LazyVGrid(columns: columns, spacing: gridSpacing) {
                            ForEach(vm.albumResults) { album in
                                let albumDesigns = store.designs.filter {
                                    album.albumDesignIDs.contains($0.id)
                                }
                                let thumbnail = albumDesigns.first?.thumbnailPath ?? "photo"
                                
                                NavigationLink {
                                    AlbumPreviewView(album: album)
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
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, horizontalPadding)
                    }
                }
            }
            .padding(.vertical, 16)
        }
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
