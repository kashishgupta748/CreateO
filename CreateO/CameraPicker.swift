import AVFoundation
import Combine
import SwiftUI
import UIKit

@MainActor
struct CameraPicker: View {
    @Binding var image: UIImage?
    @Binding var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = CameraCaptureModel()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let capturedImage = camera.capturedImage {
                capturedPhotoView(capturedImage)
            } else {
                liveCameraView
            }
        }
        .task {
            await camera.prepareIfNeeded()
            if camera.unavailableMessage != nil {
                errorMessage = camera.unavailableMessage
                dismiss()
            }
        }
        .onDisappear {
            camera.stopSession()
        }
    }

    private var liveCameraView: some View {
        ZStack {
            CameraPreviewView(session: camera.session)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    glassIconButton("xmark") {
                        dismiss()
                    }

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)

                Spacer()

                VStack(spacing: 18) {
                    Text("Take Photo")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))

                    Button {
                        camera.capturePhoto()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(.white.opacity(0.22))
                                .frame(width: 82, height: 82)

                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 70, height: 70)
                                .overlay {
                                    Circle()
                                        .stroke(.white.opacity(0.85), lineWidth: 3)
                                }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(!camera.isReady)
                    .opacity(camera.isReady ? 1 : 0.45)
                }
                .padding(.bottom, 28)
            }
        }
    }

    private func capturedPhotoView(_ capturedImage: UIImage) -> some View {
        ZStack {
            Image(uiImage: capturedImage)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    glassIconButton("chevron.left") {
                        camera.retake()
                    }

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)

                Spacer()

                HStack(spacing: 14) {
                    glassActionButton(title: "Retake", systemImage: "camera.rotate") {
                        camera.retake()
                    }

                    glassActionButton(title: "Use Photo", systemImage: "checkmark") {
                        image = capturedImage.downscaledForCanvas() ?? capturedImage.normalizedForEditing() ?? capturedImage
                        dismiss()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
        }
    }

    private func glassIconButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(glassCircleBackground)
        }
        .buttonStyle(.plain)
    }

    private func glassActionButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(glassCapsuleBackground)
        }
        .buttonStyle(.plain)
    }

    private var glassCircleBackground: AnyView {
        if #available(iOS 26.0, *) {
            return AnyView(
                Circle()
                    .fill(.clear)
                    .glassEffect(.regular, in: Circle())
            )
        } else {
            return AnyView(
                Circle()
                    .fill(.regularMaterial)
                    .overlay {
                        Circle().stroke(.white.opacity(0.28), lineWidth: 0.8)
                    }
            )
        }
    }

    private var glassCapsuleBackground: AnyView {
        if #available(iOS 26.0, *) {
            return AnyView(
                Capsule()
                    .fill(.clear)
                    .glassEffect(.regular, in: Capsule())
            )
        } else {
            return AnyView(
                Capsule()
                    .fill(.regularMaterial)
                    .overlay {
                        Capsule().stroke(.white.opacity(0.28), lineWidth: 0.8)
                    }
            )
        }
    }
}

private struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewContainerView {
        let view = PreviewContainerView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewContainerView, context: Context) {
        uiView.previewLayer.session = session
    }
}

private final class PreviewContainerView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}

@MainActor
private final class CameraCaptureModel: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()

    @Published var capturedImage: UIImage?
    @Published var isReady = false
    var unavailableMessage: String?

    private let output = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "createo.camera.session")
    private var isConfigured = false
    private var didPrepare = false

    func prepareIfNeeded() async {
        guard !didPrepare else {
            startSession()
            return
        }
        didPrepare = true

        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            unavailableMessage = "Camera is not available on this device. Try using Upload instead."
            return
        }

        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            await configureSessionIfNeeded()
            startSession()
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if granted {
                await configureSessionIfNeeded()
                startSession()
            } else {
                unavailableMessage = "Camera access was denied. Allow camera access in Settings to take photos."
            }
        default:
            unavailableMessage = "Camera access is unavailable. Allow camera access in Settings to take photos."
        }
    }

    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .off
        output.capturePhoto(with: settings, delegate: self)
    }

    func retake() {
        capturedImage = nil
        startSession()
    }

    func stopSession() {
        sessionQueue.async {
            guard self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    private func startSession() {
        sessionQueue.async {
            guard self.isConfigured, !self.session.isRunning else { return }
            self.session.startRunning()
            Task { @MainActor in
                self.isReady = true
            }
        }
    }

    private func configureSessionIfNeeded() async {
        guard !isConfigured else { return }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            sessionQueue.async {
                self.session.beginConfiguration()
                self.session.sessionPreset = .photo

                defer {
                    self.session.commitConfiguration()
                    self.isConfigured = true
                    continuation.resume()
                }

                guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                      let input = try? AVCaptureDeviceInput(device: device),
                      self.session.canAddInput(input),
                      self.session.canAddOutput(self.output) else {
                    Task { @MainActor in
                        self.unavailableMessage = "Could not start the camera. Please try again."
                    }
                    return
                }

                self.session.addInput(input)
                self.session.addOutput(self.output)
                self.output.isHighResolutionCaptureEnabled = true
                if self.output.availablePhotoCodecTypes.contains(.hevc) {
                    self.output.maxPhotoDimensions = CMVideoDimensions(width: 3024, height: 4032)
                }
            }
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if error != nil {
            unavailableMessage = "Could not capture the photo. Please try again."
            return
        }

        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            unavailableMessage = "Could not process the photo. Please try again."
            return
        }

        stopSession()
        capturedImage = image.normalizedForEditing() ?? image
    }
}
