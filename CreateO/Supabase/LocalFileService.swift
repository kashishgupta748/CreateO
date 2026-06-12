//
//  LocalFileService.swift
//  creato
//
//  Created by GU on 24/04/26.
//

import Foundation

// MARK: - LocalFileService
// Responsible for persisting the designs/albums JSON cache to disk.
// This provides instant load on launch and full offline support.

enum LocalFileService {

    // MARK: - Directories

    static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private static var cacheDirectory: URL {
        documentsDirectory.appendingPathComponent("creato_cache", isDirectory: true)
    }

    // MARK: - Generic JSON Cache

    static func save<T: Encodable>(_ items: T, toFile filename: String) {
        createCacheDirectoryIfNeeded()
        let url = cacheDirectory.appendingPathComponent(filename)
        if let data = try? JSONEncoder().encode(items) {
            try? data.write(to: url, options: .atomic)
        }
    }

    static func load<T: Decodable>(_ type: T.Type, fromFile filename: String) -> T? {
        let url = cacheDirectory.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    static func delete(filename: String) {
        let url = cacheDirectory.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - File existence / cleanup

    static func fileExists(atPath path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }

    static func removeFile(atPath path: String) {
        guard !path.isEmpty else { return }
        let url = URL(fileURLWithPath: path)
        guard url.path.hasPrefix(documentsDirectory.path) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Private

    private static func createCacheDirectoryIfNeeded() {
        let path = cacheDirectory.path
        if !FileManager.default.fileExists(atPath: path) {
            try? FileManager.default.createDirectory(
                atPath: path,
                withIntermediateDirectories: true
            )
        }
    }
}

