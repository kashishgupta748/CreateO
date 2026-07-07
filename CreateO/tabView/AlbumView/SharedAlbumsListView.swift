import SwiftUI

struct SharedAlbumsListView: View {
    @Environment(DataStore.self) var designStore
    @Environment(AuthManager.self) var authManager
    
    @State private var showJoinSheet = false
    @State private var joinInput = ""
    @State private var joinAlertMessage = ""
    @State private var showJoinAlert = false
    @State private var isSuccessAlert = false
    
    @State private var showCreateSheet = false
    @State private var newAlbumName = ""
    
    private let gridSpacing: CGFloat = 16
    private let horizontalPadding: CGFloat = 16
    private let cardHeight: CGFloat = 200
    
    private var columns: [GridItem] {
        [
            GridItem(.flexible(), spacing: gridSpacing),
            GridItem(.flexible(), spacing: gridSpacing)
        ]
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if designStore.sharedAlbums.isEmpty {
                    emptyState
                        .padding(.top, 40)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Active Projects")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, horizontalPadding)
                            .padding(.top, 16)
                        
                        LazyVGrid(columns: columns, spacing: gridSpacing) {
                            ForEach(designStore.sharedAlbums) { album in
                                NavigationLink {
                                    SharedAlbumDetailView(albumID: album.id)
                                } label: {
                                    sharedAlbumCard(album)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, horizontalPadding)
                    }
                    .padding(.bottom, 30)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Shared Albums")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        newAlbumName = ""
                        showCreateSheet = true
                    } label: {
                        Label("Create Collaborative Album", systemImage: "folder.badge.plus")
                    }
                    
                    Button {
                        joinInput = ""
                        showJoinSheet = true
                    } label: {
                        Label("Join Collaborative Album", systemImage: "person.badge.plus")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                }
            }
        }
        .sheet(isPresented: $showJoinSheet) {
            joinAlbumSheet
        }
        .sheet(isPresented: $showCreateSheet) {
            createAlbumSheet
        }
        .alert(isSuccessAlert ? "Joined Album!" : "Error", isPresented: $showJoinAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(joinAlertMessage)
        }
    }
    
    private var createAlbumSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Create Shared Album")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.primary)
                    .padding(.top, 10)
                
                Text("Start a new collaborative project. Invite friends to contribute designs and track activities.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                
                TextField("Album Name", text: $newAlbumName)
                    .font(.system(size: 15))
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                    )
                
                Button {
                    let name = newAlbumName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !name.isEmpty else { return }
                    
                    let _ = designStore.createSharedAlbum(named: name, initialDesignIDs: [], authManager: authManager)
                    
                    newAlbumName = ""
                    showCreateSheet = false
                } label: {
                    Text("Create Album")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(newAlbumName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(newAlbumName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .buttonStyle(.plain)
                
                Spacer()
            }
            .padding(24)
            .navigationTitle("New Shared Album")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        showCreateSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    private func sharedAlbumCard(_ album: SharedAlbum) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .bottom) {
                if !album.thumbnailPath.isEmpty {
                    DesignImageView(path: album.thumbnailPath)
                        .scaledToFill()
                        .frame(height: cardHeight - 50)
                        .frame(maxWidth: .infinity)
                        .clipped()
                } else {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                        .frame(height: cardHeight - 50)
                        .overlay {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 32))
                                .foregroundStyle(.secondary)
                        }
                }
                
                // Gradient Overlay for Legibility
                LinearGradient(
                    colors: [.clear, .black.opacity(0.55)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                // Bottom Content Overlay
                HStack(alignment: .center) {
                    // Owner Label
                    Text(album.ownerName)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.25))
                        .clipShape(Capsule())
                    
                    Spacer()
                    
                    // Overlapping Collaborators Row
                    HStack(spacing: -6) {
                        ForEach(album.collaborators.prefix(3)) { collab in
                            CollaboratorAvatarView(collaborator: collab, size: 20, fontSize: 7)
                                .overlay(
                                    Circle()
                                        .stroke(Color.black.opacity(0.15), lineWidth: 1)
                                )
                        }
                    }
                }
                .padding(10)
            }
            .frame(height: cardHeight - 50)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(album.albumName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text("\(album.collaborators.count) collaborator\(album.collaborators.count == 1 ? "" : "s")")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 5)
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 60)
            
            Image(systemName: "folder.badge.person.crop")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(.secondary.opacity(0.8))
            
            Text("No Shared Albums")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.primary)
            
            Text("Albums shared with you or collaborative projects will appear here.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button {
                joinInput = ""
                showJoinSheet = true
            } label: {
                Text("Join Shared Album")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(.top, 8)
            
            Spacer(minLength: 100)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var joinAlbumSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Enter Album Link or ID")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.primary)
                    .padding(.top, 10)
                
                Text("Ask the owner for a link, paste it below, and you'll be added to the shared project instantly.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                
                TextField("createo://album/join?id=...", text: $joinInput)
                    .font(.system(size: 15))
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                    )
                
                HStack(spacing: 12) {
                    Button {
                        if let clipboardString = UIPasteboard.general.string {
                            joinInput = clipboardString
                        }
                    } label: {
                        HStack {
                            Image(systemName: "doc.on.clipboard")
                            Text("Paste")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemGray5))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        let (success, albumName) = designStore.joinSharedAlbum(byLink: joinInput, authManager: authManager)
                        showJoinSheet = false
                        
                        if success {
                            isSuccessAlert = true
                            joinAlertMessage = "You joined '\(albumName)' successfully! You can now collaborate and view updates."
                            showJoinAlert = true
                        } else {
                            isSuccessAlert = false
                            joinAlertMessage = "Invalid shared link or album ID. Please check the code and try again."
                            showJoinAlert = true
                        }
                    } label: {
                        Text("Join Album")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(joinInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(joinInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .buttonStyle(.plain)
                }
                
                Spacer()
            }
            .padding(24)
            .navigationTitle("Join Album")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showJoinSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
