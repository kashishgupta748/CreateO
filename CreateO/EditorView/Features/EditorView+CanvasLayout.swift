import SwiftUI

extension EditorView {
    var editorContent: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Spacer(minLength: isTextStylePanelVisible ? 2 : 12)
                canvasSection(geometry: geometry)
                Spacer(minLength: isTextStylePanelVisible ? 2 : 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, 10)
            .padding(.top, 4)
            .padding(.bottom, isTextStylePanelVisible ? 0 : 8)
            .animation(.easeInOut(duration: 0.2), value: isTextStylePanelVisible)
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
            bringTextLayerToFront: bringTextLayerToFront,
            presentBrushActions: presentBrushActions,
            openLayerSheet: openLayerSheet,
            beginHistoryTransaction: beginHistoryTransaction,
            endHistoryTransaction: endHistoryTransaction
        )
    }

    @ViewBuilder
    var activeEditorOverlay: some View {
        if isFilterActive {
            EditorFilterPicker(
                selectedFilter: selectedFilter,
                previewImage: selectedCanvasImage?.image,
                onSelectFilter: applyFilterSelection
            )
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.32), lineWidth: 1)
                }
                .shadow(color: Color.black.opacity(0.06), radius: 8, y: 4)
                .padding(.horizontal, 10)
                .padding(.top, 6)
                .padding(.bottom, 2)
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
        } else if focusedTextID == nil, let textStyleBinding = selectedTextStyleBinding {
            EditorTextStylePanel(
                selectedFontName: textStyleBinding.fontName,
                selectedTextColor: textStyleBinding.textColor,
                selectedTextSize: $selectedTextSizeDraft,
                isBold: textStyleBinding.isBold,
                isItalic: textStyleBinding.isItalic,
                isUnderlined: textStyleBinding.isUnderlined,
                onSelectFontName: applySelectedTextFont,
                onSelectTextColor: applySelectedTextColor,
                onToggleBold: toggleSelectedTextBold,
                onToggleItalic: toggleSelectedTextItalic,
                onToggleUnderline: toggleSelectedTextUnderline,
                onBeginSizeEditing: beginTextSizeEditing,
                onCommitSizeEditing: commitTextSizeEditing,
                onPreviewTextSize: previewSelectedTextSize
            )
            .padding(.horizontal, 10)
            .padding(.bottom, 4)
            .transition(.move(edge: .bottom).combined(with: .opacity))
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
