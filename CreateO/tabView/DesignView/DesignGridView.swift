import SwiftUI

struct DesignGridView: View {
    let designs: [Design]
    let layoutMode: LayoutMode
    let masonColumn: Int
    let columns: [GridItem]
    let onAddTap: () -> Void
    var showsAddCard = true

    private let spacing: CGFloat = 10
    private let horizontalPadding: CGFloat = 16
    private let baselineCardWidth: CGFloat = 180

    var body: some View {
        Group {
            if layoutMode == .grid {
                let cardWidth = masonryCardWidth

                MasonryLayout(columns: masonColumn, spacing: spacing) {
                    if showsAddCard {
                        DesignAddCard(size: addCardSize(width: cardWidth), action: onAddTap)
                    }

                    ForEach(designs) { design in
                        DesignCard(
                            size: size(for: design, cardWidth: cardWidth),
                            design: design
                        )
                    }
                }
                .padding(horizontalPadding)
            } else {
                DesignGroupingView(
                    designs: designs,
                    layoutMode: layoutMode,
                    columns: columns,
                    onAddTap: onAddTap
                )
            }
        }
    }

    private var masonryCardWidth: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        let resolvedColumns = max(CGFloat(masonColumn), 1)
        let availableWidth = max(screenWidth - (horizontalPadding * 2), 1)
        let totalSpacing = spacing * (resolvedColumns - 1)
        return max((availableWidth - totalSpacing) / resolvedColumns, 1)
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

    private func addCardSize(width: CGFloat) -> CGSize {
        scaledSize(height: 252, cardWidth: width)
    }

    private func scaledSize(height baselineHeight: CGFloat, cardWidth: CGFloat) -> CGSize {
        let ratio = baselineHeight / baselineCardWidth
        return CGSize(width: cardWidth, height: cardWidth * ratio)
    }

}

struct DesignAddCard: View {
    @Environment(FirstDesignGuideManager.self) private var guideManager

    let size: CGSize
    let action: () -> Void

    init(size: CGSize = CGSize(width: 180, height: 252), action: @escaping () -> Void) {
        self.size = size
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: "plus")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(.primary)

                Text("New Design")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("Tap to create")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(width: size.width, height: size.height)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color(.separator).opacity(0.35), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.12), radius: 16, y: 9)
        }
        .guideHighlight(
            .homeCreate,
            isActive: guideManager.currentStep == .homeCreate
        )
        .buttonStyle(.plain)
    }
}
