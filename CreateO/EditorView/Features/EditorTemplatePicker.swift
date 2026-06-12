import SwiftUI

struct EditorTemplatePicker: View {
    var selectedColor: Color
    var onSelect: (Color) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showPreview = false

    private let templates: [Color] = [
        .purple, .orange, .yellow, .pink,
        .gray, .black, .mint
    ]

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    private let defaultCanvasColor: Color = .white

    var body: some View {
        NavigationStack {
            Group {
                if showPreview {
                    ZStack {
                        Color.white
                            .ignoresSafeArea()

                        GeometryReader { geo in
                            ScrollView(.horizontal) {
                                HStack(spacing: 20) {
                                    ForEach(templates, id: \.self) { color in
                                        RoundedRectangle(cornerRadius: 30)
                                            .fill(color)
                                            .overlay {
                                                RoundedRectangle(cornerRadius: 30)
                                                    .stroke(
                                                        isSelected(color) ? Color.accentColor : Color.clear,
                                                        lineWidth: 5
                                                    )
                                            }
                                            .frame(
                                                width: geo.size.width * 0.9,
                                                height: geo.size.height * 0.85
                                            )
                                            .shadow(color: .black.opacity(0.2), radius: 10)
                                            .onTapGesture {
                                                onSelect(toggledColor(for: color))
                                                dismiss()
                                            }
                                    }
                                }
                                .padding(.horizontal, 30)
                                .padding(.top, 10)
                            }
                            .scrollIndicators(.hidden)
                        }
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(templates, id: \.self) { color in
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(color)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(
                                                isSelected(color) ? Color.accentColor : Color.clear,
                                                lineWidth: 4
                                            )
                                    }
                                    .frame(height: 150)
                                    .shadow(color: .black.opacity(0.1), radius: 4)
                                    .onTapGesture {
                                        onSelect(toggledColor(for: color))
                                        dismiss()
                                    }
                            }
                        }
                        .padding()
                    }
                }
            }
            .background(showPreview ? Color.white : Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Templates")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showPreview.toggle()
                    } label: {
                        Image(systemName: showPreview ? "rectangle.fill" : "square.grid.2x2.fill")
                    }
                }
            }
        }
    }

    private func toggledColor(for color: Color) -> Color {
        isSelected(color) ? defaultCanvasColor : color
    }

    private func isSelected(_ color: Color) -> Bool {
        UIColor(color).isEqual(UIColor(selectedColor))
    }
}

#Preview {
    EditorTemplatePicker(selectedColor: .white) { _ in }
}
