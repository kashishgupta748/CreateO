
import SwiftUI

struct OnboardingContainerView: View {
    
    @Binding var hasSeenOnboarding: Bool
    @State private var currentPage = 0
    
    let totalPages = 3
    
    var body: some View {
        ZStack {
            
            // MARK: BACKGROUND PAGES
            
            switch currentPage {
                
            case 0:
                CollagePageView(pageIndex: 0)
                
            case 1:
                CollagePage2View()
                
            case 2:
                CollagePage3View(hasSeenOnboarding: $hasSeenOnboarding)
                
            default:
                CollagePageView(pageIndex: 0)
            }
            
            
          
            
            if currentPage != 2 {
                
                // DARK GRADIENT
                
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.black.opacity(0.65)
                    ],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                
                // TOP RIGHT SKIP
                
                VStack {
                    HStack {
                        Spacer()
                        
                        Button("Skip") {
                            hasSeenOnboarding = true
                        }
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.top, 50)
                        .padding(.trailing, 24)
                    }
                    
                    Spacer()
                }
                
                
                // BOTTOM CONTENT
                
                VStack {
                    Spacer()
                    
                    VStack(spacing: 12) {
                        
                        Text(titleForPage(currentPage))
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text(subtitleForPage(currentPage))
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        
                        
                        // DOTS
                        
                        HStack(spacing: 8) {
                            ForEach(0..<totalPages, id: \.self) { i in
                                Circle()
                                    .fill(
                                        i == currentPage
                                        ? Color.white
                                        : Color.white.opacity(0.4)
                                    )
                                    .frame(width: 8, height: 8)
                            }
                        }
                        .padding(.top, 10)
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .ignoresSafeArea()
        
        
        // MARK: SWIPE NAVIGATION
        
        .gesture(
            DragGesture()
                .onEnded { value in
                    
                    if value.translation.width < -50 &&
                        currentPage < totalPages - 1 {
                        
                        withAnimation(.spring()) {
                            currentPage += 1
                        }
                    }
                    
                    else if value.translation.width > 50 &&
                                currentPage > 0 {
                        
                        withAnimation(.spring()) {
                            currentPage -= 1
                        }
                    }
                }
        )
    }
    
    
    // MARK: TITLES
    
    private func titleForPage(_ page: Int) -> String {
        switch page {
        case 0:
            return "Finding Canvas Boring"
        case 1:
            return "Tap to Stylize Image"
        case 2:
            return "Create A StoryBoard"
        default:
            return ""
        }
    }
    
    
    // MARK: SUBTITLES
    
    private func subtitleForPage(_ page: Int) -> String {
        switch page {
        case 0:
            return "Capture your favourite memories"
        case 1:
            return "Turn Your photos into beautiful canvas"
        case 2:
            return "Connect through the stories you tell"
        default:
            return ""
        }
    }
}
