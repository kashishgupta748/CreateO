import SwiftUI
import Photos
import PhotosUI

struct DesignView: View {
    @State private var showCamera = false
    @State private var selectedImage: UIImage?
    @State private var cameraErrorMessage: String?
    @State private var showUploadLibrary = false
    @State private var pendingEditorImages: [UIImage] = []
    @State private var showAddOptions = false
    @State private var showStoryBoard = false
    @State private var showEditor = false
    @State private var showSortMenu = false

    @Environment(DataStore.self) var designStore
    @State public var layoutMode: LayoutMode = .grid
    @Environment(\.horizontalSizeClass) private var hSize

    private var isPadLike: Bool { hSize == .regular }
    private let ideaAccent = Color(
        red: 109.0 / 255.0,
        green: 124.0 / 255.0,
        blue: 1.0
    )

    private var columns: [GridItem] {
        [
            GridItem(.adaptive(minimum: isPadLike ? 180 : 150, maximum: 280), spacing: 18)
        ]
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topTrailing) {
                Group {
                    if designStore.designs.isEmpty {
                        emptyStateView
                    } else {
                        ScrollView {
                            DesignGridView(
                                designs: designStore.designs,
                                layoutMode: layoutMode,
                                masonColumn: isPadLike ? 4 : 2,
                                columns: columns,
                                onAddTap: openFirstDesignOptions
                            )
                        }
                        .background(Color(.systemGroupedBackground))
                    }
                }
                
                if showSortMenu {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                showSortMenu = false
                            }
                        }
                        .ignoresSafeArea()
                    
                    sortDropdownMenu
                }
            }
            .navigationTitle(designStore.designs.isEmpty ? "" : "Designs")
            .navigationBarTitleDisplayMode(designStore.designs.isEmpty ? .inline : .large)
            .toolbar {
                DesignToolbar(layoutMode: $layoutMode, showSortMenu: $showSortMenu)
            }
            .sheet(isPresented: $showAddOptions) {
                AddDesignOptionsSheet(
                    createCanvas: startBlankCanvas,
                    clickPicture: startCamera,
                    uploadPicture: startUpload,
                    createStory: startStory
                )
                .presentationDetents([.height(324)])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showCamera) {
                CameraPicker(
                    image: $selectedImage,
                    errorMessage: $cameraErrorMessage
                )
            }
            .sheet(isPresented: $showUploadLibrary) {
                DesignPhotoLibraryPicker(
                    images: $pendingEditorImages,
                    isPresented: $showUploadLibrary,
                    showEditor: $showEditor
                )
            }
            .navigationDestination(isPresented: $showEditor) {
                EditorView(initialImportedImages: pendingEditorImages)
            }
            .navigationDestination(isPresented: $showStoryBoard) {
                StoryBoard()
            }
        }
        .onChange(of: selectedImage) { _, newImage in
            guard let newImage else { return }
            pendingEditorImages = [newImage]
            showEditor = true
            selectedImage = nil
        }
        .alert(
            "Camera Unavailable",
            isPresented: Binding(
                get: { cameraErrorMessage != nil },
                set: { if !$0 { cameraErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(cameraErrorMessage ?? "")
        }
    }

    // MARK: EMPTY UI - 1st user

    private var emptyStateView: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 700
            let horizontalPadding: CGFloat = isPadLike ? 40 : 28
            let contentWidth = min(
                max(proxy.size.width - (horizontalPadding * 2), 1),
                isPadLike ? 520 : 430
            )
            let imageHeight = min(
                max(proxy.size.width * (compact ? 0.72 : 0.90), compact ? 245 : 310),
                isPadLike ? 460 : 405
            )
            let titleToSubtitle: CGFloat = compact ? 12 : 18
            let topAlignmentInset = min(max(proxy.size.height * 0.04, compact ? 10 : 18), compact ? 20 : 34)
            let buttonBottomInset = min(max(proxy.size.height * 0.025, compact ? 8 : 12), compact ? 16 : 24)
            let titleCenterY = topAlignmentInset + (compact ? 58 : 72)
            let buttonGap: CGFloat = compact ? 24 : 34
            let buttonMaxCenterY = proxy.size.height - buttonBottomInset - 28
            let preferredImageCenterY = proxy.size.height * (compact ? 0.48 : 0.50)
            let minimumImageCenterY = titleCenterY + imageHeight / 2 + 42
            let maximumImageCenterY = buttonMaxCenterY - 28 - buttonGap - imageHeight / 2
            let imageCenterLimitY = max(minimumImageCenterY, maximumImageCenterY)
            let imageCenterY = min(max(preferredImageCenterY, minimumImageCenterY), imageCenterLimitY)
            let preferredButtonCenterY = imageCenterY + imageHeight / 2 + buttonGap + 28
            let buttonCenterY = min(preferredButtonCenterY, buttonMaxCenterY)

            ScrollView {
                ZStack {
                    VStack(spacing: 0) {
                        Text("Welcome to CreateO")
                            .font(.system(size: compact ? 29 : 34, weight: .bold))
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)

                        Text("Draw, edit, and stylize\neveryday moments into designs.")
                            .font(.system(size: compact ? 16 : 18, weight: .regular))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.top, titleToSubtitle)
                            .frame(maxWidth: contentWidth)
                    }
                    .frame(width: contentWidth)
//                    .position(x: proxy.size.width / 2, y: titleCenterY)
//
//                    Image("duck")
//                        .resizable()
//                        .scaledToFit()
//                        .frame(width: contentWidth, height: imageHeight, alignment: .center)
//                        .position(x: proxy.size.width / 2, y: imageCenterY)
                    
                    VStack(spacing: 0) {
                        Button(action: {
                            startBlankCanvas()
                        }) {
                            Text("Create Your First Design")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .frame(width: contentWidth)
                    }
                    .position(x: proxy.size.width / 2, y: buttonCenterY)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: proxy.size.height)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background(Color(.systemGroupedBackground))
            .scrollIndicators(.hidden)
        }
    }

    // MARK: ACTIONS

    private func startBlankCanvas() {
        dismissAddOptionsThen {
            pendingEditorImages = []
            showEditor = true
        }
    }

    private func startCamera() {
        dismissAddOptionsThen(delay: 0.4) {
            showCamera = true
        }
    }

    private func startUpload() {
        pendingEditorImages.removeAll()
        showEditor = false
        showUploadLibrary = false
        dismissAddOptionsThen(delay: 0.35) {
            showUploadLibrary = true
        }
    }

    private func startStory() {
        dismissAddOptionsThen {
            showStoryBoard = true
        }
    }

    private func openFirstDesignOptions() {
        showAddOptions = true
    }

    private func dismissAddOptionsThen(
        delay: TimeInterval = 0.2,
        _ action: @escaping () -> Void
    ) {
        showAddOptions = false
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            action()
        }
    }

    private var sortDropdownMenu: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Sort Designs")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 8)
            
            Divider()
                .padding(.horizontal, 16)
            
            VStack(alignment: .leading, spacing: 2) {
                dropdownButton(title: "Grid View", icon: "square.grid.2x2", mode: .grid)
                dropdownButton(title: "Week wise", icon: "calendar", mode: .week)
                dropdownButton(title: "Month wise", icon: "calendar.circle", mode: .month)
                dropdownButton(title: "Year wise", icon: "calendar.badge.clock", mode: .year)
            }
            .padding(.vertical, 6)
        }
        .frame(width: 200)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .padding(.top, 8)
        .padding(.trailing, 16)
        .transition(.asymmetric(
            insertion: .scale(scale: 0.9, anchor: .topTrailing).combined(with: .opacity),
            removal: .scale(scale: 0.9, anchor: .topTrailing).combined(with: .opacity)
        ))
        .zIndex(100)
    }

    private func dropdownButton(title: String, icon: String, mode: LayoutMode) -> some View {
        let isSelected = layoutMode == mode
        return Button {
            withAnimation(.snappy(duration: 0.2)) {
                layoutMode = mode
                showSortMenu = false
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.accentColor : .primary)
                    .frame(width: 20)
                
                Text(title)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.accentColor : .primary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

@MainActor
private struct DesignPhotoLibraryPicker: UIViewControllerRepresentable {
    @Binding var images: [UIImage]
    @Binding var isPresented: Bool
    @Binding var showEditor: Bool

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
        private let parent: DesignPhotoLibraryPicker

        init(_ parent: DesignPhotoLibraryPicker) {
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

                    parent.images = loadedImages
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [self] in
                        parent.showEditor = true
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

// MARK: CARDS

private struct HomeQuickCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    let height: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .center, spacing: 0) {
                HStack {
                    Spacer(minLength: 0)

                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [tint.opacity(0.92), tint.opacity(0.78)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Image(systemName: icon)
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 70, height: 70)
                    .shadow(color: tint.opacity(0.2), radius: 12, y: 8)

                    Spacer(minLength: 0)
                }

                Spacer(minLength: 24)

                VStack(alignment: .center, spacing: 7) {
                    Text(title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .center)

                Spacer(minLength: 16)
            }
            .padding(18)
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(.systemBackground), tint.opacity(0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.black.opacity(0.04), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.035), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
    }

}

// MARK: SHEET

private struct AddDesignOptionsSheet: View {
    @Environment(\.dismiss) private var dismiss

    let createCanvas: () -> Void
    let clickPicture: () -> Void
    let uploadPicture: () -> Void
    let createStory: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                SheetRow(
                    title: "Blank Canvas",
                    subtitle: "Start fresh and create from scratch.",
                    icon: "square.and.pencil",
                    action: createCanvas
                )

                sheetDivider

                SheetRow(
                    title: "Take Photo",
                    subtitle: "Capture a moment and edit your way.",
                    icon: "camera.fill",
                    action: clickPicture
                )

                sheetDivider

                SheetRow(
                    title: "Upload Photo",
                    subtitle: "Import images and customize creatively.",
                    icon: "photo",
                    action: uploadPicture
                )

                sheetDivider

                SheetRow(
                    title: "Create Story",
                    subtitle: "Build your own stories with your designs.",
                    icon: "play.rectangle.on.rectangle.fill",
                    action: createStory
                )
            }
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .navigationTitle("New Design")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .cancel) {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                    }
                }
            }
        }
    }

    private var sheetDivider: some View {
        Divider()
            .padding(.leading, 70)
            .padding(.trailing, 24)
    }
}

private struct SheetRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {

                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.tertiarySystemFill))

                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))

                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.80)
                        .allowsTightening(true)
                }
                .layoutPriority(1)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let store = DataStore()

    DesignView()
        .environment(store)
}
