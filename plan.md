# GitHub Integration Plan

## Overview

Integrate GitHub account connectivity into Peakview, allowing users to:
1. Connect their GitHub account via Personal Access Token (PAT)
2. View all their repositories alongside local projects
3. See which local projects are linked to GitHub repos
4. Clone uncloned repositories with a single click

---

## 1. Authentication & Settings

### 1.1 GitHub Token Storage

**New file: `GitHubManager.swift`**

```swift
@Observable
class GitHubManager {
    static let shared = GitHubManager()

    var isConnected: Bool { token != nil }
    var username: String?

    private var token: String? // Stored in Keychain
}
```

**Token storage approach:**
- Use macOS Keychain Services for secure token storage (not UserDefaults)
- Service name: `com.peakview.github`
- Account name: `github-pat`

**Why Keychain?**
- Encrypted at rest
- Survives app reinstalls
- Standard macOS security practice for secrets

### 1.2 Settings UI Updates

**File: `SettingsView.swift`**

Add new "GitHub" tab to Settings:
- Connection status indicator (connected/disconnected)
- Username display when connected
- "Connect" button → shows PAT input field
- Link to GitHub PAT creation page: `https://github.com/settings/tokens/new?scopes=repo`
- Disconnect button (removes token from Keychain)
- Required scope: `repo` (read access to repositories)

**UI Flow:**
```
┌─────────────────────────────────────┐
│ GitHub                              │
├─────────────────────────────────────┤
│ Status: ● Connected as @username    │
│                                     │
│ [Disconnect]                        │
├─────────────────────────────────────┤
│        - OR (when disconnected) -   │
├─────────────────────────────────────┤
│ Status: ○ Not connected             │
│                                     │
│ Personal Access Token:              │
│ ┌─────────────────────────────────┐ │
│ │ ghp_xxxxxxxxxxxxxxxxxxxx        │ │
│ └─────────────────────────────────┘ │
│ Requires 'repo' scope               │
│ [Create token on GitHub ↗] [Connect]│
└─────────────────────────────────────┘
```

---

## 2. GitHub Repository Data Model

### 2.1 Repository Model

**In `GitHubManager.swift`:**

```swift
struct GitHubRepo: Codable, Identifiable {
    let id: Int64                    // GitHub's repo ID (stable)
    let name: String                 // Repository name
    let fullName: String             // "owner/repo" format
    let htmlUrl: String              // https://github.com/owner/repo
    let cloneUrl: String             // https://github.com/owner/repo.git
    let sshUrl: String               // git@github.com:owner/repo.git
    let isPrivate: Bool
    let pushedAt: Date?              // Last push date (≈ last commit activity)
    let defaultBranch: String

    // Local state (not from API)
    var localPath: String?           // Set when matched to local folder
}
```

### 2.2 Persistence

**New file: `GitHubCache.swift`**

```swift
class GitHubCache {
    static let shared = GitHubCache()

    private let cacheFileURL: URL  // ~/Library/Application Support/Peakview/github_repos.json

    private var repos: [GitHubRepo] = []
    private var lastFetched: Date?

    func loadCache()
    func saveCache()
    func updateRepos(_ repos: [GitHubRepo])
    func getRepos() -> [GitHubRepo]
    func clearCache()  // Called on disconnect
}
```

**Cache structure:**
```json
{
    "lastFetched": "2026-01-19T12:00:00Z",
    "username": "kristoffer",
    "repos": [
        {
            "id": 123456,
            "name": "my-project",
            "fullName": "kristoffer/my-project",
            "htmlUrl": "https://github.com/kristoffer/my-project",
            "cloneUrl": "https://github.com/kristoffer/my-project.git",
            "sshUrl": "git@github.com:kristoffer/my-project.git",
            "isPrivate": false,
            "pushedAt": "2026-01-15T10:30:00Z",
            "defaultBranch": "main"
        }
    ]
}
```

**Why separate from FolderCache?**
- FolderCache is keyed by local path and cleared on refresh
- GitHubCache is keyed by GitHub repo ID and persists independently
- Prevents losing GitHub data when folder cache is invalidated

---

## 3. GitHub API Integration

### 3.1 API Client

**In `GitHubManager.swift`:**

```swift
extension GitHubManager {
    func fetchRepositories() async throws -> [GitHubRepo]
    func fetchUser() async throws -> GitHubUser
}
```

**API Endpoints:**
- User info: `GET https://api.github.com/user`
- User repos: `GET https://api.github.com/user/repos?per_page=100&sort=pushed`

**Pagination:**
- Handle pagination via `Link` header for users with >100 repos
- Fetch all pages during background refresh

**Rate Limiting:**
- Authenticated requests: 5,000/hour (plenty for our use case)
- Store rate limit info from response headers
- Show warning if approaching limit

### 3.2 Smart Fetching Strategy

**Goal:** Minimize API calls while keeping data reasonably fresh.

**Approach: Conditional Requests with ETag**

GitHub API supports conditional requests via `ETag` and `If-None-Match`:
```
Request:  GET /user/repos
          If-None-Match: "abc123"

Response: 304 Not Modified (no body, doesn't count against rate limit)
    - OR -
Response: 200 OK + new ETag + full data
```

**Implementation:**
```swift
class GitHubCache {
    var lastFetched: Date?
    var etag: String?           // Store ETag from last successful fetch

    func shouldRefresh() -> Bool {
        guard let last = lastFetched else { return true }
        return Date().timeIntervalSince(last) > minimumRefreshInterval
    }
}
```

**Minimum Refresh Interval:** 5 minutes
- Prevents hammering API on repeated app opens
- Manual refresh button bypasses this (always fetches)

**Trigger points:**
| Event | Behavior |
|-------|----------|
| App launch | Refresh if >5 min since last fetch (conditional request) |
| Manual refresh button | Always fetch (conditional request) |
| Token connected | Always fetch (full request, no ETag yet) |
| Window becomes active | Refresh if >5 min since last fetch |

**Refresh flow:**
```
1. Check if shouldRefresh() - skip if too recent (except manual)
2. Make conditional request with stored ETag
3. If 304: done, data unchanged
4. If 200: parse repos, update cache, store new ETag
5. Match repos to local folders (see Section 4)
6. Notify UI to refresh
```

**Cache structure update:**
```json
{
    "lastFetched": "2026-01-19T12:00:00Z",
    "etag": "\"abc123def456\"",
    "username": "kristoffer",
    "repos": [...]
}
```

**Benefits:**
- 304 responses don't count against rate limit
- Instant response when data unchanged
- Still gets fresh data when repos actually change

---

## 4. Matching Local Projects to GitHub Repos

### 4.1 Matching Algorithm

For each local folder with a `remoteUrl`:
1. Parse the remote URL to extract `owner/repo`
2. Normalize URL formats (SSH, HTTPS, with/without .git)
3. Match against `fullName` in GitHub repos

**Normalization examples:**
```
git@github.com:owner/repo.git     → owner/repo
https://github.com/owner/repo.git → owner/repo
https://github.com/owner/repo     → owner/repo
```

**Note:** We already have `GitDetector.displayName(from:)` that does this!

### 4.2 Data Structures

**Update `ScannedFolder`:**
```swift
struct ScannedFolder {
    // ... existing fields ...
    var linkedGitHubRepoId: Int64?      // Matched GitHub repo ID
    var linkedGitHubPushedAt: Date?     // Last push date from GitHub
}
```

**Matching happens in:**
- `FolderScanner.scanFolders()` - for cached entries
- `FolderScanner.refreshStatuses()` - for fresh scans
- After GitHub API refresh - re-match all folders

---

## 5. UI Updates

### 5.1 Main Window Layout Changes

**File: `ContentView.swift`**

Current order:
1. Local folders (sorted by modification date desc)
2. Online-only folders (sorted by modification date desc)

New order:
1. Local folders (sorted by modification date desc) - some may be linked
2. Online-only folders (sorted by modification date desc)
3. **NEW: Uncloned GitHub repos** (sorted by `pushedAt` desc)

### 5.2 Linked State Indicator

For local folders that match a GitHub repo:
- The existing GitHub icon turns **blue** (instead of default gray/secondary)
- Show "Updated X ago" timestamp from GitHub's `pushedAt` field

```
┌─────────────────────────────────────────────────────────────┐
│ 📦 my-project                                       🐙 📁  │
│    kristoffer/my-project · Updated 2 days ago        ↑      │
└─────────────────────────────────────────────────────────────┘
                                                       │
                                              Blue = linked to
                                              your GitHub account
```

**Visual states for GitHub icon:**
| State | Icon Color | Meaning |
|-------|------------|---------|
| Has remote URL, linked to account | Blue | This is YOUR repo |
| Has remote URL, not linked | Default (gray) | Repo exists but not in your account |
| No remote URL | No icon | Not a git repo |

**Implementation:**
```swift
// Existing GitHub button, now with conditional color
if let remoteUrl = folder.remoteUrl,
   let browserUrl = GitDetector.shared.browserUrl(from: remoteUrl) {
    Button {
        NSWorkspace.shared.open(browserUrl)
    } label: {
        Image("GitHubIcon")
            .resizable()
            .frame(width: 14, height: 14)
            .foregroundStyle(folder.linkedGitHubRepoId != nil ? .blue : .secondary)
    }
    .buttonStyle(.borderless)
    .help(folder.linkedGitHubRepoId != nil
        ? "Open your repository on GitHub"
        : "Open repository on GitHub")
}
```

### 5.3 Subtitle with GitHub Timestamp

For linked projects, show the GitHub `pushedAt` date alongside the repo name:

```swift
// In folder row subtitle
VStack(alignment: .leading) {
    Text(folder.name)
        .fontWeight(.medium)
    if let remoteUrl = folder.remoteUrl,
       let displayName = GitDetector.shared.displayName(from: remoteUrl) {
        HStack(spacing: 4) {
            Text(displayName)
            if let pushedAt = folder.linkedGitHubPushedAt {
                Text("·")
                Text("Updated \(pushedAt.relativeDescription)")  // "2 days ago"
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
```

**Update `ScannedFolder` to include pushed date:**
```swift
struct ScannedFolder {
    // ... existing fields ...
    var linkedGitHubRepoId: Int64?      // Matched GitHub repo ID
    var linkedGitHubPushedAt: Date?     // Last push from GitHub API
}
```

### 5.4 Uncloned Repos Section

**Appearance:**
- Grayed out (opacity 0.5) like online-only folders
- GitHub icon (gray) on the left instead of cloud icon
- Clone button on the right

```
┌─────────────────────────────────────────────────────────────┐
│ 🐙 another-project                              [Clone ⬇️] │
│    kristoffer/another-project · Updated 3 days ago         │
└─────────────────────────────────────────────────────────────┘
```

**Clone button:**
- Primary action: Clone to selected folder
- If multiple watch folders configured: show folder picker first

---

## 6. Clone Functionality

### 6.1 Git Detection

**New file: `GitCommandRunner.swift`**

```swift
class GitCommandRunner {
    static let shared = GitCommandRunner()

    enum CloneMethod {
        case gitCLI          // /usr/bin/git or from PATH
        case xcodeGit        // Xcode command line tools
        case none            // No git available
    }

    func detectGitInstallation() -> CloneMethod
    func isGitAvailable() -> Bool
    func gitPath() -> String?
}
```

**Detection order:**
1. Check `/usr/bin/git` (Xcode CLT)
2. Check common Homebrew paths: `/opt/homebrew/bin/git`, `/usr/local/bin/git`
3. Run `which git` to find any other installation

### 6.2 Clone Process

```swift
extension GitCommandRunner {
    func clone(
        repo: GitHubRepo,
        to destinationFolder: URL,
        progress: @escaping (String) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    )
}
```

**Clone flow:**
1. User clicks "Clone"
2. If multiple watch folders: show folder picker sheet
3. Confirm destination path (watch folder + repo name)
4. Run git clone in background
5. Show progress (spinner, status text)
6. On success: refresh folder list, new folder appears as local+linked
7. On error: show alert with error message

**Clone command:**
```bash
git clone https://github.com/owner/repo.git /path/to/watch-folder/repo-name
```

**Why HTTPS over SSH?**
- Works without SSH key setup
- PAT can be used for authentication if needed
- User can switch to SSH later by changing remote

### 6.3 Clone Destination Picker

**When user has multiple watch folders:**

```
┌─────────────────────────────────────┐
│ Clone "my-project" to...            │
├─────────────────────────────────────┤
│ ○ ~/Projects                        │
│ ○ ~/Work                            │
│ ● ~/Personal                        │
├─────────────────────────────────────┤
│ Destination:                        │
│ ~/Personal/my-project               │
├─────────────────────────────────────┤
│           [Cancel]  [Clone]         │
└─────────────────────────────────────┘
```

---

## 7. Cleanup & Sync

### 7.1 Deleted Repos Handling

On each GitHub refresh:
1. Compare fetched repos with cached repos
2. Repos in cache but not in API response = deleted/transferred
3. Remove from cache
4. Local folders with stale `linkedGitHubRepoId` → clear the link

**Note:** Don't show deleted repos in uncloned section (they're gone from GitHub)

### 7.2 Cache Invalidation Scenarios

| Event | FolderCache | GitHubCache |
|-------|-------------|-------------|
| Manual refresh button | Cleared & rebuilt | Refreshed from API |
| App launch | Read from disk | Read from disk, background refresh |
| GitHub disconnect | Unchanged | Cleared |
| Watch folder added/removed | Affected paths only | Unchanged |

---

## 8. Implementation Order

### Phase 1: Foundation
1. [ ] Create `GitHubManager.swift` with Keychain storage
2. [ ] Create `GitHubCache.swift` for repo persistence
3. [ ] Add GitHub API client methods (fetch user, fetch repos)
4. [ ] Add "GitHub" tab to Settings with connect/disconnect UI

### Phase 2: Data Integration
5. [ ] Add `linkedGitHubRepoId` and `linkedGitHubPushedAt` to `ScannedFolder`
6. [ ] Implement repo-to-folder matching in `FolderScanner`
7. [ ] Add smart refresh with ETag support and 5-min minimum interval
8. [ ] Add background refresh trigger points (app launch, window active)
9. [ ] Update cache handling to preserve GitHub data

### Phase 3: UI Updates
10. [ ] Make GitHub icon blue for linked repos
11. [ ] Add "Updated X ago" subtitle for linked repos
12. [ ] Create uncloned repos section in folder list
13. [ ] Style uncloned repos (grayed, GitHub icon, clone button)
14. [ ] Add sorting for uncloned section (by pushedAt)

### Phase 4: Clone Feature
15. [ ] Create `GitCommandRunner.swift` with git detection
16. [ ] Implement clone functionality
17. [ ] Create clone destination picker UI
18. [ ] Add clone progress/status display
19. [ ] Handle clone errors gracefully

### Phase 5: Polish
20. [ ] Add deleted repo cleanup logic
21. [ ] Handle rate limiting gracefully
22. [ ] Add loading states during GitHub operations
23. [ ] Test with large repo counts (pagination)

---

## 9. New Files Summary

| File | Purpose |
|------|---------|
| `GitHubManager.swift` | Auth, API client, business logic |
| `GitHubCache.swift` | Persist GitHub repos to disk |
| `GitCommandRunner.swift` | Git CLI detection and clone execution |

---

## 10. Security Considerations

- **Token storage:** Keychain only, never in UserDefaults or plain files
- **Token scope:** Request minimum needed (`repo` for private repo access)
- **Token display:** Mask in UI after entry (show only last 4 chars)
- **Clone auth:** Use HTTPS with token embedded only if necessary, prefer unauthenticated for public repos
- **No token logging:** Ensure token never appears in debug logs

---

## 11. Error Handling

| Error | User Message | Action |
|-------|--------------|--------|
| Invalid token | "Invalid token. Please check and try again." | Clear token field |
| Token expired | "Token expired. Please reconnect." | Show reconnect UI |
| Rate limited | "GitHub rate limit reached. Try again later." | Show retry time |
| Network error | "Could not connect to GitHub." | Offer retry |
| Clone failed | "Clone failed: {error}" | Show full error |
| Git not found | "Git is not installed. Install Xcode Command Line Tools." | Link to install instructions |

---

## 12. Future Enhancements (Out of Scope)

- OAuth flow (instead of PAT) - more complex, needs registered app
- Organization repos - requires different API endpoint and permissions
- Push/pull status - would need to run git commands regularly
- Create new repos - requires write permissions, different use case
