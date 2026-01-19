# Peakview

A macOS menu bar app for developers to quickly access and open project folders in their preferred code editor.

## What is Peakview?

Peakview is a productivity tool designed for developers who work with multiple projects stored in various locations. Instead of navigating through Finder or using the terminal to find and open projects, Peakview provides instant access to all your project folders from the menu bar.

**Key features:**
- **Menu bar app** - Lives in the menu bar, click to open, no dock clutter
- **Watch multiple folders** - Configure any number of parent folders to watch
- **One-click editor launch** - Click a project to open it directly in your code editor
- **Smart sorting** - Projects sorted by last modified date, most recent first
- **Cloud sync awareness** - Detects if folders are local or online-only (Dropbox/Google Drive)
- **Git integration** - Shows GitHub repository info and provides quick links to the repo
- **Per-folder settings** - Assign different editors or website links to specific projects
- **Fast filtering** - Search/filter to quickly find projects by name

## How to Use

1. Click the Peakview icon in the menu bar to open the window
2. Go to Settings (Cmd+,) and add folder paths to watch (e.g., `~/Projects`, `~/Work`)
3. The main window shows all subfolders from your watched paths
4. Click any folder to open it in your default editor
5. Right-click the menu bar icon for quick access to Settings or Quit

### Folder List Icons

- **App icon** (VS Code, Cursor, etc.) - Folder will open in that editor
- **Blue folder** - Local folder, no editor assigned
- **Cloud icon (dimmed)** - Online-only, not downloaded from cloud storage

### Folder Actions

- **Click folder** - Open in assigned/default editor
- **Globe icon** - Open configured website URL
- **GitHub icon** - Open repository on GitHub
- **Gear icon** - Per-folder settings (editor, website URL)
- **Folder icon** - Reveal in Finder

## How It Works

### Architecture

Peakview is a SwiftUI app that runs as a menu bar accessory. The dock icon only appears when the main window is open.

### File Structure

```
Peakview/
├── HomebaseApp.swift        # App entry, menu bar setup, window management
├── ContentView.swift        # Main folder list UI with filtering and actions
├── SettingsView.swift       # Settings panel for watched paths and editors
├── SettingsManager.swift    # Persists watched paths (UserDefaults + security bookmarks)
├── FolderScanner.swift      # Async scanning of watched paths for subfolders
├── FolderCache.swift        # JSON cache for folder status persistence
├── CloudStatusDetector.swift # Detects Dropbox/Google Drive sync status
├── GitDetector.swift        # Parses .git/config to extract remote URLs
├── EditorManager.swift      # Manages available editors and opens folders
├── FolderSettingsManager.swift # Per-folder settings (editor, website URL)
└── Assets.xcassets/         # App icons, menu bar icon, GitHub icon
```

### Data Flow

1. **Startup**: App reads watched paths from `SettingsManager`, which stores security-scoped bookmarks for sandbox access
2. **Scanning**: `FolderScanner` enumerates subfolders, checks `FolderCache` for cached status
3. **Cache miss**: `CloudStatusDetector` checks sync status, `GitDetector` reads `.git/config` for remote URL
4. **Display**: `ContentView` shows sorted folders with appropriate icons and actions
5. **Opening**: `EditorManager` launches the folder in the configured editor via `NSWorkspace`

### Performance

- Folder status is cached in `~/Library/Application Support/Homebase/folder_cache.json`
- Cache entries are invalidated when folder modification dates change
- Async scanning runs on background threads to keep UI responsive
- Debug logging can be enabled via `FolderScanner.debugLogging`

### Supported Editors

Built-in detection for: VS Code, Cursor, Zed, PhpStorm, WebStorm, Xcode, Sublime Text

Custom editors can be added via Settings by selecting any `.app` bundle.

## Roadmap

### Terminal Integration (Planned)
- Add terminal app support alongside code editors
- Quick-launch folders in Terminal, iTerm, Warp, or other terminal apps
- Per-folder terminal preference

### GitHub Integration (Planned)
- Show all GitHub repositories from user's account
- Match remote repos with local cloned folders
- One-click clone for repos not yet on disk
- Sync status between local and remote

## Development

Built with:
- SwiftUI for UI
- macOS 14+ (Sonoma)
- App Sandbox with security-scoped bookmarks for folder access
