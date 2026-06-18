import PhotosUI
import PencilKit
import SwiftUI
import UIKit

struct EditorView: View {
    static let canvasAspectRatio: CGFloat = 7.0 / 12.0

    let editingDesign: Design?
    let initialImportedImages: [UIImage]

    init(editingDesign: Design? = nil, initialImportedImages: [UIImage] = []) {
        self.editingDesign = editingDesign
        self.initialImportedImages = initialImportedImages
        _designName = State(initialValue: editingDesign?.designName ?? "")
        _selectedSaveAlbumID = State(initialValue: editingDesign?.albumID)
    }

    @Environment(DataStore.self) var designStore
    @Environment(AuthManager.self) var authManager
    @Environment(FirstDesignGuideManager.self) var guideManager
    @Environment(\.dismiss) var dismiss
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass

    @State var canvasImages: [CanvasImage] = []
    @State var canvasTexts: [CanvasText] = []
    @State var showUploadLibrary = false

    @State var showSheet = false
    @State var showTemplateSheet = false
    @State var canvasColor: Color = .white
    @State var showSaveSheet = false
    @State var isBrushActive = false
    @State var isFilterActive = false
    @State var isBorderActive = false
    @State var isDoodleActive = false
    @State var showImageActionMenu = false
    @State var imageActionTargetID: UUID?
    @State var imageActionMenuPosition: CGPoint = .zero
    @State var showLayerSheet = false
    @State var showTextActionMenu = false
    @State var textActionTargetID: UUID?
    @State var selectedTextSizeDraft: Double = 34
    @State var showCropSheet = false
    @State var backgroundRemovalImageID: UUID?
    @State var showBrushActionMenu = false
    @State var brushLayerZIndex = 0
    @State var isBrushLayerVisible = true
    @State var brushHasContent = false

    @State var designName: String
    @State var selectedSaveAlbumID: UUID?
    @State var newAlbumName = ""
    @State var selectedImageID: UUID?
    @State var activeImageInteractionID: UUID?
    @State var selectedTextID: UUID?
    @State var focusedTextID: UUID?
    @State var selectedFilter: Filter = .original
    @State var borderEditingImageID: UUID?
    @State var borderDraftWidth: Double = 0
    @State var borderDraftColor: SavedColor = SavedColor(red: 0, green: 0, blue: 0, alpha: 1)
    @State var borderOriginalWidth: Double = 0
    @State var borderOriginalColor: SavedColor = SavedColor(red: 0, green: 0, blue: 0, alpha: 1)
    @State var isEditingTextSize = false

    @State var savedStickers: [UIImage] = []
    @State var selectedSticker: UIImage?
    @State var selectedEmoji: String?
    @State var recentStickers: [UIImage] = []

    @State var drawingCanvas = PKCanvasView()
    @State var toolPicker = PKToolPicker()
    @State var currentCanvasSize = CGSize(width: 350, height: 600)
    @State var didLoadInitialContent = false
    @State var undoStack: [EditorHistorySnapshot] = []
    @State var redoStack: [EditorHistorySnapshot] = []
    @State var activeHistorySnapshot: EditorHistorySnapshot?
    @State var isRestoringHistory = false

    var body: some View {
        editorNavigation
            .toolbar(.hidden, for: .tabBar)
            .sheet(isPresented: $showSheet) {
                stickerSheet
            }
            .onChange(of: selectedSticker) { _, _ in
                addSelectedStickerToCanvas()
            }
            .onChange(of: selectedEmoji) { _, emoji in
                guard let emoji else { return }
                addEmojiToCanvas(emoji)
                selectedEmoji = nil
            }
            .sheet(isPresented: $showTemplateSheet) {
                templateSheet
            }
            .sheet(isPresented: $showSaveSheet) {
                saveSheet
            }
            .sheet(isPresented: $showCropSheet) {
                cropSheet
            }
            .sheet(isPresented: $showLayerSheet) {
                layerSheet
            }
            .sheet(isPresented: $showUploadLibrary) {
                EditorPhotoLibraryPicker(isPresented: $showUploadLibrary) { images in
                    addCanvasImages(images)
                }
            }
            .confirmationDialog("Brush Options", isPresented: $showBrushActionMenu, titleVisibility: .visible) {
                Button("Duplicate") {
                    duplicateBrushDrawing()
                }
                Button("Delete", role: .destructive) {
                    deleteBrushDrawing()
                }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog("Text Options", isPresented: $showTextActionMenu, titleVisibility: .visible) {
                Button("Style") {
                    showTextActionMenu = false
                    if let textActionTargetID {
                        selectTextLayer(textActionTargetID)
                    }
                }
                Button("Duplicate") {
                    duplicateSelectedText()
                }
                Button("Delete", role: .destructive) {
                    deleteSelectedText()
                }
                Button("Cancel", role: .cancel) {}
            }
            .overlay {
                imageActionOverlay
            }
            .onChange(of: selectedTextID) { _, _ in
                syncSelectedTextSizeDraft()
            }
            .onAppear {
                syncSelectedTextSizeDraft()
                guideManager.showIfNeeded(.editorColors)
            }
    }

    private var editorNavigation: some View {
        NavigationStack {
            editorContent
                .toolbarTitleDisplayMode(.inline)
                .navigationBarBackButtonHidden(true)
                .toolbar {
                    editorToolbar
                }
                .task {
                    loadInitialContentIfNeeded()
                }
                .overlay(alignment: .bottom) {
                    activeEditorOverlay
                }
        }
    }

    private var editorContent: some View {
        GeometryReader { geometry in
            VStack {
                Spacer(minLength: 12)
                canvasSection(geometry: geometry)
                Spacer(minLength: 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private func canvasSection(geometry: GeometryProxy) -> some View {
        EditorCanvasView(
            canvasImages: $canvasImages,
            canvasTexts: $canvasTexts,
            canvasColor: $canvasColor,
            selectedImageID: $selectedImageID,
            activeImageInteractionID: $activeImageInteractionID,
            backgroundRemovalImageID: $backgroundRemovalImageID,
            selectedTextID: $selectedTextID,
            focusedTextID: $focusedTextID,
            drawingCanvas: $drawingCanvas,
            toolPicker: $toolPicker,
            brushHasContent: $brushHasContent,
            currentCanvasSize: $currentCanvasSize,
            isBrushActive: isBrushActive,
            isBrushLayerVisible: isBrushLayerVisible,
            brushLayerZIndex: brushLayerZIndex,
            availableSize: geometry.size,
            horizontalSizeClass: horizontalSizeClass,
            verticalSizeClass: verticalSizeClass,
            adaptiveCanvasSize: adaptiveCanvasSize,
            clearSelection: clearSelection,
            presentImageActions: presentImageActions,
            bringLayerToFront: bringLayerToFront,
            dismissImageActions: dismissImageActions,
            presentTextActions: presentTextActions,
            removeTextLayerIfEmpty: removeTextLayerIfEmpty,
            presentBrushActions: presentBrushActions,
            brushDrawingUsedForGuide: brushDrawingUsedForGuide,
            openLayerSheet: openLayerSheet,
            beginHistoryTransaction: beginHistoryTransaction,
            endHistoryTransaction: endHistoryTransaction
        )
    }

    @ToolbarContentBuilder
    private var editorToolbar: some ToolbarContent {
        EditorToolbar(
            isAnyEditorModeActive: isAnyEditorModeActive,
            canUndo: canUndo,
            canRedo: canRedo,
            onCloseOrDismiss: {
                if isAnyEditorModeActive {
                    closeActiveEditorMode()
                } else {
                    dismiss()
                }
            },
            onDoneOrSave: {
                if isAnyEditorModeActive {
                    completeActiveEditorMode()
                } else {
                    dismissImageActions()
                    guideManager.show(.saveDesign)
                    showSaveSheet = true
                }
            },
            onUndo: undo,
            onRedo: redo,
            onFilter: {
                activateFilterMode()
            },
            onDoodle: {
                toggleDoodleMode()
            },
            onBrush: {
                toggleBrushMode()
            },
            onSticker: {
                openStickerSheet()
            },
            onText: {
                isDoodleActive = false
                addTextLayer()
            },
            onTemplate: {
                openTemplateSheet()
            },
            onUpload: {
                startUpload()
            }
        )
    }

    @ViewBuilder
    private var activeEditorOverlay: some View {
        if isFilterActive {
            EditorFilterPicker(selectedFilter: selectedFilter, onSelectFilter: applyFilterSelection)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding()
        } else if isBorderActive {
            EditorBorderPicker(
                borderWidth: Binding(
                    get: { borderDraftWidth },
                    set: { newValue in
                        borderDraftWidth = newValue
                        previewBorderChanges()
                    }
                ),
                borderColor: Binding(
                    get: { borderDraftColor.color },
                    set: { newValue in
                        borderDraftColor = SavedColor(newValue)
                        previewBorderChanges()
                    }
                )
            )
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding()
        } else if let textStyleBinding = selectedTextStyleBinding {
            EditorTextStylePanel(
                selectedFontName: textStyleBinding.fontName,
                selectedTextColor: textStyleBinding.textColor,
                selectedTextSize: $selectedTextSizeDraft,
                onSelectFontName: applySelectedTextFont,
                onSelectTextColor: applySelectedTextColor,
                onBeginSizeEditing: beginTextSizeEditing,
                onCommitSizeEditing: commitTextSizeEditing,
                onPreviewTextSize: previewSelectedTextSize
            )
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding()
        }
    }

    /// True when the currently targeted image action element is an emoji.
    private var isEmojiActionTarget: Bool {
        guard let id = imageActionTargetID else { return false }
        return canvasImages.first(where: { $0.element.id == id })?.element.elementType == .emojis
    }

    @ViewBuilder
    private var imageActionOverlay: some View {
        if showImageActionMenu {
            ZStack {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismissImageActions()
                    }

                if isEmojiActionTarget {
                    // Emojis only get Duplicate + Delete
                    EmojiActionMenu(
                        onDuplicate: {
                            if let imageActionTargetID {
                                duplicateLayer(imageActionTargetID)
                            }
                        },
                        onDelete: {
                            if let imageActionTargetID {
                                deleteLayer(imageActionTargetID)
                            }
                        }
                    )
                    .position(imageActionMenuPosition)
                } else {
                    EditorImageActionMenu(
                        onCrop: openCropSheet,
                        onDoodle: {
                            dismissImageActions()
                            isDoodleActive = true
                            applyFilterSelection(.doodle)
                        },
                        onFilters: openImageFilters,
                        onBackground: {
                            removeBackgroundFromSelectedImage()
                        },
                        onBorder: {
                            openBorderEditor()
                        },
                        onDuplicate: {
                            if let imageActionTargetID {
                                duplicateLayer(imageActionTargetID)
                            }
                        },
                        onDelete: {
                            if let imageActionTargetID {
                                deleteLayer(imageActionTargetID)
                            }
                        }
                    )
                    .position(imageActionMenuPosition)
                }
            }
        }
    }

    private var stickerSheet: some View {
        Sticker(
            savedStickers: $savedStickers,
            selectedSticker: $selectedSticker,
            recentStickers: $recentStickers,
            selectedEmoji: $selectedEmoji
        )
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private var templateSheet: some View {
        EditorTemplatePicker(selectedColor: canvasColor) { color in
            applyCanvasColorTemplate(color)
            guideManager.advance(from: .editorColors)
            showTemplateSheet = false
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(30)
    }

    private var saveSheet: some View {
        EditorSaveSheet(
            designName: $designName,
            albums: designStore.albums,
            selectedAlbumID: $selectedSaveAlbumID,
            newAlbumName: $newAlbumName
        ) { destination in
            saveDesign(in: designStore, dismiss: dismiss, destination: destination)
        }
    }

    @ViewBuilder
    private var cropSheet: some View {
        if let image = selectedCanvasImage {
            ImageCropSheet(
                image: image.image,
                onCancel: {
                    showCropSheet = false
                },
                onApply: { croppedImage in
                    applyCropImage(croppedImage)
                    showCropSheet = false
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(30)
        }
    }

    private var layerSheet: some View {
        EditorLayerSheet(
            layerItems: layerItems,
            selectedImageID: $selectedImageID,
            selectedTextID: $selectedTextID,
            selectImage: selectLayer,
            selectText: selectTextLayer,
            selectBrush: selectBrushLayer,
            toggleImage: toggleLayerVisibility,
            toggleText: toggleTextLayerVisibility,
            toggleBrush: toggleBrushLayerVisibility,
            duplicateImage: duplicateLayer,
            duplicateText: duplicateTextLayer,
            duplicateBrush: duplicateBrushDrawing,
            deleteImage: deleteLayer,
            deleteText: deleteTextLayer,
            deleteBrush: deleteBrushDrawing,
            moveLayer: { source, target in
                moveLayer(source, target)
            }
        )
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(30)
    }

    private func openLayerSheet() {
        dismissImageActions()
        showLayerSheet = true
    }

    private func startUpload() {
        isFilterActive = false
        isBrushActive = false
        isDoodleActive = false
        dismissImageActions()
        showUploadLibrary = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            showUploadLibrary = true
        }
    }
}

@MainActor
private struct EditorPhotoLibraryPicker: UIViewControllerRepresentable {
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
