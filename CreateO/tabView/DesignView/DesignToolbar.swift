import SwiftUI

struct DesignToolbar: ToolbarContent {
    @Binding var layoutMode: LayoutMode

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            NavigationLink {
                FavouriteView()
            } label: {
                Image(systemName: "heart")
                    .font(.system(size: 17, weight: .medium))
            }

            Menu {
                Text("Sort Designs")

                Button {
                    withAnimation { layoutMode = .grid }
                } label: {
                    Label("Grid View", systemImage: "square.grid.2x2")
                        .symbolVariant(layoutMode == .grid ? .fill : .none)
                }

                Button {
                    withAnimation { layoutMode = .week }
                } label: {
                    Label("Week wise", systemImage: layoutMode == .week ? "checkmark" : "calendar")
                }

                Button {
                    withAnimation { layoutMode = .month }
                } label: {
                    Label("Month wise", systemImage: layoutMode == .month ? "checkmark" : "calendar.circle")
                }

                Button {
                    withAnimation { layoutMode = .year }
                } label: {
                    Label("Year wise", systemImage: layoutMode == .year ? "checkmark" : "calendar.badge.clock")
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 17, weight: .medium))
            }
        }
    }
}
