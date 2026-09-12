import Foundation
import Testing
@testable import MomoCore
@testable import MomoKit

/// The TASK-043 Watch-cascade binding suites (R3/R6): the MomoKit seam is a
/// PASSTHROUGH — these tests pin that `WatchCascade.liveQuestLine` IS the
/// shared `QuestGeneration.cascade` at the argument level (the identical
/// line at 0/1/2-of-3 progress; the `.allDone` swap only at completion; the
/// hour windows bind through), and the provenance property: a snapshot
/// built through the REAL push arm's derivation (`makeDisplayState` + the
/// day-record lookup + `makeWatchSnapshot`) re-cascaded at its push hour
/// equals its carried `display.questLine` — the test that bites when the
/// DTO/builder drifts from the shared cascade.
///
/// NOT duplicated here: the cascade's six-rule matrix itself (MomoCore's
/// `QuestCascadeTests`/`DisplayStateTests` own that derivation; the Watch
/// side owns the BINDING).
@Suite("WatchCascade — the Watch-side binding + snapshot provenance (TASK-043; 05 §4.8/§4.11)")
struct WatchCascadeTests {

    private let fixture = SyncFixture()
    private let storeFixture = StoreFixture()

    /// The injected UTC calendar — the sanctioned derivation calendar (the
    /// `StoreFixture` discipline); the provenance test's push instants are
    /// UTC literals, so their local hours are exact.
    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    // MARK: - The binding (R6: identical line at 0/1/2-of-3; all-done swap)

    /// The W1 set shape [Q1 ✓, Q2 ✓, Q7 at n-of-3] cascades to `.wish(.q7)`
    /// at EVERY local hour for every incomplete progress — the identical
    /// line the UX §6.1 rule requires — and the seam's answer IS the shared
    /// cascade's answer at the same arguments (the binding's whole content).
    @Test("the binding is the shared cascade: identical line at 0/1/2-of-3 across the hour sweep",
          arguments: [0, 1, 2])
    func identicalLineAtPartialProgress(progress: Int) {
        let questSet = [
            fixture.quest(.q1, progress: 1, completed: true),
            fixture.quest(.q2, progress: 1, completed: true),
            fixture.quest(.q7, progress: progress, completed: false),
        ]
        for hour in 0..<24 {
            let bound = WatchCascade.liveQuestLine(questSet: questSet, localHour: hour)
            #expect(
                bound == .wish(.q7),
                "at \(progress)-of-3 and hour \(hour) the W1 line must stay the pat wish"
            )
            #expect(
                bound == QuestGeneration.cascade(questSet: questSet, localHour: hour),
                "the seam must be the shared cascade at hour \(hour)"
            )
        }
    }

    /// The `.allDone` swap happens ONLY at completion: the same set with Q7
    /// completed cascades to `.allDone` at every hour, while every
    /// incomplete progress (the argument matrix above) stays the wish —
    /// asserted at the BINDING level (the shared cascade's rule 6, through
    /// the Watch's seam).
    @Test("all-done swaps in only at completion, at every local hour")
    func allDoneSwapsOnlyAtCompletion() {
        let completedSet = [
            fixture.quest(.q1, progress: 1, completed: true),
            fixture.quest(.q2, progress: 1, completed: true),
            fixture.quest(.q7, progress: 3, completed: true),
        ]
        for hour in 0..<24 {
            let bound = WatchCascade.liveQuestLine(questSet: completedSet, localHour: hour)
            #expect(bound == .allDone, "the completed set must read all-done at hour \(hour)")
            #expect(
                bound == QuestGeneration.cascade(questSet: completedSet, localHour: hour),
                "the seam must be the shared cascade at hour \(hour)"
            )
        }
    }

    /// The hour is passed through untouched: over a windowed set (Q1/Q2/Q6
    /// all incomplete) the binding returns the shared cascade's window
    /// answers — Q6 in its evening/early-morning window, Q1 before noon, Q2
    /// otherwise — so the Watch's re-derivation genuinely tracks local time.
    @Test("the binding passes the local hour through — the window rules bind identically",
          arguments: [
            (hour: 3, expected: QuestGeneration.QuestLine.wish(.q6)),
            (hour: 9, expected: QuestGeneration.QuestLine.wish(.q1)),
            (hour: 14, expected: QuestGeneration.QuestLine.wish(.q2)),
            (hour: 21, expected: QuestGeneration.QuestLine.wish(.q6)),
          ])
    func hourPassesThroughToTheWindowRules(hour: Int, expected: QuestGeneration.QuestLine) {
        let questSet = [
            fixture.quest(.q1, progress: 0, completed: false),
            fixture.quest(.q2, progress: 0, completed: false),
            fixture.quest(.q6, progress: 0, completed: false),
        ]
        let bound = WatchCascade.liveQuestLine(questSet: questSet, localHour: hour)
        #expect(bound == expected, "hour \(hour) must select the window rule's quest")
        #expect(
            bound == QuestGeneration.cascade(questSet: questSet, localHour: hour),
            "the seam must be the shared cascade at hour \(hour)"
        )
    }

    // MARK: - The provenance property (R3)

    /// The push arm's derivation, replicated through the public API exactly
    /// as the iPhone wiring shapes it (`MomoAppModel+Watch.pushWatchSnapshot`):
    /// `makeDisplayState(state, at: push, calendar:)` for the display, the
    /// day-record lookup for the quest inputs, `makeWatchSnapshot` for the
    /// build. THE PROPERTY: `cascade(questSet: snapshot.questInputs,
    /// localHour: <push hour>)` == `snapshot.display.questLine` — the
    /// builder's output and the Watch's re-derivation agree at the push
    /// instant. The windowed set makes the two push hours disagree (rule 1's
    /// Q6 window vs rule 5's Q7), so an agreement that held for the wrong
    /// reason cannot pass.
    @Test("a built snapshot re-cascades to its carried line at its push hour (the provenance property)",
          arguments: [
            (push: "2026-09-09T21:00:00Z", expected: QuestGeneration.QuestLine.wish(.q6)),
            (push: "2026-09-09T09:00:00Z", expected: QuestGeneration.QuestLine.wish(.q7)),
          ])
    func builtSnapshotRecascadesToItsCarriedLineAtThePushHour(
        push: String,
        expected: QuestGeneration.QuestLine
    ) {
        let pushInstant = fixture.instant(push)
        let pushHour = utc.component(.hour, from: pushInstant)
        // The day's set: Q2 done, Q7 at 2-of-3, Q6 untouched — window-
        // sensitive (Q6 in-set but out-of-window at 09:00, in-window at
        // 21:00).
        let questSet = [
            fixture.quest(.q2, progress: 1, completed: true),
            fixture.quest(.q7, progress: 2, completed: false),
            fixture.quest(.q6, progress: 0, completed: false),
        ]
        let dayRecord = storeFixture.day(
            dayKey: DayKey.make(from: pushInstant, calendar: utc),
            feed: 1, play: 0, care: 0, pat: 2,
            questSet: questSet,
            helloAwarded: false,
            familiesUsed: [.feed, .pet, .care],
            bondAwarded: 4
        )
        let state = storeFixture.state(days: [dayRecord], processedIntents: [])

        // The push arm's exact derivation shape.
        let display = makeDisplayState(state, at: pushInstant, calendar: utc)
        let todayKey = DayKey.make(from: pushInstant, calendar: utc)
        let questInputs = state.days
            .first(where: { $0.dayKey == todayKey })!
            .questSet
        let result = makeWatchSnapshot(
            state: state,
            display: display,
            questInputs: questInputs,
            watermarkEpoch: fixture.watermarkEpoch,
            sync: SyncState()
        )
        let snapshot = result.snapshot

        // The display derivation itself cascaded to the window's answer at
        // the push hour (the premise — if this ever drifts the property
        // below would be comparing against a strawman).
        #expect(
            snapshot.display.questLine == expected,
            "makeDisplayState at hour \(pushHour) must cascade to the window's answer"
        )
        // THE PROPERTY (R3): the Watch-side re-derivation at the push hour
        // equals the carried line.
        #expect(
            WatchCascade.liveQuestLine(questSet: snapshot.questInputs, localHour: pushHour)
                == snapshot.display.questLine,
            "the re-cascade at the push hour must equal the carried display.questLine"
        )
    }

    /// The property's teeth, demonstrated in-suite: feeding the builder
    /// inputs that do NOT match the display's derivation (here: empty
    /// inputs against a display cascaded over the real set) makes the
    /// property FAIL — an empty set cascades to `.allDone`, which is not the
    /// carried wish. A builder/DTO drift that mis-threads `questInputs`
    /// lands exactly here.
    @Test("the provenance property bites on drifted inputs (the negative control)")
    func provenanceBitesOnDriftedInputs() {
        let pushInstant = fixture.instant("2026-09-09T21:00:00Z")
        let pushHour = utc.component(.hour, from: pushInstant)
        let questSet = [
            fixture.quest(.q2, progress: 1, completed: true),
            fixture.quest(.q7, progress: 2, completed: false),
            fixture.quest(.q6, progress: 0, completed: false),
        ]
        let dayRecord = storeFixture.day(
            dayKey: DayKey.make(from: pushInstant, calendar: utc),
            feed: 1, play: 0, care: 0, pat: 2,
            questSet: questSet,
            helloAwarded: false,
            familiesUsed: [.feed, .pet, .care],
            bondAwarded: 4
        )
        let state = storeFixture.state(days: [dayRecord], processedIntents: [])
        let display = makeDisplayState(state, at: pushInstant, calendar: utc)
        let result = makeWatchSnapshot(
            state: state,
            display: display,
            questInputs: [], // the DRIFT: not the display's derivation inputs
            watermarkEpoch: fixture.watermarkEpoch,
            sync: SyncState()
        )
        #expect(
            WatchCascade.liveQuestLine(questSet: result.snapshot.questInputs, localHour: pushHour)
                != result.snapshot.display.questLine,
            "drifted inputs must break the provenance agreement (empty set → .allDone ≠ the carried wish)"
        )
    }
}
