import SwiftUI
import Foundation
import AVFoundation
import UIKit

extension StoryBoard {
    func timelineThumb(
        _ page: StoryPage,
        _ index: Int
    ) -> some View {
        Button {
            showPage(index)
        } label: {
            ZStack(alignment: .topLeading) {
                DesignImageView(path: page.design.thumbnailPath)
                    .scaledToFill()
                    .frame(width: timelineThumbWidth, height: timelineThumbHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(
                                currentPageIndex == index
                                ? Color.accentColor
                                : Color.black.opacity(0.06),
                                lineWidth: currentPageIndex == index ? 3 : 1
                            )
                    }
                    .shadow(
                        color: currentPageIndex == index ? Color.accentColor.opacity(0.20) : .clear,
                        radius: 10,
                        y: 6
                    )

                Text("\(index + 1)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(currentPageIndex == index ? .white : .primary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(currentPageIndex == index ? Color.accentColor : .white)
                    )
                    .padding(6)
            }
        }
        .buttonStyle(.plain)
    }

    var playbackGuideLine: some View {
        GeometryReader { geo in
            let width = max(geo.size.width, 1)
            let progressWidth = max(2, width * playbackFraction)

            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.black.opacity(0.16))
                    .frame(height: 1.5)

                Rectangle()
                    .fill(Color.black.opacity(0.72))
                    .frame(width: progressWidth, height: 1.5)
            }
        }
        .frame(height: 2)
        .padding(.horizontal, 12)
    }

    func timelinePlayhead(
        leadingInset: CGFloat
    ) -> some View {
        Group {
            if !storyPages.isEmpty {
                ZStack {
                    Rectangle()
                        .fill(.clear)
                        .frame(width: 32, height: timelineThumbHeight + 26)

                    VStack(spacing: 0) {
                        Capsule()
                            .fill(Color.black.opacity(0.74))
                            .frame(width: 2, height: timelineThumbHeight + 10)

                        Circle()
                            .fill(Color.black.opacity(0.78))
                            .frame(width: 6, height: 6)
                            .offset(y: -1)
                    }
                }
                .offset(x: leadingInset + playheadOffsetX, y: -3)
                .contentShape(Rectangle())
                .highPriorityGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            handlePlayheadDragChanged(
                                translation: value.translation.width,
                                leadingInset: leadingInset
                            )
                        }
                        .onEnded { _ in
                            scrubAnchorOffsetX = nil
                        }
                )
                .offset(y: timelinePlayheadYOffset)
            }
        }
    }

    func plusInline(
        _ index: Int
    ) -> some View {
        Button {
            openAlbumPicker(insertAt: index)
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 34, height: 34)
                .background(.white, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        }
        .buttonStyle(.plain)
        .frame(width: timelineTrailingPlusWidth, height: timelineThumbHeight)
        .offset(x: -12)
    }

    func plusBridge(
        _ index: Int,
        leadingInset: CGFloat
    ) -> some View {
        Button {
            if transitionForGap(index) == .none {
                openInsertOptions(insertAt: index)
            } else {
                openAnimationSheet(mode: .singleGap(index))
            }
        } label: {
            let gapTransition = transitionForGap(index)

            if gapTransition == .none {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 32, height: 32)
                    .background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
            } else {
                CompactTransitionBridge(transition: gapTransition)
            }
        }
        .buttonStyle(.plain)
        .offset(
            x: bridgeOffsetX(
                for: index,
                itemWidth: transitionForGap(index) == .none ? timelinePlusBridgeSize : timelineTransitionBridgeWidth,
                leadingInset: leadingInset
            ),
            y: transitionForGap(index) == .none ? timelinePlusBridgeOffsetY : timelineTransitionBridgeOffsetY
        )
    }
}
