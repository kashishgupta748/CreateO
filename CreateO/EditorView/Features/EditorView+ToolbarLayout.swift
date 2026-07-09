import SwiftUI

extension EditorView {
    var editorBottomControlBar: some View {
        VStack(spacing: 6) {
            if shouldShowBottomToolbar {
                EditorBottomToolbar(
                    items: bottomToolbarItems,
                    onUpload: startUpload
                )
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .bottomToolbarGlass()
                .padding(.horizontal, 24)
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 3)
        .frame(maxWidth: .infinity)
        .background {
            Rectangle()
                .fill(.clear)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    var bottomToolbarItems: [EditorToolbar.BottomToolbarItem] {
        [
            .action(EditorToolbar.ToolbarAction(id: "filter", symbol: "wand.and.sparkles", title: "Filter") {
                activateFilterMode()
            }),
            .action(EditorToolbar.ToolbarAction(id: "doodle", symbol: "scribble.variable", title: "Doodle") {
                toggleDoodleMode()
            }),
            .action(EditorToolbar.ToolbarAction(id: "brush", symbol: "paintbrush.pointed.fill", title: "Brush") {
                toggleBrushMode()
            }),
            .upload,
            .action(EditorToolbar.ToolbarAction(id: "sticker", symbol: "face.smiling.inverse", title: "Sticker") {
                openStickerSheet()
            }),
            .action(EditorToolbar.ToolbarAction(id: "text", symbol: "textformat", title: "Text") {
                isDoodleActive = false
                addTextLayer()
            }),
            .action(EditorToolbar.ToolbarAction(id: "template", symbol: "square.grid.2x2", title: "Template") {
                openTemplateSheet()
            })
        ]
    }

    @ToolbarContentBuilder
    var editorToolbar: some ToolbarContent {
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
}

private extension View {
    @ViewBuilder
    func bottomToolbarGlass() -> some View {
        if #available(iOS 26.0, *) {
            self
                .glassEffect(.regular, in: Capsule())
        } else {
            self
                .background(.regularMaterial, in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.35), lineWidth: 0.8)
                }
                .shadow(color: Color.black.opacity(0.12), radius: 16, y: 8)
        }
    }
}
