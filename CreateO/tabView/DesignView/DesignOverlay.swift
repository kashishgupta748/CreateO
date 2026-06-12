import SwiftUI

struct DesignOverlay: View {
    
    let design: Design
    
    var body: some View {
        VStack{
            HStack{
                Spacer()
                if design.isFavorite{
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red)
                        .padding(20)
                }
            }
            Spacer()
            HStack{
                Text(design.designName)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                Spacer()
            }
            .padding(12)
            .background(
                LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom)
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        
    }
}
#Preview {
    let store = DataStore()
    DesignOverlay(design: store.designs[0])
        .environment(store)
}


