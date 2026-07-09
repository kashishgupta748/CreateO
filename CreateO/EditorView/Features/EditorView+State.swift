import SwiftUI

extension EditorView {
    var isAnyEditorModeActive: Bool {
        isBrushActive || isFilterActive || isBorderActive || isDoodleActive || focusedTextID != nil
    }

    var shouldShowBottomToolbar: Bool {
        !isBrushActive && !isFilterActive && !isBorderActive && focusedTextID == nil
    }

    var selectedCanvasImage: CanvasImage? {
        guard let imageActionTargetID else { return nil }
        return canvasImages.first { $0.element.id == imageActionTargetID }
    }

    var layerItems: [LayerSheetItem] {
        let images = canvasImages.map {
            LayerSheetItem(
                id: layerIdentifier(forImageID: $0.element.id),
                title: $0.element.elementType == .sticker ? "Sticker" : "Image",
                subtitle: $0.element.elementType == .sticker ? "Sticker" : "Image",
                zIndex: $0.element.zIndex,
                isVisible: $0.isVisible,
                thumbnail: .image($0.image)
            )
        }
        let texts = canvasTexts.map {
            LayerSheetItem(
                id: layerIdentifier(forTextID: $0.id),
                title: "Text",
                subtitle: "Text",
                zIndex: $0.zIndex,
                isVisible: $0.isVisible,
                thumbnail: .symbol("textformat")
            )
        }
        let brush = brushHasContent
            ? [LayerSheetItem(id: brushLayerIdentifier(), title: "Brush", subtitle: "Stroke", zIndex: brushLayerZIndex, isVisible: isBrushLayerVisible, thumbnail: .symbol("paintbrush.pointed.fill"))]
            : []

        return (images + texts + brush).sorted { $0.zIndex > $1.zIndex }
    }

    func adaptiveCanvasSize(
        _ availableSize: CGSize,
        _ horizontalSizeClass: UserInterfaceSizeClass?,
        _ verticalSizeClass: UserInterfaceSizeClass?
    ) -> CGSize {
        let horizontalPadding = horizontalSizeClass == .regular ? 48.0 : 24.0
        let verticalPadding = verticalSizeClass == .compact ? 20.0 : 36.0
        let maxWidth = min(max(availableSize.width - horizontalPadding, 220), 520)
        let maxHeight = max(availableSize.height - verticalPadding, 320)

        var width = min(maxWidth, maxHeight * Self.canvasAspectRatio)
        var height = width / Self.canvasAspectRatio

        if height > maxHeight {
            height = maxHeight
            width = height * Self.canvasAspectRatio
        }

        return CGSize(width: width, height: height)
    }

    func loadInitialContentIfNeeded() {
        guard !didLoadInitialContent else { return }
        didLoadInitialContent = true

        if let editingDesign {
            loadEditableDesign(editingDesign)
        } else {
            addCanvasImages(initialImportedImages, shouldRecordHistory: false)
        }

        resetHistory()
    }

    func loadEditableDesign(_ design: Design) {
        designName = design.designName
        selectedSaveAlbumID = design.albumID

        if let projectPath = design.projectPath,
           loadSavedProject(from: projectPath) {
            return
        }

        if let fallbackImage = DesignImageLoader.image(for: design.designPath) {
            addCanvasImages([fallbackImage], shouldRecordHistory: false)
        }
    }

    func clearSelection() {
        isBrushActive = false
        dismissImageActions()
        showBrushActionMenu = false
        selectedImageID = nil
        selectedTextID = nil
        focusedTextID = nil
    }
}
