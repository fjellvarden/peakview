//
//  TerminalManager.swift
//  Peakview
//

import Foundation
import AppKit

struct Terminal: Identifiable, Codable, Hashable {
    let id: String  // Bundle identifier or path for custom
    let name: String
    let bundleIdentifier: String?
    let customAppPath: String?  // For user-added apps

    var isCustom: Bool { customAppPath != nil }
}

@Observable
class TerminalManager {
    static let shared = TerminalManager()

    // Well-known terminals with their bundle identifiers
    static let knownTerminals: [Terminal] = [
        Terminal(id: "terminal", name: "Terminal", bundleIdentifier: "com.apple.Terminal", customAppPath: nil),
        Terminal(id: "ghostty", name: "Ghostty", bundleIdentifier: "com.mitchellh.ghostty", customAppPath: nil),
        Terminal(id: "warp", name: "Warp", bundleIdentifier: "dev.warp.Warp-Stable", customAppPath: nil),
    ]

    private(set) var installedTerminals: [Terminal] = []
    private(set) var customTerminals: [Terminal] = []
    var defaultTerminalId: String?

    var allAvailableTerminals: [Terminal] {
        installedTerminals + customTerminals
    }

    /// Returns the default terminal, falling back to macOS Terminal if no default is set
    var defaultTerminal: Terminal? {
        if let id = defaultTerminalId,
           let terminal = allAvailableTerminals.first(where: { $0.id == id }) {
            return terminal
        }
        // Fall back to macOS Terminal if installed
        return allAvailableTerminals.first(where: { $0.id == "terminal" })
    }

    private let customTerminalsKey = "customTerminals"
    private let defaultTerminalKey = "defaultTerminalId"

    private init() {
        loadSettings()
        detectInstalledTerminals()
    }

    private func loadSettings() {
        defaultTerminalId = UserDefaults.standard.string(forKey: defaultTerminalKey)

        if let data = UserDefaults.standard.data(forKey: customTerminalsKey),
           let decoded = try? JSONDecoder().decode([Terminal].self, from: data) {
            customTerminals = decoded
        }
    }

    private func saveSettings() {
        UserDefaults.standard.set(defaultTerminalId, forKey: defaultTerminalKey)

        if let data = try? JSONEncoder().encode(customTerminals) {
            UserDefaults.standard.set(data, forKey: customTerminalsKey)
        }
    }

    func detectInstalledTerminals() {
        installedTerminals = Self.knownTerminals.filter { terminal in
            guard let bundleId = terminal.bundleIdentifier else { return false }
            return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) != nil
        }
    }

    func setDefaultTerminal(_ terminal: Terminal?) {
        defaultTerminalId = terminal?.id
        saveSettings()
    }

    func addCustomTerminal(from appURL: URL) {
        guard let bundle = Bundle(url: appURL),
              let bundleId = bundle.bundleIdentifier,
              let name = bundle.infoDictionary?["CFBundleName"] as? String ?? appURL.deletingPathExtension().lastPathComponent as String? else {
            return
        }

        // Check if already added
        guard !allAvailableTerminals.contains(where: { $0.bundleIdentifier == bundleId || $0.customAppPath == appURL.path }) else {
            return
        }

        let terminal = Terminal(
            id: "custom-\(bundleId)",
            name: name,
            bundleIdentifier: bundleId,
            customAppPath: appURL.path
        )

        customTerminals.append(terminal)
        saveSettings()
    }

    func removeCustomTerminal(_ terminal: Terminal) {
        customTerminals.removeAll { $0.id == terminal.id }
        if defaultTerminalId == terminal.id {
            defaultTerminalId = nil
        }
        saveSettings()
    }

    func openFolder(_ folderURL: URL, with terminal: Terminal) -> Bool {
        // Try bundle identifier first
        if let bundleId = terminal.bundleIdentifier,
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            return openFolder(folderURL, withAppAt: appURL)
        }

        // Fall back to custom app path
        if let appPath = terminal.customAppPath {
            let appURL = URL(fileURLWithPath: appPath)
            return openFolder(folderURL, withAppAt: appURL)
        }

        return false
    }

    private func openFolder(_ folderURL: URL, withAppAt appURL: URL) -> Bool {
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true

        NSWorkspace.shared.open([folderURL], withApplicationAt: appURL, configuration: config) { _, error in
            if let error = error {
                print("Failed to open folder in terminal: \(error)")
            }
        }

        return true
    }

    /// Get the app icon for a terminal
    func icon(for terminal: Terminal) -> NSImage? {
        // Try bundle identifier first
        if let bundleId = terminal.bundleIdentifier,
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            return NSWorkspace.shared.icon(forFile: appURL.path)
        }

        // Fall back to custom app path
        if let appPath = terminal.customAppPath {
            return NSWorkspace.shared.icon(forFile: appPath)
        }

        return nil
    }

    /// Get the terminal that would be used for a folder (checking folder-specific settings first)
    func terminalForFolder(_ folderPath: String) -> Terminal? {
        let folderSettings = FolderSettingsManager.shared.getSettings(for: folderPath)

        // Check folder-specific terminal first
        if let terminalId = folderSettings.terminalId,
           let terminal = allAvailableTerminals.first(where: { $0.id == terminalId }) {
            return terminal
        }

        // Fall back to default terminal
        return defaultTerminal
    }
}
