//
//  SupabaseDatabaseService.swift
//  creato
//
//  Created by GU on 24/04/26.
//

import Foundation
import Supabase

// MARK: - DTOs (snake_case to match Supabase column names)

struct DesignDTO: Codable, Sendable {
    var id: UUID
    var userID: UUID
    var designName: String
    var designType: String
    var isFavorite: Bool
    var designHeight: Int
    var designWidth: Int
    var mediaURL: String
    var thumbnailURL: String
    var albumID: UUID?
    var projectPath: String?
    var createdAt: Date
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userID       = "user_id"
        case designName   = "design_name"
        case designType   = "design_type"
        case isFavorite   = "is_favorite"
        case designHeight = "design_height"
        case designWidth  = "design_width"
        case mediaURL     = "media_url"
        case thumbnailURL = "thumbnail_url"
        case albumID      = "album_id"
        case projectPath  = "project_path"
        case createdAt    = "created_at"
        case updatedAt    = "updated_at"
    }
}

struct AlbumDTO: Codable, Sendable {
    var id: UUID
    var userID: UUID
    var albumName: String
    var thumbnailURL: String
    var createdAt: Date
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userID       = "user_id"
        case albumName    = "album_name"
        case thumbnailURL = "thumbnail_url"
        case createdAt    = "created_at"
        case updatedAt    = "updated_at"
    }
}

// MARK: - SupabaseDatabaseService

final class SupabaseDatabaseService: Sendable {

    private let client = SupabaseManager.shared.client

    // MARK: - Designs

    func insertDesign(_ dto: DesignDTO) async throws {
        try await client
            .from("designs")
            .insert(dto)
            .execute()
    }

    func fetchDesigns(for userID: UUID) async throws -> [DesignDTO] {
        try await client
            .from("designs")
            .select()
            .eq("user_id", value: userID)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func updateDesign(_ dto: DesignDTO) async throws {
        try await client
            .from("designs")
            .update(dto)
            .eq("id", value: dto.id)
            .execute()
    }

    func deleteDesign(id: UUID) async throws {
        try await client
            .from("designs")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Albums

    func insertAlbum(_ dto: AlbumDTO) async throws {
        try await client
            .from("albums")
            .insert(dto)
            .execute()
    }

    func fetchAlbums(for userID: UUID) async throws -> [AlbumDTO] {
        try await client
            .from("albums")
            .select()
            .eq("user_id", value: userID)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func updateAlbum(_ dto: AlbumDTO) async throws {
        try await client
            .from("albums")
            .update(dto)
            .eq("id", value: dto.id)
            .execute()
    }

    func deleteAlbum(id: UUID) async throws {
        try await client
            .from("albums")
            .delete()
            .eq("id", value: id)
            .execute()
    }
}
