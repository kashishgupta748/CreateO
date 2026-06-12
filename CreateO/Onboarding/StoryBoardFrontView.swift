import SwiftUI

struct StoryBoardFrontView: View {

    @Environment(AuthManager.self) private var authManager

    @State private var collapseCards = false
    @State private var showHeroLarge = false
    @State private var showMeta = false
    @State private var finalExpand = false
    @State private var showButton = false

    @Binding var hasSeenOnboarding: Bool

    var body: some View {
        GeometryReader { geo in
            let isPad = geo.size.width > 700

            let cardW: CGFloat = isPad ? 240 : 160
            let cardH: CGFloat = isPad ? 460 : 340

            let heroW = min(geo.size.width * 0.78, isPad ? 620 : 340)
            let heroH = min(geo.size.height * 0.62, isPad ? 820 : 560)

            ZStack {
                Color.black.ignoresSafeArea()

                Image("15")
                    .resizable()
                    .scaledToFill()
                    .frame(
                        width: finalExpand ? geo.size.width : (showHeroLarge ? heroW : cardW),
                        height: finalExpand ? geo.size.height : (showHeroLarge ? heroH : cardH)
                    )
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: finalExpand ? 0 : 24, style: .continuous))
                    .position(
                        x: geo.size.width / 2,
                        y: finalExpand ? geo.size.height / 2 : (showHeroLarge ? geo.size.height * 0.46 : geo.size.height * 0.50)
                    )
                    .zIndex(10)
                    .animation(.timingCurve(0.45, 0.0, 0.2, 1.0, duration: 1.0), value: showHeroLarge)
                    .animation(.easeInOut(duration: 0.9), value: finalExpand)

                if !finalExpand {
                    Group {
                        storyCard("16", w: cardW, h: cardH)
                            .position(
                                x: collapseCards ? geo.size.width * 0.50 : geo.size.width * 0.50,
                                y: collapseCards ? geo.size.height * 0.40 : geo.size.height * 0.50
                            )
                            .scaleEffect(collapseCards ? 0.92 : 1)
                            .rotationEffect(.degrees(collapseCards ? -5 : 0))
                            .opacity(showHeroLarge ? 0 : 1)

                        storyCard("17", w: cardW, h: cardH)
                            .position(
                                x: collapseCards ? geo.size.width * 0.50 : geo.size.width * 0.78,
                                y: collapseCards ? geo.size.height * 0.42 : geo.size.height * 0.50
                            )
                            .scaleEffect(collapseCards ? 0.88 : 1)
                            .rotationEffect(.degrees(collapseCards ? 4 : 0))
                            .opacity(showHeroLarge ? 0 : 1)

                        storyCard("18", w: cardW, h: cardH)
                            .position(
                                x: collapseCards ? geo.size.width * 0.50 : geo.size.width * 1.02,
                                y: collapseCards ? geo.size.height * 0.44 : geo.size.height * 0.50
                            )
                            .scaleEffect(collapseCards ? 0.84 : 1)
                            .rotationEffect(.degrees(collapseCards ? 8 : 0))
                            .opacity(showHeroLarge ? 0 : 1)
                    }
                    .zIndex(5)
                    .animation(.timingCurve(0.45, 0.0, 0.2, 1.0, duration: 0.9), value: collapseCards)
                }

                LinearGradient(
                    colors: [.clear, .black.opacity(0.86)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .zIndex(11)

                if showMeta && !showButton {
                    VStack {
                        Spacer()

                        Text("Create a StoryBoard")
                            .font(.system(size: isPad ? 34 : 24, weight: .bold))
                            .foregroundStyle(.white)

                        Text("Connect through the stories you tell")
                            .font(.system(size: isPad ? 21 : 15, weight: .medium))
                            .foregroundStyle(.white.opacity(0.84))
                            .padding(.top, 4)

                        HStack(spacing: 10) {
                            Circle().fill(.white.opacity(0.45)).frame(width: 9, height: 9)
                            Circle().fill(.white.opacity(0.45)).frame(width: 9, height: 9)
                            Capsule().fill(.white).frame(width: 24, height: 9)
                        }
                        .padding(.top, 18)
                        .padding(.bottom, 42)
                    }
                    .padding(.horizontal, 30)
                    .zIndex(12)
                    .transition(.opacity)
                }

                if showButton {
                    VStack {
                        Spacer()

                        Button {
                            finishOnboarding()
                        } label: {
                            Text("Get Started")
                                .font(.system(size: isPad ? 24 : 18, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: isPad ? 420 : .infinity)
                                .padding(.vertical, 18)
                                .background(Color.accentColor, in: Capsule())
                                .padding(.horizontal, 30)
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, 48)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    .zIndex(15)
                }
            }
            .ignoresSafeArea()
            .task {
                await runSequence()
            }
            .onDisappear {
                collapseCards = false
                showHeroLarge = false
                showMeta = false
                finalExpand = false
                showButton = false
            }
        }
    }

    private func storyCard(_ img: String, w: CGFloat, h: CGFloat) -> some View {
        Image(img)
            .resizable()
            .scaledToFill()
            .frame(width: w, height: h)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func finishOnboarding() {
        if authManager.state == .guest {
            authManager.hasSeenAuthScreen = false
        }
        hasSeenOnboarding = true
    }

    @MainActor
    private func runSequence() async {
        collapseCards = false
        showHeroLarge = false
        showMeta = false
        finalExpand = false
        showButton = false

        withAnimation(.timingCurve(0.45, 0.0, 0.2, 1.0, duration: 0.9)) {
            collapseCards = true
        }

        try? await Task.sleep(nanoseconds: 320_000_000)
        withAnimation(.timingCurve(0.45, 0.0, 0.2, 1.0, duration: 0.95)) {
            showHeroLarge = true
        }

        try? await Task.sleep(nanoseconds: 800_000_000)
        withAnimation(.easeInOut(duration: 0.35)) {
            showMeta = true
        }

        try? await Task.sleep(nanoseconds: 1_450_000_000)
        withAnimation(.easeInOut(duration: 0.8)) {
            finalExpand = true
        }

        try? await Task.sleep(nanoseconds: 850_000_000)
        withAnimation(.easeInOut(duration: 0.2)) {
            showMeta = false
        }

        try? await Task.sleep(nanoseconds: 180_000_000)
        withAnimation(.spring(response: 0.68, dampingFraction: 0.86)) {
            showButton = true
        }
    }
}
