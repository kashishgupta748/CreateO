import SwiftUI
import Foundation
import AVFoundation
import UIKit

extension StoryBoard {
    func emptyCanvas(
        width: CGFloat,
        height: CGFloat
    ) -> some View {
        Button {
            openAlbumPicker(insertAt: 0)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(.secondarySystemBackground),
                                Color(.systemBackground)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: width, height: height)

                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(0.12))
                            .frame(width: 58, height: 58)

                        Image(systemName: "plus.viewfinder")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                    }

                    Text("Start your story")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.primary)

                    Text("Add designs from an album to build a clean, swipeable story sequence.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            }
        }
        .buttonStyle(.plain)
    }

    var playerBar: some View {
        HStack(spacing: 12) {
            Spacer(minLength: 0)

            Text(playbackTimeText)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.primary)

            Button {
                togglePlayback()
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(width: 56, height: 56)
                    .background(.white, in: Circle())
                    .shadow(color: .black.opacity(0.10), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(storyPages.count < 2)
            .opacity(storyPages.count < 2 ? 0.45 : 1)

            Text(durationText)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
        .padding(.top, 0)
        .padding(.bottom, 0)
    }

    var timelineBar: some View {
        VStack(spacing: 4) {
            playbackGuideLine

            GeometryReader { geo in
                let viewportWidth = max(geo.size.width - 32, 1)
                let leadingInset = timelineLeadingInset(for: viewportWidth)

                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        ZStack(alignment: .topLeading) {
                            HStack(spacing: timelineGapSpacing) {
                                Color.clear
                                    .frame(width: leadingInset, height: 1)

                                ForEach(Array(storyPages.enumerated()), id: \.element.id) { index, page in
                                    timelineThumb(page, index)
                                }

                                if storyPages.isEmpty {
                                    plusInline(storyPages.count)
                                }

                                Color.clear
                                    .frame(width: leadingInset, height: 1)
                            }
                            .frame(height: timelineCardHeight, alignment: .center)
                            .padding(.trailing, 4)

                            ForEach(storyPages.indices, id: \.self) { index in
                                Color.clear
                                    .frame(width: 1, height: 1)
                                    .id(timelineAnchorID(index))
                                    .offset(
                                        x: leadingInset + thumbnailProgressStartX(for: index),
                                        y: timelineCardHeight / 2
                                    )
                            }

                            timelinePlayhead(leadingInset: leadingInset)

                            ForEach(0..<max(storyPages.count - 1, 0), id: \.self) { index in
                                plusBridge(index + 1, leadingInset: leadingInset)
                            }

                            if !storyPages.isEmpty {
                                trailingPlusBridge(leadingInset: leadingInset)
                            }
                        }
                        .frame(height: timelineCardHeight)
                        .contentShape(Rectangle())
                        .simultaneousGesture(
                            SpatialTapGesture()
                                .onEnded { value in
                                    scrubAnchorOffsetX = nil
                                    scrubPlayback(
                                        toTimelineOffset: value.location.x,
                                        leadingInset: leadingInset
                                    )
                                }
                        )
                        .padding(.horizontal, 16)
                        .padding(.vertical, 2)
                    }
                    .onAppear {
                        scrollTimeline(to: currentPageIndex, with: proxy)
                    }
                    .onChange(of: currentPageIndex) { _, newValue in
                        scrollTimeline(to: newValue, with: proxy)
                    }
                    .onChange(of: transitioningPageIndex) { _, newValue in
                        guard let newValue else { return }
                        scrollTimeline(
                            to: newValue,
                            with: proxy,
                            animation: .easeInOut(duration: transitionDuration)
                        )
                    }
                }
            }
            .frame(height: timelineCardHeight + 4)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.white)
            )
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .frame(height: timelineCardHeight + 10)
        .padding(.top, 0)
    }
}
