//
//  CloudStatusDetector.swift
//  Peakview
//

import Foundation

enum SyncStatus: String, Codable {
    case local
    case onlineOnly
}

struct CloudStatusDetector {
    static let shared = CloudStatusDetector()

    private init() {}

    /// Detect sync status for a folder by checking up to 3 files inside
    func detectSyncStatus(for url: URL) -> SyncStatus {
        let fileManager = FileManager.default

        // Quick optimization: Use enumerator for early exit instead of loading all contents
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]  // Don't recurse into subdirectories
        ) else {
            return .local
        }

        // Check up to 3 files (not folders)
        var filesChecked = 0
        
        for case let itemURL as URL in enumerator {
            guard filesChecked < 3 else { break }

            guard let dirCheck = try? itemURL.resourceValues(forKeys: [.isDirectoryKey]),
                  let isDirectory = dirCheck.isDirectory,
                  !isDirectory else {
                continue
            }

            filesChecked += 1
            let status = checkFileStatus(itemURL)

            // If any file is online-only, the folder is online-only
            if status == .onlineOnly {
                return .onlineOnly
            }
        }

        return .local
    }

    private func checkFileStatus(_ fileURL: URL) -> SyncStatus {
        guard let values = try? fileURL.resourceValues(forKeys: [
            .isUbiquitousItemKey,
            .ubiquitousItemDownloadingStatusKey
        ]) else {
            return .local
        }

        // If the file is NOT ubiquitous (not cloud-backed), it's local
        guard let isUbiquitous = values.isUbiquitousItem, isUbiquitous else {
            return .local
        }

        // If it is ubiquitous, check the download status
        guard let status = values.ubiquitousItemDownloadingStatus else {
            return .local
        }

        switch status {
        case .current, .downloaded:
            return .local
        case .notDownloaded:
            return .onlineOnly
        default:
            return .local
        }
    }
}
