//
//  SettingsView.swift
//  Homebase
//

import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Bindable var settingsManager = SettingsManager.shared
    @State private var editorManager = EditorManager.shared

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
}

#Preview {
    SettingsView()
}
