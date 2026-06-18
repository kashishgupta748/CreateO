import SwiftUI

struct EditorToolbar: ToolbarContent {
    @Environment(FirstDesignGuideManager.self) private var guideManager

    let isAnyEditorModeActive: Bool
    let canUndo: Bool
    let canRedo: Bool
    let onCloseOrDismiss: () -> Void
    let onDoneOrSave: () -> Void
    let onUndo: () -> Void
    let onRedo: () -> Void
    let onFilter: () -> Void
    let onDoodle: () -> Void
    let onBrush: () -> Void
    let onSticker: () -> Void
    let onText: () -> Void
    let onTemplate: () -> Void
    let onUpload: () -> Void

    struct ToolbarAction: Identifiable {
        let id: String
        let symbol: String
        let title: String
        let action: () -> Void
    }

    enum BottomToolbarItem: Identifiable {
        case action(ToolbarAction)
        case upload

        var id: String {
            switch self {
            case .action(let action):
                return action.id
            case .upload:
                return "upload"
            }
        }
    }

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(action: onCloseOrDismiss) {
                Image(systemName: isAnyEditorModeActive ? "xmark" : "chevron.backward")
            }
        }

        ToolbarItem(placement: .principal) {
            HStack(spacing: 12) {
                toolbarIconButton(symbol: "arrow.uturn.backward", title: "Undo", isEnabled: canUndo, action: onUndo)
                toolbarIconButton(symbol: "arrow.uturn.forward", title: "Redo", isEnabled: canRedo, action: onRedo)
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button(action: onDoneOrSave) {
                Image(systemName: "checkmark")
                    .font(.system(size: isAnyEditorModeActive ? 17 : 18, weight: .semibold))
                    .foregroundStyle(isAnyEditorModeActive ? Color.white : Color.primary)
                    .frame(
                        width: isAnyEditorModeActive ? 42 : 28,
                        height: isAnyEditorModeActive ? 42 : 28
                    )
                    .background {
                        if isAnyEditorModeActive {
                            Circle()
                                .fill(Color.accentColor)
                                .shadow(color: Color.accentColor.opacity(0.2), radius: 8, y: 4)
                        }
                    }
                    .contentShape(Circle())
            }
            .guideHighlight(
                .editorSave,
                isActive: guideManager.currentStep == .saveDesign
            )
            .buttonStyle(.plain)
            .accessibilityLabel(isAnyEditorModeActive ? "Done" : "Save")
        }

    }

    private var filterAction: ToolbarAction {
        ToolbarAction(id: "filter", symbol: "wand.and.sparkles", title: "Filter") {
            onFilter()
        }
    }

    private var doodleAction: ToolbarAction {
        ToolbarAction(id: "doodle", symbol: "scribble.variable", title: "Doodle") {
            onDoodle()
        }
    }

    private var brushAction: ToolbarAction {
        ToolbarAction(id: "brush", symbol: "paintbrush.pointed.fill", title: "Brush") {
            onBrush()
        }
    }

    private var stickerAction: ToolbarAction {
        ToolbarAction(id: "sticker", symbol: "face.smiling.inverse", title: "Sticker") {
            onSticker()
        }
    }

    private var textAction: ToolbarAction {
        ToolbarAction(id: "text", symbol: "textformat", title: "Text") {
            onText()
        }
    }

    private var templateAction: ToolbarAction {
        ToolbarAction(id: "template", symbol: "square.grid.2x2", title: "Template") {
            onTemplate()
        }
    }

    private func toolbarIconButton(symbol: String, title: String, isEnabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.35)
        .accessibilityLabel(title)
    }
}
