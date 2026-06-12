//
//  SupabaseStorageService.swift
//  creato
//
//  Created by GU on 24/04/26.
//

import Foundation
import Supabase

// MARK: - SupabaseStorageService
// Uploads media files and thumbnails to Supabase Storage.
// Uses actor isolation to keep concurrent uploads safe.

final class SupabaseStorageService: Sendable {

    private let client = SupabaseManager.shared.client

    // MARK: - Upload

    /// Uploads raw `Data` to a Supabase Storage bucket.
    /// - Parameters:
    ///   - data: File bytes (PNG, JPEG, MP4, etc.)
    ///   - bucket: Storage bucket name, e.g. "designs" or "thumbnails"
    ///   - path: Remote path within bucket, e.g. "userID/designID.png"
    /// - Returns: The public URL of the uploaded file.
    func upload(data: Data, bucket: String, path: String) async throws -> URL {
        try await client.storage
            .from(bucket)
            .upload(path, data: data, options: FileOptions(upsert: true))

        return try publicURL(bucket: bucket, path: path)
    }

    // MARK: - Delete

    func delete(bucket: String, path: String) async throws {
        try await client.storage
            .from(bucket)
            .remove(paths: [path])
    }

    // MARK: - Private

    private func publicURL(bucket: String, path: String) throws -> URL {
        try client.storage.from(bucket).getPublicURL(path: path)
    }
}

