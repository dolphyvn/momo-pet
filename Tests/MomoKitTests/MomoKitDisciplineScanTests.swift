import Foundation
import Testing

/// The standing discipline scans over `Sources/MomoKit` (TASK-021
/// Requirement 6): no ambient time anywhere, no ambient path outside the one
/// sanctioned `StoreRules.defaultDirectory()` factory, Foundation+MomoCore
/// imports only. Non-vacuity is layered exactly like `EnginePurityScanTests`:
/// (1) every banned literal is proven to actually match a canonical fixture
/// (a typo'd literal can never green the scan), (2) the documented exemption
/// is proven live — its file exists, holds the sanctioned pattern, and the
/// same content elsewhere still fails, (3) the seeded-violation RED proof is
/// the fixture set itself: each banned literal demonstrably turns the scan
/// red, then restoring the real tree greens it (the real-tree test is the
/// restore-green half of that proof).
@Suite("MomoKit discipline scan — no ambient time/paths, Foundation+MomoCore imports only")
struct MomoKitDisciplineScanTests {

    // MARK: - Fixture self-tests (the seeded-violation red halves)

    @Test("violating fixture: every ambient-time spelling is caught, with attribution")
    func ambientTimeFails() {
        let source = """
        let a = Date()
        let b = Date.now
        let c = Date(timeIntervalSince1970: 0)
        """
        let violations = MomoKitDisciplineScan.timeViolations(
            files: [("Sources/MomoKit/Fixtures/Time.swift", source)]
        )
        #expect(violations == [
            MomoKitDisciplineScan.Violation(file: "Sources/MomoKit/Fixtures/Time.swift", literal: "Date("),
            MomoKitDisciplineScan.Violation(file: "Sources/MomoKit/Fixtures/Time.swift", literal: "Date.now"),
        ])
    }

    @Test("violating fixture: every ambient-path spelling is caught outside the exempt file")
    func ambientPathsFail() {
        let source = """
        let a = NSHomeDirectory()
        let b = homeDirectoryForCurrentUser
        let c = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let d = NSTemporaryDirectory()
        let e = URL.temporaryDirectory
        """
        let violations = MomoKitDisciplineScan.pathViolations(
            files: [("Sources/MomoKit/Fixtures/Paths.swift", source)]
        )
        #expect(
            violations.map(\.literal) == [
                "NSHomeDirectory(",
                "NSTemporaryDirectory(",
                "applicationSupportDirectory",
                "homeDirectoryForCurrentUser",
                "temporaryDirectory",
            ],
            "every banned path literal must actually match (non-vacuous matcher)"
        )
    }

    @Test("mentions inside comments do not fake violations (spec citations are fine)")
    func commentMentionsPass() {
        let source = """
        // The store never touches Date() or Date.now — savedAt is injected.
        /// See §5.2: the default directory is Application Support/Momo,
        /// resolved by StoreRules.defaultDirectory(), never NSHomeDirectory().
        let savedAt = clock.now()
        """
        #expect(MomoKitDisciplineScan.timeViolations(files: [("Fixtures/Comments.swift", source)]).isEmpty)
        #expect(MomoKitDisciplineScan.pathViolations(files: [("Fixtures/Comments.swift", source)]).isEmpty)
    }

    @Test("the path exemption spares only StoreRules.swift, and only the path family")
    func exemptionAppliesToDeclaredFileOnly() {
        let factorySource = """
        let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let now = Date.now
        """
        // Exempted for paths…
        #expect(MomoKitDisciplineScan.pathViolations(files: [("Sources/MomoKit/StoreRules.swift", factorySource)]).isEmpty,
                "the path exemption must cover StoreRules.swift")
        // …but the SAME content elsewhere fails…
        #expect(
            MomoKitDisciplineScan.pathViolations(files: [("Sources/MomoKit/SnapshotStore.swift", factorySource)])
                .map(\.literal) == ["applicationSupportDirectory"],
            "the exemption is per-file: identical content in another MomoKit source must fail"
        )
        // …and the exemption is family-scoped: ambient time is banned there too.
        #expect(
            MomoKitDisciplineScan.timeViolations(files: [("Sources/MomoKit/StoreRules.swift", factorySource)])
                .map(\.literal) == ["Date.now"],
            "no file is exempt from the ambient-time family"
        )
    }

    @Test("violating fixture: an import outside Foundation+MomoCore is caught")
    func foreignImportFails() {
        let violations = MomoKitDisciplineScan.importViolations(
            files: [("Sources/MomoKit/Fixtures/Import.swift", "import Foundation\nimport SwiftUI\nimport MomoCore\n")]
        )
        #expect(violations == [MomoKitDisciplineScan.Violation(file: "Sources/MomoKit/Fixtures/Import.swift", literal: "SwiftUI")])
    }

    // MARK: - Matcher non-vacuity

    @Test("every banned time/path literal actually matches its canonical fixture (no typo'd literals)")
    func everyPatternMatchesSomething() {
        for literal in MomoKitDisciplineScan.bannedTimeLiterals {
            let fixture = "private let probe = \(literal)\n"
            let violations = MomoKitDisciplineScan.timeViolations(files: [("Fixtures/Probe.swift", fixture)])
            #expect(violations.map(\.literal) == [literal], "banned literal \(literal) failed to match anything")
        }
        for literal in MomoKitDisciplineScan.bannedPathLiterals {
            let fixture = "private let probe = \(literal)\n"
            let violations = MomoKitDisciplineScan.pathViolations(files: [("Fixtures/Probe.swift", fixture)])
            #expect(violations.map(\.literal) == [literal], "banned literal \(literal) failed to match anything")
        }
    }

    // MARK: - The standing scans over the real MomoKit sources
    // (the restore-green halves of the seeded-violation proofs above)

    @Test("MomoKit as it stands is free of ambient time (non-empty source set)")
    func momoKitHasNoAmbientTime() throws {
        let sources = try KitRepo.momoKitSources()
        #expect(!sources.isEmpty, "Sources/MomoKit must exist and contain Swift sources")
        let violations = MomoKitDisciplineScan.timeViolations(files: sources)
        #expect(violations.isEmpty, "ambient-time violation: \(violations.map { "\($0.file): \($0.literal)" })")
    }

    @Test("MomoKit as it stands computes no ambient path outside the sanctioned factory")
    func momoKitHasNoAmbientPaths() throws {
        let sources = try KitRepo.momoKitSources()
        let violations = MomoKitDisciplineScan.pathViolations(files: sources)
        #expect(violations.isEmpty, "ambient-path violation: \(violations.map { "\($0.file): \($0.literal)" })")
    }

    @Test("the path exemption is live: its file exists and holds exactly one sanctioned path read")
    func pathExemptionIsLive() throws {
        let sources = try KitRepo.momoKitSources()
        let storeRulesFiles = sources.filter { $0.name == MomoKitDisciplineScan.pathExemptFileName }
        #expect(storeRulesFiles.count == 1, "exactly one StoreRules.swift must exist for the exemption to be meaningful")
        let stripped = MomoKitDisciplineScan.strippingComments(from: storeRulesFiles[0].contents)
        // Occurrence-pinned (REVIEW-TASK-014 MINOR-2's discipline): the
        // whole-file exemption would excuse a SECOND ambient read in this
        // file, so the sanctioned site is pinned to exactly one occurrence —
        // any further one must fail and be justified.
        let pathReadOccurrences = stripped.components(separatedBy: "applicationSupportDirectory").count - 1
        #expect(pathReadOccurrences == 1, "StoreRules.swift must contain exactly one applicationSupportDirectory read (the sanctioned defaultDirectory factory) — found \(pathReadOccurrences)")
    }

    @Test("MomoKit as it stands imports Foundation and MomoCore only")
    func momoKitImportsAreWhitelisted() throws {
        let sources = try KitRepo.momoKitSources()
        let violations = MomoKitDisciplineScan.importViolations(files: sources)
        #expect(violations.isEmpty, "import violation: \(violations.map { "\($0.file): \($0.literal)" })")
    }
}
