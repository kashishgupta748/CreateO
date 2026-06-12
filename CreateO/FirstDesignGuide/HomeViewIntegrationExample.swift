import SwiftUI

struct HomeViewIntegrationExample: View {
    @Environment(FirstDesignGuideManager.self) private var guideManager

    var body: some View {
        Button("Create Design") {
            guideManager.advance(from: .homeCreate)
        }
        .guideHighlight(
            .homeCreate,
            isActive: guideManager.currentStep == .homeCreate
        )
    }
}
