
import SwiftUI

struct CollagePage2View: View {
    
    let baseImages = ["1","2","3","4","5","6"]
    
    let firstMap: [Int:String] = [
        1:"14",
        3:"8",
        4:"9",
        5:"20"
    ]
    
    let secondMap: [Int:String] = [
        1:"13",
        3:"8",
        4:"12",
        5:"19"
    ]
    
    @State private var stage = 0
    @State private var expandHero = false
    @State private var show15 = false
    
    var body: some View {
        GeometryReader { geo in
            
            let cellW = geo.size.width * 0.5
            let cellH = geo.size.height / 3
            
            ZStack {
                
                // MARK: NORMAL GRID IMAGES
                
                ForEach(0..<6, id: \.self) { index in
                    
                    // hide all other images once expansion starts
                    if !(expandHero && index != 4) {
                        
                        let base = baseImages[index]
                        let first = firstMap[index] ?? base
                        let second = secondMap[index] ?? first
                        
                        ZStack {
                            
                            // 5TH IMAGE (INDEX 4)
                            if index == 4 {
                                
                                Image(show15 ? "15" : second)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(
                                        width: expandHero ? geo.size.width : cellW,
                                        height: expandHero ? geo.size.height : cellH
                                    )
                                    .clipped()
                                
                            } else {
                                
                                if firstMap[index] == nil {
                                    
                                    Image(base)
                                        .resizable()
                                        .scaledToFill()
                                    
                                } else {
                                    
                                    Image(base)
                                        .resizable()
                                        .scaledToFill()
                                        .opacity(stage == 0 ? 1 : 0)
                                    
                                    Image(first)
                                        .resizable()
                                        .scaledToFill()
                                        .opacity(stage == 1 ? 1 : 0)
                                    
                                    Image(second)
                                        .resizable()
                                        .scaledToFill()
                                        .opacity(stage == 2 ? 1 : 0)
                                }
                            }
                        }
                        .frame(
                            width: expandHero && index == 4 ? geo.size.width : cellW,
                            height: expandHero && index == 4 ? geo.size.height : cellH
                        )
                        .clipped()
                        .position(
                            x: xPos(index: index, geo: geo, expanded: expandHero),
                            y: yPos(index: index, geo: geo, expanded: expandHero)
                        )
                        .animation(.spring(response: 0.9, dampingFraction: 0.82), value: expandHero)
                        .animation(.easeInOut(duration: 0.4), value: show15)
                    }
                }
            }
            .ignoresSafeArea()
            .onAppear {
                
                stage = 0
                
                // First image replacement
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        stage = 1
                    }
                }
                
                // Second image replacement
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        stage = 2
                    }
                }
                
                // Expand 5th image to FULLSCREEN from TOP RIGHT
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    withAnimation(.spring(response: 0.9, dampingFraction: 0.82)) {
                        expandHero = true
                    }
                }
                
                // Change to image 15 after expansion
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.8) {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        show15 = true
                    }
                }
            }
        }
    }
    
    // MARK: Position
    
    func xPos(index: Int, geo: GeometryProxy, expanded: Bool) -> CGFloat {
        if index == 4 && expanded {
            return geo.size.width / 2
        }
        
        return index % 2 == 0
        ? geo.size.width * 0.25
        : geo.size.width * 0.75
    }
    
    func yPos(index: Int, geo: GeometryProxy, expanded: Bool) -> CGFloat {
        if index == 4 && expanded {
            return geo.size.height / 2
        }
        
        return geo.size.height * (CGFloat(index / 2) * 0.333 + 0.166)
    }
}

