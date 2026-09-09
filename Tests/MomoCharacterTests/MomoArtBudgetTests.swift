import Foundation
import Testing

@testable import MomoCharacter

/// Generated-source budgets (TASK-025, 04 §8.3): the committed geometry layer
/// must stay inside the Phase-1 art budget. Buckets are pinned by exact file
/// sets — a new generated file lands in no bucket and fails the coverage pin,
/// so the budget cannot be silently side-stepped.
@Suite("Art budgets (04 §8.3 generated-source byte limits)")
struct MomoArtBudgetTests {

    /// §8.3 buckets, pinned to the emission layout (GeneratedRigCatalog).
    private static let rigFiles = GeneratedRigCatalog.generatedFiles
        .filter { $0.contains("MomoRig+") }
    private static let roomAndPropsFiles = [
        "Sources/MomoCharacter/MomoRoom.swift",
        "Sources/MomoCharacter/MomoProps.swift",
    ]

    /// §8.3 limits on the same KB basis as the buckets (1024-byte KB).
    private static let limits = (
        rig: 300 * 1024,          // §8.3: rig ≤ 300 KB
        roomAndProps: 250 * 1024, // §8.3: room + props ≤ 250 KB
        total: 1536 * 1024        // §8.3: total ≤ 1.5 MB
    )

    private static func byteCount(_ file: String) throws -> Int {
        try GeneratedRigCatalog.readGeneratedFile(file).utf8.count
    }

    @Test("rig bucket within the §8.3 limit")
    func rigBudget() throws {
        let bytes = try Self.rigFiles.reduce(0) { try $0 + Self.byteCount($1) }
        #expect(bytes <= Self.limits.rig,
                "rig generated source \(bytes) bytes exceeds the 300 KB budget")
        #expect(bytes > 40_000, "rig bucket suspiciously small (\(bytes)) — inventory drift")
    }

    @Test("room + props bucket within the §8.3 limit")
    func roomAndPropsBudget() throws {
        let bytes = try Self.roomAndPropsFiles.reduce(0) { try $0 + Self.byteCount($1) }
        #expect(bytes <= Self.limits.roomAndProps,
                "room + props generated source \(bytes) bytes exceeds the 250 KB budget")
        #expect(bytes > 5_000, "room + props bucket suspiciously small (\(bytes))")
    }

    @Test("total generated art within the §8.3 budget, every file covered")
    func totalBudgetAndCoverage() throws {
        let rig = try Self.rigFiles.reduce(0) { try $0 + Self.byteCount($1) }
        let roomAndProps = try Self.roomAndPropsFiles.reduce(0) { try $0 + Self.byteCount($1) }
        let total = rig + roomAndProps
        // §8.3 total budget 1.5 MB; measured at authoring time ≈ 70 KB.
        #expect(total <= Self.limits.total,
                "total generated art \(total) bytes exceeds budget")
        #expect(total > 45_000, "total suspiciously small (\(total)) — inventory drift")

        // Coverage: the buckets must account for every generated file, so a
        // future generated file cannot land outside the budget scan.
        #expect(Self.rigFiles.count + Self.roomAndPropsFiles.count
                    == GeneratedRigCatalog.generatedFiles.count,
                "bucket file sets must partition the 11 generated files")
    }
}
