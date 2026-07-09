import SwiftUI

struct shapes: View {
    @Binding var selectedSticker: UIImage?

    private let shapeSymbols: [(symbol: String, title: String)] = [
        ("circle.fill", "Circle"),
        ("square.fill", "Square"),
        ("triangle.fill", "Triangle"),
        ("diamond.fill", "Diamond"),
        ("star.fill", "Star"),
        ("heart.fill", "Heart"),
        ("seal.fill", "Seal"),
        ("hexagon.fill", "Hexagon"),
        ("capsule.fill", "Capsule"),
        ("bolt.fill", "Bolt"),
        ("moon.fill", "Moon"),
        ("cloud.fill", "Cloud")
    ]

    private let columns = [
        GridItem(.adaptive(minimum: 92, maximum: 124), spacing: 14)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(shapeSymbols, id: \.symbol) { item in
                    Button {
                        selectedSticker = renderShapeSticker(symbolName: item.symbol)
                    } label: {
                        VStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(Color(uiColor: .secondarySystemBackground))
                                    .frame(height: 94)

                                Image(systemName: item.symbol)
                                    .font(.system(size: 34, weight: .semibold))
                                    .foregroundStyle(.primary)
                            }

                            Text(item.title)
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    private func renderShapeSticker(symbolName: String) -> UIImage? {
        let configuration = UIImage.SymbolConfiguration(pointSize: 180, weight: .semibold)
        guard let baseImage = UIImage(systemName: symbolName, withConfiguration: configuration) else {
            return nil
        }

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 240, height: 240))
        return renderer.image { _ in
            UIColor.clear.setFill()
            UIBezierPath(rect: CGRect(x: 0, y: 0, width: 240, height: 240)).fill()

            let tinted = baseImage.withTintColor(.black, renderingMode: .alwaysOriginal)
            let rect = CGRect(x: 30, y: 30, width: 180, height: 180)
            tinted.draw(in: rect)
        }
    }
}

#Preview {
    shapes(selectedSticker: .constant(nil))
}
