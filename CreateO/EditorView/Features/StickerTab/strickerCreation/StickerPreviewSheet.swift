//
//  StickerPreviewSheet.swift
//  DummySwiftApp
//
//  Created by GU on 19/03/26.
//

import SwiftUI

struct StickerPreviewSheet: View {

    let image: UIImage

    @Binding var showPreview: Bool
    @Binding var savedStickers: [UIImage]
    @Binding var selectedSticker: UIImage?

    @State private var processedImage: UIImage?
    @State private var isProcessing = true

    private var previewImage: UIImage {
        processedImage ?? image
    }

    var body: some View {
        VStack(spacing: 16) {

            Text("New Sticker")
                .font(.title2.bold())
                .padding(.top)

            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground))

                Image(uiImage: previewImage)
                    .resizable()
                    .scaledToFit()
                    .padding(14)

                if isProcessing {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)

                    ProgressView()
                        .controlSize(.large)
                        .tint(Color.accentColor)
                }
            }
            .frame(maxHeight: 400)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal)

            Spacer()

            HStack {

                Button {
                    showPreview = false
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 50, height: 50)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(Circle())
                        .foregroundStyle(.black)
                }
                
                Spacer()

                Button {
                    let sticker = previewImage
                    if !savedStickers.contains(where: { $0.pngData() == sticker.pngData() }) {
                        savedStickers.append(sticker)
                    }
                    selectedSticker = sticker
                    showPreview = false
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 50, height: 50)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(Circle())
                        .foregroundStyle(.black)
                }
                .disabled(isProcessing)
                .opacity(isProcessing ? 0.45 : 1)
            }
            .padding(.horizontal, 40)
            .padding(.bottom)
        }
        .task {
            await prepareStickerPreview()
        }
    }

    @MainActor
    private func prepareStickerPreview() async {
        isProcessing = true

        let sourceImage = image
        let preparedImage = sourceImage.normalizedForEditing()?.downscaledForProcessing() ?? sourceImage
        let cutout = await EditorView.backgroundRemovedImage(from: preparedImage)

        processedImage = cutout?.visibleAlphaCrop(padding: 12)?.image ?? cutout ?? sourceImage
        isProcessing = false
    }
}

#Preview {
    StickerPreviewSheet(
        image: UIImage(systemName: "photo") ?? UIImage(),
        showPreview: .constant(true),
        savedStickers: .constant([]),
        selectedSticker: .constant(nil)
    )
}
