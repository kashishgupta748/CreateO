import Dispatch
import SwiftUI

struct EditorLayerButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: "square.3.layers.3d")
                    .font(.system(size: 16, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                Text("Layer")
                    .font(.system(size: 9, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(.primary)
            .frame(width: 48, height: 48)
            .background(Circle().fill(.ultraThinMaterial))
            .overlay(Circle().stroke(Color.white.opacity(0.65), lineWidth: 1))
            .shadow(color: .black.opacity(0.12), radius: 7, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Layers")
    }
}

struct EditorLayerSheet: View {
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

    var body: some View {
        EditorLayerSheetView(
            layerItems: layerItems,
            selectedImageID: $selectedImageID,
            selectedTextID: $selectedTextID,
            selectImage: selectImage,
            selectText: selectText,
            selectBrush: selectBrush,
            toggleImage: toggleImage,
            toggleText: toggleText,
            toggleBrush: toggleBrush,
            duplicateImage: duplicateImage,
            duplicateText: duplicateText,
            duplicateBrush: duplicateBrush,
            deleteImage: deleteImage,
            deleteText: deleteText,
            deleteBrush: deleteBrush,
            moveLayer: moveLayer
        )
    }
}

struct LayerSheetItem: Identifiable {
    enum Thumbnail {
        case image(UIImage)
        case symbol(String)
    }

    let id: String
    let title: String
    let subtitle: String
    let zIndex: Int
    let isVisible: Bool
    let thumbnail: Thumbnail
}

struct EditorLayerSheetEmptyState: View {
    let metrics: LayerSheetMetrics

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.3.layers.3d")
                .font(.system(size: metrics.emptyIconSize, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("No Layers")
                .font(.system(size: metrics.emptyTitleSize, weight: .semibold))
            Text("Add an image, text, or brush stroke to manage layers here.")
                .font(.system(size: metrics.emptyBodySize))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EditorLayerSheetRow: View {
    let item: LayerSheetItem
    let displayIndex: Int
    let metrics: LayerSheetMetrics
    let isSelected: Bool
    let isDragPreview: Bool
    let onToggle: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    private var rowShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
    }

    var body: some View {
        HStack(spacing: 14) {
            EditorLayerSheetThumbnail(item: item, metrics: metrics)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(item.title) \(displayIndex)")
                    .font(.system(size: metrics.rowTitleSize, weight: .medium))
                Text(item.subtitle)
                    .font(.system(size: metrics.rowSubtitleSize))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onToggle) {
                Image(systemName: item.isVisible ? "eye" : "eye.slash")
                    .font(.system(size: metrics.rowIconSize, weight: .semibold))
                    .frame(width: metrics.rowControlSize, height: metrics.rowControlSize)
            }
            .buttonStyle(.plain)

            Menu {
                Button(action: onDuplicate) {
                    Label("Duplicate", systemImage: "doc.on.doc")
                }
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .rotationEffect(.degrees(90))
                    .frame(width: metrics.rowControlSize, height: metrics.rowControlSize)
            }
        }
        .padding(metrics.rowPadding)
        .background {
            rowShape
                .fill(isSelected ? Color.accentColor.opacity(0.11) : Color(.secondarySystemBackground))
        }
        .overlay {
            rowShape
                .stroke(
                    isSelected ? Color.accentColor.opacity(0.62) : Color.black.opacity(0.05),
                    lineWidth: isSelected ? 1.25 : 1
                )
        }
        .opacity(isDragPreview ? 0.96 : 1)
        .clipShape(rowShape)
        .shadow(color: .clear, radius: 0, y: 0)
        .contentShape(.dragPreview, rowShape)
        .contentShape(rowShape)
    }
}

struct EditorLayerSheetThumbnail: View {
    let item: LayerSheetItem
    let metrics: LayerSheetMetrics

    var body: some View {
        switch item.thumbnail {
        case .image(let image):
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: metrics.thumbnailSize, height: metrics.thumbnailSize)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.75), lineWidth: 1) }
        case .symbol(let name):
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.gray.opacity(0.12))
                .frame(width: metrics.thumbnailSize, height: metrics.thumbnailSize)
                .overlay {
                    Image(systemName: name)
                        .font(.system(size: metrics.thumbnailIconSize, weight: .semibold))
                }
        }
    }
}
