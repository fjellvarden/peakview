//
//  GitHubCache.swift
//  Peakview
//

import Foundation

struct GitHubCacheData: Codable {
    var lastFetched: Date?
    var etag: String?
    var username: String?
    var repos: [GitHubRepo]
}

class GitHubCache {
    static let shared = GitHubCache()

    private let cacheFileURL: URL
    private var cacheData: GitHubCacheData

    /// Minimum interval between automatic refreshes (5 minutes)
    private let minimumRefreshInterval: TimeInterval = 5 * 60

    var lastFetched: Date? {
        get { cacheData.lastFetched }
        set { cacheData.lastFetched = newValue }
    }

    var etag: String? {
        get { cacheData.etag }
        set { cacheData.etag = newValue }
    }

    var username: String? {
        get { cacheData.username }
        set { cacheData.username = newValue }
    }

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let peakviewDir = appSupport.appendingPathComponent("Peakview")
        cacheFileURL = peakviewDir.appendingPathComponent("github_repos.json")

        // Ensure directory exists
        try? FileManager.default.createDirectory(at: peakviewDir, withIntermediateDirectories: true)

        // Load existing cache
        if let data = try? Data(contentsOf: cacheFileURL) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let decoded = try? decoder.decode(GitHubCacheData.self, from: data) {
                self.cacheData = decoded
                return
            }
        }

        // Default empty cache
        self.cacheData = GitHubCacheData(lastFetched: nil, etag: nil, username: nil, repos: [])
    }

    func saveCache() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(cacheData) else { return }
        try? data.write(to: cacheFileURL)
    }

    func shouldRefresh() -> Bool {
        guard let last = cacheData.lastFetched else { return true }
        return Date().timeIntervalSince(last) > minimumRefreshInterval
    }

    func updateLastFetched() {
        cacheData.lastFetched = Date()
        saveCache()
    }

    func updateRepos(_ repos: [GitHubRepo], etag: String?) {
        cacheData.repos = repos
        cacheData.etag = etag
        cacheData.lastFetched = Date()
        saveCache()
    }

    func getRepos() -> [GitHubRepo] {
        return cacheData.repos
    }

    func getRepo(byId id: Int64) -> GitHubRepo? {
        return cacheData.repos.first { $0.id == id }
    }

    func getRepo(byFullName fullName: String) -> GitHubRepo? {
        let lowercased = fullName.lowercased()
        return cacheData.repos.first { $0.fullName.lowercased() == lowercased }
    }

    func clearCache() {
        cacheData = GitHubCacheData(lastFetched: nil, etag: nil, username: nil, repos: [])
        try? FileManager.default.removeItem(at: cacheFileURL)
    }

    /// Remove repos that no longer exist on GitHub (called after API refresh)
    func removeDeletedRepos(currentIds: Set<Int64>) {
        cacheData.repos.removeAll { !currentIds.contains($0.id) }
        saveCache()
    }
}
