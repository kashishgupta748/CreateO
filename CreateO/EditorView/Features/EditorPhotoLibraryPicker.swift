import PhotosUI
import SwiftUI
import UIKit

@MainActor
struct EditorPhotoLibraryPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onImagesPicked: ([UIImage]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: PHPhotoLibrary.shared())
        configuration.filter = .images
        configuration.selectionLimit = 0

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) { }

    @MainActor
    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let parent: EditorPhotoLibraryPicker

        init(_ parent: EditorPhotoLibraryPicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard !results.isEmpty else {
                picker.dismiss(animated: true)
                parent.isPresented = false
                return
            }

            Task {
                var loadedImages: [UIImage] = []

                for result in results {
                    guard let image = await loadImage(from: result.itemProvider) else { continue }

                    let processed =
                        image.downscaledForCanvas()
                        ?? image.normalizedForEditing()
                        ?? image

                    loadedImages.append(processed)
                }

                await MainActor.run {
                    picker.dismiss(animated: true)
                    parent.isPresented = false

                    guard !loadedImages.isEmpty else { return }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [self] in
                        parent.onImagesPicked(loadedImages)
                    }
                }
            }
        }

        private func loadImage(from provider: NSItemProvider) async -> UIImage? {
            guard provider.canLoadObject(ofClass: UIImage.self) else { return nil }

            return await withCheckedContinuation { continuation in
                provider.loadObject(ofClass: UIImage.self) { object, _ in
                    continuation.resume(returning: object as? UIImage)
                }
            }
        }
    }
}
