//
//  ContentView.swift
//  Homebase
//
//  Created by Kristoffer Follestad on 18/01/2026.
//

import SwiftUI
import AppKit

struct ContentView: View {
    @State private var settingsManager = SettingsManager.shared
    @State private var editorManager = EditorManager.shared
    @State private var terminalManager = TerminalManager.shared
    @State private var folderSettingsManager = FolderSettingsManager.shared
    @State private var folders: [ScannedFolder] = []
    @State private var isLoading = false
    @State private var isRefreshingStatuses = false
    @State private var searchText = ""
    @State private var editorPickerFolder: ScannedFolder?
    @State private var settingsPopoverFolder: ScannedFolder?

    private var filteredFolders: [ScannedFolder] {
        let sorted = FolderScanner.sortFolders(folders)
        if searchText.isEmpty {
            return sorted
        }
        return sorted.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            if settingsManager.watchedPaths.isEmpty {
                emptyStateView
            } else if isLoading && folders.isEmpty {
                loadingView
            } else if folders.isEmpty {
                noFoldersView
            } else {
                searchBarView
                folderListView
            }
        }
        .frame(minWidth: 400, minHeight: 300)
        .onAppear { refreshFolders() }
        .onChange(of: settingsManager.watchedPaths) { _, _ in refreshFolders() }
    }

    private var searchBarView: some View {
        HStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Filter folders...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(.quaternary)
            .cornerRadius(8)

            Button {
                refreshFolders(forceStatusRefresh: true)
            } label: {
                if isRefreshingStatuses {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .buttonStyle(.bordered)
            .disabled(isLoading || isRefreshingStatuses)
            .help("Refresh folder list and sync statuses")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No folders configured")
                .font(.headline)
            Text("Go to Settings to add folders to watch")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Scanning folders...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noFoldersView: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No subfolders found")
                .font(.headline)
            Text("The watched folders don't contain any subfolders")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var folderListView: some View {
        List(filteredFolders) { folder in
            let isOnlineOnly = folder.syncStatus == .onlineOnly
            let folderSettings = folderSettingsManager.getSettings(for: folder.id)
            let hasCustomSettings = !folderSettings.isEmpty
            let targetEditor = editorManager.editorForFolder(folder.id)
            let targetTerminal = terminalManager.terminalForFolder(folder.id)
            HStack {
                if isOnlineOnly {
                    Image(systemName: "cloud")
                        .foregroundStyle(.secondary)
                        .frame(width: 20, height: 20)
                } else if let editor = targetEditor,
                          let icon = editorManager.icon(for: editor) {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 20, height: 20)
                } else {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(.blue)
                        .frame(width: 20, height: 20)
                }
                VStack(alignment: .leading) {
                    Text(folder.name)
                        .fontWeight(.medium)
                    if let remoteUrl = folder.remoteUrl,
                       let displayName = GitDetector.shared.displayName(from: remoteUrl) {
                        Text(displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    openInEditor(folder)
                }
                .popover(isPresented: Binding(
                    get: { editorPickerFolder?.id == folder.id },
                    set: { if !$0 { editorPickerFolder = nil } }
                )) {
                    editorPickerView(for: folder)
                }
                Spacer()
                if let websiteUrl = folderSettings.websiteUrl,
                   let url = URL(string: websiteUrl) {
                    Button {
                        NSWorkspace.shared.open(url)
                    } label: {
                        Image(systemName: "globe")
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.borderless)
                    .help("Open website")
                }
                if let remoteUrl = folder.remoteUrl,
                   let browserUrl = GitDetector.shared.browserUrl(from: remoteUrl) {
                    Button {
                        NSWorkspace.shared.open(browserUrl)
                    } label: {
                        Image("GitHubIcon")
                            .resizable()
                            .frame(width: 14, height: 14)
                    }
                    .buttonStyle(.borderless)
                    .help("Open repository on GitHub")
                }
                Button {
                    settingsPopoverFolder = folder
                } label: {
                    Image(systemName: hasCustomSettings ? "gearshape.fill" : "gearshape")
                        .foregroundStyle(hasCustomSettings ? .blue : .secondary)
                }
                .buttonStyle(.borderless)
                .help("Folder settings")
                .popover(isPresented: Binding(
                    get: { settingsPopoverFolder?.id == folder.id },
                    set: { if !$0 { settingsPopoverFolder = nil } }
                )) {
                    folderSettingsView(for: folder)
                }
                // Terminal button - shows terminal app icon
                if let terminal = targetTerminal, !isOnlineOnly {
                    Button {
                        openInTerminal(folder)
                    } label: {
                        if let icon = terminalManager.icon(for: terminal) {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 14, height: 14)
                        } else {
                            Image(systemName: "terminal")
                        }
                    }
                    .buttonStyle(.borderless)
                    .help("Open in \(terminal.name)")
                }
                Button {
                    FolderScanner.shared.revealInFinder(folder)
                } label: {
                    Image(systemName: "folder")
                }
                .buttonStyle(.borderless)
                .help("Reveal in Finder")
            }
            .padding(.vertical, 4)
            .opacity(isOnlineOnly ? 0.5 : 1.0)
        }
    }

    private func editorPickerView(for folder: ScannedFolder) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Open with...")
                .font(.headline)
                .padding(.bottom, 4)

            if editorManager.allAvailableEditors.isEmpty {
                Text("No editors available")
                    .foregroundStyle(.secondary)
                Text("Add editors in Settings")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(editorManager.allAvailableEditors) { editor in
                    Button {
                        editorManager.setDefaultEditor(editor)
                        _ = editorManager.openFolder(folder.path, with: editor)
                        editorPickerFolder = nil
                        WindowManager.closeMainWindow()
                    } label: {
                        HStack {
                            Image(systemName: "app.fill")
                            Text(editor.name)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .frame(minWidth: 200)
    }

    private func folderSettingsView(for folder: ScannedFolder) -> some View {
        let currentSettings = folderSettingsManager.getSettings(for: folder.id)

        return VStack(alignment: .leading, spacing: 12) {
            Text("Folder Settings")
                .font(.headline)

            Text(folder.name)
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            // Editor picker
            VStack(alignment: .leading, spacing: 4) {
                Text("Open with")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Picker("", selection: Binding(
                    get: { currentSettings.editorId ?? "" },
                    set: { newValue in
                        folderSettingsManager.setEditor(
                            for: folder.id,
                            editorId: newValue.isEmpty ? nil : newValue
                        )
                    }
                )) {
                    Text("Default").tag("")
                    Divider()
                    ForEach(editorManager.allAvailableEditors) { editor in
                        Text(editor.name).tag(editor.id)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)
            }

            Divider()

            // Terminal picker
            VStack(alignment: .leading, spacing: 4) {
                Text("Terminal")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Picker("", selection: Binding(
                    get: { currentSettings.terminalId ?? "" },
                    set: { newValue in
                        folderSettingsManager.setTerminal(
                            for: folder.id,
                            terminalId: newValue.isEmpty ? nil : newValue
                        )
                    }
                )) {
                    Text("Default").tag("")
                    Divider()
                    ForEach(terminalManager.allAvailableTerminals) { terminal in
                        Text(terminal.name).tag(terminal.id)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)
            }

            Divider()

            // Website URL
            VStack(alignment: .leading, spacing: 4) {
                Text("Website")
                    .font(.subheadline)
                    .fontWeight(.medium)

                TextField("https://example.com", text: Binding(
                    get: { currentSettings.websiteUrl ?? "" },
                    set: { newValue in
                        folderSettingsManager.setWebsiteUrl(
                            for: folder.id,
                            url: newValue.isEmpty ? nil : newValue
                        )
                    }
                ))
                .textFieldStyle(.roundedBorder)
            }

            Divider()

            // Clear settings button
            if !currentSettings.isEmpty {
                Button("Reset to Defaults") {
                    folderSettingsManager.clearSettings(for: folder.id)
                    settingsPopoverFolder = nil
                }
                .foregroundStyle(.red)
            }
        }
        .padding()
        .frame(width: 250)
    }

    private func openInEditor(_ folder: ScannedFolder) {
        // Check folder-specific editor first
        let folderSettings = folderSettingsManager.getSettings(for: folder.id)
        if let editorId = folderSettings.editorId,
           let editor = editorManager.allAvailableEditors.first(where: { $0.id == editorId }) {
            _ = editorManager.openFolder(folder.path, with: editor)
            WindowManager.closeMainWindow()
            return
        }

        // Fall back to default editor
        if let editor = editorManager.defaultEditor {
            _ = editorManager.openFolder(folder.path, with: editor)
            WindowManager.closeMainWindow()
        } else if !editorManager.allAvailableEditors.isEmpty {
            editorPickerFolder = folder
        }
    }

    private func openInTerminal(_ folder: ScannedFolder) {
        // Check folder-specific terminal first
        let folderSettings = folderSettingsManager.getSettings(for: folder.id)
        if let terminalId = folderSettings.terminalId,
           let terminal = terminalManager.allAvailableTerminals.first(where: { $0.id == terminalId }) {
            _ = terminalManager.openFolder(folder.path, with: terminal)
            return
        }

        // Fall back to default terminal
        if let terminal = terminalManager.defaultTerminal {
            _ = terminalManager.openFolder(folder.path, with: terminal)
        }
    }

    private func refreshFolders(forceStatusRefresh: Bool = false) {
        isLoading = true
        Task {
            let scanned = await FolderScanner.shared.scanFolders(in: settingsManager.watchedPaths)
            await MainActor.run {
                folders = scanned
                isLoading = false

                // Cleanup orphaned folder settings
                let existingPaths = Set(scanned.map { $0.id })
                folderSettingsManager.cleanupOrphanedSettings(existingPaths: existingPaths)
            }

            // If forced refresh, re-check all statuses in background
            if forceStatusRefresh {
                await MainActor.run {
                    isRefreshingStatuses = true
                }

                await FolderScanner.shared.refreshStatuses(for: scanned) { updated in
                    // Update the folder in place
                    if let index = folders.firstIndex(where: { $0.id == updated.id }) {
                        folders[index] = updated
                    }
                }

                await MainActor.run {
                    isRefreshingStatuses = false
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
