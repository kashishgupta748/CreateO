
import SwiftUI

struct InfoSheet: View {
    let design: Design

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    InfoRow(title: "Name", value: design.designName)
                    InfoRow(title: "Type", value: design.designType.rawValue.capitalized)
                    InfoRow(title: "Favorite", value: design.isFavorite ? "Yes" : "No")
                }

                Section("Dates") {
                    InfoRow(title: "Created", value: formatDate(design.createdAt))

                    if let updated = design.updatedAt {
                        InfoRow(title: "Updated", value: formatDate(updated))
                    }
                }
            }
            .navigationTitle("Details")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct InfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    let store = DataStore()
    InfoSheet(design: store.designs[0])
        .environment(DataStore())
}
