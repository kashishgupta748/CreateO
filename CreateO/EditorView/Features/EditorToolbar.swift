import SwiftUI

struct EditorToolbar: ToolbarContent {

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
        let isEnabled: Bool
        let action: () -> Void

        init(id: String, symbol: String, title: String, isEnabled: Bool = true, action: @escaping () -> Void) {
            self.id = id
            self.symbol = symbol
            self.title = title
            self.isEnabled = isEnabled
            self.action = action
        }
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
            if isAnyEditorModeActive {
                Button(action: onDoneOrSave) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.circle)
                .tint(.accentColor)
                .controlSize(.large)
                .animation(.none, value: isAnyEditorModeActive)
                .accessibilityLabel("Done")
            } else {
                Button(action: onDoneOrSave) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .animation(.none, value: isAnyEditorModeActive)
                .accessibilityLabel("Save")
            }
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
