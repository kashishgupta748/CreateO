import SwiftUI

struct DesignToolbar: ToolbarContent {
    @Binding var layoutMode: LayoutMode
    @Binding var showSortMenu: Bool

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            NavigationLink {
                FavouriteView()
            } label: {
                Image(systemName: "heart")
                    .font(.system(size: 17, weight: .medium))
            }

            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    showSortMenu.toggle()
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(showSortMenu ? Color.accentColor : .primary)
            }
        }
    }
}
