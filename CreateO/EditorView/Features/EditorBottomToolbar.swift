import SwiftUI

struct EditorBottomToolbar: View {
    @Environment(FirstDesignGuideManager.self) private var guideManager

    let items: [EditorToolbar.BottomToolbarItem]
    let onUpload: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                toolbarItems
            }
            .frame(maxWidth: .infinity)

            ScrollViewReader { scrollProxy in
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        toolbarItems
                    }
                    .padding(.horizontal, 4)
                }
                .scrollIndicators(.hidden)
                .onAppear {
                    scrollToActiveGuideItem(with: scrollProxy, animated: false)
                }
                .onChange(of: guideManager.currentStep?.id) { _, _ in
                    scrollToActiveGuideItem(with: scrollProxy, animated: true)
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
                    .guideHighlight(
                        guideAnchor(for: action.id),
                        isActive: guideManager.currentStep?.anchor == guideAnchor(for: action.id)
                    )
            case .upload:
                uploadToolbarButton
                    .id("upload")
                    .guideHighlight(
                        .editorUpload,
                        isActive: guideManager.currentStep?.anchor == .editorUpload
                    )
            }
        }
    }

    private func guideAnchor(for id: String) -> GuideAnchor {
        switch id {
        case "doodle":
            return .editorDoodle
        case "template":
            return .editorColors
        case "filter":
            return .editorFilters
        case "text":
            return .editorText
        case "sticker":
            return .editorStickers
        case "brush":
            return .editorAdjustments
        default:
            return .editorAdjustments
        }
    }

    private func itemID(for anchor: GuideAnchor?) -> String? {
        switch anchor {
        case .editorFilters:
            return "filter"
        case .editorDoodle:
            return "doodle"
        case .editorAdjustments:
            return "brush"
        case .editorUpload:
            return "upload"
        case .editorStickers:
            return "sticker"
        case .editorText:
            return "text"
        case .editorColors:
            return "template"
        default:
            return nil
        }
    }

    private func scrollToActiveGuideItem(with scrollProxy: ScrollViewProxy, animated: Bool) {
        guard let itemID = itemID(for: guideManager.currentStep?.anchor) else { return }

        DispatchQueue.main.async {
            if animated {
                withAnimation(.snappy(duration: 0.28)) {
                    scrollProxy.scrollTo(itemID, anchor: .center)
                }
            } else {
                scrollProxy.scrollTo(itemID, anchor: .center)
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
