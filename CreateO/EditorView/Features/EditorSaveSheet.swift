import SwiftUI

struct EditorSaveSheet: View {

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
                }
                .disabled(!isSaveEnabled)
            }
            .contentMargins(.top, 8, for: .scrollContent)
            .contentMargins(.bottom, 18, for: .scrollContent)
            .navigationTitle("Save Design")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
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
            onSave(.library)
        case .existingAlbum:
            guard let selectedAlbumID else { return }
            onSave(.existingAlbum(selectedAlbumID))
        case .newAlbum:
            let trimmedAlbumName = newAlbumName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedAlbumName.isEmpty else { return }
            onSave(.newAlbum(trimmedAlbumName))
        }
    }
}
