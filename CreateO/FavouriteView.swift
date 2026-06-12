import SwiftUI

struct FavouriteView: View {
    @Environment(DataStore.self) var designStore
    
    let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 280), spacing: 16)
    ]
    
    var favouriteDesigns: [Design] {
        designStore.designs.filter { $0.isFavorite }
    }
    
    var body: some View {
        ScrollView(.vertical) {
            if favouriteDesigns.isEmpty {
                Text("No Favourite Designs")
                    .padding(.top, 100)
            } else {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(favouriteDesigns) { design in
                        NavigationLink {
                            PreviewView(design: design)
                        }label:{
                            ZStack(alignment: .topTrailing) {
                                DesignImageView(path: design.thumbnailPath)
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 24))
                                    .contextMenu{
                                        Button{
                                            designStore.removeFavourite(design)
                                        } label: {
                                            Label("unfavourite",systemImage: "heart.slash")
                                        }
                                    }
                                
                                VStack {
                                    HStack {
                                        Spacer()
                                        Image(systemName: "heart.fill")
                                            .foregroundStyle(.red)
                                            .padding(10)
                                    }
                                    
                                    Spacer()
                                    
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
                                }
                                .aspectRatio(2.0 / 3.0, contentMode: .fit)
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 24))
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
            }.scrollIndicators(.visible)
        .navigationTitle("Favourites")
        }
    }


#Preview {
    FavouriteView()
        .environment(DataStore())
}
