import SwiftUI


enum EditorSaveDestination {
    case library
    case existingAlbum(UUID)
    case newAlbum(String)
}

struct EditorFilterPicker: View {
    let selectedFilter: Filter
    let onSelectFilter: (Filter) -> Void

    private let filters = Filter.allCases

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Filters")
                .font(.headline)
            
            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(filters, id: \.self) { filter in
                        filterCell(filter)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal)
    }
    
    private func filterCell(_ filter: Filter) -> some View {
        let isSelected = selectedFilter == filter
        return VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.accentColor : Color(.secondarySystemFill))
                    .frame(width: 60, height: 60)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(
                                isSelected ? Color.accentColor : Color(.separator),
                                lineWidth: isSelected ? 0 : 1
                            )
                    )
                Image(systemName: filter.icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(isSelected ? .white : .primary)
            }
            .onTapGesture {
                onSelectFilter(filter)
            }
            
            Text(filter.title)
                .font(.caption2)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? Color.accentColor : .primary)
        }
        .frame(width: 64)
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
        .onChange(of: selectedTextSize) { _, newSize in
            if isEditingSize {
                onPreviewTextSize(newSize)
            }
        }
    }

    private func fontChip(for preset: EditorFontPreset) -> some View {
        let isSelected = selectedFontName == preset.fontName

        return Button {
            onSelectFontName(preset.fontName)
        } label: {
            HStack(spacing: 6) {
                Text("Aa")
                    .font(.custom(preset.fontName, size: 15))
                    .foregroundStyle(isSelected ? .white : .primary)

                Text(preset.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : .primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.accentColor : Color(.secondarySystemFill))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : Color.black.opacity(0.08), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func colorSwatch(for color: Color) -> some View {
        let isSelected = SavedColor(color) == SavedColor(selectedTextColor)

        return Button {
            onSelectTextColor(color)
        } label: {
            Circle()
                .fill(color)
                .frame(width: 28, height: 28)
                .overlay {
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                }
                .overlay {
                    Circle()
                        .stroke(
                            isSelected ? Color.accentColor : Color.black.opacity(0.12),
                            lineWidth: isSelected ? 2.5 : 1
                        )
                        .padding(isSelected ? -4 : -2)
                }
        }
        .buttonStyle(.plain)
    }
}

private struct EditorFontPreset: Identifiable {
    let title: String
    let fontName: String

    var id: String { fontName + title }

    static var roundedFontName: String {
        let roundedDescriptor = UIFont.systemFont(ofSize: 20, weight: .semibold)
            .fontDescriptor
            .withDesign(.rounded) ?? UIFont.systemFont(ofSize: 20, weight: .semibold).fontDescriptor
        return UIFont(descriptor: roundedDescriptor, size: 20).fontName
    }
}

struct EditorSaveSheet: View {
    @Environment(FirstDesignGuideManager.self) private var guideManager

    @Binding var designName: String
    let albums: [Album]
    @Binding var selectedAlbumID: UUID?
    @Binding var newAlbumName: String
    let onSave: (EditorSaveDestination) -> Void

    @State private var selectedOption: SaveOption = .library

    private enum SaveOption: String, CaseIterable, Identifiable {
        case library
        case existingAlbum
        case newAlbum

        var id: String { rawValue }

        var title: String {
            switch self {
            case .library:
                return "Designs"
            case .existingAlbum:
                return "Existing Album"
            case .newAlbum:
                return "New Album"
            }
        }

        var subtitle: String {
            switch self {
            case .library:
                return "Save to Designs only"
            case .existingAlbum:
                return "Add this design to an album"
            case .newAlbum:
                return "Make a new album and save there"
            }
        }
    }

    private var isSaveEnabled: Bool {
        switch selectedOption {
        case .library:
            return true
        case .existingAlbum:
            return selectedAlbumID != nil
        case .newAlbum:
            return !newAlbumName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Design name", text: $designName)
                }

                Section("Save To") {
                    Picker("", selection: $selectedOption) {
                        ForEach(SaveOption.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.inline)
                }

                if selectedOption == .existingAlbum {
                    Section("Album") {
                        if albums.isEmpty {
                            Text("No albums available")
                                .foregroundStyle(.secondary)
                        } else {
                            Picker("Album", selection: $selectedAlbumID) {
                                Text("Select album").tag(nil as UUID?)
                                ForEach(albums) { album in
                                    Text(album.albumName).tag(Optional(album.id))
                                }
                            }
                        }
                    }
                }

                if selectedOption == .newAlbum {
                    Section("New Album") {
                        TextField("Album name", text: $newAlbumName)
                    }
                }

                Section {
                    Button(saveButtonTitle, action: handleSave)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .guideHighlight(
                            .editorSave,
                            isActive: guideManager.currentStep == .saveDesign
                        )
                }
                .disabled(!isSaveEnabled)
            }
            .contentMargins(.top, 8, for: .scrollContent)
            .contentMargins(.bottom, 18, for: .scrollContent)
            .navigationTitle("Save Design")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                guideManager.show(.saveDesign)
            }
        }
        .presentationDetents([.medium, .large])
        .firstDesignGuideOverlay(manager: guideManager)
    }

    private var saveButtonTitle: String {
        switch selectedOption {
        case .library:
            return "Save"
        case .existingAlbum:
            return "Save To Album"
        case .newAlbum:
            return "Create Album And Save"
        }
    }

    private func handleSave() {
        switch selectedOption {
        case .library:
            guideManager.advance(from: .saveDesign)
            onSave(.library)
        case .existingAlbum:
            guard let selectedAlbumID else { return }
            guideManager.advance(from: .saveDesign)
            onSave(.existingAlbum(selectedAlbumID))
        case .newAlbum:
            let trimmedAlbumName = newAlbumName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedAlbumName.isEmpty else { return }
            guideManager.advance(from: .saveDesign)
            onSave(.newAlbum(trimmedAlbumName))
        }
    }
}
