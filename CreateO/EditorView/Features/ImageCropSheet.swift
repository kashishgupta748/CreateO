import SwiftUI

struct ImageCropSheet: View {
    let image: UIImage
    let onCancel: () -> Void
    let onApply: (UIImage) -> Void

    @State var cropRect = CGRect.zero
    @State var initialCropRect = CGRect.zero
    @State var canvasSide: CGFloat = 300
    @State var didConfigure = false

    @State var rotationDegrees: Double = 0
    @State var isMirrored = false

    let minSize: CGFloat = 120

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let side = max(240, min(geo.size.width - 32, geo.size.height - 250))

                VStack(spacing: 0) {
                    Spacer(minLength: 16)

                    cropCanvas(side: side)
                        .frame(maxWidth: .infinity)

                    Spacer(minLength: 20)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(uiColor: .systemGroupedBackground))
                .safeAreaInset(edge: .bottom) {
                    cropToolbar
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, max(12, geo.safeAreaInsets.bottom))
                        .background(.regularMaterial)
                }
                .onAppear {
                    configureIfNeeded(side: side)
                }
                .onChange(of: side) { _, newSide in
                    configureIfNeeded(side: newSide)
                }
            }
            .navigationTitle("Crop")
            .toolbarTitleDisplayMode(.inline)
            .toolbar { topBar }
        }
    }
}

extension ImageCropSheet {
    var moveGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if initialCropRect == .zero {
                    initialCropRect = cropRect
                }

                var newRect = initialCropRect.offsetBy(
                    dx: value.translation.width,
                    dy: value.translation.height
                )

                newRect.origin.x = max(0, min(canvasSide - newRect.width, newRect.origin.x))
                newRect.origin.y = max(0, min(canvasSide - newRect.height, newRect.origin.y))

                cropRect = newRect
            }
            .onEnded { _ in
                initialCropRect = .zero
            }
    }

    func resizeGesture(_ type: CropHandle) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if initialCropRect == .zero {
                    initialCropRect = cropRect
                }

                var rect = initialCropRect

                switch type {
                case .topLeft:
                    rect.origin.x += value.translation.width
                    rect.origin.y += value.translation.height
                    rect.size.width -= value.translation.width
                    rect.size.height -= value.translation.height

                case .topRight:
                    rect.origin.y += value.translation.height
                    rect.size.width += value.translation.width
                    rect.size.height -= value.translation.height

                case .bottomLeft:
                    rect.origin.x += value.translation.width
                    rect.size.width -= value.translation.width
                    rect.size.height += value.translation.height

                case .bottomRight:
                    rect.size.width += value.translation.width
                    rect.size.height += value.translation.height
                }

                if rect.width > minSize && rect.height > minSize &&
                    rect.origin.x >= 0 && rect.origin.y >= 0 &&
                    rect.maxX <= canvasSide && rect.maxY <= canvasSide {
                    cropRect = rect
                }
            }
            .onEnded { _ in
                initialCropRect = .zero
            }
    }

    var cropToolbar: some View {
        HStack(spacing: 12) {
            cropActionButton(symbol: "rotate.left.fill", title: "Rotate") {
                rotationDegrees -= 90
            }

            cropActionButton(symbol: "flip.horizontal.fill", title: "Mirror") {
                isMirrored.toggle()
            }

            cropActionButton(symbol: "arrow.counterclockwise", title: "Reset") {
                reset()
            }
        }
    }

    func cropActionButton(symbol: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 62)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}
