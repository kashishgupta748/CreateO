import SwiftUI

private struct GuideHighlightPreferenceKey: PreferenceKey {
    static var defaultValue: [GuideAnchor: CGRect] = [:]

    static func reduce(value: inout [GuideAnchor: CGRect], nextValue: () -> [GuideAnchor: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, newValue in newValue })
    }
}

struct GuideHighlightModifier: ViewModifier {
    let anchor: GuideAnchor
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .preference(
                            key: GuideHighlightPreferenceKey.self,
                            value: isActive ? [anchor: proxy.frame(in: .global)] : [:]
                        )
                }
            }
    }
}

extension View {
    func guideHighlight(_ anchor: GuideAnchor, isActive: Bool) -> some View {
        modifier(GuideHighlightModifier(anchor: anchor, isActive: isActive))
    }

    func firstDesignGuideOverlay(manager: FirstDesignGuideManager) -> some View {
        modifier(FirstDesignGuideOverlayModifier(manager: manager))
    }
}

private struct FirstDesignGuideOverlayModifier: ViewModifier {
    @Bindable var manager: FirstDesignGuideManager
    @State private var highlightFrames: [GuideAnchor: CGRect] = [:]

    func body(content: Content) -> some View {
        content
            .onPreferenceChange(GuideHighlightPreferenceKey.self) { frames in
                highlightFrames = frames
            }
            .overlay {
                GuideOverlayView(
                    step: manager.currentStep,
                    highlightFrame: activeHighlightFrame,
                    onSkip: { manager.skip() },
                    onClose: { manager.complete() }
                )
            }
    }

    private var activeHighlightFrame: CGRect? {
        guard let step = manager.currentStep else { return nil }
        return highlightFrames[step.anchor]
    }
}
