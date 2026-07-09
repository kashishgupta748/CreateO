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
    @State var showDiscardChangesAlert = false
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
    @State var showBackgroundRemovalFailedAlert = false
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
            }
            .alert(
                "Leave Canvas?",
                isPresented: $showDiscardChangesAlert
            ) {
                Button("Keep Editing", role: .cancel) { }
                Button("Save") {
                    dismissImageActions()
                    showSaveSheet = true
                }
                Button("Discard Changes", role: .destructive) {
                    dismiss()
                }
            } message: {
                Text("If you go back now, the changes on this canvas will not be saved.")
            }
            .alert(
                "Background Removal Failed",
                isPresented: $showBackgroundRemovalFailedAlert
            ) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Could not detect a clear subject in this photo. Try using a photo where the subject stands out from the background.")
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
                .overlay(alignment: .bottom) {
                    if hasActiveEditorOverlay {
                        activeEditorOverlay
                            .padding(.horizontal, 10)
                            .padding(.bottom, 8)
                    }
                }
                .task {
                    loadInitialContentIfNeeded()
                }
        }
    }

    var isEmojiActionTarget: Bool {
        guard let id = imageActionTargetID else { return false }
        return canvasImages.first(where: { $0.element.id == id })?.element.elementType == .emojis
    }
}
