import Foundation
import Testing
@testable import MomoCore

/// Clock protocol behavior (TASK-014 Requirement 5 / AC-2; 05 §4.10).
@Suite("EngineClock (protocol + production + manual)")
struct EngineClockTests {

    private func utcInstant(_ iso: String) -> Instant {
        ISO8601DateFormatter().date(from: iso)!
    }

    // MARK: - ManualEngineClock (the test clock)

    @Test("manual clock reports the instant it was set to")
    func manualReportsSetInstant() {
        let clock = ManualEngineClock(at: utcInstant("2026-09-08T12:00:00Z"))
        #expect(clock.now() == utcInstant("2026-09-08T12:00:00Z"))
    }

    @Test("manual clock default starts at the Unix epoch (deterministic)")
    func manualDefaultIsEpoch() {
        #expect(ManualEngineClock().now() == utcInstant("1970-01-01T00:00:00Z"))
    }

    @Test("advance(to:) moves absolutely — including backwards (§4.3 clock-change cases)")
    func manualAdvanceAbsolute() {
        var clock = ManualEngineClock(at: utcInstant("2026-09-08T12:00:00Z"))
        clock.advance(to: utcInstant("2026-09-09T07:00:00Z"))
        #expect(clock.now() == utcInstant("2026-09-09T07:00:00Z"))
        clock.advance(to: utcInstant("2026-09-09T06:59:59Z"))
        #expect(clock.now() == utcInstant("2026-09-09T06:59:59Z"))
    }

    @Test("advance(by:) shifts relatively, negative included")
    func manualAdvanceRelative() {
        var clock = ManualEngineClock(at: utcInstant("2026-09-08T12:00:00Z"))
        clock.advance(by: 5400)
        #expect(clock.now() == utcInstant("2026-09-08T13:30:00Z"))
        clock.advance(by: -7200)
        #expect(clock.now() == utcInstant("2026-09-08T11:30:00Z"))
    }

    @Test("value semantics: advancing a copy never moves the original")
    func manualValueSemantics() {
        let original = ManualEngineClock(at: utcInstant("2026-09-08T12:00:00Z"))
        var copy = original
        copy.advance(to: utcInstant("2026-09-10T00:00:00Z"))
        #expect(original.now() == utcInstant("2026-09-08T12:00:00Z"))
        #expect(copy.now() == utcInstant("2026-09-10T00:00:00Z"))
    }

    // MARK: - SystemEngineClock (the production clock)

    @Test("system clock reads the real wall clock (within a generous tolerance)")
    func systemReadsWallClock() throws {
        let clock = SystemEngineClock()
        let before = Date()
        let read = clock.now()
        let after = Date()
        #expect(read >= before.addingTimeInterval(-1))
        #expect(read <= after.addingTimeInterval(1))
        // Monotonicity across two reads of the wall clock (§4.10's production path).
        let secondRead = clock.now()
        #expect(secondRead >= read)
    }

    @Test("both clocks satisfy the EngineClock protocol contract (existential use)")
    func protocolContract() {
        let expected = utcInstant("2026-09-08T12:00:00Z")
        let clocks: [any EngineClock] = [SystemEngineClock(), ManualEngineClock(at: expected)]
        // Existential dispatch answers with each clock's own time source.
        #expect(clocks[1].now() == expected)
        let systemRead = clocks[0].now()
        #expect(abs(systemRead.timeIntervalSinceNow) < 5)
    }
}
