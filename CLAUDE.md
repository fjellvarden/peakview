# Homebase

macOS SwiftUI app for browsing folders from configured paths.

## Structure

- `HomebaseApp.swift` - App entry point with main window and Settings scene
- `ContentView.swift` - Main view showing folder list sorted by modification date
- `SettingsView.swift` - Settings panel to add/remove watched folder paths
- `SettingsManager.swift` - Persists watched paths using UserDefaults
- `FolderScanner.swift` - Async scanning of watched paths for subfolders
- `CloudStatusDetector.swift` - Detects cloud sync status (local vs online-only)
- `FolderCache.swift` - JSON cache for folder status persistence

## Usage

1. Open Settings (Cmd+,) to add folder paths
2. Main window displays all subfolders from watched paths
3. Folders sorted by last modified (recent first)
4. Click "Reveal in Finder" to open folder location

## Cloud Sync Detection

Detects whether folders in Dropbox or Google Drive are fully downloaded (local) or online-only placeholders:

- **Blue folder icon** = Local (fully downloaded)
- **Orange cloud icon** = Online-only (cloud placeholder)
- **Gray folder with ?** = Unknown status

Detection uses macOS FileProvider resource values with a size heuristic fallback. Status is cached in `~/Library/Application Support/Homebase/folder_cache.json` and only re-checked when folder modification dates change.
