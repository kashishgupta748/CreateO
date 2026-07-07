import SwiftUI

extension EditorView {
    var editorContent: some View {
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
    func canvasSection(geometry: GeometryProxy) -> some View {
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

    @ViewBuilder
    var activeEditorOverlay: some View {
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

    @ViewBuilder
    var imageActionOverlay: some View {
        if showImageActionMenu {
            ZStack {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismissImageActions()
                    }

                if isEmojiActionTarget {
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
}
