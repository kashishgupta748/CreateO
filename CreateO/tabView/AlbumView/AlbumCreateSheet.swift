import SwiftUI

struct AlbumCreateSheet: View {
    @Environment(DataStore.self) private var designStore
    @Environment(\.dismiss) private var dismiss

    @State private var albumName = ""
    @State private var selectedDesignId: [UUID] = []
    @State private var showDesignPicker = false

    private var trimmedAlbumName: String {
        albumName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var selectedThumbnailPath: String? {
        guard let firstSelectedID = selectedDesignId.first else { return nil }
        return designStore.designs.first(where: { $0.id == firstSelectedID })?.thumbnailPath
    }

    private var canCreateAlbum: Bool {
        true
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                VStack(spacing: 22) {

                    artworkCard
                        .padding(.top, 34)

                    Button {
                        showDesignPicker = true
                    } label: {
                        Text(selectedDesignId.isEmpty ? "Add Designs" : "Edit Designs")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(Color.accentColor)
                            .padding(.horizontal, 26)
                            .frame(height: 42)
                            .background(
                                Capsule()
                                    .fill(Color(uiColor: .systemGray5))
                            )
                    }
                    .buttonStyle(.plain)

                    TextField("Album Name", text: $albumName)
                        .font(.system(size: 18, weight: .regular))
                        .padding(.horizontal, 22)
                        .frame(height: 54)
                        .background(
                            Capsule()
                                .fill(.white)
                        )
                        .padding(.horizontal, 28)

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("New Album")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .cancel) {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        _ = designStore.createAlbum(
                            named: trimmedAlbumName,
                            initialDesignIDs: selectedDesignId
                        )
                        dismiss()
                    } label: {
                        Text("Create")
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.accentColor)
                    .disabled(!canCreateAlbum)
                }
            }

            .sheet(isPresented: $showDesignPicker) {
                DesignPickerView(selectedDesignId: $selectedDesignId)
                    .presentationDetents([.large])
            }
        }
    }

    private var artworkCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color(uiColor: .systemGray5))
                .frame(width: 260, height: 260)

            if let selectedThumbnailPath {
                DesignImageView(path: selectedThumbnailPath)
                    .scaledToFill()
                    .frame(width: 260, height: 260)
                    .clipShape(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                    )
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 46, weight: .medium))
                    .foregroundStyle(Color(uiColor: .systemGray3))
            }
        }
    }
}

#Preview {
    let store = DataStore()
    AlbumCreateSheet()
        .environment(store)
}
