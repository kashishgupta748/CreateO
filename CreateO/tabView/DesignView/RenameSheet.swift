
import SwiftUI

struct RenameSheet: View {
    @Binding var name: String
    var onSave: () -> Void
    var onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    onCancel()
                }

            VStack {
                Spacer()

                VStack(spacing: 16) {
                    Capsule()
                        .frame(width: 40, height: 5)
                        .foregroundColor(.white.opacity(0.4))

                    Text("Rename Design")
                        .foregroundColor(.white)

                    TextField("Design name", text: $name)
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)

                    HStack {
                        Button("Cancel") {
                            onCancel()
                        }

                        Spacer()

                        Button("Save") {
                            onSave()
                        }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .foregroundColor(.white)
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(25)
                .padding()
            }
        }
    }
}
