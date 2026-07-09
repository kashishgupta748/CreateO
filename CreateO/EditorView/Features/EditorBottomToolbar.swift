import SwiftUI

struct EditorBottomToolbar: View {

    let items: [EditorToolbar.BottomToolbarItem]
    let onUpload: () -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                toolbarItems
            }
            .padding(.horizontal, 4)
        }
        .scrollIndicators(.hidden)
        .frame(width: 309, alignment: .leading)
    }

    private var toolbarItems: some View {
        ForEach(items) { item in
            switch item {
            case .action(let action):
                toolbarButton(symbol: action.symbol, title: action.title, isEnabled: action.isEnabled, action: action.action)
                    .id(action.id)
            case .upload:
                uploadToolbarButton
                    .id("upload")
            }
        }
    }


    private func toolbarButton(symbol: String, title: String, isEnabled: Bool, action:  @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 18, height: 18)
                    .offset(x: symbol == "textformat" ? 1 : 0)

                Text(title)
                    .font(.system(size: 11.5, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(.primary)
            .frame(width: 58)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.34)
    }

    private var uploadToolbarButton: some View {
        Button(action: onUpload) {
            VStack(spacing: 6) {
                Image(systemName: "photo.badge.plus.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 18, height: 18)

                Text("Upload")
                    .font(.system(size: 11.5, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(.primary)
            .frame(width: 58)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
