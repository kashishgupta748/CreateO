import SwiftUI

struct EditorImageActionMenu: View {
    @Environment(FirstDesignGuideManager.self) private var guideManager

    let onCrop: () -> Void
    let onDoodle: () -> Void
    let onFilters: () -> Void
    let onBackground: () -> Void
    let onBorder: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                topActionButton(symbol: "crop", title: "Crop", action: onCrop)

                topActionButton(symbol: "scribble", title: "doodle", action: onDoodle)

                topActionButton(symbol: "wand.and.stars", title: "filters", action: onFilters)
            }
            .padding(.top, 18)
            .padding(.bottom, 14)

            Divider()
                .padding(.horizontal, 18)

            menuRow(
                symbol: "person.crop.square.fill",
                title: "Background Remove",
                guideAnchor: .imageBackground,
                action: onBackground
            )

            Divider()
                .padding(.horizontal, 18)

            menuRow(
                symbol: "square.dashed",
                title: "Border",
                guideAnchor: .imageBorder,
                action: onBorder
            )

            Divider()
                .padding(.horizontal, 18)

            menuRow(symbol: "doc.on.doc", title: "Duplicate", action: onDuplicate)

            Divider()
                .padding(.horizontal, 18)

            menuRow(symbol: "trash", title: "Delete", isDestructive: true, action: onDelete)
        }
        .frame(width: 292)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 14, y: 8)
    }

    private func topActionButton(symbol: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .regular))
                Text(title)
                    .font(.system(size: 15))
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    private func menuRow(
        symbol: String,
        title: String,
        guideAnchor: GuideAnchor? = nil,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 18) {
                Image(systemName: symbol)
                    .font(.system(size: 21, weight: .regular))
                    .frame(width: 28)
                Text(title)
                    .font(.system(size: 17))
                Spacer()
            }
            .foregroundStyle(isDestructive ? .red : .primary)
            .padding(.horizontal, 20)
            .frame(height: 58)
        }
        .buttonStyle(.plain)
        .guideHighlight(
            guideAnchor ?? .editorCanvas,
            isActive: guideAnchor.map { guideManager.currentStep?.anchor == $0 } ?? false
        )
    }
}
