import SwiftUI

struct DesignPickerView: View {
    @Environment(DataStore.self) var designStore
    @Environment(\.dismiss) var dismiss
    @Binding var selectedDesignId: [UUID]

    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 240), spacing: 14)
    ]

    private var allSelected: Bool {
        !designStore.designs.isEmpty && selectedDesignId.count == designStore.designs.count
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(designStore.designs) { design in
                            designCard(design)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 120)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Select Designs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(allSelected ? "Clear" : "Select All") {
                        if allSelected {
                            selectedDesignId.removeAll()
                        } else {
                            selectedDesignId = designStore.designs.map(\.id)
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    dismiss()
                } label: {
                    Text(selectedDesignId.isEmpty ? "Select designs" : "Use \(selectedDesignId.count) design\(selectedDesignId.count == 1 ? "" : "s")")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(selectedDesignId.isEmpty ? Color.gray.opacity(0.45) : Color.accentColor)
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 6)
                        .background(Color(.systemGroupedBackground))
                }
                .buttonStyle(.plain)
                .disabled(selectedDesignId.isEmpty)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Choose designs")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.primary)

            Text(
                selectedDesignId.isEmpty
                ? "Tap the designs you want in this album."
                : "\(selectedDesignId.count) selected"
            )
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.secondary)
        }
    }

    private func designCard(_ design: Design) -> some View {
        let isSelected = selectedDesignId.contains(design.id)

        return Button {
            toggle(design.id)
        } label: {
            ZStack(alignment: .topTrailing) {
                DesignImageView(path: design.thumbnailPath)
                    .scaledToFill()
                    .aspectRatio(2.0 / 3.0, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(isSelected ? Color.black.opacity(0.16) : .clear)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(isSelected ? Color.accentColor : Color.black.opacity(0.08), lineWidth: isSelected ? 3 : 1)
                    }

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.95), isSelected ? Color.accentColor : Color.black.opacity(0.20))
                    .padding(10)
            }
        }
        .buttonStyle(.plain)
    }

    private func toggle(_ id: UUID) {
        if selectedDesignId.contains(id) {
            selectedDesignId.removeAll { $0 == id }
        } else {
            selectedDesignId.append(id)
        }
    }
}

#Preview {
    DesignPickerView(selectedDesignId: .constant([]))
        .environment(DataStore())
}
