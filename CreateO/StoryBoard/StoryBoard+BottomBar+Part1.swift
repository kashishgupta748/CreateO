import SwiftUI
import Foundation
import AVFoundation
import UIKit

extension StoryBoard {


    var selectedGapIndexForToolbarAnimation: Int? {
        let nextGapIndex = currentPageIndex + 1
        guard storyPages.count > 1, nextGapIndex > 0, nextGapIndex < storyPages.count else {
            return nil
        }
        return nextGapIndex
    }

    var bottomToolbar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                bottomToolbarItems
            }
            .frame(maxWidth: .infinity)

            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    bottomToolbarItems
                }
                .padding(.horizontal, 4)
            }
            .scrollIndicators(.hidden)
        }
    }

    var bottomToolbarItems: some View {
        Group {
            bottomButton("plus", "Add") {
                openAlbumPicker(
                    insertAt: storyPages.isEmpty ? 0 : currentPageIndex + 1
                )
            }

            bottomButton("music.note", "Audio") {
                showAudioAlert = true
            }

            bottomButton("trash", "Delete", tint: .red) {
                deleteCurrentPage()
            }
            .disabled(storyPages.isEmpty)
            .opacity(storyPages.isEmpty ? 0.35 : 1)

            bottomButton("sparkles", "Animate") {
                if let gapIndex = selectedGapIndexForToolbarAnimation {
                    openAnimationSheet(mode: .singleGap(gapIndex))
                }
            }
            .disabled(selectedGapIndexForToolbarAnimation == nil)
            .opacity(selectedGapIndexForToolbarAnimation == nil ? 0.35 : 1)
        }
    }

    func bottomButton(
        _ icon: String,
        _ title: String,
        tint: Color = .primary,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 20, height: 20)

                Text(title)
                    .font(.caption2)
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(width: 58)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
