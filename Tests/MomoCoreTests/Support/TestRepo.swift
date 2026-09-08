import Foundation

/// Filesystem anchors for the standing scans, derived from `#filePath` so they
/// are deterministic and independent of the test process's working directory.
/// This file lives at `<root>/Tests/MomoCoreTests/Support/` — three path
/// components below the repository root.
enum TestRepo {

    /// The repository root (the directory containing `Package.swift`).
    static let repoRoot: String = {
        let support = (#filePath as NSString).deletingLastPathComponent // Tests/MomoCoreTests/Support
        let coreTests = (support as NSString).deletingLastPathComponent // Tests/MomoCoreTests
        let tests = (coreTests as NSString).deletingLastPathComponent   // Tests
        return (tests as NSString).deletingLastPathComponent            // repo root
    }()

    /// Directories never worth scanning (VCS/build/IDE artifacts).
    private static let skippedDirectoryNames: Set<String> = [
        ".git",
        ".build",
        ".claude",
        "DerivedData",
        "xcuserdata",
    ]

    /// All Swift sources under `Sources/MomoCore`, recursively, sorted by path.
    /// The scan test asserts this set is non-empty so a missing/renamed module
    /// directory can never make the whitelist scan vacuously green.
    static func momoCoreSources() throws -> [(name: String, contents: String)] {
        let directory = repoRoot + "/Sources/MomoCore"
        return try files(in: directory, pathExtension: "swift")
            .map { url in
                (
                    name: url.path.replacingOccurrences(of: repoRoot + "/", with: ""),
                    contents: try String(contentsOf: url, encoding: .utf8)
                )
            }
    }

    /// All String Catalogs (`.xcstrings`) under the repository root, recursively.
    /// Until TASK-011 lands there are none, so the banned-vocabulary scan is
    /// vacuously green by design (TASK-010 Requirement 5).
    static func stringCatalogs() throws -> [(url: URL, name: String)] {
        try files(in: repoRoot, pathExtension: "xcstrings")
            .map { (url: $0, name: $0.path.replacingOccurrences(of: repoRoot + "/", with: "")) }
    }

    /// Recursive file enumeration with the artifact directories skipped.
    /// Pure Foundation — no subprocesses (TASK-010 constraint: fast, deterministic).
    private static func files(in directory: String, pathExtension: String) throws -> [URL] {
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
            let name = url.lastPathComponent
            if url.hasDirectoryPath {
                if skippedDirectoryNames.contains(name) || name.hasSuffix(".xcodeproj") {
                    enumerator.skipDescendants()
                }
                continue
            }
            if url.pathExtension == pathExtension {
                found.append(url)
            }
        }
        return found.sorted { $0.path < $1.path }
    }
}
