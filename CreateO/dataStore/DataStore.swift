
import Foundation
import Observation

// MARK: - DataStore

@Observable
class DataStore {
    // MARK: - In-memory collections

    var designs: [Design] = []
    var albums: [Album] = []
    var sharedAlbums: [SharedAlbum] = []

    // Set to true once bootstrap() has resolved auth and loaded data.
    private(set) var isReady = false

    private var bootstrappedState: AuthState?

    // Tracks whether we are in guest mode so mutation methods can skip
    // persistence (guests never write to disk or cloud).
    private var isGuest = false

    // Lazy Supabase service instances — created only if the user is authenticated.
    private var dbService: SupabaseDatabaseService?
    private var storageService: SupabaseStorageService?
    private var currentAuthManager: AuthManager?

    private func sanitizedIdentifier(_ raw: String) -> String {
        raw.replacingOccurrences(
            of: #"[^A-Za-z0-9]+"#,
            with: "_",
            options: .regularExpression
        )
        .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
    }

    private func cacheFilename(prefix: String, authManager: AuthManager) -> String {
        let identifier: String
        if let userID = authManager.currentUserID {
            identifier = userID.uuidString
        } else if let email = authManager.currentUserEmail, !email.isEmpty {
            identifier = "pending_\(sanitizedIdentifier(email))"
        } else {
            identifier = "guest"
        }
        return "\(prefix)_\(identifier).json"
    }

    // MARK: - Bootstrap

    /// Called once from the app entry point after auth state is resolved.
    func bootstrap(authManager: AuthManager) async {
        guard bootstrappedState != authManager.state || !isReady else { return }
        bootstrappedState = authManager.state

        switch authManager.state {
        case .guest:
            isGuest = true
            currentAuthManager = nil
            loadDummyData()
            await MainActor.run { isReady = true }

        case .pendingEmailConfirmation:
            isGuest = false
            currentAuthManager = authManager
            dbService = nil
            storageService = nil

            loadLocalCache(authManager: authManager)
            await MainActor.run { isReady = true }

        case .authenticated:
            isGuest = false
            currentAuthManager = authManager
            dbService = SupabaseDatabaseService()
            storageService = SupabaseStorageService()

            // Load cached data first for an instant UI.
            loadLocalCache(authManager: authManager)
            await MainActor.run { isReady = true }

            // Then sync from the cloud in the background.
            await syncFromSupabase(authManager: authManager)

        case .loading:
            // Will be called again once state resolves.
            break
        }
    }

    // MARK: - Guest dummy data

    private func loadDummyData() {
        designs = Self.makeDummyDesigns()
        albums = Self.makeDummyAlbums(from: designs)
        sharedAlbums = Self.makeDummySharedAlbums(from: designs)
    }

    // MARK: - Local cache (authenticated users only)

    private func loadLocalCache(authManager: AuthManager) {
        if let savedDesigns = LocalFileService.load(
            [Design].self,
            fromFile: cacheFilename(prefix: "designs", authManager: authManager)
        ) {
            designs = savedDesigns
        } else {
            designs = []
        }

        if let savedAlbums = LocalFileService.load(
            [Album].self,
            fromFile: cacheFilename(prefix: "albums", authManager: authManager)
        ) {
            albums = savedAlbums
        } else {
            albums = []
        }

        if let savedSharedAlbums = LocalFileService.load(
            [SharedAlbum].self,
            fromFile: cacheFilename(prefix: "shared_albums", authManager: authManager)
        ) {
            sharedAlbums = savedSharedAlbums
        } else {
            sharedAlbums = []
        }
    }

    private func saveLocalCache(authManager: AuthManager) {
        guard !isGuest else { return }
        LocalFileService.save(
            designs,
            toFile: cacheFilename(prefix: "designs", authManager: authManager)
        )
        LocalFileService.save(
            albums,
            toFile: cacheFilename(prefix: "albums", authManager: authManager)
        )
        LocalFileService.save(
            sharedAlbums,
            toFile: cacheFilename(prefix: "shared_albums", authManager: authManager)
        )
    }

    // MARK: - Supabase sync (authenticated users only)

    func syncFromSupabase(authManager: AuthManager) async {
        guard authManager.isLoggedIn,
              let db = dbService,
              let userID = authManager.currentUserID else { return }

        do {
            let designDTOs = try await db.fetchDesigns(for: userID)
            let albumDTOs  = try await db.fetchAlbums(for: userID)

            let remoteDesigns = designDTOs.map { dto -> Design in
                Design(
                    id: dto.id,
                    designName: dto.designName,
                    createdAt: dto.createdAt,
                    updatedAt: dto.updatedAt,
                    isFavorite: dto.isFavorite,
                    designType: DesignType(rawValue: dto.designType) ?? .image,
                    designHeight: dto.designHeight,
                    designWidth: dto.designWidth,
                    designPath: dto.mediaURL,
                    thumbnailPath: dto.thumbnailURL,
                    albumID: dto.albumID,
                    cloudSynced: true,
                    projectPath: dto.projectPath
                )
            }

            let remoteAlbums = albumDTOs.map { dto -> Album in
                // Albums don't have a design-ID list in the DB; we derive it
                // from designs that reference that albumID.
                let designIDs = remoteDesigns
                    .filter { $0.albumID == dto.id }
                    .map(\.id)

                return Album(
                    id: dto.id,
                    albumName: dto.albumName,
                    createdAt: dto.createdAt,
                    updatedAt: dto.updatedAt,
                    albumPath: "",
                    thumbnailPath: dto.thumbnailURL,
                    albumDesignIDs: designIDs
                )
            }

            await MainActor.run {
                designs = remoteDesigns
                albums  = remoteAlbums
            }

            saveLocalCache(authManager: authManager)
        } catch {
            // Network failure is non-fatal; local cache is already shown.
        }
    }

    // MARK: - Cloud upload (authenticated users only)

    /// Uploads a design's preview image to Supabase Storage and writes the
    /// metadata row to the database. Called in a background task after local save.
    func uploadDesignToCloud(design: Design, authManager: AuthManager) async {
        guard authManager.isLoggedIn,
              let db = dbService,
              let storage = storageService,
              let userID = authManager.currentUserID else { return }

        do {
            // Upload the preview PNG if it is a local file path.
            var mediaURL = design.designPath
            var thumbURL = design.thumbnailPath

            if design.designPath.hasPrefix("/") {
                let localURL = URL(fileURLWithPath: design.designPath)
                if let data = try? Data(contentsOf: localURL) {
                    let remotePath = "\(userID)/\(design.id.uuidString).png"
                    let uploaded = try await storage.upload(
                        data: data,
                        bucket: "designs",
                        path: remotePath
                    )
                    mediaURL = uploaded.absoluteString
                    thumbURL = uploaded.absoluteString
                }
            }

            let dto = DesignDTO(
                id: design.id,
                userID: userID,
                designName: design.designName,
                designType: design.designType.rawValue,
                isFavorite: design.isFavorite,
                designHeight: design.designHeight,
                designWidth: design.designWidth,
                mediaURL: mediaURL,
                thumbnailURL: thumbURL,
                albumID: design.albumID,
                projectPath: design.projectPath,
                createdAt: design.createdAt,
                updatedAt: design.updatedAt
            )

            // Upsert: insert if new, update if it exists.
            if designs.first(where: { $0.id == design.id })?.cloudSynced == true {
                try await db.updateDesign(dto)
            } else {
                try await db.insertDesign(dto)
            }

            // Mark as synced in the local store.
            await MainActor.run {
                if let idx = designs.firstIndex(where: { $0.id == design.id }) {
                    designs[idx].cloudSynced = true
                    designs[idx].designPath  = mediaURL
                    designs[idx].thumbnailPath = thumbURL
                }
            }
            saveLocalCache(authManager: authManager)
        } catch {
            // Cloud sync failure is silent; next launch will retry via syncFromSupabase.
        }
    }

    /// Uploads an album to Supabase (insert or update).
    func uploadAlbumToCloud(album: Album, authManager: AuthManager) async {
        guard authManager.isLoggedIn,
              let db = dbService,
              let userID = authManager.currentUserID else { return }

        let dto = AlbumDTO(
            id: album.id,
            userID: userID,
            albumName: album.albumName,
            thumbnailURL: album.thumbnailPath,
            createdAt: album.createdAt,
            updatedAt: album.updatedAt
        )

        do {
            try await db.insertAlbum(dto)
        } catch {
            // Might already exist — try update.
            try? await db.updateAlbum(dto)
        }
    }

    // MARK: - Clear & reload for login transition

    func clearAndLoadFromCloud(authManager: AuthManager) async {
        isGuest = false
        currentAuthManager = authManager
        dbService = dbService ?? SupabaseDatabaseService()
        storageService = storageService ?? SupabaseStorageService()
        bootstrappedState = .authenticated

        await MainActor.run {
            designs = []
            albums  = []
        }
        // Load any previously cached data for this account.
        loadLocalCache(authManager: authManager)
        await syncFromSupabase(authManager: authManager)
    }

    /// Resets to guest mode after sign-out.
    func resetToGuestMode() {
        isGuest = true
        currentAuthManager = nil
        dbService = nil
        storageService = nil
        bootstrappedState = .guest
        loadDummyData()
        isReady = true
    }

    // MARK: - Mutations

    func saveAlbum(albumName: String, selectedDesignID: [UUID]) {
        let name = albumName
        let selectedDesign = designs.filter { selectedDesignID.contains($0.id) }
        let thumbnail = selectedDesign.first?.thumbnailPath ?? ""
        let newAlbum = Album(
            id: UUID(),
            albumName: name,
            createdAt: Date(),
            updatedAt: nil,
            albumPath: "",
            thumbnailPath: thumbnail,
            albumDesignIDs: selectedDesignID
        )
        albums.append(newAlbum)
        if let authManager = currentAuthManager {
            saveLocalCache(authManager: authManager)
        }
    }

    func createAlbum(named albumName: String, initialDesignIDs: [UUID]) -> UUID {
        let trimmedName = albumName.trimmingCharacters(in: .whitespacesAndNewlines)
        let selectedDesign = designs.filter { initialDesignIDs.contains($0.id) }
        let thumbnail = selectedDesign.first?.thumbnailPath ?? ""
        let album = Album(
            id: UUID(),
            albumName: trimmedName.isEmpty ? "Untitled Album" : trimmedName,
            createdAt: Date(),
            updatedAt: nil,
            albumPath: "",
            thumbnailPath: thumbnail,
            albumDesignIDs: initialDesignIDs
        )
        albums.append(album)
        if let authManager = currentAuthManager {
            saveLocalCache(authManager: authManager)
        }
        return album.id
    }

    func addDesign(_ designID: UUID, toAlbum albumID: UUID) {
        guard let index = albums.firstIndex(where: { $0.id == albumID }) else { return }
        if !albums[index].albumDesignIDs.contains(designID) {
            albums[index].albumDesignIDs.append(designID)
        }
        if let design = designs.first(where: { $0.id == designID }),
           albums[index].thumbnailPath.isEmpty {
            albums[index].thumbnailPath = design.thumbnailPath
        }
        albums[index].updatedAt = Date()
        if let authManager = currentAuthManager {
            saveLocalCache(authManager: authManager)
        }
    }

    func updateAlbumDesigns(albumID: UUID, designIDs: [UUID]) {
        guard let index = albums.firstIndex(where: { $0.id == albumID }) else { return }
        albums[index].albumDesignIDs = designIDs
        
        let selectedDesign = designs.filter { designIDs.contains($0.id) }
        albums[index].thumbnailPath = selectedDesign.first?.thumbnailPath ?? ""
        
        albums[index].updatedAt = Date()
        if let authManager = currentAuthManager {
            saveLocalCache(authManager: authManager)
        }
    }

    func deleteAlbum(album: Album) {
        albums.removeAll { $0.id == album.id }
        if let authManager = currentAuthManager {
            saveLocalCache(authManager: authManager)
        }
    }

    func deleteDesign(design: Design) {
        deletePersistedAssetIfNeeded(at: design.designPath)
        if design.thumbnailPath != design.designPath {
            deletePersistedAssetIfNeeded(at: design.thumbnailPath)
        }
        if let projectPath = design.projectPath {
            deletePersistedProjectIfNeeded(at: projectPath)
        }
        designs.removeAll { $0.id == design.id }
        for index in albums.indices {
            albums[index].albumDesignIDs.removeAll { $0 == design.id }
        }
        if let authManager = currentAuthManager {
            saveLocalCache(authManager: authManager)
        }
    }

    func updateDesign(design: Design) {
        if let index = designs.firstIndex(where: { $0.id == design.id }) {
            designs[index] = design
        }
        if let authManager = currentAuthManager {
            saveLocalCache(authManager: authManager)
        }
    }

    func renameDesign(id: UUID, newName: String) {
        if let index = designs.firstIndex(where: { $0.id == id }) {
            designs[index].designName = newName
            designs[index].updatedAt  = Date()
        }
        if let authManager = currentAuthManager {
            saveLocalCache(authManager: authManager)
        }
    }

    func renameAlbum(id: UUID, newName: String) {
        if let index = albums.firstIndex(where: { $0.id == id }) {
            albums[index].albumName = newName
            albums[index].updatedAt  = Date()
        }
        if let authManager = currentAuthManager {
            saveLocalCache(authManager: authManager)
        }
    }

    func toggleFavorite(id: UUID) {
        if let index = designs.firstIndex(where: { $0.id == id }) {
            designs[index].isFavorite.toggle()
        }
        if let authManager = currentAuthManager {
            saveLocalCache(authManager: authManager)
        }
    }

    func removeFavourite(_ design: Design) {
        if let index = designs.firstIndex(where: { $0.id == design.id }) {
            designs[index].isFavorite = false
        }
        if let authManager = currentAuthManager {
            saveLocalCache(authManager: authManager)
        }
    }

    func countAllDesigns() -> Int {
        designs.count
    }

    // MARK: - Compat shims (kept for existing callers)

    func markAllAsUnsynced() {
        for index in designs.indices {
            designs[index].cloudSynced = false
        }
        if let authManager = currentAuthManager {
            saveLocalCache(authManager: authManager)
        }
    }

    // MARK: - Private helpers

    private func deletePersistedAssetIfNeeded(at path: String) {
        guard !path.isEmpty else { return }
        let fileURL = URL(fileURLWithPath: path)
        let documentsDirectory = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        ).first
        guard let documentsDirectory,
              fileURL.path.hasPrefix(documentsDirectory.path),
              FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func deletePersistedProjectIfNeeded(at path: String) {
        guard !path.isEmpty else { return }
        let projectURL = URL(fileURLWithPath: path, isDirectory: true)
        let documentsDirectory = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        ).first
        guard let documentsDirectory,
              projectURL.path.hasPrefix(documentsDirectory.path),
              FileManager.default.fileExists(atPath: projectURL.path) else { return }
        try? FileManager.default.removeItem(at: projectURL)
    }

    // MARK: - Shared Album Mutations

    func createSharedAlbum(named name: String, initialDesignIDs: [UUID], authManager: AuthManager) -> UUID {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let albumName = trimmedName.isEmpty ? "Untitled Shared Album" : trimmedName
        
        let selectedDesign = designs.filter { initialDesignIDs.contains($0.id) }
        let thumbnail = selectedDesign.first?.thumbnailPath ?? ""
        
        let currentUserId = authManager.currentUserID ?? UUID()
        let currentUserEmail = authManager.currentUserEmail ?? "guest@createo.app"
        let currentUserName = currentUserEmail.components(separatedBy: "@").first ?? "Guest User"
        
        let currentCollaborator = Collaborator(
            id: currentUserId,
            name: currentUserName.capitalized,
            email: currentUserEmail,
            avatarColorHex: "#26A69A",
            isCurrentUser: true
        )
        
        let albumID = UUID()
        
        let newSharedAlbum = SharedAlbum(
            id: albumID,
            albumName: albumName,
            ownerName: currentUserName.capitalized,
            ownerID: currentUserId,
            createdAt: Date(),
            updatedAt: nil,
            thumbnailPath: thumbnail,
            designIDs: initialDesignIDs,
            collaborators: [currentCollaborator],
            activities: [
                AlbumActivity(
                    id: UUID(),
                    userName: currentUserName.capitalized,
                    userEmail: currentUserEmail,
                    activityType: "created",
                    detail: "",
                    timestamp: Date()
                )
            ]
        )
        
        sharedAlbums.append(newSharedAlbum)
        saveLocalCache(authManager: authManager)
        return albumID
    }

    func shareExistingAlbum(album: Album, authManager: AuthManager) -> UUID {
        // If it's already a shared album, return its ID
        if let existing = sharedAlbums.first(where: { $0.id == album.id }) {
            return existing.id
        }
        
        let currentUserId = authManager.currentUserID ?? UUID()
        let currentUserEmail = authManager.currentUserEmail ?? "guest@createo.app"
        let currentUserName = currentUserEmail.components(separatedBy: "@").first ?? "Guest User"
        
        let currentCollaborator = Collaborator(
            id: currentUserId,
            name: currentUserName.capitalized,
            email: currentUserEmail,
            avatarColorHex: "#26A69A",
            isCurrentUser: true
        )
        
        let newSharedAlbum = SharedAlbum(
            id: album.id,
            albumName: album.albumName,
            ownerName: currentUserName.capitalized,
            ownerID: currentUserId,
            createdAt: album.createdAt,
            updatedAt: Date(),
            thumbnailPath: album.thumbnailPath,
            designIDs: album.albumDesignIDs,
            collaborators: [currentCollaborator],
            activities: [
                AlbumActivity(
                    id: UUID(),
                    userName: currentUserName.capitalized,
                    userEmail: currentUserEmail,
                    activityType: "created",
                    detail: "",
                    timestamp: Date()
                )
            ]
        )
        
        sharedAlbums.append(newSharedAlbum)
        saveLocalCache(authManager: authManager)
        return album.id
    }

    func joinSharedAlbum(byLink linkOrId: String, authManager: AuthManager) -> (success: Bool, albumName: String) {
        var targetIdString = ""
        var targetName = ""
        
        if let url = URL(string: linkOrId.trimmingCharacters(in: .whitespacesAndNewlines)),
           let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
           let queryItems = components.queryItems {
            targetIdString = queryItems.first(where: { $0.name == "id" })?.value ?? ""
            targetName = queryItems.first(where: { $0.name == "name" })?.value ?? ""
        } else {
            targetIdString = linkOrId.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        guard let albumID = UUID(uuidString: targetIdString) else {
            return (false, "")
        }
        
        let resolvedName = targetName.isEmpty ? "Collaborative Album" : targetName
        
        // Check if already joined
        if let index = sharedAlbums.firstIndex(where: { $0.id == albumID }) {
            let currentUserEmail = authManager.currentUserEmail ?? "guest@createo.app"
            let currentUserId = authManager.currentUserID ?? UUID()
            let currentUserName = currentUserEmail.components(separatedBy: "@").first ?? "Guest User"
            
            if !sharedAlbums[index].collaborators.contains(where: { $0.email == currentUserEmail }) {
                let currentCollaborator = Collaborator(
                    id: currentUserId,
                    name: currentUserName.capitalized,
                    email: currentUserEmail,
                    avatarColorHex: "#FFB74D",
                    isCurrentUser: true
                )
                sharedAlbums[index].collaborators.append(currentCollaborator)
                sharedAlbums[index].activities.append(
                    AlbumActivity(
                        id: UUID(),
                        userName: currentUserName.capitalized,
                        userEmail: currentUserEmail,
                        activityType: "joined",
                        detail: "",
                        timestamp: Date()
                    )
                )
                saveLocalCache(authManager: authManager)
            }
            return (true, sharedAlbums[index].albumName)
        }
        
        let currentUserId = authManager.currentUserID ?? UUID()
        let currentUserEmail = authManager.currentUserEmail ?? "guest@createo.app"
        let currentUserName = currentUserEmail.components(separatedBy: "@").first ?? "Guest User"
        
        let currentCollaborator = Collaborator(
            id: currentUserId,
            name: currentUserName.capitalized,
            email: currentUserEmail,
            avatarColorHex: "#26A69A",
            isCurrentUser: true
        )
        
        let ownerID = UUID()
        let ownerName = "Jane Miller"
        
        let randomDesigns = Array(designs.shuffled().prefix(3))
        let designIDs = randomDesigns.map(\.id)
        let thumbnail = randomDesigns.first?.thumbnailPath ?? ""
        
        let newSharedAlbum = SharedAlbum(
            id: albumID,
            albumName: resolvedName,
            ownerName: ownerName,
            ownerID: ownerID,
            createdAt: Date().addingTimeInterval(-86400),
            updatedAt: Date(),
            thumbnailPath: thumbnail,
            designIDs: designIDs,
            collaborators: [
                Collaborator(id: ownerID, name: ownerName, email: "jane@createo.design", avatarColorHex: "#EC407A", isCurrentUser: false),
                currentCollaborator
            ],
            activities: [
                AlbumActivity(id: UUID(), userName: ownerName, userEmail: "jane@createo.design", activityType: "created", detail: "", timestamp: Date().addingTimeInterval(-86400)),
                AlbumActivity(id: UUID(), userName: ownerName, userEmail: "jane@createo.design", activityType: "added_design", detail: randomDesigns.first?.designName ?? "Design", timestamp: Date().addingTimeInterval(-86400 + 3600)),
                AlbumActivity(id: UUID(), userName: currentUserName.capitalized, userEmail: currentUserEmail, activityType: "joined", detail: "", timestamp: Date())
            ]
        )
        
        sharedAlbums.append(newSharedAlbum)
        saveLocalCache(authManager: authManager)
        return (true, resolvedName)
    }

    func addDesignToSharedAlbum(albumID: UUID, designID: UUID, authManager: AuthManager) {
        guard let index = sharedAlbums.firstIndex(where: { $0.id == albumID }) else { return }
        
        if !sharedAlbums[index].designIDs.contains(designID) {
            sharedAlbums[index].designIDs.append(designID)
        }
        
        if let design = designs.first(where: { $0.id == designID }) {
            sharedAlbums[index].thumbnailPath = design.thumbnailPath
        }
        
        let currentUserEmail = authManager.currentUserEmail ?? "guest@createo.app"
        let currentUserName = currentUserEmail.components(separatedBy: "@").first ?? "Guest User"
        let designName = designs.first(where: { $0.id == designID })?.designName ?? "a design"
        
        sharedAlbums[index].activities.append(
            AlbumActivity(
                id: UUID(),
                userName: currentUserName.capitalized,
                userEmail: currentUserEmail,
                activityType: "added_design",
                detail: designName,
                timestamp: Date()
            )
        )
        
        sharedAlbums[index].updatedAt = Date()
        saveLocalCache(authManager: authManager)
    }

    func removeDesignFromSharedAlbum(albumID: UUID, designID: UUID, authManager: AuthManager) {
        guard let index = sharedAlbums.firstIndex(where: { $0.id == albumID }) else { return }
        
        let designName = designs.first(where: { $0.id == designID })?.designName ?? "a design"
        sharedAlbums[index].designIDs.removeAll { $0 == designID }
        
        if let firstID = sharedAlbums[index].designIDs.first,
           let design = designs.first(where: { $0.id == firstID }) {
            sharedAlbums[index].thumbnailPath = design.thumbnailPath
        } else {
            sharedAlbums[index].thumbnailPath = ""
        }
        
        let currentUserEmail = authManager.currentUserEmail ?? "guest@createo.app"
        let currentUserName = currentUserEmail.components(separatedBy: "@").first ?? "Guest User"
        
        sharedAlbums[index].activities.append(
            AlbumActivity(
                id: UUID(),
                userName: currentUserName.capitalized,
                userEmail: currentUserEmail,
                activityType: "removed_design",
                detail: designName,
                timestamp: Date()
            )
        )
        
        sharedAlbums[index].updatedAt = Date()
        saveLocalCache(authManager: authManager)
    }

    func renameSharedAlbum(albumID: UUID, newName: String, authManager: AuthManager) {
        guard let index = sharedAlbums.firstIndex(where: { $0.id == albumID }) else { return }
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        sharedAlbums[index].albumName = trimmedName
        
        let currentUserEmail = authManager.currentUserEmail ?? "guest@createo.app"
        let currentUserName = currentUserEmail.components(separatedBy: "@").first ?? "Guest User"
        
        sharedAlbums[index].activities.append(
            AlbumActivity(
                id: UUID(),
                userName: currentUserName.capitalized,
                userEmail: currentUserEmail,
                activityType: "renamed_album",
                detail: trimmedName,
                timestamp: Date()
            )
        )
        
        sharedAlbums[index].updatedAt = Date()
        saveLocalCache(authManager: authManager)
    }

    func deleteSharedAlbum(albumID: UUID, authManager: AuthManager) {
        sharedAlbums.removeAll { $0.id == albumID }
        saveLocalCache(authManager: authManager)
    }

    func simulateCollaboratorAction(albumID: UUID, authManager: AuthManager) {
        guard let index = sharedAlbums.firstIndex(where: { $0.id == albumID }) else { return }
        
        let mockNames = ["Sophia Martinez", "Liam Vance", "Emma Watson", "Alex Turner", "Chloe Bennett", "Daniel Craig"]
        let mockEmails = ["sophia@createo.design", "liam@createo.design", "emma@createo.design", "alex@createo.design", "chloe@createo.design", "daniel@createo.design"]
        let mockColors = ["#E91E63", "#9C27B0", "#673AB7", "#3F51B5", "#2196F3", "#00BCD4", "#4CAF50", "#FFC107", "#FF5722"]
        
        let randIdx = Int.random(in: 0..<mockNames.count)
        let name = mockNames[randIdx]
        let email = mockEmails[randIdx]
        let color = mockColors.randomElement() ?? "#E91E63"
        
        let newCollab = Collaborator(id: UUID(), name: name, email: email, avatarColorHex: color, isCurrentUser: false)
        
        if !sharedAlbums[index].collaborators.contains(where: { $0.email == email }) {
            sharedAlbums[index].collaborators.append(newCollab)
        }
        
        sharedAlbums[index].activities.append(
            AlbumActivity(
                id: UUID(),
                userName: name,
                userEmail: email,
                activityType: "joined",
                detail: "",
                timestamp: Date()
            )
        )
        saveLocalCache(authManager: authManager)
        
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            
            await MainActor.run {
                guard let idx = self.sharedAlbums.firstIndex(where: { $0.id == albumID }) else { return }
                let localDesigns = self.designs
                guard !localDesigns.isEmpty else { return }
                
                let currentDesignIDs = self.sharedAlbums[idx].designIDs
                let candidateDesigns = localDesigns.filter { !currentDesignIDs.contains($0.id) }
                let designToAdd = candidateDesigns.randomElement() ?? localDesigns.randomElement()!
                
                self.sharedAlbums[idx].designIDs.append(designToAdd.id)
                self.sharedAlbums[idx].thumbnailPath = designToAdd.thumbnailPath
                
                self.sharedAlbums[idx].activities.append(
                    AlbumActivity(
                        id: UUID(),
                        userName: name,
                        userEmail: email,
                        activityType: "added_design",
                        detail: designToAdd.designName,
                        timestamp: Date()
                    )
                )
                self.sharedAlbums[idx].updatedAt = Date()
                self.saveLocalCache(authManager: authManager)
                
                NotificationCenter.default.post(
                    name: NSNotification.Name("SharedAlbumUpdate"),
                    object: nil,
                    userInfo: ["albumName": self.sharedAlbums[idx].albumName, "collaboratorName": name, "designName": designToAdd.designName]
                )
            }
        }
    }
}

// MARK: - Dummy data factory (guest / unauthenticated preview)

private extension DataStore {

    static func makeDummyDesigns() -> [Design] {
        [
            Design(id: UUID(), designName: "Sunset Glow",    createdAt: Date(timeIntervalSinceNow: -86400 * 149), updatedAt: nil, isFavorite: true,  designType: .image, designPath: "img1",  thumbnailPath: "img1",  albumID: nil),
            Design(id: UUID(), designName: "Ocean Breeze",   createdAt: Date(timeIntervalSinceNow: -86400 * 141), updatedAt: nil, isFavorite: false, designType: .image, designPath: "img2",  thumbnailPath: "img2",  albumID: nil),
            Design(id: UUID(), designName: "Floral Dream",   createdAt: Date(timeIntervalSinceNow: -86400 * 136), updatedAt: nil, isFavorite: true,  designType: .image, designPath: "img3",  thumbnailPath: "img3",  albumID: nil),
            Design(id: UUID(), designName: "Night Sky",      createdAt: Date(timeIntervalSinceNow: -86400 * 128), updatedAt: nil, isFavorite: false, designType: .image, designPath: "img4",  thumbnailPath: "img4",  albumID: nil),
            Design(id: UUID(), designName: "City Lights",    createdAt: Date(timeIntervalSinceNow: -86400 * 121), updatedAt: nil, isFavorite: true,  designType: .image, designPath: "img5",  thumbnailPath: "img5",  albumID: nil),
            Design(id: UUID(), designName: "Soft Pastel",    createdAt: Date(timeIntervalSinceNow: -86400 * 115), updatedAt: nil, isFavorite: false, designType: .image, designPath: "img6",  thumbnailPath: "img6",  albumID: nil),
            Design(id: UUID(), designName: "Golden Hour",    createdAt: Date(timeIntervalSinceNow: -86400 * 108), updatedAt: nil, isFavorite: true,  designType: .image, designPath: "img7",  thumbnailPath: "img7",  albumID: nil),
            Design(id: UUID(), designName: "Mountain Peak",  createdAt: Date(timeIntervalSinceNow: -86400 * 102), updatedAt: nil, isFavorite: false, designType: .image, designPath: "img8",  thumbnailPath: "img8",  albumID: nil),
            Design(id: UUID(), designName: "Abstract Art",   createdAt: Date(timeIntervalSinceNow: -86400 * 97),  updatedAt: nil, isFavorite: true,  designType: .image, designPath: "img9",  thumbnailPath: "img9",  albumID: nil),
            Design(id: UUID(), designName: "Cute Doodle",    createdAt: Date(timeIntervalSinceNow: -86400 * 91),  updatedAt: nil, isFavorite: true,  designType: .image, designPath: "img10", thumbnailPath: "img10", albumID: nil),
            Design(id: UUID(), designName: "Dreamscape",     createdAt: Date(timeIntervalSinceNow: -86400 * 85),  updatedAt: nil, isFavorite: true,  designType: .image, designPath: "img11", thumbnailPath: "img11", albumID: nil),
            Design(id: UUID(), designName: "Vintage Mood",   createdAt: Date(timeIntervalSinceNow: -86400 * 79),  updatedAt: nil, isFavorite: false, designType: .image, designPath: "img12", thumbnailPath: "img12", albumID: nil),
            Design(id: UUID(), designName: "Bright Pop",     createdAt: Date(timeIntervalSinceNow: -86400 * 74),  updatedAt: nil, isFavorite: true,  designType: .image, designPath: "img13", thumbnailPath: "img13", albumID: nil),
            Design(id: UUID(), designName: "Soft Blur",      createdAt: Date(timeIntervalSinceNow: -86400 * 69),  updatedAt: nil, isFavorite: true,  designType: .image, designPath: "img14", thumbnailPath: "img14", albumID: nil),
            Design(id: UUID(), designName: "Rainbow Splash", createdAt: Date(timeIntervalSinceNow: -86400 * 64),  updatedAt: nil, isFavorite: true,  designType: .image, designPath: "img15", thumbnailPath: "img15", albumID: nil),
            Design(id: UUID(), designName: "Nature Calm",    createdAt: Date(timeIntervalSinceNow: -86400 * 60),  updatedAt: nil, isFavorite: false, designType: .image, designPath: "img16", thumbnailPath: "img16", albumID: nil),
            Design(id: UUID(), designName: "Sketch Lines",   createdAt: Date(timeIntervalSinceNow: -86400 * 56),  updatedAt: nil, isFavorite: true,  designType: .image, designPath: "img17", thumbnailPath: "img17", albumID: nil),
            Design(id: UUID(), designName: "Ink Flow",       createdAt: Date(timeIntervalSinceNow: -86400 * 52),  updatedAt: nil, isFavorite: false, designType: .image, designPath: "img18", thumbnailPath: "img18", albumID: nil),
            Design(id: UUID(), designName: "Minimal Space",  createdAt: Date(timeIntervalSinceNow: -86400 * 48),  updatedAt: nil, isFavorite: true,  designType: .image, designPath: "img19", thumbnailPath: "img19", albumID: nil),
            Design(id: UUID(), designName: "Dark Mode",      createdAt: Date(timeIntervalSinceNow: -86400 * 44),  updatedAt: nil, isFavorite: false, designType: .image, designPath: "img20", thumbnailPath: "img20", albumID: nil),
            Design(id: UUID(), designName: "Fantasy Glow",   createdAt: Date(timeIntervalSinceNow: -86400 * 40),  updatedAt: nil, isFavorite: true,  designType: .image, designPath: "img21", thumbnailPath: "img21", albumID: nil),
            Design(id: UUID(), designName: "Crystal Light",  createdAt: Date(timeIntervalSinceNow: -86400 * 36),  updatedAt: nil, isFavorite: false, designType: .image, designPath: "img22", thumbnailPath: "img22", albumID: nil),
            Design(id: UUID(), designName: "Soft Glow",      createdAt: Date(timeIntervalSinceNow: -86400 * 32),  updatedAt: nil, isFavorite: true,  designType: .image, designPath: "img23", thumbnailPath: "img23", albumID: nil),
            Design(id: UUID(), designName: "Dream Pink",     createdAt: Date(timeIntervalSinceNow: -86400 * 29),  updatedAt: nil, isFavorite: false, designType: .image, designPath: "img24", thumbnailPath: "img24", albumID: nil),
            Design(id: UUID(), designName: "Bold Lines",     createdAt: Date(timeIntervalSinceNow: -86400 * 26),  updatedAt: nil, isFavorite: true,  designType: .image, designPath: "img25", thumbnailPath: "img25", albumID: nil),
            Design(id: UUID(), designName: "Neon Light",     createdAt: Date(timeIntervalSinceNow: -86400 * 23),  updatedAt: nil, isFavorite: false, designType: .image, designPath: "img26", thumbnailPath: "img26", albumID: nil),
            Design(id: UUID(), designName: "Galaxy Art",     createdAt: Date(timeIntervalSinceNow: -86400 * 20),  updatedAt: nil, isFavorite: true,  designType: .image, designPath: "img27", thumbnailPath: "img27", albumID: nil),
            Design(id: UUID(), designName: "Sky Blue",       createdAt: Date(timeIntervalSinceNow: -86400 * 17),  updatedAt: nil, isFavorite: false, designType: .image, designPath: "img28", thumbnailPath: "img28", albumID: nil),
            Design(id: UUID(), designName: "Magic Dust",     createdAt: Date(timeIntervalSinceNow: -86400 * 14),  updatedAt: nil, isFavorite: true,  designType: .image, designPath: "img29", thumbnailPath: "img29", albumID: nil),
            Design(id: UUID(), designName: "Blur Fade",      createdAt: Date(timeIntervalSinceNow: -86400 * 12),  updatedAt: nil, isFavorite: false, designType: .image, designPath: "img30", thumbnailPath: "img30", albumID: nil),
            Design(id: UUID(), designName: "Warm Tone",      createdAt: Date(timeIntervalSinceNow: -86400 * 10),  updatedAt: nil, isFavorite: true,  designType: .image, designPath: "img31", thumbnailPath: "img31", albumID: nil),
            Design(id: UUID(), designName: "Cool Shade",     createdAt: Date(timeIntervalSinceNow: -86400 * 9),   updatedAt: nil, isFavorite: false, designType: .image, designPath: "img32", thumbnailPath: "img32", albumID: nil),
            Design(id: UUID(), designName: "Light Fade",     createdAt: Date(timeIntervalSinceNow: -86400 * 8),   updatedAt: nil, isFavorite: true,  designType: .image, designPath: "img33", thumbnailPath: "img33", albumID: nil),
            Design(id: UUID(), designName: "Sharp Edge",     createdAt: Date(timeIntervalSinceNow: -86400 * 7),   updatedAt: nil, isFavorite: false, designType: .image, designPath: "img34", thumbnailPath: "img34", albumID: nil),
            Design(id: UUID(), designName: "Glow Pop",       createdAt: Date(timeIntervalSinceNow: -86400 * 6),   updatedAt: nil, isFavorite: true,  designType: .image, designPath: "img35", thumbnailPath: "img35", albumID: nil),
            Design(id: UUID(), designName: "Retro Style",    createdAt: Date(timeIntervalSinceNow: -86400 * 5),   updatedAt: nil, isFavorite: false, designType: .image, designPath: "img36", thumbnailPath: "img36", albumID: nil),
            Design(id: UUID(), designName: "Ink Shadow",     createdAt: Date(timeIntervalSinceNow: -86400 * 4),   updatedAt: nil, isFavorite: true,  designType: .image, designPath: "img37", thumbnailPath: "img37", albumID: nil),
            Design(id: UUID(), designName: "White Space",    createdAt: Date(timeIntervalSinceNow: -86400 * 3),   updatedAt: nil, isFavorite: false, designType: .image, designPath: "img38", thumbnailPath: "img38", albumID: nil),
            Design(id: UUID(), designName: "Artistic Flow",  createdAt: Date(timeIntervalSinceNow: -86400 * 2),   updatedAt: nil, isFavorite: true,  designType: .image, designPath: "img39", thumbnailPath: "img39", albumID: nil),
            Design(id: UUID(), designName: "Pixel Touch",    createdAt: Date(timeIntervalSinceNow: -86400 * 1),   updatedAt: nil, isFavorite: false, designType: .image, designPath: "img40", thumbnailPath: "img40", albumID: nil),
        ]
    }

    static func makeDummyAlbums(from designs: [Design]) -> [Album] {
        guard designs.count >= 32 else { return [] }
        return [
            Album(
                id: UUID(),
                albumName: "Collection",
                createdAt: Date(timeIntervalSinceNow: -86400 * 5),
                updatedAt: nil,
                albumPath: "",
                thumbnailPath: designs[0].thumbnailPath,
                albumDesignIDs: [
                    designs[0].id, designs[2].id, designs[4].id,
                    designs[6].id, designs[8].id
                ]
            ),
            Album(
                id: UUID(),
                albumName: "Nature Vibes",
                createdAt: Date(timeIntervalSinceNow: -86400 * 25),
                updatedAt: nil,
                albumPath: "",
                thumbnailPath: designs[1].thumbnailPath,
                albumDesignIDs: [
                    designs[1].id, designs[7].id, designs[15].id,
                    designs[27].id, designs[31].id
                ]
            )
        ]
    }

    static func makeDummySharedAlbums(from designs: [Design]) -> [SharedAlbum] {
        guard designs.count >= 32 else { return [] }
        let ownerID = UUID()
        let colleague1ID = UUID()
        let colleague2ID = UUID()
        
        return [
            SharedAlbum(
                id: UUID(uuidString: "7e504c5a-d1a1-432d-947d-81532eeadbf7") ?? UUID(),
                albumName: "Brand Collaboration",
                ownerName: "Sarah Jenkins",
                ownerID: ownerID,
                createdAt: Date().addingTimeInterval(-86400 * 3),
                updatedAt: Date().addingTimeInterval(-86400 * 1),
                thumbnailPath: designs[2].thumbnailPath,
                designIDs: [designs[2].id, designs[4].id, designs[6].id],
                collaborators: [
                    Collaborator(id: ownerID, name: "Sarah Jenkins", email: "sarah@createo.design", avatarColorHex: "#FF7043", isCurrentUser: false),
                    Collaborator(id: colleague1ID, name: "Marcus Chen", email: "marcus@createo.design", avatarColorHex: "#26A69A", isCurrentUser: false),
                    Collaborator(id: colleague2ID, name: "Emma Watson", email: "emma@createo.design", avatarColorHex: "#5C6BC0", isCurrentUser: false)
                ],
                activities: [
                    AlbumActivity(id: UUID(), userName: "Sarah Jenkins", userEmail: "sarah@createo.design", activityType: "created", detail: "", timestamp: Date().addingTimeInterval(-86400 * 3)),
                    AlbumActivity(id: UUID(), userName: "Marcus Chen", userEmail: "marcus@createo.design", activityType: "joined", detail: "", timestamp: Date().addingTimeInterval(-86400 * 2)),
                    AlbumActivity(id: UUID(), userName: "Sarah Jenkins", userEmail: "sarah@createo.design", activityType: "added_design", detail: designs[2].designName, timestamp: Date().addingTimeInterval(-86400 * 2)),
                    AlbumActivity(id: UUID(), userName: "Emma Watson", userEmail: "emma@createo.design", activityType: "joined", detail: "", timestamp: Date().addingTimeInterval(-86400 * 1)),
                    AlbumActivity(id: UUID(), userName: "Marcus Chen", userEmail: "marcus@createo.design", activityType: "added_design", detail: designs[4].designName, timestamp: Date().addingTimeInterval(-86400 * 1 - 3600)),
                    AlbumActivity(id: UUID(), userName: "Emma Watson", userEmail: "emma@createo.design", activityType: "added_design", detail: designs[6].designName, timestamp: Date().addingTimeInterval(-86400 * 1))
                ]
            ),
            SharedAlbum(
                id: UUID(uuidString: "bd675547-0b1a-4c28-9774-4b533a1e9447") ?? UUID(),
                albumName: "UI/UX Feedback",
                ownerName: "Liam Vance",
                ownerID: UUID(),
                createdAt: Date().addingTimeInterval(-86400 * 5),
                updatedAt: Date().addingTimeInterval(-86400 * 2),
                thumbnailPath: designs[8].thumbnailPath,
                designIDs: [designs[8].id, designs[10].id],
                collaborators: [
                    Collaborator(id: UUID(), name: "Liam Vance", email: "liam@creato.app", avatarColorHex: "#AB47BC", isCurrentUser: false),
                    Collaborator(id: UUID(), name: "David Kim", email: "david@creato.app", avatarColorHex: "#29B6F6", isCurrentUser: false)
                ],
                activities: [
                    AlbumActivity(id: UUID(), userName: "Liam Vance", userEmail: "liam@creato.app", activityType: "created", detail: "", timestamp: Date().addingTimeInterval(-86400 * 5)),
                    AlbumActivity(id: UUID(), userName: "David Kim", userEmail: "david@creato.app", activityType: "joined", detail: "", timestamp: Date().addingTimeInterval(-86400 * 4)),
                    AlbumActivity(id: UUID(), userName: "Liam Vance", userEmail: "liam@creato.app", activityType: "added_design", detail: designs[8].designName, timestamp: Date().addingTimeInterval(-86400 * 3)),
                    AlbumActivity(id: UUID(), userName: "David Kim", userEmail: "david@creato.app", activityType: "added_design", detail: designs[10].designName, timestamp: Date().addingTimeInterval(-86400 * 2))
                ]
            )
        ]
    }
}



   
