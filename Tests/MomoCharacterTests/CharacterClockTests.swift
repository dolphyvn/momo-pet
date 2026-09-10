import Foundation
import MomoCore
import Testing

@testable import MomoCharacter

/// TASK-026 Requirement 1 / 04 §9.5 + §7.4 rule 1: ONE pausable character
/// timeline over an injected time source (no ambient reads). Pause zeroes the
/// timeline; resume restarts accumulation from zero (no backlog replay);
/// both are idempotent; a stopped clock freezes elapsed at zero; every query
/// is side-effect-free so a TimelineView context date can render the pose
/// deterministically.
@Suite("CharacterClock — zero-on-pause, resume-from-zero, one-call gate")
struct CharacterClockTests {

    /// Epoch — the fixed anchor every test's source starts at.
    private static let epoch = Instant(timeIntervalSince1970: 0)

    private func makeClock(source: SteppedClock = SteppedClock()) -> CharacterClock {
        CharacterClock(timeSource: source)
    }

    // MARK: - Initial state

    @Test("Init starts STOPPED with a zeroed timeline — rest pose until resumed")
    func initIsStoppedAtZero() {
        let source = SteppedClock()
        let clock = makeClock(source: source)

        #expect(!clock.isRunning)
        source.advance(by: 100) // time passing while stopped accrues nothing
        #expect(clock.elapsed() == 0)
    }

    // MARK: - Resume / pause fundamentals

    @Test("Resume starts accumulation from zero; elapsed tracks the injected source")
    func resumeAccumulatesFromZero() {
        let source = SteppedClock()
        let clock = makeClock(source: source)

        clock.resume()
        #expect(clock.isRunning)
        #expect(clock.elapsed() == 0) // resumed, but nothing has passed yet

        source.advance(by: 2.5)
        #expect(clock.elapsed() == 2.5)

        source.advance(by: 1.25)
        #expect(clock.elapsed() == 3.75)
    }

    @Test("Pause zeroes the timeline and freezes it there")
    func pauseZeroes() {
        let source = SteppedClock()
        let clock = makeClock(source: source)

        clock.resume()
        source.advance(by: 3)
        clock.pause()

        #expect(!clock.isRunning)
        #expect(clock.elapsed() == 0)

        source.advance(by: 100) // the world moves on; the stopped clock does not
        #expect(clock.elapsed() == 0)
    }

    @Test("Resume after pause restarts from zero — no backlog replay (04 §5.3)")
    func resumeAfterPauseRestartsFromZero() {
        let source = SteppedClock()
        let clock = makeClock(source: source)

        clock.resume()
        source.advance(by: 3)
        clock.pause()
        source.advance(by: 10) // background dwell must NOT replay on resume

        clock.resume()
        source.advance(by: 1.5)
        #expect(clock.elapsed() == 1.5)
    }

    // MARK: - Idempotence

    @Test("Double pause is idempotent: still zero, still restarts from zero")
    func doublePauseIsIdempotent() {
        let source = SteppedClock()
        let clock = makeClock(source: source)

        clock.resume()
        source.advance(by: 2)
        clock.pause()
        clock.pause()
        source.advance(by: 5)

        #expect(!clock.isRunning)
        #expect(clock.elapsed() == 0)

        clock.resume()
        source.advance(by: 1)
        #expect(clock.elapsed() == 1) // the second pause did not re-anchor
    }

    @Test("Double resume never resets the anchor — accumulation continues")
    func doubleResumeNeverResets() {
        let source = SteppedClock()
        let clock = makeClock(source: source)

        clock.resume()
        source.advance(by: 1)
        clock.resume() // no-op: must NOT re-anchor to the later instant
        source.advance(by: 1)

        #expect(clock.elapsed() == 2)
    }

    @Test("Resume without a prior pause keeps accumulating (defined: no reset)")
    func resumeWithoutPauseContinues() {
        let source = SteppedClock()
        let clock = makeClock(source: source)

        clock.resume()
        source.advance(by: 4)
        clock.resume()
        source.advance(by: 4)
        #expect(clock.elapsed() == 8)
    }

    // MARK: - Deterministic rendering

    @Test("elapsed(at:) answers an injected instant without touching the source")
    func elapsedAtInstantIsPure() {
        let source = SteppedClock()
        let clock = makeClock(source: source)

        clock.resume()
        let anchorPlus2 = Self.epoch.addingTimeInterval(2)
        #expect(clock.elapsed(at: anchorPlus2) == 2)

        source.advance(by: 500) // the source's own time is irrelevant to the query
        #expect(clock.elapsed(at: anchorPlus2) == 2)
    }

    @Test("A backward-running source never yields negative elapsed")
    func backwardTimeClampsToZero() {
        let source = SteppedClock()
        let clock = makeClock(source: source)

        clock.resume()
        source.advance(by: 2)
        source.advance(by: -50) // manual wall-clock change while running

        #expect(clock.elapsed() == 0)
        #expect(clock.elapsed(at: Self.epoch.addingTimeInterval(-10)) == 0)
    }

    // MARK: - The one-call gate made visible through the motion model

    @Test("Single gate: a paused clock freezes the character at the unaged pose")
    func pausedClockStopsEveryChannel() {
        let source = SteppedClock()
        let clock = makeClock(source: source)
        let model = RigMotionModel()
        let state = Self.contentState

        clock.resume()
        source.advance(by: MomoCurves.breathCycleSeconds / 4) // inhale peak
        let breathing = model.pose(at: clock.elapsed(), displayState: state)
        #expect(breathing.body.scaleY > 1.0)

        clock.pause() // the ONE call — everything stops
        let frozen = model.pose(at: clock.elapsed(), displayState: state)
        // (TASK-027 move of the former `.rest` pin, which predated the
        // expression system: pause now freezes at the model's t = 0 pose —
        // the band base with every motion channel zeroed. Equally strict,
        // digit-for-digit.)
        #expect(frozen == model.pose(at: 0, displayState: state))
        #expect(frozen.body == .identity) // no motion at the frozen instant
    }

    // MARK: - Shared display state

    static let contentState = CharacterDisplayState(
        moodBand: .content, energyBand: .relaxed, bondStage: .gettingClose,
        wakefulness: .awake, activity: nil, satietyHint: nil, momentRequest: nil)
}
