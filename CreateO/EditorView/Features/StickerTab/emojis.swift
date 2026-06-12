//
//  emojis.swift
//  DummySwiftApp
//
//  Created by GU on 18/03/26.
//

import SwiftUI

struct emojis: View {
    private let emojiOptions = ["😀", "😃", "😄", "😁", "😆", "🥹", "😍", "🤩", "😎", "🥳", "🤖", "🌟"]
    private let columns = [
        GridItem(.adaptive(minimum: 60, maximum: 88), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(emojiOptions, id: \.self) { emoji in
                    Text(emoji)
                        .font(.system(size: 34))
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .padding()
        }
    }
}

#Preview {
    emojis()
}
