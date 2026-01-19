//
//  GitDetector.swift
//  Homebase
//

import Foundation

struct GitDetector {
    static let shared = GitDetector()

    private init() {}

    /// Check if folder has .git/config and extract remote URL
    func detectRemoteUrl(for folderUrl: URL) -> String? {
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            if elapsed > 0.1 {
                print("[GitDetector] ⚠️ Slow git detection (\(String(format: "%.3f", elapsed))s): \(folderUrl.lastPathComponent)")
            }
        }

        let gitConfigUrl = folderUrl.appendingPathComponent(".git/config")

        // Check if config file exists
        guard FileManager.default.fileExists(atPath: gitConfigUrl.path) else {
            return nil
        }

        // Try to read directly first
        if let configContent = try? String(contentsOf: gitConfigUrl, encoding: .utf8),
           !configContent.isEmpty {
            return parseRemoteUrl(from: configContent)
        }

        // File might be online-only, try to trigger download
        if let configContent = triggerDownloadAndRead(gitConfigUrl) {
            return parseRemoteUrl(from: configContent)
        }

        print("[GitDetector] ❌ Failed to read config: \(gitConfigUrl.path)")
        return nil
    }

    /// Try to download an online-only file and read it
    private func triggerDownloadAndRead(_ fileURL: URL) -> String? {
        let fileManager = FileManager.default

        // Check if the file is cloud-backed (ubiquitous)
        guard let values = try? fileURL.resourceValues(forKeys: [
            .isUbiquitousItemKey,
            .ubiquitousItemDownloadingStatusKey
        ]) else {
            return nil
        }

        let isUbiquitous = values.isUbiquitousItem ?? false
        let downloadStatus = values.ubiquitousItemDownloadingStatus

        // If it's not cloud-backed or already downloaded, nothing more to try
        if !isUbiquitous {
            return nil
        }

        // For iCloud Drive: use the proper API to trigger download
        if downloadStatus == .notDownloaded {
            do {
                try fileManager.startDownloadingUbiquitousItem(at: fileURL)
                print("[GitDetector] ⬇️ Triggered download for: \(fileURL.lastPathComponent)")
            } catch {
                // For Dropbox, this will fail - that's OK, Dropbox downloads on access
                print("[GitDetector] ℹ️ startDownloading failed (likely Dropbox): \(error.localizedDescription)")
            }
        }

        // Wait for download to complete (up to 3 seconds, polling every 100ms)
        let maxAttempts = 30
        for attempt in 1...maxAttempts {
            // Check if file is now downloaded
            if let content = try? String(contentsOf: fileURL, encoding: .utf8),
               !content.isEmpty {
                print("[GitDetector] ✅ Downloaded and read config after \(attempt * 100)ms")
                return content
            }

            // Brief wait before retry
            Thread.sleep(forTimeInterval: 0.1)
        }

        return nil
    }

    private func parseRemoteUrl(from config: String) -> String? {
        // Look for [remote "origin"] section and extract url
        let lines = config.components(separatedBy: .newlines)
        var inRemoteOrigin = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("[remote") {
                inRemoteOrigin = trimmed.contains("\"origin\"")
                continue
            }

            if trimmed.hasPrefix("[") {
                inRemoteOrigin = false
                continue
            }

            if inRemoteOrigin && trimmed.hasPrefix("url") {
                // Extract URL after "url = "
                if let equalIndex = trimmed.firstIndex(of: "=") {
                    let urlPart = trimmed[trimmed.index(after: equalIndex)...]
                        .trimmingCharacters(in: .whitespaces)
                    return urlPart.isEmpty ? nil : urlPart
                }
            }
        }

        return nil
    }

    /// Convert git remote URL to browser-friendly HTTPS URL
    func browserUrl(from remoteUrl: String) -> URL? {
        var urlString = remoteUrl

        // Convert SSH format: git@github.com:user/repo.git -> https://github.com/user/repo
        if urlString.hasPrefix("git@") {
            urlString = urlString
                .replacingOccurrences(of: "git@", with: "https://")
                .replacingOccurrences(of: ":", with: "/", range: urlString.range(of: ":"))
        }

        // Remove .git suffix
        if urlString.hasSuffix(".git") {
            urlString = String(urlString.dropLast(4))
        }

        return URL(string: urlString)
    }

    /// Extract "user/repo" from remote URL for display
    func displayName(from remoteUrl: String) -> String? {
        var urlString = remoteUrl

        // Handle SSH format: git@github.com:user/repo.git
        if urlString.hasPrefix("git@") {
            if let colonIndex = urlString.firstIndex(of: ":") {
                urlString = String(urlString[urlString.index(after: colonIndex)...])
            }
        } else {
            // Handle HTTPS format: https://github.com/user/repo.git
            if let url = URL(string: urlString), url.host != nil {
                urlString = url.path
                if urlString.hasPrefix("/") {
                    urlString = String(urlString.dropFirst())
                }
            }
        }

        // Remove .git suffix
        if urlString.hasSuffix(".git") {
            urlString = String(urlString.dropLast(4))
        }

        return urlString.isEmpty ? nil : urlString
    }
}
