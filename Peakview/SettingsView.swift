//
//  SettingsView.swift
//  Peakview
//

import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Bindable var settingsManager = SettingsManager.shared
    @State private var editorManager = EditorManager.shared
    @State private var terminalManager = TerminalManager.shared
    @State private var gitHubManager = GitHubManager.shared

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            foldersTab
                .tabItem {
                    Label("Folders", systemImage: "folder")
                }

            editorsTab
                .tabItem {
                    Label("Editors", systemImage: "chevron.left.forwardslash.chevron.right")
                }

            terminalsTab
                .tabItem {
                    Label("Terminals", systemImage: "terminal")
                }

            gitHubTab
                .tabItem {
                    Label("GitHub", image: "GitHubIcon")
                }
        }
        .frame(width: 450, height: 380)
    }

    private var generalTab: some View {
        Form {
            Section {
                Toggle("Show in Dock", isOn: $settingsManager.showInDock)
                Text("When disabled, Peakview only appears in the menu bar.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var foldersTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Watched Folders")
                .font(.headline)

            List {
                ForEach(settingsManager.watchedPaths, id: \.self) { path in
                    HStack {
                        Image(systemName: "folder")
                            .foregroundStyle(.secondary)
                        Text(path)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Button(action: {
                            settingsManager.removePath(path)
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(minHeight: 150)

            HStack {
                Spacer()
                Button("Add Folder...") {
                    selectFolder()
                }
            }
        }
        .padding()
    }

    private var editorsTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Default Editor")
                .font(.headline)

            Text("Click a folder name to open it in your default editor.")
                .font(.caption)
                .foregroundStyle(.secondary)

            List {
                if editorManager.allAvailableEditors.isEmpty {
                    Text("No editors detected")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(editorManager.allAvailableEditors) { editor in
                        HStack {
                            Image(systemName: editor.isCustom ? "app" : "app.fill")
                                .foregroundStyle(editor.id == editorManager.defaultEditorId ? .blue : .secondary)
                            Text(editor.name)
                            Spacer()
                            if editor.id == editorManager.defaultEditorId {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                            if editor.isCustom {
                                Button {
                                    editorManager.removeCustomEditor(editor)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editorManager.setDefaultEditor(editor)
                        }
                    }
                }
            }
            .frame(minHeight: 150)

            HStack {
                Button("Refresh") {
                    editorManager.detectInstalledEditors()
                }
                Spacer()
                Button("Add App...") {
                    selectApp()
                }
            }
        }
        .padding()
    }

    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select a folder to watch"

        if panel.runModal() == .OK, let url = panel.url {
            settingsManager.addPath(url)
        }
    }

    private func selectApp() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.message = "Select an application to add"

        if panel.runModal() == .OK, let url = panel.url {
            editorManager.addCustomEditor(from: url)
        }
    }

    private var terminalsTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Default Terminal")
                .font(.headline)

            Text("Click the terminal icon in the folder list to open that folder in your default terminal.")
                .font(.caption)
                .foregroundStyle(.secondary)

            List {
                if terminalManager.allAvailableTerminals.isEmpty {
                    Text("No terminals detected")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(terminalManager.allAvailableTerminals) { terminal in
                        HStack {
                            if let icon = terminalManager.icon(for: terminal) {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 20, height: 20)
                            } else {
                                Image(systemName: terminal.isCustom ? "app" : "terminal")
                                    .foregroundStyle(terminal.id == terminalManager.defaultTerminalId ? .blue : .secondary)
                                    .frame(width: 20, height: 20)
                            }
                            Text(terminal.name)
                            Spacer()
                            if terminal.id == terminalManager.defaultTerminalId {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                            if terminal.isCustom {
                                Button {
                                    terminalManager.removeCustomTerminal(terminal)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            terminalManager.setDefaultTerminal(terminal)
                        }
                    }
                }
            }
            .frame(minHeight: 150)

            HStack {
                Button("Refresh") {
                    terminalManager.detectInstalledTerminals()
                }
                Spacer()
                Button("Add App...") {
                    selectTerminalApp()
                }
            }
        }
        .padding()
    }

    // MARK: - GitHub Tab

    @State private var tokenInput: String = ""
    @State private var showTokenField: Bool = false
    @State private var connectionError: String?

    private var gitHubTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("GitHub Integration")
                .font(.headline)

            if gitHubManager.isConnected {
                // Connected state
                HStack(spacing: 8) {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                    Text("Connected as")
                        .foregroundStyle(.secondary)
                    Text("@\(gitHubManager.username ?? "unknown")")
                        .fontWeight(.medium)
                }

                Text("Your GitHub repositories will appear in the folder list. Repos not cloned locally can be cloned with one click.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let repoCount = GitHubCache.shared.getRepos().count as Int?, repoCount > 0 {
                    Text("\(repoCount) repositories synced")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Disconnect") {
                    gitHubManager.disconnect()
                    tokenInput = ""
                    showTokenField = false
                    connectionError = nil
                }
                .foregroundStyle(.red)
            } else {
                // Disconnected state
                HStack(spacing: 8) {
                    Circle()
                        .fill(.secondary.opacity(0.5))
                        .frame(width: 8, height: 8)
                    Text("Not connected")
                        .foregroundStyle(.secondary)
                }

                Text("Connect your GitHub account to see all your repositories and clone them with one click.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()

                if showTokenField {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Personal Access Token")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        SecureField("ghp_xxxxxxxxxxxxxxxxxxxx", text: $tokenInput)
                            .textFieldStyle(.roundedBorder)

                        Text("Requires 'repo' scope for private repositories")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if let error = connectionError {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }

                        HStack {
                            Button("Create token on GitHub") {
                                if let url = URL(string: "https://github.com/settings/tokens/new?scopes=repo&description=Peakview") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                            .buttonStyle(.link)

                            Spacer()

                            Button("Cancel") {
                                showTokenField = false
                                tokenInput = ""
                                connectionError = nil
                            }

                            Button("Connect") {
                                connectWithToken()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(tokenInput.isEmpty || gitHubManager.isLoading)
                        }
                    }
                } else {
                    Spacer()

                    Button("Connect GitHub Account...") {
                        showTokenField = true
                    }
                    .buttonStyle(.borderedProminent)
                }

                if gitHubManager.isLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Connecting...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
    }

    private func connectWithToken() {
        connectionError = nil
        Task {
            do {
                try await gitHubManager.connect(with: tokenInput)
                await MainActor.run {
                    tokenInput = ""
                    showTokenField = false
                }
            } catch {
                await MainActor.run {
                    connectionError = error.localizedDescription
                }
            }
        }
    }

    private func selectTerminalApp() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.message = "Select a terminal application to add"

        if panel.runModal() == .OK, let url = panel.url {
            terminalManager.addCustomTerminal(from: url)
        }
    }
}

#Preview {
    SettingsView()
}
