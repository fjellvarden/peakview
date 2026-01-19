# Peakview

**Your projects at a glance, from the peak.**

---

## Why "Peakview"?

In Norwegian mountain culture, a *varde* is a stone cairn built on peaks to mark the way for fellow hikers. The name **Peakview** draws from this tradition—combining "peak" (the summit) with "view" (the panorama you earn by reaching it).

For developers, each project is its own varde: a marker of progress, a milestone in the journey. Peakview gives you the commanding view from the summit—all your projects laid out before you, ready to open with a single click.

Whether you're navigating between client projects or your own creations, Peakview is your vantage point.

---

## What is Peakview?

Peakview is a macOS menu bar app for developers who work across multiple projects. Instead of digging through Finder or typing `cd` commands, access any project instantly from your menu bar.

### Features

- **Menu bar access** — Click the icon, see your projects, get to work. No dock clutter.
- **Watch multiple folders** — Point Peakview at `~/Projects`, `~/Work`, or anywhere else. It watches them all.
- **One-click editor launch** — Click a project to open it in VS Code, Cursor, Zed, Xcode, or any editor you choose.
- **Terminal integration** — Open folders directly in Terminal, Ghostty, Warp, or your preferred terminal app.
- **Smart sorting** — Projects sorted by last modified date. Your active work rises to the top.
- **Cloud sync awareness** — Detects Dropbox and iCloud folders. See which projects are local vs. online-only.
- **GitHub integration** — Connect your GitHub account to see all your repositories. Clone uncloned repos with one click.
- **Per-folder settings** — Assign specific editors, terminals, or website links to individual projects.
- **Quick filtering** — Type to filter. Find any project in seconds.

### How It Works

1. Click the Peakview icon in your menu bar
2. Add folders to watch in Settings (Cmd+,)
3. Click any project to open it in your default editor
4. Right-click the menu bar icon for quick access to Settings or Quit

### Folder List

The main window organizes your projects into sections:

| Section | Description |
|---------|-------------|
| **Local folders** | Projects available on disk, sorted by last modified |
| **Online Only** | Cloud-synced projects not yet downloaded locally |
| **Not Cloned** | GitHub repositories you own but haven't cloned |

### Supported Editors

Built-in detection for:
- Visual Studio Code
- Cursor
- Zed
- PhpStorm / WebStorm
- Xcode
- Sublime Text

Add any `.app` as a custom editor in Settings.

### Supported Terminals

Built-in detection for:
- Terminal (macOS)
- Ghostty
- Warp

Add any terminal app in Settings.

---

## Requirements

- macOS 14 (Sonoma) or later
- For GitHub integration: Personal Access Token with `repo` scope

---

## Building from Source

```bash
git clone https://github.com/your-username/peakview.git
cd peakview
open Peakview.xcodeproj
```

Build and run with Xcode (Cmd+R).

---

## License

MIT

---

*Built with SwiftUI. Inspired by Norwegian trails.*
