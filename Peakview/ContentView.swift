//
//  ContentView.swift
//  Peakview
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
    @State private var gitHubManager = GitHubManager.shared
    @State private var folders: [ScannedFolder] = []
    @State private var unclonedRepos: [GitHubRepo] = []
    @State private var isLoading = false
    @State private var isRefreshingStatuses = false
    @State private var searchText = ""
    @State private var editorPickerFolder: ScannedFolder?
    @State private var settingsPopoverFolder: ScannedFolder?
    @State private var expandedUrlsFolder: ScannedFolder?
    @State private var hoveredFolderId: String?
    @State private var cloneDestinationRepo: GitHubRepo?
    @State private var gitRunner = GitCommandRunner.shared

    private var filteredFolders: [ScannedFolder] {
        let sorted = FolderScanner.sortFolders(folders)
        if searchText.isEmpty {
            return sorted
        }
        return sorted.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var localFolders: [ScannedFolder] {
        filteredFolders.filter { $0.syncStatus == .local }
    }

    private var onlineOnlyFolders: [ScannedFolder] {
        filteredFolders.filter { $0.syncStatus == .onlineOnly }
    }

    private var filteredUnclonedRepos: [GitHubRepo] {
        if searchText.isEmpty {
            return unclonedRepos
        }
        return unclonedRepos.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
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
        .onChange(of: gitHubManager.isConnected) { _, _ in refreshFolders() }
        .alert("Clone Failed", isPresented: $showCloneError) {
            Button("OK") { cloneErrorMessage = nil }
        } message: {
            Text(cloneErrorMessage ?? "Unknown error")
        }
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
        List {
            // Local folders
            ForEach(localFolders) { folder in
                folderRow(folder)
            }

            // Online-only folders section
            if !onlineOnlyFolders.isEmpty {
                Section {
                    ForEach(onlineOnlyFolders) { folder in
                        folderRow(folder)
                    }
                } header: {
                    HStack {
                        Image(systemName: "cloud")
                        Text("Online Only")
                            .font(.caption)
                            .textCase(.uppercase)
                    }
                    .foregroundStyle(.secondary)
                }
            }

            // Uncloned GitHub repos section
            if !filteredUnclonedRepos.isEmpty {
                Section {
                    ForEach(filteredUnclonedRepos) { repo in
                        unclonedRepoRow(repo)
                    }
                } header: {
                    HStack {
                        Image("GitHubIcon")
                            .resizable()
                            .frame(width: 12, height: 12)
                        Text("Not Cloned")
                            .font(.caption)
                            .textCase(.uppercase)
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
        .sheet(item: $cloneDestinationRepo) { repo in
            cloneDestinationPicker(for: repo)
        }
    }

    private func folderRow(_ folder: ScannedFolder) -> some View {
        let isOnlineOnly = folder.syncStatus == .onlineOnly
        let folderSettings = folderSettingsManager.getSettings(for: folder.id)
        let targetEditor = editorManager.editorForFolder(with: folderSettings)
        let targetTerminal = terminalManager.terminalForFolder(with: folderSettings)
        let websiteUrls = folderSettings.websiteUrls
        let isExpanded = expandedUrlsFolder?.id == folder.id
        let isHovered = hoveredFolderId == folder.id

        return VStack(alignment: .leading, spacing: 0) {
                HStack {
                    // Editor icon / gear on hover - clicking opens settings
                    Group {
                        if isHovered && !isOnlineOnly {
                            Image(systemName: "gearshape")
                                .foregroundStyle(.secondary)
                        } else if isOnlineOnly {
                            Image(systemName: "cloud")
                                .foregroundStyle(.secondary)
                        } else if let editor = targetEditor,
                                  let icon = editorManager.icon(for: editor) {
                            Image(nsImage: icon)
                                .resizable()
                        } else {
                            Image(systemName: "folder.fill")
                                .foregroundStyle(.blue)
                        }
                    }
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if !isOnlineOnly {
                            settingsPopoverFolder = folder
                        }
                    }
                    .popover(isPresented: Binding(
                        get: { settingsPopoverFolder?.id == folder.id },
                        set: { if !$0 { settingsPopoverFolder = nil } }
                    )) {
                        folderSettingsView(for: folder)
                    }
                    VStack(alignment: .leading) {
                        Text(folder.name)
                            .fontWeight(.medium)
                        if let remoteUrl = folder.remoteUrl,
                           let displayName = GitDetector.shared.displayName(from: remoteUrl) {
                            HStack(spacing: 4) {
                                Text(displayName)
                                if let pushedAt = folder.linkedGitHubPushedAt {
                                    Text("·")
                                    Text("Updated \(pushedAt.relativeDescription)")
                                }
                            }
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
                    // Website button - single URL opens directly, multiple URLs expands list
                    if websiteUrls.count == 1, let url = URL(string: websiteUrls[0]) {
                        Button {
                            NSWorkspace.shared.open(url)
                        } label: {
                            Image(systemName: "globe")
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.borderless)
                        .help("Open \(domainName(from: websiteUrls[0]))")
                    } else if websiteUrls.count > 1 {
                        Button {
                            if isExpanded {
                                expandedUrlsFolder = nil
                            } else {
                                expandedUrlsFolder = folder
                            }
                        } label: {
                            Image(systemName: isExpanded ? "link.circle.fill" : "link.circle")
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.borderless)
                        .help("Show \(websiteUrls.count) websites")
                    }
                    if let remoteUrl = folder.remoteUrl,
                       let browserUrl = GitDetector.shared.browserUrl(from: remoteUrl) {
                        Button {
                            NSWorkspace.shared.open(browserUrl)
                        } label: {
                            Image("GitHubIcon")
                                .resizable()
                                .renderingMode(folder.isLinkedToGitHub ? .template : .original)
                                .foregroundStyle(folder.isLinkedToGitHub ? .blue : .primary)
                                .frame(width: 14, height: 14)
                        }
                        .buttonStyle(.borderless)
                        .help(folder.isLinkedToGitHub ? "Open your repository on GitHub" : "Open repository on GitHub")
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

                // Expanded URLs list
                if isExpanded && websiteUrls.count > 1 {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(websiteUrls.enumerated()), id: \.offset) { index, urlString in
                            if let url = URL(string: urlString) {
                                Button {
                                    NSWorkspace.shared.open(url)
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "arrow.right")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(domainName(from: urlString))
                                            .font(.callout)
                                        Spacer()
                                    }
                                    .padding(.vertical, 2)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.blue)
                            }
                        }
                    }
                    .padding(.leading, 28)
                    .padding(.top, 6)
                }
        }
        .padding(.vertical, 4)
        .opacity(isOnlineOnly ? 0.5 : 1.0)
        .onHover { hovering in
            hoveredFolderId = hovering ? folder.id : nil
        }
    }

    private func unclonedRepoRow(_ repo: GitHubRepo) -> some View {
        let isCloning = gitRunner.currentCloningRepoId == repo.id

        return HStack {
            // GitHub icon (gray for uncloned)
            Image("GitHubIcon")
                .resizable()
                .frame(width: 20, height: 20)
                .opacity(0.5)

            VStack(alignment: .leading) {
                Text(repo.name)
                    .fontWeight(.medium)
                HStack(spacing: 4) {
                    if isCloning {
                        Text(gitRunner.cloneProgress)
                            .lineLimit(1)
                    } else {
                        Text(repo.fullName)
                        if let pushedAt = repo.pushedAt {
                            Text("·")
                            Text("Updated \(pushedAt.relativeDescription)")
                        }
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            // Open on GitHub
            if let url = URL(string: repo.htmlUrl) {
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    Image("GitHubIcon")
                        .resizable()
                        .frame(width: 14, height: 14)
                }
                .buttonStyle(.borderless)
                .help("Open on GitHub")
            }

            // Clone button / progress
            if isCloning {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 60)
            } else {
                Button {
                    if settingsManager.watchedPaths.count == 1 {
                        cloneRepo(repo, to: settingsManager.watchedPaths[0])
                    } else if settingsManager.watchedPaths.isEmpty {
                        print("[ContentView] No watched folders configured")
                    } else {
                        cloneDestinationRepo = repo
                    }
                } label: {
                    Label("Clone", systemImage: "square.and.arrow.down")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .disabled(gitRunner.isCloning)
                .help("Clone repository")
            }
        }
        .padding(.vertical, 4)
        .opacity(isCloning ? 1.0 : 0.6)
    }

    private func cloneDestinationPicker(for repo: GitHubRepo) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Clone \"\(repo.name)\" to...")
                .font(.headline)

            Text("This will open Terminal to run the git clone command.")
                .font(.caption)
                .foregroundStyle(.secondary)

            List(settingsManager.watchedPaths, id: \.self) { path in
                HStack {
                    Image(systemName: "folder")
                        .foregroundStyle(.secondary)
                    Text(path)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("Clone") {
                        cloneDestinationRepo = nil
                        cloneRepo(repo, to: path)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Button {
                        GitCommandRunner.shared.copyCloneCommand(repo: repo, to: URL(fileURLWithPath: path))
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Copy clone command to clipboard")
                }
                .contentShape(Rectangle())
            }
            .frame(minHeight: 120)

            HStack {
                Spacer()
                Button("Cancel") {
                    cloneDestinationRepo = nil
                }
            }
        }
        .padding()
        .frame(width: 450, height: 280)
    }

    /// Extract a readable domain name from a URL string
    private func domainName(from urlString: String) -> String {
        guard let url = URL(string: urlString),
              let host = url.host else {
            return urlString
        }
        // Remove www. prefix and capitalize first letter
        let domain = host.replacingOccurrences(of: "www.", with: "")
        // Extract main domain name (e.g., "notion" from "notion.so")
        let parts = domain.split(separator: ".")
        if let name = parts.first {
            return String(name).capitalized
        }
        return domain
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

            // Website URLs
            WebsiteUrlsEditor(folderPath: folder.id)

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
            // Refresh GitHub repos in background (respects rate limiting)
            if gitHubManager.isConnected {
                Task {
                    do {
                        _ = try await gitHubManager.fetchRepositories(forceRefresh: forceStatusRefresh)
                    } catch {
                        print("[ContentView] GitHub refresh error: \(error.localizedDescription)")
                    }
                }
            }

            let scanned = await FolderScanner.shared.scanFolders(in: settingsManager.watchedPaths)
            await MainActor.run {
                folders = scanned
                isLoading = false

                // Cleanup orphaned folder settings
                let existingPaths = Set(scanned.map { $0.id })
                folderSettingsManager.cleanupOrphanedSettings(existingPaths: existingPaths)

                // Update uncloned repos list
                updateUnclonedRepos()
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
                    updateUnclonedRepos()
                }
            }
        }
    }

    private func updateUnclonedRepos() {
        guard gitHubManager.isConnected else {
            unclonedRepos = []
            return
        }

        // Get all remote URLs from local folders
        let localRepoFullNames = Set(folders.compactMap { folder -> String? in
            guard let remoteUrl = folder.remoteUrl else { return nil }
            return GitDetector.shared.displayName(from: remoteUrl)
        })

        // Get uncloned repos sorted by pushedAt
        unclonedRepos = gitHubManager.getUnclonedRepos(localRepoFullNames: localRepoFullNames)
            .sorted { ($0.pushedAt ?? .distantPast) > ($1.pushedAt ?? .distantPast) }
    }

    @State private var cloneErrorMessage: String?
    @State private var showCloneError = false

    private func cloneRepo(_ repo: GitHubRepo, to destinationPath: String) {
        Task {
            do {
                let clonedPath = try await gitRunner.clone(
                    repo: repo,
                    to: URL(fileURLWithPath: destinationPath)
                )
                await MainActor.run {
                    refreshFolders()
                }
                print("[ContentView] Successfully cloned to: \(clonedPath.path)")
            } catch {
                await MainActor.run {
                    cloneErrorMessage = error.localizedDescription
                    showCloneError = true
                }
                print("[ContentView] Clone failed: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Date Extension for Relative Formatting

extension Date {
    var relativeDescription: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

// MARK: - Website URLs Editor

struct WebsiteUrlsEditor: View {
    let folderPath: String
    @State private var folderSettingsManager = FolderSettingsManager.shared
    @State private var newUrl: String = ""
    @State private var isAddingNew: Bool = false

    private var currentUrls: [String] {
        folderSettingsManager.getSettings(for: folderPath).websiteUrls
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Websites")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                if currentUrls.count < 10 && !isAddingNew {
                    Button {
                        isAddingNew = true
                    } label: {
                        Image(systemName: "plus.circle")
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                    .help("Add website")
                }
            }

            // Existing URLs with remove buttons
            ForEach(Array(currentUrls.enumerated()), id: \.offset) { index, url in
                HStack(spacing: 4) {
                    TextField("https://example.com", text: Binding(
                        get: { url },
                        set: { newValue in
                            var urls = currentUrls
                            urls[index] = newValue
                            folderSettingsManager.setWebsiteUrls(for: folderPath, urls: urls)
                        }
                    ))
                    .textFieldStyle(.roundedBorder)

                    Button {
                        folderSettingsManager.removeWebsiteUrl(for: folderPath, at: index)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }

            // New URL field (shown when + is clicked)
            if isAddingNew {
                HStack(spacing: 4) {
                    TextField("https://example.com", text: $newUrl)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            commitNewUrl()
                        }

                    Button {
                        commitNewUrl()
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                    .buttonStyle(.plain)
                    .disabled(newUrl.isEmpty)

                    Button {
                        newUrl = ""
                        isAddingNew = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Show empty field if no URLs yet
            if currentUrls.isEmpty && !isAddingNew {
                TextField("https://example.com", text: $newUrl)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        if !newUrl.isEmpty {
                            folderSettingsManager.addWebsiteUrl(for: folderPath, url: newUrl)
                            newUrl = ""
                        }
                    }
            }
        }
    }

    private func commitNewUrl() {
        if !newUrl.isEmpty {
            folderSettingsManager.addWebsiteUrl(for: folderPath, url: newUrl)
            newUrl = ""
        }
        isAddingNew = false
    }
}

#Preview {
    ContentView()
}
