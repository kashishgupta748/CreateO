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
                Picker("Sort Designs", selection: $layoutMode) {
                    Label("Grid View", systemImage: "square.grid.2x2")
                        .tag(LayoutMode.grid)
                    Label("Week wise", systemImage: "calendar")
                        .tag(LayoutMode.week)
                    Label("Month wise", systemImage: "calendar.circle")
                        .tag(LayoutMode.month)
                    Label("Year wise", systemImage: "calendar.badge.clock")
                        .tag(LayoutMode.year)
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 17, weight: .medium))
            }
        }
    }
}
