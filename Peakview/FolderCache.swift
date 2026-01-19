//
//  FolderCache.swift
//  Peakview
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
    private let lock = NSLock()

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let peakviewDir = appSupport.appendingPathComponent("Peakview")
        cacheFileURL = peakviewDir.appendingPathComponent("folder_cache.json")

        // Ensure directory exists
        try? FileManager.default.createDirectory(at: peakviewDir, withIntermediateDirectories: true)

        // Migrate from old Homebase directory if exists
        let oldDir = appSupport.appendingPathComponent("Homebase")
        let oldCacheFile = oldDir.appendingPathComponent("folder_cache.json")
        if FileManager.default.fileExists(atPath: oldCacheFile.path) &&
           !FileManager.default.fileExists(atPath: cacheFileURL.path) {
            try? FileManager.default.copyItem(at: oldCacheFile, to: cacheFileURL)
        }

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
        lock.lock()
        defer { lock.unlock() }

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(cache) else { return }
        try? data.write(to: cacheFileURL)
    }

    func getCachedEntry(for path: String, currentModDate: Date) -> FolderCacheEntry? {
        lock.lock()
        defer { lock.unlock() }

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
        lock.lock()
        defer { lock.unlock() }

        cache[path] = FolderCacheEntry(
            status: status,
            lastChecked: Date(),
            folderModDate: modDate,
            remoteUrl: remoteUrl
        )
    }
}
