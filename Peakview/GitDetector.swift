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

        // Check if config file exists and is available
        guard FileManager.default.fileExists(atPath: gitConfigUrl.path) else {
            return nil
        }

        // Read and parse git config
        guard let configContent = try? String(contentsOf: gitConfigUrl, encoding: .utf8) else {
            print("[GitDetector] ❌ Failed to read config: \(gitConfigUrl.path)")
            return nil
        }

        return parseRemoteUrl(from: configContent)
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
