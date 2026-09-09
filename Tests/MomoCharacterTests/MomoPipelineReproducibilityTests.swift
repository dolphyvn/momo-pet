import Foundation
import Testing

@testable import MomoCharacter

/// Reproducibility pin (TASK-025 R6 + §8.2): re-running the pipeline must
/// reproduce the committed generated sources AND the committed SVG evidence
/// byte-identically. The test drives `generate.py` the way a developer does
/// (python3 from PATH, run from the repository root), writes into a temp
/// directory, and diffs against the committed bytes — output drift fails
/// loudly with the offending file list. No skip path: a host that cannot run
/// the pipeline cannot honestly claim the pin, so that is a failure, not a
/// skip (the tooling record in Tools/character-pipeline/README.md documents
/// the verified hosts).
@Suite("Pipeline reproducibility (regeneration is byte-identical)")
struct MomoPipelineReproducibilityTests {

    /// Evidence canvases committed beside the Swift output (the --evidence-dir
    /// payload). The PNG evidence is a separate host rasterizer, not part of
    /// this pin (see README).
    private static let evidenceFiles = [
        "rig-full.svg", "rig-lod-glance.svg", "rig-glyph.svg", "room-scene.svg",
    ]

    /// `python3` resolved from PATH, or nil with an actionable message.
    private static func resolvePython3() -> String? {
        let path = ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin"
        for directory in path.split(separator: ":") {
            let candidate = URL(fileURLWithPath: String(directory))
                .appendingPathComponent("python3").path
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }

    /// Runs the pipeline from the repository root; returns
    /// (exit code, stdout, stderr).
    private static func runPipeline(outputDirectory: String)
        throws -> (code: Int32, stdout: String, stderr: String) {
        let python3 = try #require(resolvePython3(), """
        python3 not found on PATH — the reproducibility pin requires the \
        pipeline toolchain (see Tools/character-pipeline/README.md)
        """)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: python3)
        process.arguments = [
            "Tools/character-pipeline/generate.py",
            "--out-dir", outputDirectory + "/swift",
            "--evidence-dir", outputDirectory + "/evidence",
        ]
        process.currentDirectoryURL = URL(fileURLWithPath: RepoTree.repoRoot)
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (
            process.terminationStatus,
            String(data: data, encoding: .utf8) ?? "",
            String(data: errData, encoding: .utf8) ?? ""
        )
    }

    private static func bytes(at path: String) throws -> [UInt8] {
        try Array(Data(contentsOf: URL(fileURLWithPath: path)))
    }

    @Test("regeneration reproduces the committed Swift output byte-identically")
    func swiftOutputReproduces() throws {
        let scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("momo-repro-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: scratch) }

        let (code, stdout, stderr) = try Self.runPipeline(outputDirectory: scratch.path)
        #expect(code == 0, "pipeline failed (exit \(code)):\n\(stderr)\n\(stdout)")

        var drift: [String] = []
        for file in GeneratedRigCatalog.generatedFiles {
            let name = (file as NSString).lastPathComponent
            let committed = try Self.bytes(at: RepoTree.repoRoot + "/" + file)
            let fresh = try Self.bytes(at: scratch.path + "/swift/" + name)
            if committed != fresh {
                drift.append("\(name) (\(committed.count) committed vs \(fresh.count) fresh bytes)")
            }
        }
        #expect(drift.isEmpty, """
        pipeline output drift — re-run \
        \(GeneratedRigCatalog.generateCommand) and commit: \(drift)
        """)
    }

    @Test("regeneration reproduces the committed SVG evidence byte-identically")
    func evidenceReproduces() throws {
        let scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("momo-repro-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: scratch) }

        let (code, stdout, stderr) = try Self.runPipeline(outputDirectory: scratch.path)
        #expect(code == 0, "pipeline failed (exit \(code)):\n\(stderr)\n\(stdout)")

        var drift: [String] = []
        for file in Self.evidenceFiles {
            let committed = try Self.bytes(
                at: RepoTree.repoRoot + "/docs/evidence/character/" + file)
            let fresh = try Self.bytes(at: scratch.path + "/evidence/" + file)
            if committed != fresh {
                drift.append("\(file) (\(committed.count) committed vs \(fresh.count) fresh bytes)")
            }
        }
        #expect(drift.isEmpty, "evidence drift — regenerate with --evidence-dir docs/evidence/character: \(drift)")
    }

    @Test("the pipeline's own --check agrees (exit 0 against the committed tree)")
    func pipelineSelfCheckPasses() throws {
        let scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("momo-repro-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: scratch) }

        // --check compares a fresh regeneration against the COMMITTED tree and
        // exits 1 listing drift — the pipeline's own voice confirming the two
        // pins above.
        let process = Process()
        process.executableURL = URL(
            fileURLWithPath: try #require(Self.resolvePython3(),
                                          "python3 not found on PATH"))
        process.arguments = ["Tools/character-pipeline/generate.py", "--check"]
        process.currentDirectoryURL = URL(fileURLWithPath: RepoTree.repoRoot)
        let stderr = Pipe()
        process.standardError = stderr
        try process.run()
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        #expect(process.terminationStatus == 0, """
        generate.py --check reported drift against the committed tree:
        \(String(data: errData, encoding: .utf8) ?? "")
        """)
    }
}
