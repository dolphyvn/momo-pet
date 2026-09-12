import MomoCore

// MARK: - Watch quest cascade binding (TASK-043 R1; 05-technical-architecture
// §4.8/§4.11)

/// The Watch quest line's ONE binding seam. W1's quest line is the SHARED
/// cascade derivation re-run locally: the iPhone pushes the raw quest inputs
/// (`WatchSnapshot.questInputs`) and the Watch re-derives its own line with
/// ITS local hour through the one `QuestGeneration.cascade` — the same
/// function the push-time builder's `display` derivation runs. Zero
/// Watch-side cascade logic: the Watch consumes the shared derivation, it
/// never re-implements it.
///
/// Why a MomoKit seam at all: the Watch app target is structurally banned
/// from naming engine surfaces in its code (`WatchGlanceScan`'s no-engine
/// census — every derivation the Watch needs arrives as a MomoKit pure
/// function with kit-level tests pinning the binding). This wrapper IS the
/// binding: one passthrough, no logic, so the kit suite can pin
/// `liveQuestLine` ≡ `QuestGeneration.cascade` at the argument level and the
/// provenance property (a built snapshot re-cascaded at its push hour equals
/// its carried `display.questLine`) can never drift.
///
/// **Day semantics (the contract's R1 reading).** The cascade always runs
/// over the CARRIED set under the Watch's local hour. The Watch never
/// synthesizes a day's quest set — no invented quests; the set refreshes
/// only on the next snapshot. (The shared cascade's own totality covers the
/// empty set: it cascades to `.allDone`.)
public enum WatchCascade {

    /// The Watch's live quest line: the shared cascade over the carried
    /// inputs under the caller's local hour — the hour derived from the
    /// Watch app model's INJECTED `wallClock` + `calendar` (`calendar
    /// .component(.hour, from: wallClock.now())`, the `makeDisplayState`
    /// shape; D20 — no ambient reads).
    public static func liveQuestLine(
        questSet: [QuestProgress],
        localHour: Int
    ) -> QuestGeneration.QuestLine {
        QuestGeneration.cascade(questSet: questSet, localHour: localHour)
    }
}
