import SwiftUI
import Foundation
import AVFoundation
import UIKit

extension StoryAlbumDesignBrowserView {
    func designCell(
        _ design: Design
    ) -> some View {
        let selected = selectedIDs.contains(design.id)

        return Button {
            if isSelecting {
                if selected {
                    selectedIDs.remove(design.id)
                } else {
                    selectedIDs.insert(design.id)
                }
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                DesignImageView(path: design.thumbnailPath)
                    .scaledToFill()
                    .frame(height: 212)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(isSelecting && selected ? Color.white.opacity(0.30) : .clear)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(
                                isSelecting && selected ? Color.accentColor : Color.black.opacity(0.08),
                                lineWidth: isSelecting && selected ? 3 : 1
                            )
                    }

                if isSelecting {
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(
                            selected ? .white : .white.opacity(0.9),
                            selected ? Color.accentColor : Color.black.opacity(0.25)
                        )
                        .padding(10)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
