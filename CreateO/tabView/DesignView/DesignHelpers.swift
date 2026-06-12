import SwiftUI
import PhotosUI

struct DesignHelpers {

    static func loadUploadItems(
        pendingEditorImages: Binding<[UIImage]>,
        showEditor: Binding<Bool>,
        uploadItems: Binding<[PhotosPickerItem]>,
        items: [PhotosPickerItem]
    ) {
        guard !items.isEmpty else { return }

        Task {
            var images: [UIImage] = []

            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {

                    let processed =
                        image.downscaledForCanvas()
                        ?? image.normalizedForEditing()
                        ?? image

                    images.append(processed)
                }
            }

            guard !images.isEmpty else { return }

            await MainActor.run {
                pendingEditorImages.wrappedValue = images
                showEditor.wrappedValue = true
                uploadItems.wrappedValue.removeAll()
            }
        }
    }
}
