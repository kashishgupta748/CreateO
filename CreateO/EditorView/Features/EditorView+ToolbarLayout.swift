import SwiftUI

extension EditorView {
    var editorBottomControlBar: some View {
        EditorBottomToolbar(
            items: bottomToolbarItems,
            onUpload: startUpload
        )
    }

    var bottomToolbarItems: [EditorToolbar.BottomToolbarItem] {
        let hasCanvasImage = !canvasImages.isEmpty

        return [
            .action(EditorToolbar.ToolbarAction(id: "filter", symbol: "wand.and.sparkles", title: "Filter", isEnabled: hasCanvasImage) {
                activateFilterMode()
            }),
            .action(EditorToolbar.ToolbarAction(id: "doodle", symbol: "scribble.variable", title: "Doodle", isEnabled: hasCanvasImage) {
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
                    dismissImageActions()
                    showDiscardChangesAlert = true
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

        if shouldShowBottomToolbar {
            ToolbarItem(placement: .bottomBar) {
                editorBottomControlBar
            }
        }
    }
}
