//
//  EditorManager.swift
//  Peakview
//

import Foundation
import AppKit

struct Editor: Identifiable, Codable, Hashable {
    let id: String  // Bundle identifier or path for custom
    let name: String
    let bundleIdentifier: String?
    let customAppPath: String?  // For user-added apps

    var isCustom: Bool { customAppPath != nil }
}

@Observable
class EditorManager {
    static let shared = EditorManager()

    // Well-known editors with their bundle identifiers
    static let knownEditors: [Editor] = [
        Editor(id: "vscode", name: "Visual Studio Code", bundleIdentifier: "com.microsoft.VSCode", customAppPath: nil),
        Editor(id: "cursor", name: "Cursor", bundleIdentifier: "com.todesktop.230313mzl4w4u92", customAppPath: nil),
        Editor(id: "zed", name: "Zed", bundleIdentifier: "dev.zed.Zed", customAppPath: nil),
        Editor(id: "phpstorm", name: "PhpStorm", bundleIdentifier: "com.jetbrains.PhpStorm", customAppPath: nil),
        Editor(id: "webstorm", name: "WebStorm", bundleIdentifier: "com.jetbrains.WebStorm", customAppPath: nil),
        Editor(id: "xcode", name: "Xcode", bundleIdentifier: "com.apple.dt.Xcode", customAppPath: nil),
        Editor(id: "sublime", name: "Sublime Text", bundleIdentifier: "com.sublimetext.4", customAppPath: nil),
    ]

    private(set) var installedEditors: [Editor] = []
    private(set) var customEditors: [Editor] = []
    var defaultEditorId: String?

    var allAvailableEditors: [Editor] {
        installedEditors + customEditors
    }

    var defaultEditor: Editor? {
        guard let id = defaultEditorId else { return nil }
        return allAvailableEditors.first { $0.id == id }
    }

    private let customEditorsKey = "customEditors"
    private let defaultEditorKey = "defaultEditorId"

    private init() {
        loadSettings()
        detectInstalledEditors()
    }

    private func loadSettings() {
        defaultEditorId = UserDefaults.standard.string(forKey: defaultEditorKey)

        if let data = UserDefaults.standard.data(forKey: customEditorsKey),
           let decoded = try? JSONDecoder().decode([Editor].self, from: data) {
            customEditors = decoded
        }
    }

    private func saveSettings() {
        UserDefaults.standard.set(defaultEditorId, forKey: defaultEditorKey)

        if let data = try? JSONEncoder().encode(customEditors) {
            UserDefaults.standard.set(data, forKey: customEditorsKey)
        }
    }

    func detectInstalledEditors() {
        installedEditors = Self.knownEditors.filter { editor in
            guard let bundleId = editor.bundleIdentifier else { return false }
            return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) != nil
        }
    }

    func setDefaultEditor(_ editor: Editor?) {
        defaultEditorId = editor?.id
        saveSettings()
    }

    func addCustomEditor(from appURL: URL) {
        guard let bundle = Bundle(url: appURL),
              let bundleId = bundle.bundleIdentifier,
              let name = bundle.infoDictionary?["CFBundleName"] as? String ?? appURL.deletingPathExtension().lastPathComponent as String? else {
            return
        }

        // Check if already added
        guard !allAvailableEditors.contains(where: { $0.bundleIdentifier == bundleId || $0.customAppPath == appURL.path }) else {
            return
        }

        let editor = Editor(
            id: "custom-\(bundleId)",
            name: name,
            bundleIdentifier: bundleId,
            customAppPath: appURL.path
        )

        customEditors.append(editor)
        saveSettings()
    }

    func removeCustomEditor(_ editor: Editor) {
        customEditors.removeAll { $0.id == editor.id }
        if defaultEditorId == editor.id {
            defaultEditorId = nil
        }
        saveSettings()
    }

    func openFolder(_ folderURL: URL, with editor: Editor) -> Bool {
        // Try bundle identifier first
        if let bundleId = editor.bundleIdentifier,
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            return openFolder(folderURL, withAppAt: appURL)
        }

        // Fall back to custom app path
        if let appPath = editor.customAppPath {
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
                print("Failed to open folder: \(error)")
            }
        }

        return true
    }

    /// Get the app icon for an editor
    func icon(for editor: Editor) -> NSImage? {
        // Try bundle identifier first
        if let bundleId = editor.bundleIdentifier,
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            return NSWorkspace.shared.icon(forFile: appURL.path)
        }

        // Fall back to custom app path
        if let appPath = editor.customAppPath {
            return NSWorkspace.shared.icon(forFile: appPath)
        }

        return nil
    }

    /// Get the editor that would be used for a folder (checking folder-specific settings first)
    func editorForFolder(_ folderPath: String) -> Editor? {
        let folderSettings = FolderSettingsManager.shared.getSettings(for: folderPath)
        return editorForFolder(with: folderSettings)
    }

    /// Get the editor for a folder using pre-fetched settings (avoids duplicate lookup)
    func editorForFolder(with settings: FolderSettings) -> Editor? {
        // Check folder-specific editor first
        if let editorId = settings.editorId,
           let editor = allAvailableEditors.first(where: { $0.id == editorId }) {
            return editor
        }

        // Fall back to default editor
        return defaultEditor
    }
}
