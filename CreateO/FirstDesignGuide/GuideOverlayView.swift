import SwiftUI

struct GuideOverlayView: View {
    let step: GuideStep?
    let highlightFrame: CGRect?
    let onSkip: () -> Void
    let onClose: () -> Void

    var body: some View {
        GeometryReader { proxy in
            if let step, highlightFrame != nil {
                ZStack(alignment: .topLeading) {
                    dimmedBackground(in: proxy.size)
                        .allowsHitTesting(false)

                    if let highlightFrame {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.accentColor.opacity(0.9), lineWidth: 2)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.white.opacity(0.1))
                            )
                            .shadow(color: Color.accentColor.opacity(0.42), radius: 18)
                            .frame(
                                width: highlightFrame.insetBy(dx: -8, dy: -8).width,
                                height: highlightFrame.insetBy(dx: -8, dy: -8).height
                            )
                            .position(x: highlightFrame.midX, y: highlightFrame.midY)
                            .allowsHitTesting(false)
                    }

                    GuideTooltipCard(step: step, onSkip: onSkip, onClose: onClose)
                        .frame(width: min(proxy.size.width - 32, 360))
                        .position(tooltipPosition(for: step, in: proxy.size))
                        .allowsHitTesting(true)
                        .transition(.scale(scale: 0.96).combined(with: .opacity))
                }
                .animation(.spring(response: 0.34, dampingFraction: 0.86), value: step.id)
                .animation(.spring(response: 0.34, dampingFraction: 0.86), value: highlightFrame)
                .ignoresSafeArea()
                .zIndex(1000)
            }
        }
    }

    private func dimmedBackground(in size: CGSize) -> some View {
        Rectangle()
            .fill(Color.black.opacity(0.18))
            .frame(width: size.width, height: size.height)
            .mask {
                Rectangle()
                    .overlay {
                        if let highlightFrame {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .frame(
                                    width: highlightFrame.insetBy(dx: -10, dy: -10).width,
                                    height: highlightFrame.insetBy(dx: -10, dy: -10).height
                                )
                                .position(x: highlightFrame.midX, y: highlightFrame.midY)
                                .blendMode(.destinationOut)
                        }
                    }
            }
            .compositingGroup()
    }

    private func tooltipPosition(for step: GuideStep, in size: CGSize) -> CGPoint {
        let tooltipWidth = min(size.width - 32, 360)
        let tooltipHeight = step.tooltipEstimatedHeight
        let sidePadding: CGFloat = 16
        let topPadding: CGFloat = 62
        let bottomPadding: CGFloat = 30
        let topY = topPadding + tooltipHeight / 2
        let bottomY = size.height - bottomPadding - tooltipHeight / 2

        func clampedPoint(x: CGFloat, y: CGFloat) -> CGPoint {
            CGPoint(
                x: min(
                    max(x, sidePadding + tooltipWidth / 2),
                    size.width - sidePadding - tooltipWidth / 2
                ),
                y: min(
                    max(y, topY),
                    bottomY
                )
            )
        }

        guard let highlightFrame else {
            return clampedPoint(x: size.width / 2, y: topY)
        }

        switch step.tooltipPlacement {
        case .top:
            return clampedPoint(x: size.width / 2, y: topY)
        case .bottom:
            return clampedPoint(x: size.width / 2, y: bottomY)
        case .automatic:
            let topPoint = clampedPoint(x: highlightFrame.midX, y: topY)
            let bottomPoint = clampedPoint(x: highlightFrame.midX, y: bottomY)
            let topRect = tooltipRect(center: topPoint, width: tooltipWidth, height: tooltipHeight)
            let bottomRect = tooltipRect(center: bottomPoint, width: tooltipWidth, height: tooltipHeight)
            let paddedHighlight = highlightFrame.insetBy(dx: -14, dy: -14)

            if !topRect.intersects(paddedHighlight) {
                return topPoint
            }

            if !bottomRect.intersects(paddedHighlight) {
                return bottomPoint
            }

            let topDistance = abs(topPoint.y - highlightFrame.midY)
            let bottomDistance = abs(bottomPoint.y - highlightFrame.midY)
            return topDistance >= bottomDistance ? topPoint : bottomPoint
        }
    }

    private func tooltipRect(center: CGPoint, width: CGFloat, height: CGFloat) -> CGRect {
        CGRect(
            x: center.x - width / 2,
            y: center.y - height / 2,
            width: width,
            height: height
        )
    }
}
