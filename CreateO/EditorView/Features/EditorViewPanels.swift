import SwiftUI

enum EditorSaveDestination {
    case library
    case existingAlbum(UUID)
    case newAlbum(String)
}

struct EditorFilterPicker: View {
    let selectedFilter: Filter
    let previewImage: UIImage?
    let onSelectFilter: (Filter) -> Void

    @State private var previewCache: [Filter: UIImage] = [:]

    private let filters: [Filter] = [.original, .animeStyle, .smooth, .watercolor, .pencilcolor, .crayon]
    private let previewSize = CGSize(width: 72, height: 92)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(filters, id: \.self) { filter in
                        filterCell(filter)
                    }
                }
                .padding(.horizontal, 2)
            }
            .frame(height: previewSize.height + 22)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .task(id: previewTaskID) {
            await generatePreviewsIfNeeded()
        }
    }

    private var header: some View {
        Text("Filters")
            .font(.title3.weight(.semibold))
            .padding(.horizontal, 2)
    }

    private var previewTaskID: String {
        let imageKey = previewImage?.pngData()?.hashValue ?? 0
        return "\(selectedFilter.rawValue)-\(imageKey)"
    }

    @ViewBuilder
    private func filterCell(_ filter: Filter) -> some View {
        let isSelected = selectedFilter == filter

        Button {
            onSelectFilter(filter)
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                ZStack(alignment: .bottomLeading) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                        .frame(width: previewSize.width, height: previewSize.height)
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(isSelected ? Color.accentColor : Color.white.opacity(0.3), lineWidth: isSelected ? 2.2 : 1)
                        }

                    Group {
                        if let image = previewCache[filter] ?? previewImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                        } else {
                            ZStack {
                                LinearGradient(
                                    colors: [Color(.systemGray6), Color(.systemGray5)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                Image(systemName: filter.icon)
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(width: previewSize.width, height: previewSize.height)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    LinearGradient(
                        colors: [Color.clear, Color.black.opacity(0.28)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    Text(filter.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 5)
                }
                .shadow(color: isSelected ? Color.accentColor.opacity(0.14) : Color.black.opacity(0.05), radius: isSelected ? 8 : 4, y: 3)
                .scaleEffect(isSelected ? 1 : 0.98)

                Text(filter.title)
                    .font(.footnote.weight(isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? Color.accentColor : .primary)
                    .lineLimit(1)
                    .padding(.leading, 4)
            }
            .frame(width: previewSize.width)
        }
        .buttonStyle(.plain)
    }

    @MainActor
    private func generatePreviewsIfNeeded() async {
        guard let previewImage else {
            previewCache = [:]
            return
        }

        let targetImage = previewImage.editorFilterPreviewImage(targetSize: CGSize(width: 132, height: 132))
        let imageKey = targetImage.pngData()?.hashValue ?? 0

        if previewCache.count == filters.count,
           previewCache[.original]?.pngData()?.hashValue == imageKey {
            return
        }

        let rendered = await Task.detached(priority: .userInitiated) { () -> [Filter: UIImage] in
            var results: [Filter: UIImage] = [.original: targetImage]
            guard let sourceCG = targetImage.cgImage else { return results }

            for filter in filters where filter != .original {
                let renderedCG = ImageFilterProcessor.applySynchronously(filter, to: sourceCG)
                results[filter] = UIImage(cgImage: renderedCG)
            }
            return results
        }.value

        previewCache = rendered
    }
}

private extension UIImage {
    func editorFilterPreviewImage(targetSize: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            UIColor.white.setFill()
            UIBezierPath(rect: CGRect(origin: .zero, size: targetSize)).fill()

            let scale = max(targetSize.width / size.width, targetSize.height / size.height)
            let drawSize = CGSize(width: size.width * scale, height: size.height * scale)
            let drawRect = CGRect(
                x: (targetSize.width - drawSize.width) / 2,
                y: (targetSize.height - drawSize.height) / 2,
                width: drawSize.width,
                height: drawSize.height
            )
            draw(in: drawRect)
        }
    }
}

struct EditorTextStylePanel: View {
    let selectedFontName: String
    let selectedTextColor: Color
    @Binding var selectedTextSize: Double
    let onSelectFontName: (String) -> Void
    let onSelectTextColor: (Color) -> Void
    let onBeginSizeEditing: () -> Void
    let onCommitSizeEditing: () -> Void
    let onPreviewTextSize: (Double) -> Void

    @State private var isEditingSize = false

    private let fontPresets: [EditorFontPreset] = [
        EditorFontPreset(title: "System", fontName: UIFont.systemFont(ofSize: 20, weight: .regular).fontName),
        EditorFontPreset(title: "Rounded", fontName: EditorFontPreset.roundedFontName),
        EditorFontPreset(title: "Serif", fontName: "TimesNewRomanPSMT"),
        EditorFontPreset(title: "Mono", fontName: UIFont.monospacedSystemFont(ofSize: 20, weight: .regular).fontName)
    ]

    private let colorPresets: [Color] = [
        .black,
        Color.accentColor,
        .green,
        .orange,
        .pink,
        .red
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Text")
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Text("\(Int(selectedTextSize))")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(fontPresets) { preset in
                        fontChip(for: preset)
                    }
                }
                .padding(.horizontal, 2)
            }
            .scrollIndicators(.hidden)

            HStack(spacing: 10) {
                Text("A")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)

                Slider(
                    value: $selectedTextSize,
                    in: 16...120,
                    onEditingChanged: { editing in
                        if editing {
                            isEditingSize = true
                            onBeginSizeEditing()
                        } else {
                            onCommitSizeEditing()
                            isEditingSize = false
                        }
                    }
                )
                .tint(.accentColor)

                Text("A")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                ForEach(Array(colorPresets.enumerated()), id: \.offset) { _, color in
                    colorSwatch(for: color)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .onChange(of: selectedTextSize) { _, newValue in
            guard isEditingSize else { return }
            onPreviewTextSize(newValue)
        }
    }

    private func fontChip(for preset: EditorFontPreset) -> some View {
        let isSelected = selectedFontName == preset.fontName

        return Button {
            onSelectFontName(preset.fontName)
        } label: {
            Text(preset.title)
                .font(.custom(preset.fontName, size: 15))
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentColor.opacity(0.15) : Color(.secondarySystemBackground))
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
                )
                .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
    }

    private func colorSwatch(for color: Color) -> some View {
        let isSelected = selectedTextColor == color

        return Button {
            onSelectTextColor(color)
        } label: {
            Circle()
                .fill(color)
                .frame(width: 28, height: 28)
                .overlay {
                    Circle()
                        .stroke(isSelected ? Color.accentColor : Color.white.opacity(0.4), lineWidth: isSelected ? 2 : 1)
                }
        }
        .buttonStyle(.plain)
    }
}

private struct EditorFontPreset: Identifiable {
    let id = UUID()
    let title: String
    let fontName: String

    static let roundedFontName = UIFont.systemFont(ofSize: 20, weight: .regular, width: .standard).fontName
}
