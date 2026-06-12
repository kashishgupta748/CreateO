//
//  recent.swift
//  DummySwiftApp
//
//  Created by GU on 18/03/26.
//

import SwiftUI

struct recent: View {
    let recentStickers: [UIImage]
    @Binding var selectedSticker: UIImage?
    private let columns = [
        GridItem(.adaptive(minimum: 84, maximum: 120), spacing: 12)
    ]

    var body: some View {
        if recentStickers.isEmpty {
            VStack(spacing: 8) {
                Text("No Recent Stickers")
                    .font(.title3.weight(.semibold))
                Text("Stickers you’ve recently used will appear here.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 24)
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(recentStickers, id: \.self) { image in
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 100)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .onTapGesture {
                                selectedSticker = image
                            }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
        }
    }
}

#Preview {
    recent(recentStickers: [UIImage(systemName: "star.fill")!], selectedSticker: .constant(nil))
}
