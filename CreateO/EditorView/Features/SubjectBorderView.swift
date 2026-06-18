import SwiftUI

struct SubjectBorderView: View {
    let image: UIImage
    let size: CGSize
    let color: Color
    let lineWidth: CGFloat

    private var maskPadding: CGFloat {
        max(lineWidth * 2, 1)
    }

    private var paddedSize: CGSize {
        CGSize(
            width: size.width + (maskPadding * 2),
            height: size.height + (maskPadding * 2)
        )
    }

    private var offsetPoints: [CGSize] {
        guard lineWidth > 0 else { return [] }

        let samples = max(12, Int(ceil(lineWidth * 8)))
        return (0..<samples).map { index in
            let angle = (Double(index) / Double(samples)) * Double.pi * 2
            return CGSize(
                width: cos(angle) * lineWidth,
                height: sin(angle) * lineWidth
            )
        }
    }

    var body: some View {
        ZStack {
            ForEach(Array(offsetPoints.enumerated()), id: \.offset) { _, point in
                color
                    .frame(width: paddedSize.width, height: paddedSize.height)
                    .mask {
                        Image(uiImage: image)
                            .resizable()
                            .frame(width: size.width, height: size.height)
                            .frame(width: paddedSize.width, height: paddedSize.height)
                    }
                    .offset(point)
            }
        }
        .frame(width: paddedSize.width, height: paddedSize.height)
    }
}
