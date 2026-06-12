import SwiftUI
import Foundation
import AVFoundation
import UIKit

extension StoryBoard {


    @ToolbarContentBuilder
    var toolbarUI: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            topButton("chevron.left") {
                dismiss()
            }
        }

        ToolbarItem(placement: .principal) {
            HStack(spacing: 10) {
                topButton(
                    "arrow.uturn.backward",
                    disabled: undoStack.isEmpty
                ) {
                    undo()
                }

                topButton(
                    "arrow.uturn.forward",
                    disabled: redoStack.isEmpty
                ) {
                    redo()
                }
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            topButton("checkmark") {
                guard !isSavingStory else { return }
                guard !storyPages.isEmpty else {
                    dismiss()
                    return
                }
                prepareSaveSheet()
            }
        }

        ToolbarItem(placement: .bottomBar) {
            bottomToolbar
        }
    }

    func topButton(
        _ icon: String,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.35 : 1)
    }
}
