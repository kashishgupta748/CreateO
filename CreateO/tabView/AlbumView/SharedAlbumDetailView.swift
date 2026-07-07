import SwiftUI

struct SharedAlbumDetailView: View {
    @Environment(DataStore.self) var designStore
    @Environment(AuthManager.self) var authManager
    @Environment(\.dismiss) var dismiss
    
    let albumID: UUID
    
    @State private var selectedTab = 0 // 0 = Designs, 1 = Activity
    @State private var showDesignPicker = false
    @State private var selectedDesignIDsForAdd: [UUID] = []
    
    // Toast state for real-time collaboration simulation notifications
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var copiedHUD = false
    
    private let gridSpacing: CGFloat = 12
    private let horizontalPadding: CGFloat = 16
    private let baselineCardWidth: CGFloat = 180
    private let baselineCardHeight: CGFloat = 252
    
    // Grid configuration
    private var cardWidth: CGFloat {
        let availableWidth = max(UIScreen.main.bounds.width - (horizontalPadding * 2), 1)
        return max((availableWidth - gridSpacing) / 2, 1)
    }
    
    private var cardSize: CGSize {
        CGSize(
            width: cardWidth,
            height: cardWidth * (baselineCardHeight / baselineCardWidth)
        )
    }
    
    private var columns: [GridItem] {
        [
            GridItem(.fixed(cardSize.width), spacing: gridSpacing),
            GridItem(.fixed(cardSize.width), spacing: gridSpacing)
        ]
    }
    
    // Computed property to dynamically fetch the album state from designStore
    var album: SharedAlbum? {
        designStore.sharedAlbums.first(where: { $0.id == albumID })
    }
    
    var albumDesigns: [Design] {
        guard let album = album else { return [] }
        return designStore.designs.filter { album.designIDs.contains($0.id) }
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            if let album = album {
                VStack(spacing: 0) {
                    // Collaborator & Simulation Area
                    collaboratorHeader(album)
                        .padding(.horizontal, horizontalPadding)
                        .padding(.vertical, 14)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .padding(.horizontal, horizontalPadding)
                        .padding(.top, 16)
                    
                    // Custom Pill/Capsule Segmented Control
                    customPillPicker
                    
                    // Main Content depending on Tab
                    if selectedTab == 0 {
                        designsTab(album)
                    } else {
                        activitiesTab(album)
                    }
                }
            } else {
                // Album deleted or invalid
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("Album not found")
                        .font(.headline)
                    Button("Go Back") {
                        dismiss()
                    }
                }
                .frame(maxHeight: .infinity)
            }
            
            // HUD Toasts
            if showToast {
                toastBubble(message: toastMessage, systemImage: "sparkles", color: .orange)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            if copiedHUD {
                toastBubble(message: "Collaboration link copied!", systemImage: "link", color: .blue)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(album?.albumName ?? "Shared Album")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    selectedDesignIDsForAdd = album?.designIDs ?? []
                    showDesignPicker = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showDesignPicker) {
            DesignPickerView(selectedDesignId: $selectedDesignIDsForAdd) { updatedIDs in
                guard let album = album else { return }
                
                // Diff and apply
                let currentIDs = Set(album.designIDs)
                let newIDs = Set(updatedIDs)
                
                // Added
                for id in newIDs {
                    if !currentIDs.contains(id) {
                        designStore.addDesignToSharedAlbum(albumID: album.id, designID: id, authManager: authManager)
                    }
                }
                
                // Removed
                for id in currentIDs {
                    if !newIDs.contains(id) {
                        designStore.removeDesignFromSharedAlbum(albumID: album.id, designID: id, authManager: authManager)
                    }
                }
            }
            .presentationDetents([.large])
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SharedAlbumUpdate"))) { notification in
            if let userInfo = notification.userInfo,
               let colName = userInfo["collaboratorName"] as? String,
               let designName = userInfo["designName"] as? String {
                
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    toastMessage = "\(colName) added '\(designName)'"
                    showToast = true
                }
                
                Task {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    await MainActor.run {
                        withAnimation {
                            showToast = false
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var customPillPicker: some View {
        HStack(spacing: 8) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    selectedTab = 0
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "photo.stack.fill")
                        .font(.system(size: 12))
                    Text("Designs (\(albumDesigns.count))")
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(selectedTab == 0 ? .white : .secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(selectedTab == 0 ? Color.accentColor : Color.clear)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    selectedTab = 1
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "clock.arrow.2.circlepath")
                        .font(.system(size: 12))
                    Text("Activity")
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(selectedTab == 1 ? .white : .secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(selectedTab == 1 ? Color.accentColor : Color.clear)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
        .padding(5)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(Capsule())
        .padding(.horizontal, horizontalPadding)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }
    
    private func toastBubble(message: String, systemImage: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(color)
                .font(.system(size: 14, weight: .bold))
            Text(message)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 5)
        .padding(.top, 10)
        .zIndex(999)
    }
    
    private func collaboratorHeader(_ album: SharedAlbum) -> some View {
        HStack(spacing: 0) {
            // Overlapping Avatars
            HStack(spacing: -10) {
                ForEach(album.collaborators.prefix(4)) { collab in
                    avatarCircle(for: collab)
                }
                
                if album.collaborators.count > 4 {
                    Circle()
                        .fill(Color(.systemGray4))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Text("+\(album.collaborators.count - 4)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.primary)
                        )
                }
            }
            .padding(.trailing, 12)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(album.collaborators.count) Collaborators")
                    .font(.system(size: 14, weight: .bold))
                Text("Owner: \(album.ownerName)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Actions
            HStack(spacing: 8) {
                // Simulation Button
                Button {
                    designStore.simulateCollaboratorAction(albumID: album.id, authManager: authManager)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                        Text("Simulate")
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            colors: [Color.accentColor, Color.purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: Color.accentColor.opacity(0.2), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(.plain)
                
                // Copy Link Button
                Button {
                    let link = "createo://album/join?id=\(album.id.uuidString)&name=\(album.albumName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
                    UIPasteboard.general.string = link
                    
                    withAnimation(.spring()) {
                        copiedHUD = true
                    }
                    Task {
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        await MainActor.run {
                            withAnimation {
                                copiedHUD = false
                            }
                        }
                    }
                } label: {
                    Image(systemName: "link.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func avatarCircle(for collaborator: Collaborator) -> some View {
        CollaboratorAvatarView(collaborator: collaborator, size: 36, fontSize: 12)
            .overlay(
                Circle()
                    .stroke(Color(.secondarySystemGroupedBackground), lineWidth: 2)
            )
    }
    
    // MARK: - Tab: Designs
    
    private func designsTab(_ album: SharedAlbum) -> some View {
        ScrollView {
            if albumDesigns.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No designs in this shared album")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Tap the '+' button in the top right corner to add designs.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .padding(.top, 80)
                .frame(maxWidth: .infinity)
            } else {
                LazyVGrid(columns: columns, spacing: gridSpacing) {
                    ForEach(albumDesigns) { design in
                        // Re-fetch dynamically in case model updates
                        let currentDesign = designStore.designs.first(where: { $0.id == design.id }) ?? design
                        
                        NavigationLink {
                            PreviewView(design: currentDesign)
                        } label: {
                            DesignImageView(path: currentDesign.thumbnailPath)
                                .scaledToFill()
                                .frame(width: cardSize.width, height: cardSize.height)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .shadow(color: Color.black.opacity(0.06), radius: 5, x: 0, y: 2)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.bottom, 30)
            }
        }
    }
    
    // MARK: - Tab: Recent Activity Feed
    
    private func activitiesTab(_ album: SharedAlbum) -> some View {
        ScrollView {
            VStack(spacing: 10) {
                if album.activities.isEmpty {
                    Text("No activities recorded yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    ForEach(album.activities.sorted(by: { $0.timestamp > $1.timestamp })) { activity in
                        HStack(alignment: .top, spacing: 14) {
                            // Icon Node
                            activityIcon(for: activity.activityType)
                                .frame(width: 36, height: 36)
                                .background(activityColor(for: activity.activityType).opacity(0.12))
                                .clipShape(Circle())
                            
                            VStack(alignment: .leading, spacing: 4) {
                                activityText(for: activity)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.primary)
                                
                                Text(relativeTimeString(for: activity.timestamp))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding(14)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: Color.black.opacity(0.02), radius: 6, x: 0, y: 3)
                    }
                }
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.top, 8)
            .padding(.bottom, 30)
        }
    }
    
    private func activityIcon(for type: String) -> some View {
        var name = "info.circle"
        switch type {
        case "created": name = "folder.badge.plus"
        case "joined": name = "person.badge.plus"
        case "added_design": name = "photo"
        case "removed_design": name = "trash"
        case "renamed_album": name = "pencil"
        default: break
        }
        return Image(systemName: name)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(activityColor(for: type))
    }
    
    private func activityColor(for type: String) -> Color {
        switch type {
        case "created": return .green
        case "joined": return .blue
        case "added_design": return .orange
        case "removed_design": return .red
        case "renamed_album": return .purple
        default: return .gray
        }
    }
    
    private func activityText(for activity: AlbumActivity) -> Text {
        let name = Text(activity.userName).bold()
        switch activity.activityType {
        case "created":
            return name + Text(" created the album.")
        case "joined":
            return name + Text(" joined the album.")
        case "added_design":
            return name + Text(" added design ") + Text("'\(activity.detail)'").bold().foregroundStyle(Color.accentColor)
        case "removed_design":
            return name + Text(" removed design ") + Text("'\(activity.detail)'").bold().foregroundStyle(.red)
        case "renamed_album":
            return name + Text(" renamed album to ") + Text("'\(activity.detail)'").bold()
        default:
            return name + Text(" performed an action.")
        }
    }
    
    private func relativeTimeString(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
