//
//  SettingsView.swift
//  Homebase
//

import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Bindable var settingsManager = SettingsManager.shared
    @State private var editorManager = EditorManager.shared
    @State private var terminalManager = TerminalManager.shared

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
        }
        .frame(width: 450, height: 350)
    }

    private var generalTab: some View {
        Form {
            Section {
                Toggle("Show in Dock", isOn: $settingsManager.showInDock)
                Text("When disabled, Homebase only appears in the menu bar.")
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
