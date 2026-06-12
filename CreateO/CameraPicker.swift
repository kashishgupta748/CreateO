import SwiftUI
import AVFoundation

@MainActor
struct CameraPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Binding var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> CameraPresenterViewController {
        let controller = CameraPresenterViewController()
        controller.pickerDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: CameraPresenterViewController, context: Context) {
        uiViewController.pickerDelegate = context.coordinator
    }

    @MainActor
    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraPicker

        init(_ parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image.downscaledForCanvas() ?? image.normalizedForEditing() ?? image
            }

            picker.dismiss(animated: true) {
                self.parent.dismiss()
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true) {
                self.parent.dismiss()
            }
        }

        func handleUnavailableCamera(message: String) {
            parent.errorMessage = message
            parent.dismiss()
        }
    }
}

@MainActor
final class CameraPresenterViewController: UIViewController {
    weak var pickerDelegate: (UINavigationControllerDelegate & UIImagePickerControllerDelegate)?
    private var hasPresentedCamera = false

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        guard !hasPresentedCamera else { return }
        hasPresentedCamera = true

        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            presentPhotoLibraryFallback()
            return
        }

        let authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        switch authorizationStatus {
        case .authorized:
            presentCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.presentCamera()
                    } else {
                        (self.pickerDelegate as? CameraPicker.Coordinator)?.handleUnavailableCamera(
                            message: "Camera access was denied. Enable camera permission for Creato in Settings."
                        )
                    }
                }
            }
        case .denied, .restricted:
            (pickerDelegate as? CameraPicker.Coordinator)?.handleUnavailableCamera(
                message: "Camera access is turned off. Enable camera permission for Creato in Settings."
            )
        @unknown default:
            (pickerDelegate as? CameraPicker.Coordinator)?.handleUnavailableCamera(
                message: "Camera access couldn't be started right now. Please try again."
            )
        }
    }

    private func presentCamera() {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.modalPresentationStyle = .fullScreen
        picker.delegate = pickerDelegate
        present(picker, animated: false)
    }

    private func presentPhotoLibraryFallback() {
        guard UIImagePickerController.isSourceTypeAvailable(.photoLibrary) else {
            (pickerDelegate as? CameraPicker.Coordinator)?.handleUnavailableCamera(
                message: "Camera isn't available on this device. Try Upload Photo or run the app on a physical iPhone/iPad."
            )
            return
        }

        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.modalPresentationStyle = .fullScreen
        picker.delegate = pickerDelegate
        present(picker, animated: false)
    }
}
