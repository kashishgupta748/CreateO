
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
    @AppStorage("hasCompletedFirstDesignGuide") private var hasCompletedFirstDesignGuide = false

    @Environment(AuthManager.self) private var authManager
    @State private var showStorySavedToast = false
    @State private var storySavedToastTask: Task<Void, Never>?
    @State private var firstDesignGuideManager = FirstDesignGuideManager()

    var body: some View {
        ZStack(alignment: .top) {
            TabView(selection: $selectedTab) {
                Tab("Design", systemImage: "square.grid.2x2", value: CreatoTab.design.rawValue) {
                    DesignView()
                        .toolbar(firstDesignGuideManager.isCompleted ? .visible : .hidden, for: .tabBar)
                }

                Tab("Album", systemImage: "photo.on.rectangle", value: CreatoTab.album.rawValue) {
                    AlbumView()
                        .toolbar(firstDesignGuideManager.isCompleted ? .visible : .hidden, for: .tabBar)
                }

                Tab("Profile", systemImage: "person.circle", value: CreatoTab.profile.rawValue) {
                    ProfileView()
                        .toolbar(firstDesignGuideManager.isCompleted ? .visible : .hidden, for: .tabBar)
                }

                Tab("Search", systemImage: "magnifyingglass", value: CreatoTab.search.rawValue) {
                    SearchView()
                        .toolbar(firstDesignGuideManager.isCompleted ? .visible : .hidden, for: .tabBar)
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
        .environment(firstDesignGuideManager)
        .firstDesignGuideOverlay(manager: firstDesignGuideManager)
        .onAppear {
            configureFirstDesignGuide()
        }
        .onChange(of: hasCompletedFirstDesignGuide) { _, newValue in
            configureFirstDesignGuide(legacyCompletion: newValue)
        }
        .onChange(of: authManager.state) { _, _ in
            configureFirstDesignGuide()
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

    private var firstDesignGuideStorageKey: String {
        if let userID = authManager.currentUserID {
            return "hasCompletedFirstDesignGuide.\(userID.uuidString)"
        }

        if let email = authManager.currentUserEmail, !email.isEmpty {
            let identifier = email
                .lowercased()
                .replacingOccurrences(
                    of: #"[^A-Za-z0-9]+"#,
                    with: "_",
                    options: .regularExpression
                )
                .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
            return "hasCompletedFirstDesignGuide.pending.\(identifier)"
        }

        return "hasCompletedFirstDesignGuide.guest"
    }

    private func configureFirstDesignGuide(legacyCompletion: Bool? = nil) {
        let key = firstDesignGuideStorageKey
        let accountCompletion = UserDefaults.standard.bool(forKey: key)
        let resolvedCompletion = accountCompletion || (legacyCompletion ?? false && authManager.state == .guest)

        firstDesignGuideManager.configure(isCompleted: resolvedCompletion) {
            UserDefaults.standard.set(true, forKey: key)

            if authManager.state == .guest {
                hasCompletedFirstDesignGuide = true
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(DataStore())
        .environment(AuthManager())
}
