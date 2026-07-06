import SwiftUI

struct EditorBottomToolbar: View {

    let items: [EditorToolbar.BottomToolbarItem]
    let onUpload: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                toolbarItems
            }
            .frame(maxWidth: .infinity)

            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    toolbarItems
                }
                .padding(.horizontal, 4)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var toolbarItems: some View {
        ForEach(items) { item in
            switch item {
            case .action(let action):
                toolbarButton(symbol: action.symbol, title: action.title, action: action.action)
                    .id(action.id)
            case .upload:
                uploadToolbarButton
                    .id("upload")
            }
        }
    }



    private func toolbarButton(symbol: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 20, height: 20)
                    .offset(x: symbol == "textformat" ? 1 : 0)
                Text(title)
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(.primary)
            .frame(width: 58)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var uploadToolbarButton: some View {
        Button(action: onUpload) {
            VStack(spacing: 6) {
                Image(systemName: "photo.badge.plus.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 20, height: 20)
                Text("Upload")
                    .font(.caption2)
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
