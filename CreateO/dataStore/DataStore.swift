
import Foundation
import Observation

// MARK: - DataStore

@Observable
class DataStore {
    // MARK: - In-memory collections

    var designs: [Design] = []
    var albums: [Album] = []

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
        albums[index].updatedAt = Date()
        
        // Recalculate thumbnail if needed
        if let firstID = designIDs.first, let design = designs.first(where: { $0.id == firstID }) {
            albums[index].thumbnailPath = design.thumbnailPath
        } else {
            albums[index].thumbnailPath = ""
        }
        
        if let authManager = currentAuthManager {
            Task {
                await uploadAlbumToCloud(album: albums[index], authManager: authManager)
            }
        }
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

    func renameAlbum(id: UUID, newName: String) {
        if let index = albums.firstIndex(where: { $0.id == id }) {
            albums[index].albumName = newName
            albums[index].updatedAt = Date()
            if let authManager = currentAuthManager {
                Task {
                    await uploadAlbumToCloud(album: albums[index], authManager: authManager)
                }
            }
        }
        if let authManager = currentAuthManager {
            saveLocalCache(authManager: authManager)
        }
    }

    func removeDesignsFromAlbum(albumID: UUID, designIDs: Set<UUID>) {
        if let index = albums.firstIndex(where: { $0.id == albumID }) {
            albums[index].albumDesignIDs.removeAll { designIDs.contains($0) }
            albums[index].updatedAt = Date()
            
            // Recalculate thumbnail if needed
            let remaining = albums[index].albumDesignIDs
            if let firstID = remaining.first, let design = designs.first(where: { $0.id == firstID }) {
                albums[index].thumbnailPath = design.thumbnailPath
            } else {
                albums[index].thumbnailPath = ""
            }
            
            if let authManager = currentAuthManager {
                Task {
                    await uploadAlbumToCloud(album: albums[index], authManager: authManager)
                }
            }
        }
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
}



   
