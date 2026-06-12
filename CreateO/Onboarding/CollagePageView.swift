import SwiftUI
struct CollagePageView: View {
    let pageIndex: Int

    @Namespace private var animation
    @State private var showStack = false
    @State private var isExpanded = false

    var body: some View {
        GeometryReader { geo in
            let fullHeight = geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom
            
            ZStack {
                LinearGradient(
                    colors: [
                        Color.black,
                        Color(red: 0.16, green: 0.18, blue: 0.24)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ForEach(PageLayouts.stacked) { item in
                    let target = PageLayouts.grid.first { $0.imageName == item.imageName }!
                    
                    Image(item.imageName)
                        .resizable()
                        .scaledToFill()
                        .matchedGeometryEffect(id: item.imageName, in: animation)
                        .frame(
                            width: isExpanded
                            ? geo.size.width * target.widthFraction
                            : geo.size.width * item.widthFraction,
                            height: isExpanded
                            ? fullHeight * target.heightFraction
                            : fullHeight * item.heightFraction
                        )
                        .clipShape(RoundedRectangle(cornerRadius: isExpanded ? 0 : 22))
                        .position(
                            x: isExpanded
                            ? geo.size.width * (0.5 + target.x)
                            : geo.size.width * 0.5,
                            y: isExpanded
                            ? fullHeight * (0.5 + target.y)
                            : fullHeight * 0.5
                        )
                }
            }
        }
        .ignoresSafeArea()
            .task {
                await runSequence()
            }
            .onDisappear {
                showStack = false
                isExpanded = false
            }
        
    }

    @MainActor
    private func runSequence() async {
        showStack = false
        isExpanded = false

        withAnimation(.easeOut(duration: 0.55)) {
            showStack = true
        }

        try? await Task.sleep(nanoseconds: 850_000_000)

        withAnimation(.spring(response: 0.82, dampingFraction: 0.84)) {
            isExpanded = true
        }
    }
}


