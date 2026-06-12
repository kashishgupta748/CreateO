import SwiftUI

extension ImageCropSheet {
    @ToolbarContentBuilder
    var topBar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                onCancel()
            } label: {
                Image(systemName: "xmark")
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button {
                if let img = croppedImage() {
                    onApply(img)
                }
            } label: {
                Image(systemName: "checkmark")
            }
        }
    }

    func cropCanvas(side: CGFloat) -> some View {
        ZStack {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: side, height: side)
                .rotationEffect(.degrees(rotationDegrees))
                .scaleEffect(x: isMirrored ? -1 : 1, y: 1)

            cropMask
            cropFrame
            cropHandles
        }
        .frame(width: side, height: side)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }

    var cropMask: some View {
        ZStack {
            Color.black.opacity(0.45)

            Rectangle()
                .frame(width: cropRect.width, height: cropRect.height)
                .position(x: cropRect.midX, y: cropRect.midY)
                .blendMode(.destinationOut)
        }
        .compositingGroup()
    }

    var cropFrame: some View {
        ZStack {
            Rectangle()
                .stroke(Color.primary, lineWidth: 2)
                .frame(width: cropRect.width, height: cropRect.height)
                .position(x: cropRect.midX, y: cropRect.midY)

            gridOverlay
                .frame(width: cropRect.width, height: cropRect.height)
                .position(x: cropRect.midX, y: cropRect.midY)
        }
        .gesture(moveGesture)
    }

    var cropHandles: some View {
        Group {
            handle(.topLeft, x: cropRect.minX, y: cropRect.minY)
            handle(.topRight, x: cropRect.maxX, y: cropRect.minY)
            handle(.bottomLeft, x: cropRect.minX, y: cropRect.maxY)
            handle(.bottomRight, x: cropRect.maxX, y: cropRect.maxY)
        }
    }

    var gridOverlay: some View {
        ZStack {
            Rectangle()
                .fill(Color.primary.opacity(0.18))
                .frame(width: 1, height: cropRect.height)
                .offset(x: -cropRect.width / 6)

            Rectangle()
                .fill(Color.primary.opacity(0.18))
                .frame(width: 1, height: cropRect.height)
                .offset(x: cropRect.width / 6)

            Rectangle()
                .fill(Color.primary.opacity(0.18))
                .frame(width: cropRect.width, height: 1)
                .offset(y: -cropRect.height / 6)

            Rectangle()
                .fill(Color.primary.opacity(0.18))
                .frame(width: cropRect.width, height: 1)
                .offset(y: cropRect.height / 6)
        }
    }

    func handle(_ type: CropHandle, x: CGFloat, y: CGFloat) -> some View {
        Circle()
            .fill(Color(uiColor: .systemBackground))
            .frame(width: 18, height: 18)
            .overlay {
                Circle()
                    .stroke(Color.primary.opacity(0.2), lineWidth: 1)
            }
            .position(x: x, y: y)
            .gesture(resizeGesture(type))
    }
}
