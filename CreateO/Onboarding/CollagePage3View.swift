
import SwiftUI

struct CollagePage3View: View {
    
    @State private var moveToCenter = false
    @State private var showSecond = false
    @State private var showThird = false
    @State private var showFourth = false
    @Binding var hasSeenOnboarding: Bool

    @State private var showStoryBoard = false
    
    var body: some View {
        GeometryReader { geo in
            
            let cardW = min(geo.size.width * 0.38, 320)
            let cardH = min(geo.size.height * 0.48, 520)
            
            ZStack {
                
                // ORIGINAL PAGE 3
                
                Color(red: 0.96, green: 0.94, blue: 0.89)
                    .ignoresSafeArea()
                
                Image("15")
                    .resizable()
                    .scaledToFill()
                    .frame(width: cardW, height: cardH)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .position(
                        x: moveToCenter ? geo.size.width * 0.18 : geo.size.width / 2,
                        y: geo.size.height * 0.52
                    )
                
                if showSecond {
                    card("16", x: geo.size.width * 0.50, geo: geo)
                }
                
                if showThird {
                    card("17", x: geo.size.width * 0.82, geo: geo)
                }
                
                if showFourth {
                    card("18", x: geo.size.width * 1.08, geo: geo)
                }
                
                // DISSOLVE STORYBOARD
                
                if showStoryBoard {
                    StoryBoardFrontView(hasSeenOnboarding: $hasSeenOnboarding)
                        .transition(.opacity)
                        .zIndex(100)
                }
            }
            .animation(.easeInOut(duration: 0.8), value: showStoryBoard)
            .onAppear {
                
                withAnimation(.easeInOut(duration: 1)) {
                    moveToCenter = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showSecond = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showThird = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                    showFourth = true
                }
                
                // after 2 sec fade next screen
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
                    withAnimation(.easeInOut(duration: 0.8)) {
                        showStoryBoard = true
                    }
                }
            }
        }
    }
    
    func card(_ img: String, x: CGFloat, geo: GeometryProxy) -> some View {
        Image(img)
            .resizable()
            .scaledToFill()
            .frame(width: min(geo.size.width * 0.38, 320),
                   height: min(geo.size.height * 0.48, 520))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .position(x: x, y: geo.size.height * 0.52)
    }
}
