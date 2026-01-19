//
//  FolderSettingsManager.swift
//  Homebase
//

import Foundation

struct FolderSettings: Codable, Equatable {
    var editorId: String?       // Override default editor for this folder
    var terminalId: String?     // Override default terminal for this folder
    var websiteUrl: String?     // Custom website URL
    var isHidden: Bool = false  // Hide from main list

    var isEmpty: Bool {
        editorId == nil && terminalId == nil && websiteUrl == nil && !isHidden
    }
}

@Observable
class FolderSettingsManager {
    static let shared = FolderSettingsManager()

    private var settings: [String: FolderSettings] = [:]  // Key is folder path
    private let settingsFileURL: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let homebaseDir = appSupport.appendingPathComponent("Homebase")
        settingsFileURL = homebaseDir.appendingPathComponent("folder_settings.json")

        // Ensure directory exists
        try? FileManager.default.createDirectory(at: homebaseDir, withIntermediateDirectories: true)

        loadSettings()
    }

    private func loadSettings() {
        guard let data = try? Data(contentsOf: settingsFileURL),
              let decoded = try? JSONDecoder().decode([String: FolderSettings].self, from: data) else {
            settings = [:]
            return
        }
        settings = decoded
    }

    private func saveSettings() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        guard let data = try? encoder.encode(settings) else { return }
        try? data.write(to: settingsFileURL)
    }

    // MARK: - Public API

    func getSettings(for folderPath: String) -> FolderSettings {
        settings[folderPath] ?? FolderSettings()
    }

    func updateSettings(for folderPath: String, _ update: (inout FolderSettings) -> Void) {
        var folderSettings = settings[folderPath] ?? FolderSettings()
        update(&folderSettings)

        // Remove entry if all settings are default/empty
        if folderSettings.isEmpty {
            settings.removeValue(forKey: folderPath)
        } else {
            settings[folderPath] = folderSettings
        }

        saveSettings()
    }

    func setEditor(for folderPath: String, editorId: String?) {
        updateSettings(for: folderPath) { settings in
            settings.editorId = editorId
        }
    }

    func setWebsiteUrl(for folderPath: String, url: String?) {
        updateSettings(for: folderPath) { settings in
            settings.websiteUrl = url
        }
    }

    func setTerminal(for folderPath: String, terminalId: String?) {
        updateSettings(for: folderPath) { settings in
            settings.terminalId = terminalId
        }
    }

    func setHidden(for folderPath: String, hidden: Bool) {
        updateSettings(for: folderPath) { settings in
            settings.isHidden = hidden
        }
    }

    func clearSettings(for folderPath: String) {
        settings.removeValue(forKey: folderPath)
        saveSettings()
    }

    /// Remove settings for folders that no longer exist in the scanned list
    func cleanupOrphanedSettings(existingPaths: Set<String>) {
        let orphanedPaths = Set(settings.keys).subtracting(existingPaths)

        guard !orphanedPaths.isEmpty else { return }

        for path in orphanedPaths {
            settings.removeValue(forKey: path)
        }

        saveSettings()
        print("[FolderSettings] Cleaned up \(orphanedPaths.count) orphaned folder settings")
    }

    /// Get all folder paths that have custom settings
    var foldersWithSettings: Set<String> {
        Set(settings.keys)
    }
}
