//
//  FolderSettingsManager.swift
//  Peakview
//

import Foundation

struct FolderSettings: Codable, Equatable {
    var editorId: String?       // Override default editor for this folder
    var terminalId: String?     // Override default terminal for this folder
    var websiteUrls: [String] = []  // Custom website URLs (max 10)
    var isHidden: Bool = false  // Hide from main list

    // Migration: support reading old single websiteUrl format
    private var websiteUrl: String?

    var isEmpty: Bool {
        editorId == nil && terminalId == nil && websiteUrls.isEmpty && !isHidden
    }

    init(editorId: String? = nil, terminalId: String? = nil, websiteUrls: [String] = [], isHidden: Bool = false) {
        self.editorId = editorId
        self.terminalId = terminalId
        self.websiteUrls = websiteUrls
        self.isHidden = isHidden
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        editorId = try container.decodeIfPresent(String.self, forKey: .editorId)
        terminalId = try container.decodeIfPresent(String.self, forKey: .terminalId)
        isHidden = try container.decodeIfPresent(Bool.self, forKey: .isHidden) ?? false

        // Try to decode new websiteUrls array first, fall back to old websiteUrl
        if let urls = try container.decodeIfPresent([String].self, forKey: .websiteUrls) {
            websiteUrls = urls
        } else if let url = try container.decodeIfPresent(String.self, forKey: .websiteUrl) {
            websiteUrls = [url]
        } else {
            websiteUrls = []
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(editorId, forKey: .editorId)
        try container.encodeIfPresent(terminalId, forKey: .terminalId)
        if !websiteUrls.isEmpty {
            try container.encode(websiteUrls, forKey: .websiteUrls)
        }
        if isHidden {
            try container.encode(isHidden, forKey: .isHidden)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case editorId, terminalId, websiteUrl, websiteUrls, isHidden
    }
}

@Observable
class FolderSettingsManager {
    static let shared = FolderSettingsManager()

    private var settings: [String: FolderSettings] = [:]  // Key is folder path
    private let settingsFileURL: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let peakviewDir = appSupport.appendingPathComponent("Peakview")
        settingsFileURL = peakviewDir.appendingPathComponent("folder_settings.json")

        // Ensure directory exists
        try? FileManager.default.createDirectory(at: peakviewDir, withIntermediateDirectories: true)

        // Migrate from old Homebase directory if exists
        let oldDir = appSupport.appendingPathComponent("Homebase")
        let oldSettingsFile = oldDir.appendingPathComponent("folder_settings.json")
        if FileManager.default.fileExists(atPath: oldSettingsFile.path) &&
           !FileManager.default.fileExists(atPath: settingsFileURL.path) {
            try? FileManager.default.copyItem(at: oldSettingsFile, to: settingsFileURL)
        }

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

    func setWebsiteUrls(for folderPath: String, urls: [String]) {
        updateSettings(for: folderPath) { settings in
            settings.websiteUrls = urls.filter { !$0.isEmpty }
        }
    }

    func addWebsiteUrl(for folderPath: String, url: String) {
        guard !url.isEmpty else { return }
        updateSettings(for: folderPath) { settings in
            if settings.websiteUrls.count < 10 && !settings.websiteUrls.contains(url) {
                settings.websiteUrls.append(url)
            }
        }
    }

    func removeWebsiteUrl(for folderPath: String, at index: Int) {
        updateSettings(for: folderPath) { settings in
            guard index >= 0 && index < settings.websiteUrls.count else { return }
            settings.websiteUrls.remove(at: index)
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
