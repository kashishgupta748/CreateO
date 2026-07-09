import SwiftUI

struct EditorBottomToolbar: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let items: [EditorToolbar.BottomToolbarItem]
    let onUpload: () -> Void

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                GeometryReader { proxy in
                    ScrollView(.horizontal) {
                        HStack(spacing: 10) {
                            toolbarItems
                        }
                        .padding(.horizontal, 4)
                    }
                    .scrollIndicators(.hidden)
                    .frame(width: compactViewportWidth(for: proxy.size.width), alignment: .leading)
                    .overlay(alignment: .trailing) {
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color(.systemBackground).opacity(0.82)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: 12)
                        .allowsHitTesting(false)
                    }
                }
                .frame(height: 44)
            } else {
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

    private func compactViewportWidth(for availableWidth: CGFloat) -> CGFloat {
        max(min(availableWidth * 0.89, 320), 252)
    }

    private func toolbarButton(symbol: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 17, height: 17)
                    .offset(x: symbol == "textformat" ? 1 : 0)
                Text(title)
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(.primary)
            .frame(width: 54)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var uploadToolbarButton: some View {
        Button(action: onUpload) {
            VStack(spacing: 3) {
                Image(systemName: "photo.badge.plus.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 17, height: 17)
                Text("Upload")
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(.primary)
            .frame(width: 54)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
