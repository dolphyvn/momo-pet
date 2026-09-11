import Foundation

/// Filesystem anchor + source reader for the MomoKit standing scans — the
/// `TestRepo` pattern (MomoCoreTests) mirrored for this test target (test
/// support is per-target by house convention; the two readers are
/// deliberately independent so a refactor of one cannot silently change what
/// the other scans). Anchored at `#filePath` so it is deterministic and
/// independent of the test process's working directory. This file lives at
/// `<root>/Tests/MomoKitTests/Support/` — three path components below the
/// repository root.
enum KitRepo {

    /// The repository root (the directory containing `Package.swift`).
    static let repoRoot: String = {
        let support = (#filePath as NSString).deletingLastPathComponent // Tests/MomoKitTests/Support
        let kitTests = (support as NSString).deletingLastPathComponent  // Tests/MomoKitTests
        let tests = (kitTests as NSString).deletingLastPathComponent    // Tests
        return (tests as NSString).deletingLastPathComponent            // repo root
    }()

    /// All Swift sources under `Sources/MomoKit`, sorted by name. The module
    /// directory is flat, so a plain directory listing suffices; the scan
    /// test asserts the set is non-empty so a missing/renamed module
    /// directory can never make a scan vacuously green.
    static func momoKitSources() throws -> [(name: String, contents: String)] {
        let directory = repoRoot + "/Sources/MomoKit"
        let urls = try FileManager.default
            .contentsOfDirectory(at: URL(fileURLWithPath: directory), includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        return try urls.map { url in
            (name: url.lastPathComponent, contents: try String(contentsOf: url, encoding: .utf8))
        }
    }

    /// All Swift sources under `Apps/Momo` (the iPhone app target), sorted by
    /// name — the same flat-listing convention as `momoKitSources()`, for the
    /// TASK-040 wiring scans that pin the app target's executor seams (the
    /// push arm's transport call, the accessor-driven receive gate, the
    /// erase path's reset marker). The scan tests assert the set is
    /// non-empty so a missing/renamed app directory can never make a scan
    /// vacuously green.
    static func momoAppSources() throws -> [(name: String, contents: String)] {
        let directory = repoRoot + "/Apps/Momo"
        let urls = try FileManager.default
            .contentsOfDirectory(at: URL(fileURLWithPath: directory), includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        return try urls.map { url in
            (name: url.lastPathComponent, contents: try String(contentsOf: url, encoding: .utf8))
        }
    }
}
