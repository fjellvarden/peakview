//
//  FolderScanner.swift
//  Peakview
//

import Foundation
import AppKit

struct ScannedFolder: Identifiable, Hashable {
    let id: String  // Use path as stable ID for updates
    let name: String
    let path: URL
    let modificationDate: Date
    let syncStatus: SyncStatus
    let remoteUrl: String?  // Git remote origin URL

    // GitHub integration fields
    var linkedGitHubRepoId: Int64?      // Matched GitHub repo ID
    var linkedGitHubPushedAt: Date?     // Last push date from GitHub

    /// Whether this folder is linked to the user's GitHub account
    var isLinkedToGitHub: Bool { linkedGitHubRepoId != nil }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ScannedFolder, rhs: ScannedFolder) -> Bool {
        lhs.id == rhs.id
    }
}

class FolderScanner {
    static let shared = FolderScanner()

    // Enable/disable detailed performance logging (disabled by default for production)
    static var debugLogging = false

    private init() {}

    /// Scan folders using cached status (fast)
    func scanFolders(in watchedPaths: [String]) async -> [ScannedFolder] {
        // Run heavy I/O work off the main thread
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let result = self.scanFoldersSync(in: watchedPaths)
                continuation.resume(returning: result)
            }
        }
    }

    /// Synchronous implementation of folder scanning
    private func scanFoldersSync(in watchedPaths: [String]) -> [ScannedFolder] {
        let overallStartTime = CFAbsoluteTimeGetCurrent()
        if Self.debugLogging {
            print("\n[FolderScanner] 🔍 Starting scan of \(watchedPaths.count) watched path(s)")
        }

        var folders: [ScannedFolder] = []
        let fileManager = FileManager.default
        let detector = CloudStatusDetector.shared
        let cache = FolderCache.shared

        // Get security-scoped URLs
        let securityStartTime = CFAbsoluteTimeGetCurrent()
        let securityScopedURLs = SettingsManager.shared.startAccessingSecurityScopedResources()
        if Self.debugLogging {
            print("[FolderScanner] ⏱️ Security-scoped access: \(String(format: "%.3f", CFAbsoluteTimeGetCurrent() - securityStartTime))s")
        }

        defer {
            // Stop accessing when done
            securityScopedURLs.forEach { $0.stopAccessingSecurityScopedResource() }
        }

        for watchedPath in watchedPaths {
            let pathStartTime = CFAbsoluteTimeGetCurrent()
            let url = URL(fileURLWithPath: watchedPath)
            if Self.debugLogging {
                print("[FolderScanner] 📂 Scanning: \(watchedPath)")
            }

            guard let contents = try? fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) else {
                print("[FolderScanner] ❌ Failed to access directory: \(watchedPath)")
                continue
            }

            if Self.debugLogging {
                print("[FolderScanner]   Found \(contents.count) items")
            }
            var subfoldersFound = 0
            var cacheHits = 0
            var cacheMisses = 0

            for itemURL in contents {
                guard let resourceValues = try? itemURL.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey]),
                      let isDirectory = resourceValues.isDirectory,
                      isDirectory,
                      let modDate = resourceValues.contentModificationDate else { continue }

                subfoldersFound += 1
                let path = itemURL.path

                // Check cache first
                let status: SyncStatus
                let remoteUrl: String?
                if let cached = cache.getCachedEntry(for: path, currentModDate: modDate) {
                    status = cached.status
                    remoteUrl = cached.remoteUrl
                    cacheHits += 1
                } else {
                    // Detect and cache
                    cacheMisses += 1
                    let detectStartTime = CFAbsoluteTimeGetCurrent()
                    status = detector.detectSyncStatus(for: itemURL)
                    remoteUrl = GitDetector.shared.detectRemoteUrl(for: itemURL)
                    let detectTime = CFAbsoluteTimeGetCurrent() - detectStartTime

                    if Self.debugLogging && detectTime > 0.05 {
                        print("[FolderScanner]   ⚠️ Slow detection for '\(itemURL.lastPathComponent)': \(String(format: "%.3f", detectTime))s")
                    }

                    cache.updateCache(path: path, status: status, modDate: modDate, remoteUrl: remoteUrl)
                }

                // Check for GitHub link
                var linkedRepoId: Int64? = nil
                var linkedPushedAt: Date? = nil
                if let remoteUrl = remoteUrl,
                   let matchedRepo = GitHubManager.shared.findMatchingRepo(for: remoteUrl) {
                    linkedRepoId = matchedRepo.id
                    linkedPushedAt = matchedRepo.pushedAt
                }

                folders.append(ScannedFolder(
                    id: path,
                    name: itemURL.lastPathComponent,
                    path: itemURL,
                    modificationDate: modDate,
                    syncStatus: status,
                    remoteUrl: remoteUrl,
                    linkedGitHubRepoId: linkedRepoId,
                    linkedGitHubPushedAt: linkedPushedAt
                ))
            }

            let pathElapsed = CFAbsoluteTimeGetCurrent() - pathStartTime
            if Self.debugLogging {
                print("[FolderScanner]   ✅ Found \(subfoldersFound) subfolders (cache: \(cacheHits) hits, \(cacheMisses) misses) in \(String(format: "%.3f", pathElapsed))s")
            }
        }

        cache.saveCache()

        let overallElapsed = CFAbsoluteTimeGetCurrent() - overallStartTime
        if Self.debugLogging {
            print("[FolderScanner] ✅ Scan complete: \(folders.count) total folders in \(String(format: "%.3f", overallElapsed))s\n")
        }

        return Self.sortFolders(folders)
    }

    /// Sort folders: local first (by date desc), then online-only (by date desc)
    static func sortFolders(_ folders: [ScannedFolder]) -> [ScannedFolder] {
        folders.sorted { a, b in
            // Local folders come before online-only
            if a.syncStatus != b.syncStatus {
                return a.syncStatus == .local
            }
            // Within same status, sort by date (recent first)
            return a.modificationDate > b.modificationDate
        }
    }

    /// Re-check sync status and git info for all folders (ignores cache, detects fresh)
    func refreshStatuses(for folders: [ScannedFolder], onUpdate: @escaping (ScannedFolder) -> Void) async {
        let detector = CloudStatusDetector.shared
        let gitDetector = GitDetector.shared
        let cache = FolderCache.shared

        for folder in folders {
            // Fresh detection (no cache)
            let status = detector.detectSyncStatus(for: folder.path)
            let remoteUrl = gitDetector.detectRemoteUrl(for: folder.path)

            // Check for GitHub link
            var linkedRepoId: Int64? = nil
            var linkedPushedAt: Date? = nil
            if let remoteUrl = remoteUrl,
               let matchedRepo = GitHubManager.shared.findMatchingRepo(for: remoteUrl) {
                linkedRepoId = matchedRepo.id
                linkedPushedAt = matchedRepo.pushedAt
            }

            // Update cache with fresh values
            cache.updateCache(
                path: folder.path.path,
                status: status,
                modDate: folder.modificationDate,
                remoteUrl: remoteUrl
            )

            // Notify if anything changed
            if status != folder.syncStatus || remoteUrl != folder.remoteUrl ||
               linkedRepoId != folder.linkedGitHubRepoId {
                let updated = ScannedFolder(
                    id: folder.id,
                    name: folder.name,
                    path: folder.path,
                    modificationDate: folder.modificationDate,
                    syncStatus: status,
                    remoteUrl: remoteUrl,
                    linkedGitHubRepoId: linkedRepoId,
                    linkedGitHubPushedAt: linkedPushedAt
                )
                await MainActor.run {
                    onUpdate(updated)
                }
            }
        }

        cache.saveCache()
    }

    func revealInFinder(_ folder: ScannedFolder) {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: folder.path.path)
    }
}
