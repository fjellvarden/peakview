//
//  FolderCache.swift
//  Homebase
//

import Foundation

struct FolderCacheEntry: Codable {
    let status: SyncStatus
    let lastChecked: Date
    let folderModDate: Date
    let remoteUrl: String?
}

class FolderCache {
    static let shared = FolderCache()

    private var cache: [String: FolderCacheEntry] = [:]
    private let cacheFileURL: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let homebaseDir = appSupport.appendingPathComponent("Homebase")
        cacheFileURL = homebaseDir.appendingPathComponent("folder_cache.json")

        // Ensure directory exists
        try? FileManager.default.createDirectory(at: homebaseDir, withIntermediateDirectories: true)

        loadCache()
    }

    private func loadCache() {
        guard let data = try? Data(contentsOf: cacheFileURL),
              let decoded = try? JSONDecoder().decode([String: FolderCacheEntry].self, from: data) else {
            cache = [:]
            return
        }
        cache = decoded
    }

    func saveCache() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(cache) else { return }
        try? data.write(to: cacheFileURL)
    }

    func getCachedEntry(for path: String, currentModDate: Date) -> FolderCacheEntry? {
        guard let entry = cache[path] else {
            return nil
        }

        // Re-check if folder has been modified since last cache
        if currentModDate > entry.folderModDate {
            return nil
        }

        return entry
    }

    func updateCache(path: String, status: SyncStatus, modDate: Date, remoteUrl: String?) {
        cache[path] = FolderCacheEntry(
            status: status,
            lastChecked: Date(),
            folderModDate: modDate,
            remoteUrl: remoteUrl
        )
    }
}
