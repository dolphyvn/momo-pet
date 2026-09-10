import MomoCore
import Testing

@testable import MomoCharacter

/// The resume discipline under the zero-on-pause clock (04 §5.3's pause
/// discipline; ADR-010; the contract's Required Test 3): app-hide zeroes
/// the CharacterClock, so on resume the seeded log REGENERATES identically
/// (same seed) and plays again in real time from timeline zero — no
/// catch-up burst, and no between-pause event replay (there are no
/// between-pause events under zeroing). The TASK-026 clock pins
/// (`CharacterClockTests`) stay authoritative for the clock itself; this
/// suite pins the discipline THROUGH the sequencer + model pipeline.
@Suite("Idle resume discipline — zero-on-pause replay from zero, no burst (ADR-010)")
struct MomoIdleResumeTests {

    private let content = CharacterDisplayState(
        moodBand: .content, energyBand: .relaxed, bondStage: .gettingClose,
        wakefulness: .awake, activity: nil, satietyHint: nil, momentRequest: nil)

    @Test("Pause → wall-gap → resume restarts the timeline at zero and replays in real time")
    func resumeRestartsAtZeroAndReplaysInRealTime() {
        let source = SteppedClock()
        let clock = CharacterClock(timeSource: source)

        clock.resume()
        source.advance(by: 17) // the run reaches T = 17 s of character time
        #expect(clock.elapsed() == 17)

        clock.pause() // app-hide: the timeline zeroes and stays zeroed
        source.advance(by: 120) // a two-minute background dwell
        #expect(clock.elapsed() == 0)

        clock.resume() // return: the timeline restarts from zero
        #expect(clock.elapsed() == 0)

        // Real-time replay, not a catch-up burst: the dwell is gone, and
        // the timeline accumulates only what passes AFTER the resume.
        source.advance(by: 3)
        #expect(clock.elapsed() == 3)
    }

    @Test("The resumed run equals a fresh run: same log, no burst, same poses")
    func resumedRunEqualsAFreshRun() {
        let seed: UInt64 = 42
        let model = RigMotionModel(idleSeed: seed)

        // The fresh reference: a log over 30 s of character time that never
        // saw a pause.
        let freshLog = MomoIdleSequencer.schedule(
            idleSeed: seed, displayState: content, windowEnd: 30)

        // The resumed run: consume to T, pause, dwell, resume.
        let source = SteppedClock()
        let clock = CharacterClock(timeSource: source)
        clock.resume()
        source.advance(by: 17)
        clock.pause()
        source.advance(by: 120)
        clock.resume()

        // The schedule after resume IS the from-zero schedule
        // (byte-for-byte — determinism makes the replay identical).
        let resumedLog = MomoIdleSequencer.schedule(
            idleSeed: seed, displayState: content, windowEnd: 30)
        #expect(resumedLog == freshLog)

        // No burst: no instant of the replayed log has multiple
        // newly-active events, every event waits strictly past the resume
        // instant, and the resume instant itself (timeline zero) is quiet.
        #expect(Set(resumedLog.map(\.start)).count == resumedLog.count)
        #expect(resumedLog.allSatisfy { $0.start > 0 })
        #expect(MomoIdleArbiter.admitted(schedule: resumedLog, at: 0).isEmpty)

        // The replay is real time from zero: the timeline advances 1.5 s
        // per 1.5 s of wall time (no dwell debt), and the pose at each
        // resumed instant equals the fresh run's pose at the same
        // character-timeline t.
        for step in 1...20 {
            source.advance(by: 1.5)
            let t = clock.elapsed()
            #expect(t == Double(step) * 1.5)
            #expect(
                model.pose(at: t, displayState: content)
                    == model.pose(at: t, displayState: content, schedule: freshLog))
        }
    }
}
