//
//  SettingsManager.swift
//  Homebase
//

import Foundation
import SwiftUI
import AppKit

struct BookmarkedFolder: Codable, Equatable {
    let path: String
    let bookmark: Data
    
    static func == (lhs: BookmarkedFolder, rhs: BookmarkedFolder) -> Bool {
        lhs.path == rhs.path
    }
}

@Observable
class SettingsManager {
    static let shared = SettingsManager()

    private let settingsFileURL: URL
    private var bookmarkedFolders: [BookmarkedFolder] = [] {
        didSet {
            saveBookmarks()
        }
    }

    var showInDock: Bool {
        didSet {
            UserDefaults.standard.set(showInDock, forKey: "showInDock")
            updateDockVisibility()
        }
    }

    private func updateDockVisibility() {
        let policy: NSApplication.ActivationPolicy = showInDock ? .regular : .accessory
        NSApp.setActivationPolicy(policy)

        // Aggressively re-activate at multiple intervals to prevent other apps stealing focus
        for delay in [0.0, 0.05, 0.1, 0.2] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                NSApp.activate(ignoringOtherApps: true)
                // Find and focus any visible Homebase window
                if let window = NSApp.windows.first(where: {
                    $0.isVisible && $0.level == .normal && $0.canBecomeKey
                }) {
                    window.makeKeyAndOrderFront(nil)
                }
            }
        }
    }

    var watchedPaths: [String] {
        // Return accessible paths from bookmarks
        bookmarkedFolders.compactMap { folder in
            // Try to access the bookmarked URL
            guard let url = resolveBookmark(folder.bookmark) else { return nil }
            return url.path
        }
    }

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let homebaseDir = appSupport.appendingPathComponent("Homebase")
        settingsFileURL = homebaseDir.appendingPathComponent("watched_folders.json")

        // Load showInDock setting (default to true)
        self.showInDock = UserDefaults.standard.object(forKey: "showInDock") as? Bool ?? true

        // Ensure directory exists
        try? FileManager.default.createDirectory(at: homebaseDir, withIntermediateDirectories: true)

        // Load bookmarks
        if let data = try? Data(contentsOf: settingsFileURL),
           let folders = try? JSONDecoder().decode([BookmarkedFolder].self, from: data) {
            self.bookmarkedFolders = folders
        } else {
            // Try to migrate old paths if they exist
            let oldFileURL = homebaseDir.appendingPathComponent("watched_paths.json")
            if let data = try? Data(contentsOf: oldFileURL),
               let _ = try? JSONDecoder().decode([String].self, from: data) {
                // Old data exists but can't create bookmarks without URL access
                // User will need to re-add folders
                print("Found old paths but need to re-add them for security-scoped access")
            }
            self.bookmarkedFolders = []
        }

        // Apply dock visibility on launch (deferred until app is ready)
        DispatchQueue.main.async { [self] in
            updateDockVisibility()
        }
    }

    private func saveBookmarks() {
        guard let data = try? JSONEncoder().encode(bookmarkedFolders) else { return }
        try? data.write(to: settingsFileURL)
    }

    func addPath(_ url: URL) {
        let path = url.path
        guard !bookmarkedFolders.contains(where: { $0.path == path }) else { return }
        
        // Create security-scoped bookmark
        guard let bookmark = try? url.bookmarkData(
            options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else {
            print("Failed to create bookmark for \(path)")
            return
        }
        
        bookmarkedFolders.append(BookmarkedFolder(path: path, bookmark: bookmark))
    }

    func removePath(_ path: String) {
        bookmarkedFolders.removeAll { $0.path == path }
    }
    
    /// Resolve a security-scoped bookmark to access the folder
    func startAccessingSecurityScopedResources() -> [URL] {
        return bookmarkedFolders.compactMap { folder in
            resolveBookmark(folder.bookmark)
        }
    }
    
    private func resolveBookmark(_ bookmark: Data) -> URL? {
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmark,
            options: [.withSecurityScope, .withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return nil
        }
        
        // Start accessing the security-scoped resource
        _ = url.startAccessingSecurityScopedResource()
        
        return url
    }
}
