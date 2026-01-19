//
//  GitHubManager.swift
//  Peakview
//

import Foundation
import Security

// MARK: - Models

struct GitHubUser: Codable {
    let id: Int64
    let login: String
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, login
        case avatarUrl = "avatar_url"
    }
}

struct GitHubRepo: Codable, Identifiable {
    let id: Int64
    let name: String
    let fullName: String
    let htmlUrl: String
    let cloneUrl: String
    let sshUrl: String
    let isPrivate: Bool
    let pushedAt: Date?
    let defaultBranch: String

    enum CodingKeys: String, CodingKey {
        case id, name
        case fullName = "full_name"
        case htmlUrl = "html_url"
        case cloneUrl = "clone_url"
        case sshUrl = "ssh_url"
        case isPrivate = "private"
        case pushedAt = "pushed_at"
        case defaultBranch = "default_branch"
    }
}

// MARK: - Errors

enum GitHubError: LocalizedError {
    case notConnected
    case invalidToken
    case rateLimited(resetDate: Date)
    case networkError(Error)
    case invalidResponse
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to GitHub"
        case .invalidToken:
            return "Invalid token. Please check and try again."
        case .rateLimited(let resetDate):
            let formatter = RelativeDateTimeFormatter()
            return "Rate limit exceeded. Try again \(formatter.localizedString(for: resetDate, relativeTo: Date()))"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from GitHub"
        case .apiError(let message):
            return message
        }
    }
}

// MARK: - GitHubManager

@Observable
class GitHubManager {
    static let shared = GitHubManager()

    private let keychainService = "com.peakview.github"
    private let keychainAccount = "github-pat"

    var isConnected: Bool { token != nil }
    var username: String?
    var isLoading = false
    var lastError: GitHubError?

    private var token: String? {
        didSet {
            if token == nil {
                username = nil
                GitHubCache.shared.clearCache()
            }
        }
    }

    private init() {
        // Load token from Keychain on init
        token = loadTokenFromKeychain()

        // Load cached username
        if token != nil {
            username = GitHubCache.shared.username
        }
    }

    // MARK: - Token Management

    func connect(with token: String) async throws {
        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in isLoading = false } }

        // Validate token by fetching user
        self.token = token

        do {
            let user = try await fetchUser()
            await MainActor.run {
                self.username = user.login
            }

            // Save to Keychain only after successful validation
            saveTokenToKeychain(token)

            // Cache username
            GitHubCache.shared.username = user.login
            GitHubCache.shared.saveCache()

            // Fetch repos
            _ = try await fetchRepositories(forceRefresh: true)
        } catch {
            // Clear token if validation failed
            self.token = nil
            throw error
        }
    }

    func disconnect() {
        deleteTokenFromKeychain()
        token = nil
        username = nil
        GitHubCache.shared.clearCache()
    }

    // MARK: - Keychain Operations

    private func loadTokenFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }

        return token
    }

    private func saveTokenToKeychain(_ token: String) {
        // Delete existing first
        deleteTokenFromKeychain()

        guard let data = token.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        SecItemAdd(query as CFDictionary, nil)
    }

    private func deleteTokenFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]

        SecItemDelete(query as CFDictionary)
    }

    // MARK: - API Methods

    func fetchUser() async throws -> GitHubUser {
        guard let token = token else { throw GitHubError.notConnected }

        var request = URLRequest(url: URL(string: "https://api.github.com/user")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw GitHubError.invalidToken
        }

        if httpResponse.statusCode != 200 {
            throw GitHubError.apiError("Failed to fetch user: HTTP \(httpResponse.statusCode)")
        }

        let decoder = JSONDecoder()
        return try decoder.decode(GitHubUser.self, from: data)
    }

    func fetchRepositories(forceRefresh: Bool = false) async throws -> [GitHubRepo] {
        guard let token = token else { throw GitHubError.notConnected }

        let cache = GitHubCache.shared

        // Check if we should skip refresh (unless forced)
        if !forceRefresh && !cache.shouldRefresh() {
            return cache.getRepos()
        }

        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in isLoading = false } }

        var allRepos: [GitHubRepo] = []
        var page = 1
        var hasMore = true
        var newEtag: String?

        while hasMore {
            var request = URLRequest(url: URL(string: "https://api.github.com/user/repos?per_page=100&sort=pushed&page=\(page)")!)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

            // Add ETag for conditional request (only first page)
            if page == 1, let etag = cache.etag, !forceRefresh {
                request.setValue(etag, forHTTPHeaderField: "If-None-Match")
            }

            let (data, response) = try await performRequest(request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw GitHubError.invalidResponse
            }

            // Check for rate limiting
            if httpResponse.statusCode == 403 {
                if let resetTime = httpResponse.value(forHTTPHeaderField: "X-RateLimit-Reset"),
                   let resetTimestamp = Double(resetTime) {
                    throw GitHubError.rateLimited(resetDate: Date(timeIntervalSince1970: resetTimestamp))
                }
            }

            // 304 Not Modified - data unchanged
            if httpResponse.statusCode == 304 {
                cache.updateLastFetched()
                return cache.getRepos()
            }

            if httpResponse.statusCode == 401 {
                throw GitHubError.invalidToken
            }

            if httpResponse.statusCode != 200 {
                throw GitHubError.apiError("Failed to fetch repos: HTTP \(httpResponse.statusCode)")
            }

            // Store new ETag from first page
            if page == 1 {
                newEtag = httpResponse.value(forHTTPHeaderField: "ETag")
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let repos = try decoder.decode([GitHubRepo].self, from: data)
            allRepos.append(contentsOf: repos)

            // Check for more pages via Link header
            if let linkHeader = httpResponse.value(forHTTPHeaderField: "Link"),
               linkHeader.contains("rel=\"next\"") {
                page += 1
            } else {
                hasMore = false
            }
        }

        // Update cache
        cache.updateRepos(allRepos, etag: newEtag)

        return allRepos
    }

    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await URLSession.shared.data(for: request)
        } catch {
            throw GitHubError.networkError(error)
        }
    }

    // MARK: - Repo Matching

    /// Find a GitHub repo that matches the given remote URL
    func findMatchingRepo(for remoteUrl: String) -> GitHubRepo? {
        guard let displayName = GitDetector.shared.displayName(from: remoteUrl)?.lowercased() else {
            return nil
        }

        return GitHubCache.shared.getRepos().first { repo in
            repo.fullName.lowercased() == displayName
        }
    }

    /// Get repos that are not cloned locally
    func getUnclonedRepos(localRepoFullNames: Set<String>) -> [GitHubRepo] {
        let lowercasedLocal = Set(localRepoFullNames.map { $0.lowercased() })
        return GitHubCache.shared.getRepos().filter { repo in
            !lowercasedLocal.contains(repo.fullName.lowercased())
        }
    }
}
