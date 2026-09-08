import Foundation

/// Filesystem anchors for the TASK-011 standing scans, derived from
/// `#filePath` so they are deterministic and independent of the test
/// process's working directory. Same technique as `MomoCoreTests`' `TestRepo`
/// (duplicated because SwiftPM test targets cannot share helper modules).
/// This file lives at `<root>/Tests/MomoCharacterTests/Support/` — three path
/// components below the repository root.
enum RepoTree {

    /// The repository root (the directory containing `Package.swift`).
    static let repoRoot: String = {
        let support = (#filePath as NSString).deletingLastPathComponent   // Tests/MomoCharacterTests/Support
        let characterTests = (support as NSString).deletingLastPathComponent // Tests/MomoCharacterTests
        let tests = (characterTests as NSString).deletingLastPathComponent   // Tests
        return (tests as NSString).deletingLastPathComponent                 // repo root
    }()

    /// Directories never worth scanning (VCS/build/IDE artifacts).
    private static let skippedDirectoryNames: Set<String> = [
        ".git",
        ".build",
        ".claude",
        "DerivedData",
        "xcuserdata",
    ]

    /// All Swift sources under `Sources`, recursively, sorted by path.
    static func packageSources() throws -> [(name: String, contents: String)] {
        try swiftFiles(under: "Sources")
    }

    /// All Swift sources under `Apps`, recursively, sorted by path.
    static func appSources() throws -> [(name: String, contents: String)] {
        try swiftFiles(under: "Apps")
    }

    /// The String Catalogs under `Apps` (the app-level, both-targets-shared
    /// location). Empty until TASK-011's catalog exists — the scaffolding
    /// tests guard against that vacuity explicitly.
    static func appStringCatalogs() throws -> [(url: URL, name: String)] {
        let directory = repoRoot + "/Apps"
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: directory),
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        ) else {
            throw CocoaError(.fileReadNoSuchFile,
                             userInfo: [NSFilePathErrorKey: directory])
        }
        var found: [URL] = []
        for case let url as URL in enumerator where !url.hasDirectoryPath {
            if url.pathExtension == "xcstrings" {
                found.append(url)
            }
        }
        return found
            .map { (url: $0, name: $0.path.replacingOccurrences(of: repoRoot + "/", with: "")) }
            .sorted { $0.name < $1.name }
    }

    /// Swift files under a repo-root-relative directory, recursively,
    /// artifact directories skipped. Pure Foundation — no subprocesses.
    private static func swiftFiles(under relative: String) throws -> [(name: String, contents: String)] {
        let directory = repoRoot + "/" + relative
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: directory),
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        ) else {
            throw CocoaError(.fileReadNoSuchFile,
                             userInfo: [NSFilePathErrorKey: directory])
        }
        var found: [URL] = []
        for case let url as URL in enumerator {
            if url.hasDirectoryPath {
                let name = url.lastPathComponent
                if skippedDirectoryNames.contains(name) || name.hasSuffix(".xcodeproj") {
                    enumerator.skipDescendants()
                }
                continue
            }
            if url.pathExtension == "swift" {
                found.append(url)
            }
        }
        return try found
            .sorted { $0.path < $1.path }
            .map { url in
                (
                    name: url.path.replacingOccurrences(of: repoRoot + "/", with: ""),
                    contents: try String(contentsOf: url, encoding: .utf8)
                )
            }
    }
}
