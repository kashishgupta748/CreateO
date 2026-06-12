import SwiftUI

struct EditorLayerSheetView: View {
    let layerItems: [LayerSheetItem]
    @Binding var selectedImageID: UUID?
    @Binding var selectedTextID: UUID?
    let selectImage: (UUID) -> Void
    let selectText: (UUID) -> Void
    let selectBrush: () -> Void
    let toggleImage: (UUID) -> Void
    let toggleText: (UUID) -> Void
    let toggleBrush: () -> Void
    let duplicateImage: (UUID) -> Void
    let duplicateText: (UUID) -> Void
    let duplicateBrush: () -> Void
    let deleteImage: (UUID) -> Void
    let deleteText: (UUID) -> Void
    let deleteBrush: () -> Void
    let moveLayer: (String, String) -> Void

    @State private var draggedLayerID: String?

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let layoutMetrics = layoutMetrics(for: geometry.size.width)

                VStack(spacing: 18) {
                    Text("Layers")
                        .font(.system(size: layoutMetrics.titleFontSize, weight: .bold))
                        .padding(.top, 18)

                    if layerItems.isEmpty {
                        EditorLayerSheetEmptyState(metrics: layoutMetrics)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 14) {
                                ForEach(Array(layerItems.enumerated()), id: \.element.id) { offset, item in
                                    layerRow(for: item, at: offset + 1, metrics: layoutMetrics)
                                    .opacity(draggedLayerID == item.id ? 0.7 : 1)
                                    .scaleEffect(draggedLayerID == item.id ? 0.96 : 1)
                                    .draggable(item.id) {
                                        layerPreview(for: item, at: offset + 1, metrics: layoutMetrics)
                                            .scaleEffect(0.96)
                                            .opacity(0.7)
                                            .onAppear {
                                                draggedLayerID = item.id
                                                select(item.id)
                                            }
                                    }
                                    .dropDestination(for: String.self) { _, _ in
                                        if let draggedLayerID {
                                            select(draggedLayerID)
                                        }
                                        self.draggedLayerID = nil
                                        return true
                                    } isTargeted: { isTargeted in
                                        if isTargeted, let draggedLayerID, draggedLayerID != item.id {
                                            select(draggedLayerID)
                                            moveLayer(draggedLayerID, item.id)
                                        }
                                    }
                                    .onTapGesture { select(item.id) }
                                }
                            }
                            .padding(.top, 8)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 24)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(Color(uiColor: .systemBackground))
            }
        }
    }

    private func layerRow(for item: LayerSheetItem, at index: Int, metrics: LayerSheetMetrics) -> some View {
        EditorLayerSheetRow(
            item: item,
            displayIndex: index,
            metrics: metrics,
            isSelected: isSelected(item.id),
            isDragPreview: false,
            onToggle: { toggle(item.id) },
            onDuplicate: { duplicate(item.id) },
            onDelete: { delete(item.id) }
        )
    }

    private func layerPreview(for item: LayerSheetItem, at index: Int, metrics: LayerSheetMetrics) -> some View {
        EditorLayerSheetRow(
            item: item,
            displayIndex: index,
            metrics: metrics,
            isSelected: isSelected(item.id),
            isDragPreview: true,
            onToggle: {},
            onDuplicate: {},
            onDelete: {}
        )
    }

    private func isSelected(_ id: String) -> Bool {
        if id.hasPrefix("image:"), let uuid = UUID(uuidString: String(id.split(separator: ":").last ?? "")) {
            return selectedImageID == uuid
        }
        if id.hasPrefix("text:"), let uuid = UUID(uuidString: String(id.split(separator: ":").last ?? "")) {
            return selectedTextID == uuid
        }
        return selectedImageID == nil && selectedTextID == nil && id == "brush"
    }

    private func select(_ id: String) {
        if id == "brush" { selectBrush(); return }
        if let uuid = UUID(uuidString: String(id.split(separator: ":").last ?? "")) {
            if id.hasPrefix("image:") { selectImage(uuid) }
            if id.hasPrefix("text:") { selectText(uuid) }
        }
    }

    private func toggle(_ id: String) {
        if id == "brush" { toggleBrush(); return }
        if let uuid = UUID(uuidString: String(id.split(separator: ":").last ?? "")) {
            if id.hasPrefix("image:") { toggleImage(uuid) }
            if id.hasPrefix("text:") { toggleText(uuid) }
        }
    }

    private func duplicate(_ id: String) {
        if id == "brush" { duplicateBrush(); return }
        if let uuid = UUID(uuidString: String(id.split(separator: ":").last ?? "")) {
            if id.hasPrefix("image:") { duplicateImage(uuid) }
            if id.hasPrefix("text:") { duplicateText(uuid) }
        }
    }

    private func delete(_ id: String) {
        if id == "brush" { deleteBrush(); return }
        if let uuid = UUID(uuidString: String(id.split(separator: ":").last ?? "")) {
            if id.hasPrefix("image:") { deleteImage(uuid) }
            if id.hasPrefix("text:") { deleteText(uuid) }
        }
    }

    private func layoutMetrics(for width: CGFloat) -> LayerSheetMetrics {
        let compact = width < 390
        return LayerSheetMetrics(
            titleFontSize: compact ? 24 : 28,
            emptyIconSize: compact ? 34 : 40,
            emptyTitleSize: compact ? 21 : 24,
            emptyBodySize: compact ? 13 : 15,
            rowTitleSize: compact ? 15 : 16,
            rowSubtitleSize: compact ? 12 : 13,
            rowIconSize: compact ? 14 : 15,
            rowControlSize: compact ? 34 : 38,
            thumbnailSize: compact ? 52 : 58,
            thumbnailIconSize: compact ? 18 : 20,
            rowPadding: compact ? 14 : 16
        )
    }
}

struct LayerSheetMetrics {
    let titleFontSize: CGFloat
    let emptyIconSize: CGFloat
    let emptyTitleSize: CGFloat
    let emptyBodySize: CGFloat
    let rowTitleSize: CGFloat
    let rowSubtitleSize: CGFloat
    let rowIconSize: CGFloat
    let rowControlSize: CGFloat
    let thumbnailSize: CGFloat
    let thumbnailIconSize: CGFloat
    let rowPadding: CGFloat
}
