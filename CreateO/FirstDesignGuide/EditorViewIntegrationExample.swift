import SwiftUI

struct EditorViewIntegrationExample: View {
    @Environment(FirstDesignGuideManager.self) private var guideManager

    var body: some View {
        Button {
            guideManager.advance(from: .editorDoodle)
        } label: {
            Label("Doodle", systemImage: "scribble.variable")
        }
        .guideHighlight(
            .editorDoodle,
            isActive: guideManager.currentStep == .editorDoodle
        )
    }
}
