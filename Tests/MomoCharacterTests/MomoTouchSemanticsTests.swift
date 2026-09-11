import Testing
import Foundation
import MomoCore
@testable import MomoCharacter

/// TASK-034's cross-module touch battery: the §6.1 gesture×zone map as it
/// arrives through the PUBLIC engine fold (`reduce` — the exhaustiveness
/// proof that every touch reaction the engine can mint resolves to a clip
/// key the character layer can play), the asleep stir, and the director
/// fold SHAPE the app model's TASK-034 wiring depends on (press layers
/// from the touch boundaries, plans → clips, the hide gate, exactly-once
/// finish reports). State construction mirrors the InteractionFixture
/// discipline — literal instants, the shared fixture petID, deterministic
/// seeds. The per-cell reaction VALUES are MomoCoreTests'
/// `InteractionResponseTests` pins; this suite pins what only the
/// character layer can see: the minted clip keys and the fold's overlay
/// behavior.
@Suite("Touch semantics — public-fold exhaustiveness + director wiring shape (TASK-034)")
struct MomoTouchSemanticsTests {

    private let petID = UUID(uuidString: "7C47A9C4-2E5F-4B8A-9C1D-3E6F8A2B4C0D")!
    private let day = "2026-09-08"

    private func utcInstant(_ iso: String) -> Instant {
        ISO8601DateFormatter().date(from: iso)!
    }

    private var calendar: Calendar {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = TimeZone(identifier: "UTC")!
        return gregorian
    }

    /// An awake pet over the fixture day (quests zeroed, hello pre-awarded
    /// so the pins below isolate the response mapping).
    private func state(wakefulness: Wakefulness = .awake) -> EngineState? {
        guard let pet = Pet(id: petID, name: "Momo", createdAt: utcInstant("2026-01-01T00:00:00Z")),
              let petState = PetState(
                  mood: 60, energy: 80, bond: 0,
                  wakefulness: wakefulness, activity: nil,
                  lastFedAt: nil, satietyPhase: .hungry
              ),
              let dayRecord = DayRecord(
                  dayKey: day,
                  feedCount: 0, playCount: 0, careCount: 0, patCount: 0,
                  questSet: [
                      QuestProgress(questID: .q1, progress: 0, completed: false)!,
                      QuestProgress(questID: .q2, progress: 0, completed: false)!,
                      QuestProgress(questID: .q6, progress: 0, completed: false)!,
                  ],
                  helloAwarded: true,
                  familiesUsed: [],
                  bondAwarded: 0,
                  questGenEpoch: 1
              )
        else { return nil }
        return EngineState(
            pet: pet,
            state: petState,
            days: [dayRecord],
            settings: SettingsState(onboardingComplete: true, hapticsEnabled: true),
            pendingHandshake: nil,
            processedIntents: [],
            highestCelebratedStage: .newFriends,
            lastOpenedAt: utcInstant("2026-09-08T09:00:00Z"),
            lastEvaluatedAt: utcInstant("2026-09-08T09:00:00Z"),
            lastGreeting: nil
        )
    }

    private func reducePat(_ kind: InteractionIntent.Kind, wakefulness: Wakefulness = .awake) -> EngineOutcome {
        let state = self.state(wakefulness: wakefulness)!
        let intent = InteractionIntent(
            id: UUID(uuidString: "55555555-6666-4777-8888-999999999999")!,
            source: .iPhone,
            localDayKey: day,
            timestamp: utcInstant("2026-09-08T09:00:00Z"),
            kind: kind
        )
        var rng = SeededGenerator(seed: 0x13ec67b5bdf1e2f7)
        return reduce(
            state,
            .interaction(intent),
            clock: ManualEngineClock(at: intent.timestamp),
            calendar: calendar,
            rng: &rng
        )
    }

    // MARK: §6.1 exhaustiveness through the public fold

    /// 04 §6.1's rows: every gesture×zone cell the engine can receive
    /// (double-tap is one row for both zones; the nil-zone column is the
    /// Watch convention) mints a clip key — `MomoReactionKey` resolves, so
    /// the character layer can play the response. An unminted key would
    /// mean a touch that reduces to silence — the failure this suite
    /// exists to catch.
    @Test("every §6.1 cell mints a clip key through the public reduce (R8 exhaustiveness)")
    func everyCellMintsAClipKey() {
        let cells: [(gesture: PatGesture, zone: TouchZone?, beat: ReactionID)] = [
            (.tap, .head, ReactionKeys.tapHead),
            (.tap, .belly, ReactionKeys.tapBelly),
            (.tap, nil, ReactionKeys.tap),
            (.doubleTap, .head, ReactionKeys.doubleTap),
            (.doubleTap, .belly, ReactionKeys.doubleTap),
            (.doubleTap, nil, ReactionKeys.doubleTap),
            (.longPress, .head, ReactionKeys.longPressHead),
            (.longPress, .belly, ReactionKeys.longPressBelly),
            (.longPress, nil, ReactionKeys.longPress),
            (.stroke, .head, ReactionKeys.strokeHead),
            (.stroke, .belly, ReactionKeys.strokeBelly),
            (.stroke, nil, ReactionKeys.stroke),
        ]
        for cell in cells {
            let outcome = reducePat(.pat(gesture: cell.gesture, zone: cell.zone))
            let plan = outcome.response
            #expect(plan != nil, "\(cell.gesture) × \(String(describing: cell.zone)) must produce a plan")
            guard let plan else { continue }
            #expect(MomoReactionKey(plan.reaction) != nil,
                    "\(plan.reaction.rawValue) must mint a clip key")
            #expect(MomoReactionKey(plan.reaction) == MomoReactionKey(cell.beat),
                    "\(cell.gesture) × \(String(describing: cell.zone)) must resolve to \(cell.beat.rawValue)")
            // The spoken-line seam: a touch plan's line is a touch-pool key
            // (day-stable .02 over the fixture (petID, day) at the current
            // epoch) — the UX-8 gate's input.
            #expect(plan.lineKey == "momo.line.react.touch.02",
                    "\(cell.gesture) × \(String(describing: cell.zone)) carries the day-stable touch key")
        }
    }

    @Test("the asleep touch reduces to the stir — and the stir mints a clip key")
    func asleepTouchStirsToAMintedKey() {
        let outcome = reducePat(.pat(gesture: .tap, zone: .head), wakefulness: .asleep)
        #expect(outcome.response?.reaction == ReactionKeys.stir)
        #expect(MomoReactionKey(outcome.response!.reaction) != nil, "the stir mints a clip key")
        #expect(outcome.newState.state.wakefulness == .asleep, "the touch never wakes Momo")
    }

    // MARK: The director fold shape (the app model's wiring contract)

    @Test("a touch began opens the press layer; the hide gate clears it and show does not resurrect it")
    func pressLayerFoldsFromTouchBoundaries() {
        var director = MomoDirectorState(displayState: ReactionFixtures.content)

        director.apply(.touchBegan(zone: .head, at: 10.0))
        #expect(samples(in: 10.001...10.3, into: director).contains { $0 != .identity },
                "the L1 press layer lives while the touch is down")

        // The hide gate: the rig's clock is paused on the same transition,
        // and the director's overlay reads identity — nothing animates in
        // the hidden session.
        director.apply(.appHidden(at: 10.2))
        #expect(samples(in: 10.21...12.0, into: director).allSatisfy { $0 == .identity },
                "hidden: the press is cleared, the overlay is still")

        // Show does not resurrect what the hide cleared.
        director.apply(.appShown(at: 12.0))
        #expect(samples(in: 12.001...14.0, into: director).allSatisfy { $0 == .identity },
                "shown again: still still — no touch is down")
    }

    @Test("a touch plan plays its clip and reports the finish exactly once across later folds")
    func planPlaysAndReportsExactlyOnce() {
        var director = MomoDirectorState(displayState: ReactionFixtures.content)

        director.apply(.plan(ResponsePlan(reaction: ReactionKeys.tapHead, lineKey: nil, haptic: nil), at: 20.0))
        #expect(samples(in: 20.01...20.6, into: director).contains { $0 != .identity },
                "the tap-head clip plays")

        // Fold forward well past the clip's run: the finish is reaped at a
        // later event's reap pass, reported EXACTLY ONCE, and never
        // duplicated by subsequent folds.
        director.apply(.touchBegan(zone: .belly, at: 25.0))
        #expect(ReactionFixtures.reports(matching: ReactionFixtures.finished(ReactionKeys.tapHead), in: director).count == 1,
                "the finish report arrives with the reap pass")

        director.apply(.touchEnded(at: 25.1))
        director.apply(.appHidden(at: 26.0))
        director.apply(.appShown(at: 27.0))
        #expect(ReactionFixtures.reports(matching: ReactionFixtures.finished(ReactionKeys.tapHead), in: director).count == 1,
                "exactly-once across arbitrary later folds")

        // The hide cleared the second touch's press; shown again, the
        // overlay is still — nothing was resurrected by the show.
        #expect(samples(in: 26.01...27.5, into: director).allSatisfy { $0 == .identity },
                "the hide gate cleared the follow-up press; the show resurrects nothing")
    }

    // MARK: Sampling helper

    /// The overlay sampled at a closed range of instants (0.05 s stride) —
    /// dense enough that a transient layer cannot hide between samples.
    private func samples(in range: ClosedRange<Double>, into state: MomoDirectorState) -> [MomoReactionMotion] {
        stride(from: range.lowerBound, through: range.upperBound, by: 0.05).map {
            state.overlay(at: $0)
        }
    }
}
