import SwiftUI

struct EditorBorderPicker: View {
    @Binding var borderWidth: Double
    @Binding var borderColor: Color

    var body: some View {
        VStack(spacing: 18) {
            Divider()

            HStack(alignment: .center, spacing: 18) {
                VStack(spacing: 8) {
                    Slider(value: $borderWidth, in: 0...20)
                        .tint(.accentColor)

                    HStack(spacing: 0) {
                        ForEach(0..<4, id: \.self) { _ in
                            Circle()
                                .fill(Color.gray.opacity(0.35))
                                .frame(width: 4, height: 4)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 6)
                }

                ColorPicker("", selection: $borderColor, supportsOpacity: false)
                    .labelsHidden()
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 14)
    }
}
