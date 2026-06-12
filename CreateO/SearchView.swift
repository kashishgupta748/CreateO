import SwiftUI

struct SearchView: View {
    
    @State  var vm = SearchViewModel()
    @State private var isSearchPresented = false
    
    @State private var selectedDesign: Design?
    @State private var selectedAlbum: Album?
    
    @Environment(DataStore.self) private var store
    
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
        List {
            
            
            if !vm.designResults.isEmpty {
                Section("Designs") {
                    ForEach(vm.designResults) { design in
                        
                        NavigationLink {
                            PreviewView(design: design)
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading) {
                                    Text(design.designName)
                                    
                                }
                            }
                        }
                    }
                }
            }
            
            
            if !vm.albumResults.isEmpty {
                Section("Albums") {
                    ForEach(vm.albumResults) { album in
                        
                        NavigationLink {
                            AlbumPreviewView(album: album)
                        } label: {
                            
                            HStack(spacing: 12) {
                                
                                if let uiImage = DesignImageLoader.image(for: album.thumbnailPath) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 50, height: 50)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                } else {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 50, height: 50)
                                        .overlay(Image(systemName: "photo.on.rectangle"))
                                }
                                
                                Text(album.albumName)
                            }
                        }
                    }
                }
            }
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
