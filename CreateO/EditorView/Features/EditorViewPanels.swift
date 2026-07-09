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
    let isBold: Bool
    let isItalic: Bool
    let isUnderlined: Bool
    let onSelectFontName: (String) -> Void
    let onSelectTextColor: (Color) -> Void
    let onToggleBold: () -> Void
    let onToggleItalic: () -> Void
    let onToggleUnderline: () -> Void
    let onBeginSizeEditing: () -> Void
    let onCommitSizeEditing: () -> Void
    let onPreviewTextSize: (Double) -> Void

    @State private var isEditingSize = false
    @State private var sizeInput = ""

    @FocusState private var isSizeFieldFocused: Bool

    private let systemFontPresets: [EditorFontPreset] = [
        EditorFontPreset(title: "System", fontName: UIFont.preferredFont(forTextStyle: .body).fontName),
        EditorFontPreset(title: "Bold", fontName: UIFont.systemFont(ofSize: 20, weight: .bold).fontName),
        EditorFontPreset(title: "Rounded", fontName: EditorFontPreset.roundedFontName()),
        EditorFontPreset(title: "Serif", fontName: EditorFontPreset.serifFontName()),
        EditorFontPreset(title: "Mono", fontName: EditorFontPreset.monospacedFontName())
    ]

    private let colorPresets: [Color] = [
        .black,
        .white,
        Color(red: 0.36, green: 0.39, blue: 0.45),
        .blue,
        .green,
        .orange,
        .red
    ]

    private var deviceFonts: [EditorFontPreset] {
        UIFont.familyNames
            .sorted()
            .compactMap { familyName in
                guard let fontName = UIFont.fontNames(forFamilyName: familyName).sorted().first else {
                    return nil
                }
                return EditorFontPreset(title: familyName, fontName: fontName)
            }
    }

    private var isUsingCustomColor: Bool {
        !colorPresets.contains { SavedColor($0) == SavedColor(selectedTextColor) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            previewRow
            formattingSection
            sizeSection
            fontSection
            colorSection
        }
        .padding(12)
        .frame(maxWidth: 400)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.55), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 16, y: 8)
        .onAppear {
            syncSizeInput(with: selectedTextSize)
        }
        .onChange(of: selectedTextSize) { _, newValue in
            if !isSizeFieldFocused {
                syncSizeInput(with: newValue)
            }
            guard isEditingSize else { return }
            onPreviewTextSize(newValue)
        }
    }

    private var header: some View {
        EmptyView()
    }

    private var previewRow: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Live Preview")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Text("Text")
                    .font(previewFont)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(selectedTextColor)
                    .underline(isUnderlined, color: selectedTextColor)
                    .lineLimit(1)
            }

            Spacer()

            Text(displaySizeValue)
                .font(.footnote.weight(.semibold))
                .monospacedDigit()
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.secondarySystemBackground), in: Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.systemBackground).opacity(0.85), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var formattingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Style")

            HStack(spacing: 8) {
                formattingButton(title: "B", isActive: isBold, accessibilityLabel: "Bold", action: onToggleBold)
                formattingButton(title: "I", isActive: isItalic, accessibilityLabel: "Italic", action: onToggleItalic)
                formattingButton(title: "U", isActive: isUnderlined, accessibilityLabel: "Underline", action: onToggleUnderline)
            }
        }
    }

    private var sizeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionLabel("Size")
                Spacer()
                sizeInputField
            }

            HStack(spacing: 8) {
                sizeButton(systemName: "minus") {
                    nudgeTextSize(by: -2)
                }

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
                            syncSizeInput(with: selectedTextSize)
                        }
                    }
                )
                .tint(.accentColor)

                sizeButton(systemName: "plus") {
                    nudgeTextSize(by: 2)
                }
            }
        }
    }

    private var sizeInputField: some View {
        TextField("34", text: $sizeInput)
            .font(.caption.weight(.semibold))
            .multilineTextAlignment(.center)
            .keyboardType(.numberPad)
            .focused($isSizeFieldFocused)
            .frame(width: 44)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .onTapGesture {
                sizeInput = ""
            }
            .onChange(of: isSizeFieldFocused) { _, focused in
                if !focused {
                    commitTypedSizeInput()
                }
            }
    }

    private var fontSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Font")

            Menu {
                Section("System Styles") {
                    ForEach(systemFontPresets) { preset in
                        Button {
                            onSelectFontName(preset.fontName)
                        } label: {
                            Text(preset.title)
                                .font(.custom(preset.fontName, size: 16))
                        }
                    }
                }

                Section("Installed Fonts") {
                    ForEach(deviceFonts) { preset in
                        Button {
                            onSelectFontName(preset.fontName)
                        } label: {
                            Text(preset.title)
                                .font(.custom(preset.fontName, size: 16))
                        }
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "textformat")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Text("Font")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Color")

            HStack(spacing: 8) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(colorPresets.enumerated()), id: \.offset) { _, color in
                            colorSwatch(for: color)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                }
                .padding(.vertical, 1)

                customColorControl
            }
        }
    }

    private var customColorControl: some View {
        ColorPicker(
            "Custom Color",
            selection: Binding(
                get: { selectedTextColor },
                set: { newValue in
                    onSelectTextColor(newValue)
                }
            ),
            supportsOpacity: false
        )
        .labelsHidden()
        .frame(width: 28, height: 28)
        .padding(5)
        .background(Color(.secondarySystemBackground), in: Circle())
        .overlay {
            Circle()
                .stroke(isUsingCustomColor ? Color.accentColor : Color.clear, lineWidth: 2.5)
        }
        .frame(width: 38, height: 38)
    }

    private var currentFontLabel: String {
        systemFontPresets.first(where: { $0.fontName == selectedFontName })?.title
        ?? deviceFonts.first(where: { $0.fontName == selectedFontName })?.title
        ?? "Selected Font"
    }

    private var displaySizeValue: String {
        String(Int(selectedTextSize.rounded()))
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
    }

    private var previewFont: Font {
        Font(selectedUIFont)
    }

    private var selectedUIFont: UIFont {
        let baseFont = UIFont(name: selectedFontName, size: 28) ?? .systemFont(ofSize: 28)
        var traits = baseFont.fontDescriptor.symbolicTraits
        if isBold {
            traits.insert(.traitBold)
        }
        if isItalic {
            traits.insert(.traitItalic)
        }
        let descriptor = baseFont.fontDescriptor.withSymbolicTraits(traits) ?? baseFont.fontDescriptor
        return UIFont(descriptor: descriptor, size: 28)
    }

    private func formattingButton(title: String, isActive: Bool, accessibilityLabel: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isActive ? Color.accentColor.opacity(0.16) : Color(.secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isActive ? Color.accentColor : Color.clear, lineWidth: 1.5)
                )
                .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private func sizeButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 28, height: 28)
                .background(Color(.secondarySystemBackground), in: Circle())
        }
        .buttonStyle(.plain)
    }

    private func colorSwatch(for color: Color) -> some View {
        let isSelected = SavedColor(selectedTextColor) == SavedColor(color)

        return Button {
            onSelectTextColor(color)
        } label: {
            Circle()
                .fill(color)
                .frame(width: 26, height: 26)
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(SavedColor(color) == SavedColor(.white) ? 0.76 : 0.2), lineWidth: 1)
                }
                .overlay {
                    if isSelected {
                        Circle()
                            .stroke(Color.accentColor, lineWidth: 2.5)
                            .frame(width: 34, height: 34)
                    }
                }
                .overlay {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(SavedColor(color) == SavedColor(.white) ? Color.black : Color.white)
                    }
                }
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
    }

    private func nudgeTextSize(by delta: Double) {
        let newValue = min(max(selectedTextSize + delta, 16), 120)
        guard abs(newValue - selectedTextSize) > 0.001 else { return }

        onBeginSizeEditing()
        selectedTextSize = newValue
        onPreviewTextSize(newValue)
        onCommitSizeEditing()
        isEditingSize = false
        syncSizeInput(with: newValue)
    }

    private func commitTypedSizeInput() {
        let filteredInput = sizeInput.filter(\.isNumber)
        guard let typedValue = Double(filteredInput), !filteredInput.isEmpty else {
            syncSizeInput(with: selectedTextSize)
            return
        }

        let clampedValue = min(max(typedValue, 16), 120)
        guard abs(clampedValue - selectedTextSize) > 0.001 else {
            syncSizeInput(with: clampedValue)
            return
        }

        onBeginSizeEditing()
        selectedTextSize = clampedValue
        onPreviewTextSize(clampedValue)
        onCommitSizeEditing()
        isEditingSize = false
        syncSizeInput(with: clampedValue)
    }

    private func syncSizeInput(with value: Double) {
        sizeInput = "\(Int(value.rounded()))"
    }
}

private struct EditorFontPreset: Identifiable {
    let id = UUID()
    let title: String
    let fontName: String

    static func roundedFontName() -> String {
        let descriptor = UIFont.systemFont(ofSize: 20, weight: .semibold).fontDescriptor
        return descriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: 20).fontName } ?? UIFont.systemFont(ofSize: 20, weight: .semibold).fontName
    }

    static func serifFontName() -> String {
        let descriptor = UIFont.systemFont(ofSize: 20, weight: .semibold).fontDescriptor
        return descriptor.withDesign(.serif).map { UIFont(descriptor: $0, size: 20).fontName } ?? "TimesNewRomanPSMT"
    }

    static func monospacedFontName() -> String {
        UIFont.monospacedSystemFont(ofSize: 20, weight: .medium).fontName
    }
}
