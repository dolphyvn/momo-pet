import Testing
import Foundation
@testable import MomoCore

/// The §5.5 Watch cascade as engine decisions (TASK-018 Required Test 7;
/// AC-5): the six rules IN ORDER with the owner-amended rule 1 (OPEN-1,
/// 2026-09-08), first match wins — pinned as an exhaustive table over the
/// precedence edges, the in-set scoping of rules 3–4 (recorded reading 2),
/// and rule 5's in-set gating. The NAMED test ("a 02:00 tuck-in with Q1 done
/// selects Q6") lives with the raw-literal pins.
///
/// House discipline: window hours come from `Thresholds.Quest` (raw spec
/// literals live in `QuestGenerationPinnedTests`); the remaining hours are
/// scenario values, not spec constants.
@Suite("Watch cascade — §5.5's six rules in order (TASK-018)")
struct QuestCascadeTests {

    private static func quest(_ id: QuestID, progress: Int = 0, completed: Bool = false) -> QuestProgress {
        QuestProgress(questID: id, progress: progress, completed: completed)!
    }

    /// Every catalog quest complete (the rule-6 shape, built from the
    /// catalog so a target change cannot silently break the fixture).
    private static func allCompleteSet() -> [QuestProgress] {
        QuestCatalog.all.map { quest($0.id, progress: $0.target, completed: true) }
    }

    @Test(
        "the six-rule table, first match wins",
        arguments: [
            // (description, set, hour, expected)
            ("rule 1 beats rule 2 in the early-morning tail with Q1 still open",
             [QuestProgress]([quest(.q1), quest(.q2), quest(.q6)]),
             Thresholds.Quest.q6WindowEndHour - 1, QuestGeneration.QuestLine.wish(.q6)),
            ("rule 1 at the window's evening edge",
             [QuestProgress]([quest(.q1), quest(.q2), quest(.q6)]),
             Thresholds.Quest.q6WindowStartHour, QuestGeneration.QuestLine.wish(.q6)),
            ("rule 1 needs the window: the hour before the evening edge falls through to rule 3's feed wish (the anchor's window closed at noon)",
             [QuestProgress]([quest(.q1), quest(.q2), quest(.q6)]),
             Thresholds.Quest.q6WindowStartHour - 1, QuestGeneration.QuestLine.wish(.q2)),
            ("rule 1 needs the window: the tail's close falls through at its first closed hour",
             [QuestProgress]([quest(.q1), quest(.q2), quest(.q6)]),
             Thresholds.Quest.q6WindowEndHour, QuestGeneration.QuestLine.wish(.q1)),
            ("rule 1 needs incompleteness: a done Q6 at night falls through to rule 3's feed wish (the anchor's window closed at noon)",
             [QuestProgress]([quest(.q1), quest(.q2), quest(.q6, progress: 1, completed: true)]),
             Thresholds.Quest.q6WindowStartHour + 1, QuestGeneration.QuestLine.wish(.q2)),
            ("rule 2: the anchor before its close, no Q6 in set",
             [QuestProgress]([quest(.q1), quest(.q2), quest(.q4)]),
             2, QuestGeneration.QuestLine.wish(.q1)),
            ("rule 2's boundary: the last open hour",
             [QuestProgress]([quest(.q1), quest(.q2), quest(.q4)]),
             Thresholds.Quest.q1WindowClosesAtHour - 1, QuestGeneration.QuestLine.wish(.q1)),
            ("rule 2's close falls through to rule 3",
             [QuestProgress]([quest(.q1), quest(.q2), quest(.q4)]),
             Thresholds.Quest.q1WindowClosesAtHour, QuestGeneration.QuestLine.wish(.q2)),
            ("rule 3 scans in-set only: an out-of-set Q2 is never surfaced, the in-set Q3 is",
             [QuestProgress]([quest(.q1, progress: 1, completed: true), quest(.q3), quest(.q6)]),
             Thresholds.Quest.q1WindowClosesAtHour, QuestGeneration.QuestLine.wish(.q3)),
            ("rule 3's catalog order: the incomplete Q3 follows the done Q2",
             [QuestProgress]([quest(.q1, progress: 1, completed: true), quest(.q2, progress: 1, completed: true), quest(.q3, progress: 1)]),
             13, QuestGeneration.QuestLine.wish(.q3)),
            ("rule 3's progress holds the wish until target: Q3 at 1/2 stays the feed wish",
             [QuestProgress]([quest(.q1, progress: 1, completed: true), quest(.q3, progress: 1), quest(.q4)]),
             14, QuestGeneration.QuestLine.wish(.q3)),
            ("rule 4: the play family, in-set (an in-progress Q4 precedes the open Q5)",
             [QuestProgress]([quest(.q1, progress: 1, completed: true), quest(.q4, progress: 1), quest(.q5)]),
             13, QuestGeneration.QuestLine.wish(.q4)),
            ("rule 4's order: a done Q4 promotes Q5; no feed quest is in set",
             [QuestProgress]([quest(.q1, progress: 1, completed: true), quest(.q4, progress: 2, completed: true), quest(.q5)]),
             13, QuestGeneration.QuestLine.wish(.q5)),
            ("rule 5: the pet quest, in-set and incomplete",
             [QuestProgress]([quest(.q1, progress: 1, completed: true), quest(.q2, progress: 1, completed: true), quest(.q7, progress: 2)]),
             13, QuestGeneration.QuestLine.wish(.q7)),
            ("rule 5's in-set gating: an out-of-set Q7 never beats the all-done state",
             [QuestProgress]([quest(.q1, progress: 1, completed: true), quest(.q2, progress: 1, completed: true), quest(.q6, progress: 1, completed: true)]),
             13, QuestGeneration.QuestLine.allDone),
            ("rule 6: every quest complete — all done, midday",
             allCompleteSet(), 13, QuestGeneration.QuestLine.allDone),
            ("rule 6: every quest complete — all done, late evening",
             allCompleteSet(), 23, QuestGeneration.QuestLine.allDone),
        ]
    )
    func sixRuleTable(
        _ description: String,
        questSet: [QuestProgress],
        localHour: Int,
        expected: QuestGeneration.QuestLine
    ) {
        #expect(QuestGeneration.cascade(questSet: questSet, localHour: localHour) == expected, Comment(rawValue: description))
    }

    @Test("twin determinism: identical (set, hour) cascade to the identical line", arguments: [0, 2, 9, 12, 19, 20, 23])
    func cascadeTwins(localHour: Int) {
        let set = [Self.quest(.q1), Self.quest(.q3, progress: 1), Self.quest(.q6)]
        let a = QuestGeneration.cascade(questSet: set, localHour: localHour)
        let b = QuestGeneration.cascade(questSet: set, localHour: localHour)
        #expect(a == b)
    }

    @Test("the cascade is total over every hour for arbitrary sets (never traps, always a line)")
    func cascadeIsTotalOverEveryHour() {
        let sets: [[QuestProgress]] = [
            [Self.quest(.q1), Self.quest(.q2), Self.quest(.q6)],
            [Self.quest(.q1, progress: 1, completed: true), Self.quest(.q4), Self.quest(.q7, progress: 1)],
            Self.allCompleteSet(),
        ]
        for set in sets {
            for hour in 0...23 {
                _ = QuestGeneration.cascade(questSet: set, localHour: hour)
            }
        }
    }
}
