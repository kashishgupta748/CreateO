//
//  shapes.swift
//  DummySwiftApp
//
//  Created by GU on 18/03/26.
//

import SwiftUI

struct shapes: View {
    private let shapeSymbols = ["♦︎", "◼︎", "♠︎", "●", "▲", "★"]
    private let columns = [
        GridItem(.adaptive(minimum: 72, maximum: 96), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(shapeSymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 42))
                        .frame(maxWidth: .infinity)
                        .frame(height: 72)
                        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .padding()
        }
    }
}

#Preview {
    shapes()
}
