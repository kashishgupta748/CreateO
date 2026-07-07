import SwiftUI

struct DesignPickerView: View {
    @Environment(DataStore.self) var designStore
    @Environment(\.dismiss) var dismiss
    @Binding var selectedDesignId: [UUID]
    var onUse: (([UUID]) -> Void)? = nil

    @Environment(\.horizontalSizeClass) private var hSize

    private var isPadLike: Bool { hSize == .regular }
    private var columnsCount: Int { isPadLike ? 4 : 2 }

    private let spacing: CGFloat = 10
    private let horizontalPadding: CGFloat = 16
    private let baselineCardWidth: CGFloat = 180

    private var allSelected: Bool {
        !designStore.designs.isEmpty && selectedDesignId.count == designStore.designs.count
    }

    private var masonryCardWidth: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        let resolvedColumns = max(CGFloat(columnsCount), 1)
        let availableWidth = max(screenWidth - (horizontalPadding * 2), 1)
        let totalSpacing = spacing * (resolvedColumns - 1)
        return max((availableWidth - totalSpacing) / resolvedColumns, 1)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    let cardWidth = masonryCardWidth
                    MasonryLayout(columns: columnsCount, spacing: spacing) {
                        ForEach(designStore.designs) { design in
                            designCard(design, cardWidth: cardWidth)
                        }
                    }
                }
                .padding(.horizontal, horizontalPadding)
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
                    onUse?(selectedDesignId)
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

    private func designCard(_ design: Design, cardWidth: CGFloat) -> some View {
        let isSelected = selectedDesignId.contains(design.id)
        let cardSize = size(for: design, cardWidth: cardWidth)

        return Button {
            toggle(design.id)
        } label: {
            ZStack(alignment: .topTrailing) {
                DesignImageView(path: design.thumbnailPath)
                    .scaledToFill()
                    .frame(width: cardSize.width, height: cardSize.height)
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

    private func size(for design: Design, cardWidth: CGFloat) -> CGSize {
        let bucketHeights: [CGFloat] = [228, 252, 278, 304, 332]

        if design.designType == .video {
            let index = abs(design.id.uuidString.hashValue) % bucketHeights.count
            return scaledSize(height: bucketHeights[index], cardWidth: cardWidth)
        }

        if design.designHeight != 270 || design.designWidth != 180 {
            let ratio = max(CGFloat(design.designHeight) / max(CGFloat(design.designWidth), 1), 1.25)
            return CGSize(width: cardWidth, height: cardWidth * min(ratio, 2.05))
        }

        let index = abs(design.id.uuidString.hashValue) % bucketHeights.count
        return scaledSize(height: bucketHeights[index], cardWidth: cardWidth)
    }

    private func scaledSize(height baselineHeight: CGFloat, cardWidth: CGFloat) -> CGSize {
        let ratio = baselineHeight / baselineCardWidth
        return CGSize(width: cardWidth, height: cardWidth * ratio)
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
