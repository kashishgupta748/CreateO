import SwiftUI

extension EditorView {
    var stickerSheet: some View {
        Sticker(
            savedStickers: $savedStickers,
            selectedSticker: $selectedSticker,
            recentStickers: $recentStickers
        )
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    var templateSheet: some View {
        EditorTemplatePicker(selectedColor: canvasColor) { color in
            applyCanvasColorTemplate(color)
            guideManager.advance(from: .editorColors)
            showTemplateSheet = false
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(30)
    }

    var saveSheet: some View {
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
    var cropSheet: some View {
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

    var layerSheet: some View {
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

    func openLayerSheet() {
        dismissImageActions()
        showLayerSheet = true
    }

    func startUpload() {
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
