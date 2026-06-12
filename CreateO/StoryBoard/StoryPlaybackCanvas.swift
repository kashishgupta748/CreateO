import SwiftUI
import Foundation
import AVFoundation
import UIKit

struct StoryPlaybackCanvas: View {
    let currentPage: StoryPage
    let nextPage: StoryPage?
    let transition: StoryTransition
    let progress: CGFloat
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        let clippedShape = RoundedRectangle(cornerRadius: 20, style: .continuous)

        ZStack {
            switch transition {
            case .none:
                pageLayer((progress >= 1 ? nextPage : nil) ?? currentPage)
            case .dissolve:
                pageLayer(currentPage)
                    .opacity(Double(1 - progress))
                if let nextPage {
                    pageLayer(nextPage)
                        .opacity(Double(progress))
                }
            case .circleWipe:
                pageLayer(currentPage)
                    .opacity(Double(1 - (progress * 0.18)))
                if let nextPage {
                    pageLayer(nextPage)
                        .mask(
                            Circle()
                                .frame(
                                    width: max(width, height) * 1.7 * max(progress, 0.001),
                                    height: max(width, height) * 1.7 * max(progress, 0.001)
                                )
                        )
                }
            case .slide:
                pageLayer(currentPage)
                    .offset(x: -width * 0.18 * progress)
                if let nextPage {
                    pageLayer(nextPage)
                        .offset(x: width * (1 - progress))
                }
            case .colorWipe:
                pageLayer(currentPage)
                if let nextPage {
                    pageLayer(nextPage)
                        .mask(
                            Rectangle()
                                .frame(width: max(width * progress, 1))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        )
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.accentColor.opacity(0.55), Color.accentColor.opacity(0.08)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 34, height: height)
                        .offset(x: (width * progress) - (width / 2))
                        .blendMode(.screen)
                }
            case .lineWipe:
                pageLayer(currentPage)
                if let nextPage {
                    pageLayer(nextPage)
                        .mask(
                            Rectangle()
                                .frame(width: max(width * progress, 1))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        )
                    Rectangle()
                        .fill(Color.white.opacity(0.72))
                        .frame(width: 3, height: height)
                        .offset(x: (width * progress) - (width / 2))
                        .shadow(color: Color.accentColor.opacity(0.26), radius: 8)
                }
            case .matchAndMove:
                pageLayer(currentPage)
                    .scaleEffect(1 - (progress * 0.06))
                    .opacity(Double(1 - (progress * 0.45)))
                if let nextPage {
                    pageLayer(nextPage)
                        .scaleEffect(0.92 + (progress * 0.08))
                        .offset(y: 22 * (1 - progress))
                        .opacity(Double(progress))
                }
            case .flow:
                pageLayer(currentPage)
                    .offset(x: -28 * progress)
                    .blur(radius: 6 * progress)
                    .opacity(Double(1 - (progress * 0.5)))
                if let nextPage {
                    pageLayer(nextPage)
                        .offset(x: 38 * (1 - progress))
                        .blur(radius: 8 * (1 - progress))
                        .opacity(Double(progress))
                }
            case .stack:
                pageLayer(currentPage)
                    .scaleEffect(1 - (progress * 0.04))
                    .offset(y: -12 * progress)
                if let nextPage {
                    pageLayer(nextPage)
                        .scaleEffect(0.90 + (progress * 0.10))
                        .offset(y: height * 0.24 * (1 - progress))
                        .opacity(Double(progress))
                }
            case .chop:
                pageLayer(currentPage)
                if let nextPage {
                    pageLayer(nextPage)
                        .scaleEffect(x: max(progress, 0.001), y: 1, anchor: .leading)
                        .rotationEffect(.degrees(Double((1 - progress) * 9)), anchor: .trailing)
                        .opacity(Double(progress))
                }
            }
        }
        .frame(width: width, height: height)
        .clipShape(clippedShape)
    }

    func pageLayer(
        _ page: StoryPage
    ) -> some View {
        ZStack(alignment: .bottomLeading) {
            Rectangle()
                .fill(.white)

            DesignImageView(path: page.design.designPath)
                .scaledToFit()
                .frame(width: width, height: height)

            LinearGradient(
                colors: [
                    .black.opacity(0.26),
                    .black.opacity(0.02)
                ],
                startPoint: .bottom,
                endPoint: .center
            )

            Text(page.design.designName.isEmpty ? "Untitled Design" : page.design.designName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .frame(width: width, height: height)
    }
}
