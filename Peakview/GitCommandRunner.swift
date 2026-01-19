//
//  GitCommandRunner.swift
//  Peakview
//

import Foundation
import AppKit

enum GitCommandError: LocalizedError {
    case gitNotFound
    case cloneFailed(String)
    case destinationExists
    case cancelled

    var errorDescription: String? {
        switch self {
        case .gitNotFound:
            return "Git is not installed. Please install Xcode Command Line Tools by running: xcode-select --install"
        case .cloneFailed(let message):
            return "Clone failed: \(message)"
        case .destinationExists:
            return "Destination folder already exists."
        case .cancelled:
            return "Clone was cancelled."
        }
    }
}

@Observable
class GitCommandRunner {
    static let shared = GitCommandRunner()

    private var cachedGitPath: String?

    // Observable state for UI
    var isCloning = false
    var cloneProgress: String = ""
    var currentCloningRepoId: Int64?

    private init() {
        cachedGitPath = detectGitPath()
    }

    // MARK: - Git Detection

    private let gitSearchPaths = [
        "/usr/bin/git",
        "/opt/homebrew/bin/git",
        "/usr/local/bin/git",
        "/Applications/Xcode.app/Contents/Developer/usr/bin/git"
    ]

    private func detectGitPath() -> String? {
        for path in gitSearchPaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return nil
    }

    func isGitAvailable() -> Bool {
        return cachedGitPath != nil
    }

    // MARK: - Clone

    /// Clone a repository in the background
    func clone(repo: GitHubRepo, to destinationFolder: URL) async throws -> URL {
        guard let gitPath = cachedGitPath else {
            throw GitCommandError.gitNotFound
        }

        let repoFolder = destinationFolder.appendingPathComponent(repo.name)

        // Check if destination already exists
        if FileManager.default.fileExists(atPath: repoFolder.path) {
            throw GitCommandError.destinationExists
        }

        // Update state
        await MainActor.run {
            isCloning = true
            currentCloningRepoId = repo.id
            cloneProgress = "Cloning \(repo.name)..."
        }

        defer {
            Task { @MainActor in
                isCloning = false
                currentCloningRepoId = nil
                cloneProgress = ""
            }
        }

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: gitPath)
                process.arguments = ["clone", "--progress", repo.cloneUrl, repoFolder.path]
                process.currentDirectoryURL = destinationFolder

                let outputPipe = Pipe()
                let errorPipe = Pipe()
                process.standardOutput = outputPipe
                process.standardError = errorPipe  // git clone outputs progress to stderr

                // Read progress from stderr
                errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                    let data = handle.availableData
                    if !data.isEmpty, let output = String(data: data, encoding: .utf8) {
                        // Parse git progress output
                        let lines = output.components(separatedBy: .newlines)
                        for line in lines where !line.isEmpty {
                            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
                            Task { @MainActor [weak self] in
                                self?.cloneProgress = trimmedLine
                            }
                        }
                    }
                }

                do {
                    try process.run()
                    process.waitUntilExit()

                    // Clean up handler
                    errorPipe.fileHandleForReading.readabilityHandler = nil

                    if process.terminationStatus == 0 {
                        continuation.resume(returning: repoFolder)
                    } else {
                        // Read any remaining error output
                        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                        var errorMessage = String(data: errorData, encoding: .utf8) ?? ""

                        // Also check stdout for errors
                        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                        if let outputStr = String(data: outputData, encoding: .utf8), !outputStr.isEmpty {
                            errorMessage += "\n" + outputStr
                        }

                        errorMessage = errorMessage.trimmingCharacters(in: .whitespacesAndNewlines)
                        if errorMessage.isEmpty {
                            errorMessage = "Git exited with code \(process.terminationStatus)"
                        }

                        continuation.resume(throwing: GitCommandError.cloneFailed(errorMessage))
                    }
                } catch {
                    errorPipe.fileHandleForReading.readabilityHandler = nil
                    continuation.resume(throwing: GitCommandError.cloneFailed(error.localizedDescription))
                }
            }
        }
    }

    // MARK: - Copy Clone Command

    func copyCloneCommand(repo: GitHubRepo, to destinationFolder: URL) {
        let command = cloneCommand(for: repo, to: destinationFolder)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)
    }

    func cloneCommand(for repo: GitHubRepo, to destinationFolder: URL) -> String {
        return "cd \"\(destinationFolder.path)\" && git clone \"\(repo.cloneUrl)\""
    }
}
