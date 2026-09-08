import Foundation
import Testing
@testable import MomoCore

/// Self-tests + the standing scan for engine purity (TASK-014 Requirement 8,
/// AC-4; 05 §4.1/§4.10/ADR-004). The scanner is a pure function over literal
/// fixture sources; the real-tree scan feeds `Sources/MomoCore` contents read
/// via `TestRepo`. Non-vacuity is layered:
/// 1. every banned pattern is proven to actually match a canonical fixture
///    (a typo'd literal can never green the scan),
/// 2. the single documented exemption (`EngineClock.swift`, `Date`-family
///    only) is proven live — the file exists, contains the exempted pattern,
///    and the same content elsewhere still fails,
/// 3. the real-tree scan additionally had a seeded violation caught RED in a
///    scratch run that was reverted before review (recorded in the TASK-014
///    Implementation Notes — TASK-010's harness self-test discipline).
@Suite("Engine purity scan (no ambient time/calendar/randomness)")
struct EnginePurityScanTests {

    // MARK: - Fixture self-tests (failure and success paths)

    @Test("violating fixture: an ambient Date() fails with attribution")
    func ambientDateFails() {
        let violations = EnginePurityScan.violations(
            files: [("Sources/MomoCore/Fixtures/Violating.swift", "import Foundation\nlet now = Date()\n")]
        )
        #expect(violations == [EnginePurityScan.Violation(file: "Sources/MomoCore/Fixtures/Violating.swift", literal: "Date(")])
    }

    @Test("violating fixtures: every randomness spelling is caught")
    func randomnessFails() {
        let source = """
        let a = random()
        let b = arc4random_uniform(10)
        let c = Int.random(in: 0...10)
        let d = [1, 2, 3].randomElement()
        let e = UUID()
        let f = drand48()
        """
        let violations = EnginePurityScan.violations(
            files: [("Fixtures/Random.swift", source)]
        )
        let literals = Set(violations.map(\.literal))
        #expect(literals == ["random(", "randomElement(", "arc4random", "UUID(", "drand48("])
    }

    @Test("violating fixtures: ambient calendar/time zone are caught")
    func ambientCalendarFails() {
        let source = """
        let day = Calendar.current.component(.day, from: someInstant)
        let zone = TimeZone.current.identifier
        """
        let violations = EnginePurityScan.violations(
            files: [("Fixtures/Calendar.swift", source)]
        )
        let literals = Set(violations.map(\.literal))
        #expect(literals == ["Calendar.current", "TimeZone.current"])
    }

    @Test("mentions inside comments do not fake violations (spec citations are fine)")
    func commentMentionsPass() {
        let source = """
        // The engine never touches Date(), Calendar.current, or UUID().
        /// See §4.10: no Date.now anywhere.
        let seed = DaySeed.make(petID: id, localDayKey: key, epoch: 0, salt: .copy)
        """
        let violations = EnginePurityScan.violations(
            files: [("Fixtures/Comments.swift", source)]
        )
        #expect(violations.isEmpty)
    }

    @Test("the documented exemption spares only the exempted file")
    func exemptionAppliesToDeclaredFilesOnly() {
        let systemClockSource = """
        public struct SystemEngineClock: EngineClock {
            public func now() -> Instant { Date.now }
        }
        """
        let exempt = EnginePurityScan.violations(
            files: [("Sources/MomoCore/EngineClock.swift", systemClockSource)]
        )
        #expect(exempt.isEmpty, "the Date-family exemption must cover EngineClock.swift")
        let elsewhere = EnginePurityScan.violations(
            files: [("Sources/MomoCore/Reduce.swift", systemClockSource)]
        )
        #expect(elsewhere.map(\.literal).sorted() == ["Date.now"],
                "the same content outside the exempted file must fail")
        let randomnessStillBanned = EnginePurityScan.violations(
            files: [("Sources/MomoCore/EngineClock.swift", "let e = UUID()\n")]
        )
        #expect(randomnessStillBanned.map(\.literal) == ["UUID("],
                "the exemption is per-pattern: randomness stays banned in EngineClock.swift")
    }

    // MARK: - Matcher non-vacuity

    @Test("every banned pattern actually matches its canonical fixture (no typo'd literals)")
    func everyPatternMatchesSomething() {
        for pattern in EnginePurityScan.patterns {
            let fixture = "private let probe = \(pattern.literal)\n"
            let violations = EnginePurityScan.violations(
                files: [("Fixtures/Probe.swift", fixture)]
            )
            #expect(violations.map(\.literal) == [pattern.literal],
                    "banned literal \(pattern.literal) failed to match anything")
        }
    }

    // MARK: - The standing scan over the real MomoCore sources

    @Test("MomoCore as it stands is engine-pure (non-empty source set)")
    func momoCoreIsPure() throws {
        let sources = try TestRepo.momoCoreSources()
        // The scan must not be able to pass vacuously: a missing or renamed
        // module directory fails here instead of greening the scan.
        #expect(!sources.isEmpty, "Sources/MomoCore must exist and contain Swift sources")
        let violations = EnginePurityScan.violations(files: sources)
        #expect(violations.isEmpty, "engine-purity violation: \(violations.map { "\($0.file): \($0.literal)" })")
    }

    @Test("the documented exemption is live: its file exists and holds exactly one sanctioned Date read")
    func exemptionIsLive() throws {
        let sources = try TestRepo.momoCoreSources()
        let engineClockFiles = sources.filter { $0.name.hasSuffix("/EngineClock.swift") }
        #expect(engineClockFiles.count == 1, "exactly one EngineClock.swift must exist for the exemption to be meaningful")
        let stripped = ImportWhitelistScan.strippingComments(from: engineClockFiles[0].contents)
        #expect(stripped.contains("Date.now"),
                "SystemEngineClock's sanctioned wall-clock read must still be present — otherwise the exemption is dead and should be removed")
        // Occurrence-pinned (REVIEW-TASK-014 MINOR-2): the file+pattern
        // exemption covers the whole file, so a SECOND `Date` read inside
        // EngineClock.swift would otherwise be excused too. The count pin
        // closes that: the sanctioned read is exactly one — any further
        // `Date` occurrence in this file must fail and be justified
        // (narrowing the exemption or removing the read).
        let dateOccurrences = stripped.components(separatedBy: "Date").count - 1
        #expect(dateOccurrences == 1,
                "EngineClock.swift must contain exactly one Date occurrence (the sanctioned Date.now in SystemEngineClock) — found \(dateOccurrences)")
    }
}
