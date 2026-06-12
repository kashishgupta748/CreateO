import SwiftUI

struct DesignGroupingView: View {
    let designs: [Design]
    let layoutMode: LayoutMode
    let columns: [GridItem]
    let onAddTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            LazyVGrid(columns: columns, spacing: 16) {
                DesignAddCard(action: onAddTap)
            }
            .padding(.horizontal)

            ForEach(groupedDesigns, id: \.key) { group in
                Text(group.key)
                    .font(.title3)
                    .fontWeight(.bold)
                    .padding(.horizontal)

                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(group.value) { design in
                        DesignCard(
                            size: CGSize(width: 180, height: 270),
                            design: design
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var groupedDesigns: [(key: String, value: [Design])] {
        let calendar = Calendar.current
        let sorted = designs.sorted { $0.createdAt > $1.createdAt }

        let grouped = Dictionary(grouping: sorted) { design -> Date in
            let components: DateComponents

            switch layoutMode {
            case .week:
                components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: design.createdAt)
            case .month:
                components = calendar.dateComponents([.year, .month], from: design.createdAt)
            case .year:
                components = calendar.dateComponents([.year], from: design.createdAt)
            default:
                return design.createdAt
            }

            return calendar.date(from: components) ?? design.createdAt
        }

        return grouped.keys.sorted(by: >).map { date in
            let formatter = DateFormatter()

            switch layoutMode {
            case .week:
                formatter.dateFormat = "w yyyy"
            case .month:
                formatter.dateFormat = "MMMM yyyy"
            case .year:
                formatter.dateFormat = "yyyy"
            default:
                formatter.dateFormat = "dd MMM yyyy"
            }

            return (formatter.string(from: date), grouped[date] ?? [])
        }
    }
}
