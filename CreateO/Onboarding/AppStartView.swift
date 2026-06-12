
import SwiftUI

struct AppStartView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        if hasSeenOnboarding {
            RootView()
        } else {
            OnboardingContainerView(hasSeenOnboarding: $hasSeenOnboarding)
        }
    }
}
