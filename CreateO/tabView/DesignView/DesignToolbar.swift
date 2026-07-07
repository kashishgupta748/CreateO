import SwiftUI

struct DesignToolbar: ToolbarContent {
    @Binding var layoutMode: LayoutMode
    @State private var showMenu = false

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            NavigationLink {
                FavouriteView()
            } label: {
                Image(systemName: "heart")
                    .font(.system(size: 17, weight: .medium))
            }

            Button {
                showMenu.toggle()
            } label: {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 17, weight: .medium))
            }
            .popover(isPresented: $showMenu) {
                VStack(alignment: .leading, spacing: 0) {
                    customMenuRow(title: "Grid View", icon: "square.grid.2x2", mode: .grid)
                    Divider()
                    customMenuRow(title: "Week wise", icon: "calendar", mode: .week)
                    Divider()
                    customMenuRow(title: "Month wise", icon: "calendar.circle", mode: .month)
                    Divider()
                    customMenuRow(title: "Year wise", icon: "calendar.badge.clock", mode: .year)
                }
                .frame(width: 180)
                .presentationCompactAdaptation(.popover)
            }
        }
    }

    @ViewBuilder
    private func customMenuRow(title: String, icon: String, mode: LayoutMode) -> some View {
        let isSelected = layoutMode == mode
        let filledIcon = isSelected ? (icon == "calendar.badge.clock" ? icon : "\(icon).fill") : icon

        Button {
            layoutMode = mode
            showMenu = false
        } label: {
            HStack(spacing: 12) {
                Image(systemName: filledIcon)
                    .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                    .frame(width: 20)
                    .foregroundStyle(isSelected ? Color.accentColor : .primary)

                Text(title)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? Color.accentColor : .primary)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
