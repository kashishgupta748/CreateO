
import SwiftUI

enum CreatoTab: String {
    case design
    case album
    case profile
    case search
}


struct ContentView: View {
    @AppStorage("creato.selectedTab") private var selectedTab = CreatoTab.design.rawValue
    @AppStorage("creato.storySavedNotificationID") private var storySavedNotificationID = ""

    @Environment(AuthManager.self) private var authManager
    @State private var showStorySavedToast = false
    @State private var storySavedToastTask: Task<Void, Never>?

    var body: some View {
        ZStack(alignment: .top) {
            TabView(selection: $selectedTab) {
                Tab("Design", systemImage: "square.grid.2x2", value: CreatoTab.design.rawValue) {
                    DesignView()
                }

                Tab("Album", systemImage: "photo.on.rectangle", value: CreatoTab.album.rawValue) {
                    AlbumView()
                }

                Tab("Profile", systemImage: "person.circle", value: CreatoTab.profile.rawValue) {
                    ProfileView()
                }

                Tab("Search", systemImage: "magnifyingglass", value: CreatoTab.search.rawValue) {
                    SearchView()
                }
            }

            if showStorySavedToast {
                storySavedToast
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1)
            }
        }
        .onChange(of: storySavedNotificationID) { _, newValue in
            guard !newValue.isEmpty else { return }
            showStorySavedConfirmation(for: newValue)
        }
    }

    private var storySavedToast: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 2) {
                Text("Story saved")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.primary)

                Text("Your video is now in Designs.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.16), radius: 18, y: 8)
    }

    private func showStorySavedConfirmation(
        for notificationID: String
    ) {
        storySavedToastTask?.cancel()

        withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
            showStorySavedToast = true
        }

        storySavedToastTask = Task {
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.22)) {
                    showStorySavedToast = false
                }

                if storySavedNotificationID == notificationID {
                    storySavedNotificationID = ""
                }
            }
        }
    }


}

#Preview {
    ContentView()
        .environment(DataStore())
        .environment(AuthManager())
}
