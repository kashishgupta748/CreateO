//
//  SupabaseConfig.swift
//  creato
//
//  Created by Codex on 24/04/26.
//

import Foundation
import Supabase

// MARK: - SupabaseManager

final class SupabaseManager {

    // ─── Paste your credentials here ─────────────────────────────────────────
    private let supabaseURL    = "https://etakmwtgbceubnhlkaec.supabase.co"   // ← your Project URL
    private let supabaseAnonKey = "sb_publishable_j38Aozy7Wiz2Fwh5ps4PoQ_Iki9S4II"  // ← your anon/public key
    // ─────────────────────────────────────────────────────────────────────────

    // MARK: - Singleton

    static let shared = SupabaseManager()

    private init() {}

    // MARK: - Client

    lazy var client: SupabaseClient = {
        guard
            let url = URL(string: supabaseURL), !supabaseURL.isEmpty,
            !supabaseAnonKey.isEmpty
        else {
            print("⚠️  SupabaseManager: credentials are empty — guest mode is unaffected, cloud sync will be skipped.")
            return SupabaseClient(
                supabaseURL: URL(string: "https://placeholder.supabase.co")!,
                supabaseKey: "placeholder"
            )
        }
        return SupabaseClient(
            supabaseURL: url,
            supabaseKey: supabaseAnonKey,
            options: SupabaseClientOptions(
                auth: .init(emitLocalSessionAsInitialSession: true)
            )
        )
    }()

    // MARK: - Auth

    var currentUser: User? {
        client.auth.currentUser
    }

    func signUp(email: String, password: String) async throws -> AuthResponse {
        try await client.auth.signUp(email: email, password: password)
    }

    func signIn(email: String, password: String) async throws -> Session {
        try await client.auth.signIn(email: email, password: password)
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    func restoreSession() async throws -> Session {
        try await client.auth.session
    }

    // MARK: - Designs

    func insertDesign(_ dto: DesignDTO) async throws {
        try await client.from("designs").insert(dto).execute()
    }

    func fetchDesigns() async throws -> [DesignDTO] {
        try await client
            .from("designs")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func updateDesign(_ dto: DesignDTO) async throws {
        try await client.from("designs").update(dto).eq("id", value: dto.id).execute()
    }

    func deleteDesign(id: UUID) async throws {
        try await client.from("designs").delete().eq("id", value: id).execute()
    }

    // MARK: - Albums

    func insertAlbum(_ dto: AlbumDTO) async throws {
        try await client.from("albums").insert(dto).execute()
    }

    func fetchAlbums() async throws -> [AlbumDTO] {
        try await client
            .from("albums")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func updateAlbum(_ dto: AlbumDTO) async throws {
        try await client.from("albums").update(dto).eq("id", value: dto.id).execute()
    }

    func deleteAlbum(id: UUID) async throws {
        try await client.from("albums").delete().eq("id", value: id).execute()
    }

    // MARK: - Storage

    /// Uploads file data to a Supabase Storage bucket and returns the public URL.
    func upload(data: Data, bucket: String, path: String) async throws -> URL {
        try await client.storage
            .from(bucket)
            .upload(path, data: data, options: FileOptions(upsert: true))
        return try client.storage.from(bucket).getPublicURL(path: path)
    }

    func deleteFile(bucket: String, path: String) async throws {
        try await client.storage.from(bucket).remove(paths: [path])
    }
}
