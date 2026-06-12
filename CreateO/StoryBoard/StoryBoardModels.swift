import SwiftUI
import Foundation
import AVFoundation
import UIKit

struct StoryBoardDraft {
    let storyName: String
    let pageDesignIDs: [UUID]
    let gapTransitions: [Int: StoryTransition]
}

struct StoryPage: Identifiable {
    let id = UUID()
    let design: Design
}

struct StoryBoardSnapshot {
    let pages: [StoryPage]
    let currentIndex: Int
    let gapTransitions: [Int: StoryTransition]
}

enum StoryAnimationApplyMode: Equatable {
    case allPages
    case singleGap(Int)

    var buttonTitle: String {
        switch self {
        case .allPages:
            return "Apply between all pages"
        case .singleGap:
            return "Apply between these pages"
        }
    }

    var subtitle: String {
        switch self {
        case .allPages:
            return "Apply one transition style across the whole story."
        case .singleGap:
            return "Apply this transition only to the selected gap."
        }
    }

    func previewGapIndex(
        currentPageIndex: Int,
        pageCount: Int
    ) -> Int? {
        guard pageCount > 1 else { return nil }

        switch self {
        case .allPages:
            return min(max(currentPageIndex + 1, 1), pageCount - 1)
        case .singleGap(let gapIndex):
            return min(max(gapIndex, 1), pageCount - 1)
        }
    }
}

enum StoryTransition: String, CaseIterable, Identifiable {
    case none
    case dissolve
    case circleWipe
    case slide
    case colorWipe
    case lineWipe
    case matchAndMove
    case flow
    case stack
    case chop

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "None"
        case .dissolve: return "Dissolve"
        case .circleWipe: return "Circle Wipe"
        case .slide: return "Slide"
        case .colorWipe: return "Color Wipe"
        case .lineWipe: return "Line Wipe"
        case .matchAndMove: return "Match & Move"
        case .flow: return "Flow"
        case .stack: return "Stack"
        case .chop: return "Chop"
        }
    }

    var symbol: String {
        switch self {
        case .none: return "line.diagonal"
        case .dissolve: return "square.lefthalf.filled"
        case .circleWipe: return "circle.circle"
        case .slide: return "rectangle.portrait.and.arrow.right"
        case .colorWipe: return "rectangle.leadinghalf.filled"
        case .lineWipe: return "line.3.crossed.swirl.circle"
        case .matchAndMove: return "sparkles.rectangle.stack"
        case .flow: return "wind"
        case .stack: return "square.on.square"
        case .chop: return "triangle.righthalf.filled"
        }
    }

    var accent: Color {
        Color.accentColor
    }

    var previewAnimation: Animation {
        animation(duration: 0.75)
    }

    func animation(
        duration: Double
    ) -> Animation {
        switch self {
        case .none:
            return .linear(duration: duration)
        case .dissolve, .colorWipe, .lineWipe:
            return .easeInOut(duration: duration)
        case .circleWipe, .matchAndMove:
            return .spring(duration: duration, bounce: 0.08)
        case .slide, .flow, .stack, .chop:
            return .snappy(duration: duration, extraBounce: 0.02)
        }
    }
}

struct StoryTransitionCard: View {
    let transition: StoryTransition
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? transition.accent.opacity(0.16) : .white)
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(
                                isSelected ? transition.accent : Color.black.opacity(0.06),
                                lineWidth: isSelected ? 2 : 1
                            )
                    }
                    .frame(width: 100, height: 86)

                StoryTransitionGlyph(transition: transition)
                    .frame(width: 68, height: 44)
            }

            Text(transition.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 96)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
    }
}

struct CompactTransitionBridge: View {
    let transition: StoryTransition

    var body: some View {
        let bridgeShape = RoundedRectangle(cornerRadius: 12, style: .continuous)

        ZStack {
            bridgeShape
                .fill(.white)

            StoryTransitionGlyph(transition: transition)
                .frame(width: 24, height: 16)
                .padding(4)
                .clipShape(bridgeShape)

            bridgeShape
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        }
        .compositingGroup()
        .clipShape(bridgeShape)
        .frame(width: 32, height: 32)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}
