# REVIEW-TASK-028-FIX1 — Delta review of fix round 1 (adversarial, §11)

- **Task**: TASK-028 (`.claude/tasks/active/TASK-028-reactions-choreography.md`)
- **Reviewed by**: independent adversarial DELTA reviewer (fresh agent, Jupiter), per CLAUDE.md §10/§11/§33 — not primed; every fix attacked, not trusted
- **Date**: 2026-09-10
- **Branch / HEAD**: `feature/EPIC-006-character` @ `283310a` — changeset UNCOMMITTED (as required pre-commit)
- **Scope**: fix-round delta only — the 8 disposition items from REVIEW-TASK-028 (verdict CHANGES_REQUIRED: 2 MAJOR / 3 MINOR / 7 NOTE), plus non-regression of the original review's passings, frozen-module and hygiene discipline.
- **Method**: original findings re-read from `REVIEW-TASK-028.md`; disposition + tightened queue law read from the task file's Reviewer Findings section (treated as CLAIMS to disprove); every cited location independently inspected in source; 15 NEW adversarial probe tests written and executed against the fold (temporary file, deleted after); 1 sanctioned mutation bite with sha256-proven restore; full suite reproduced twice.

## Verdict: APPROVED_WITH_MINOR_NOTES

All 8 disposition items are remediated at the BEHAVIOR level — each survived independent adversarial streams written from the findings' original repro recipes, not from the fixer's citations. Exactly-once reporting, twin-equality determinism, the hide/show epoch matrix, and the play bound all held under a combined storm that now exercises the queue, the lost-boundary resolution, and glance-up rides together. Two new NOTE-level (non-blocking) residuals are recorded below; neither is a regression introduced by this fix round.

**New findings**: 0 MAJOR · 0 MINOR · 2 NOTE.

---

## Per-item remediation verdicts

| Item | Verdict | Independent evidence |
|---|---|---|
| MAJOR-1 (blanketAdjust cancelled the settle) | **REMEDIATED** | Routing now lists `.blanketAdjust` in the L3 case block (`MomoReactionDirector.swift:125–133`); no path from it reaches `enter()`/`startL2Clip`. Probe A1 (plan settling 1.0 → blanketAdjust 2.0 → fold 9.0): zero `handshakeCancelled(.settle)`, nudge reports once at 3.5, `settleFinished` exactly once at 4.0. Probe A1b: blanketAdjust during PLAY also never cancels the round (no `cancelled:play`, round still lands 19.4). `rule2L2Crossfade` re-pinned on the only remaining L2 pair (eating→sleepyNibbles, `MomoReactionDirectorTests.swift:74–95`); `settleSurvivesBlanketAdjust` pins the additive read (`MomoHandshakeTests.swift:95–121`). The genuine L2-cancel law stayed intact (`settleCancelledByNewerL2` green). |
| MAJOR-2 + NOTE-7 (glance-up over-scope) | **REMEDIATED** | Gate is `displayState.activity == .eating && isTouchFamily(key)` (`:165`); `isTouchFamily` = `tempoScaled` (`:218–220`) — compared against the clip TABLE, not the comment: exactly the 10 touch keys (tap·head/belly, tap, doubleTap, longPress·head/belly/zone-less, stroke·head/belly/zone-less), stir excluded; `tempoScoping` pins the same 10-key set. Probes A2a (mid-meal politelyFull renders the authored 1.2 s sigh — aperture 0.7 / cheek 0.88 at peak, reports 3.2, meal reports 4.2, zero glance slots), A2b (all 7 one-shot touch keys glance-up with the meal undisturbed — each glance reports exactly once at its own 0.5 s end), A2c (two glances + meal: three reports, each exactly once). `glanceUpLivesOnActivityNotClip` pins the activity-keyed window. |
| MINOR-1 (dead tail on the belly release) | **REMEDIATED** | `pressReleaseSeconds` on the spec (belly 0.45 `MomoReactionClips.swift:157`, head 0.6 `:149`, nil elsewhere — asserted `MomoReactionClipTests.swift:124–131`); `applyTouchEnded` resolves end = boundary + release × tempo (`MomoReactionDirector.swift:535–548`); the rock rides `duration` = 0.9 × tempo independently (`ClipMotion:74–85`); min-clamp gone. Probe A5a: head press at drowsy ×1.4 — end 3.84, spring settled at 3.83, report exactly once at 3.84. Probe A5b: the rock's zero-crossings MOVE with tempo (relaxed zero at elapsed 0.9, drowsy at 1.26; drowsy shows ≥ 0.5° at the relaxed zero instant) — tempo is no longer vestigial. `bellyPressReleaseMeetsSlotEnd` pins both tempos end-to-end. |
| MINOR-2 (zombie press) | **REMEDIATED** | `pressLostBoundarySeconds = 5.0` (`:44`, AUTHORED, the strokeCycleCap analog); `pruneCompleteLayers` resolves hold 5.0 + tempo-scaled release (`:671–687`), then the normal release/report/GC path runs. Probes A4a (head press drowsy, no boundary: hold stamps 5.0, end 6.94 = 1.1 + 5.0 + 0.6×1.4, report exactly once, slot GC'd), A4b (a legit 4 s hold is UNAFFECTED — real boundary wins, end 5.55; a boundary at EXACTLY the cap resolves once, 6.55, no double), A4c (a LATE boundary after cap-resolution does not re-resolve — one report, 6.55). `pressLostBoundaryResolves` pins the end-to-end stream; the mutation bite below proved this pin has teeth. |
| MINOR-3 (vacuous queue) | **REMEDIATED** | Real machinery: one-shot over a visible one-shot queues (`:195–199`); `queueReaction` chains start = predecessor's end, ≤ 2 pending, drop-oldest ABSORBED with survivors re-chained to the vacated start (`:234–273`); `MomoReactionSlot.start` is var solely for the re-chain (`MomoReactionState.swift:96–98`); L2/hide/press/stroke arrivals clear pending silently (`supersedeVisible` + `preemptVisibleReactions`); coalescer runs BEFORE the queue branch (code order `:171–184` vs `:195` — identical keys never queue). Probes A3a (independent 4-arrival stream: chain tiles 1.0–1.6–3.2–4.4 with no dead air and no overlap across 60 sampled instants; the dropped arrival yields ZERO reports; rendered runs report exactly once each), A3b (pending == bound exactly, then hide across the epoch: pending never reports, slots emptied, identity overlay on return), A3c (a one-shot arriving EXACTLY at a pending slot's start instant: no duplicate reports, chain order and contiguity preserved). `queueFormationAndBound` / `queueClearedByL2` / `queueClearedByLiveInput` add the contract's required teeth; the storm now drives pending to 2 and pins `pendingReactionCount ≤ 2` at 400 sampled instants. |
| NOTE-1 (+ nibble citation) | **REMEDIATED** | `longPress` relabeled AUTHORED (`MomoReactionClips.swift:165`, zone-less form, §6.4 pat-only noted) and moved into the ClipTests AUTHORED set (`MomoReactionClipTests.swift:200`). The nibble authority cites "05 §4.5 … I-2 shortened eating animation (02-mvp-prd §4)" (`MomoReactionClips.swift:242`, `MomoReactionClipMotion.swift:392–393`) — BOTH citations verified to EXIST: 05-technical-architecture.md §4.5 (the 30–90 min recently-fed nibble row, I-2 owner-confirmed) and 02-mvp-prd.md §4 (the amended FR-6 refinement). No false authority remains on the touched rows. |
| NOTE-2 (mixed-speed L2→L2 handoff) | **REMEDIATED** | `replaceStateLayer` enters at `l2CrossfadeSeconds` (`:364`) — identical to `enter()`; the overlay's outgoing half already faded over `l2CrossfadeSeconds` (`MomoReactionOverlay.swift:20–23`). Both halves of the settle-displaces-play handoff now ride the §7.1 state band; `settleDisplacesPlayThroughCrossfade` pins entry-invisible → half-in at the midpoint → settled past the band. |
| NOTE-3 (stroke same-touch edge) | **REMEDIATED** | `isUnboundaryed(since:)` requires no `touchEnded` AND no `touchBegan` since the running stroke's start (`:224–227`); the director tracks `lastTouchBegan` (`:57`, `:94`). `strokeBetweenBoundariesIsFresh` pins the exact 8.05/8.06/8.07/8.1 edge; the ordinary deepening pins (`strokeDeepening`) stayed green. |

Record-only items confirmed as recorded in the task file: NOTE-4 (cancel-then-late-finish absorbed by `HandshakeMachine`), NOTE-5 (drowsy 14.4 s contract-mandated shorter variant, doc tension recorded), NOTE-6 (at-rest sparkles pre-existing, routed to the doc-clarification backlog).

---

## Findings (new, this delta round)

### MAJOR

None.

### MINOR

None.

### NOTE

1. **Naked lost-boundary press still holds the L1 feedback indefinitely** (`MomoReactionOverlay.swift:131–144` + `MomoDirectorState.press`). `MomoPressState` is cleared only by `touchEnded`, `appHidden`, or faded by a reaction arrival. A `touchBegan` with a LOST boundary and NO reaction arrival therefore renders the 2° ear-lift / −4 pupil presence forever — the same system-gesture-cancellation hazard MINOR-2 fixed for press-shaped SLOTS, but on the L1 tracker, which the disposition's letter did not cover. Round-1 behavior, unchanged by this fix round (not a delta regression); cosmetic (2° / 4 units), bounded in practice by hide or any reaction arrival. Suggest riding the eventual `touchesCancelled` seam or a polish task; not blocking.
2. **`queueReaction`'s drop-oldest lookup is not supersede-filtered** (`MomoReactionDirector.swift:241–243`). `firstIndex(where: { $0.start == oldest.start })` matches any slot with that start, including a lingering CUT slot (cut slots are GC-retained until their ORIGINAL end passes — `:767–776`). A collision requires an exact-double coincidence: a cut slot's original fold-time start equaling a later pending slot's chain start. Verified consequence if it ever hits: the already-reported cut shell is removed instead of the oldest pending, the recount keeps pending at 2 (bound holds), the chain stays contiguous, and the next arrival's drop self-heals (the shell is gone, the real oldest is then matched). Benign today; hardening is a one-token change (`supersededAt == nil` in the predicate). Not blocking.

### Adversarial probes (temporary file `DeltaProbeTask028Fix1.swift`, deleted after the run)

A1/A1b blanketAdjust additive over settle and play · A2a–c glance-up scoping incl. per-key report exactly-once · A3a independent queue stream with drop-oldest arithmetic (the implementation's chain arithmetic survived; the REVIEWER's first expectation 4.2 vs the correct 4.4 did not — corrected, documented above) · A3b pending-at-bound across a hide · A3c exact-boundary arrival · A4a–c lost-boundary incl. exact-cap and late-boundary edges · A5a/b release-meets-slot-end at drowsy + rock tempo zero-crossings · A6 combined storm (queue + lost-boundary + hide/show + coalescing + glance-up + moment + play) with storm-wide (identity, instant) uniqueness over every report kind and twin-equality · A7 twin equality over queue+epoch paths. 15/15 passed.

### Non-regression on the original review's passings

- Exactly-once: held in A6's combined storm (no duplicate (identity, instant) pair across reactionFinished / playRoundFinished / handshakeCancelled(.settle)/(.play) / settleFinished / wakeFinished / momentFinished) and in the suite's storm (now queue-exercising).
- Twin-equality determinism: A6/A7 byte-equal states + report logs on streams exercising every new path; `MomoReactionTwinTests` green in both full runs.
- Hide/show epoch matrix: A3b (queued pending across a hide) + the suite's matrix green.
- Coalescer-before-queue ordering: code-verified; `rule3Classes` (unchanged) green.
- Play pacer ≤ 30 s: `roundBound` 22.4 + the adversarial pacer streams green; untouched by the round.
- Digit pins, budgets, pupil clamp, props, moments: all green in both full runs.

### Sanctioned mutation bite (exactly 1; sha256-proven)

| | |
|---|---|
| Bite | `pressLostBoundarySeconds` 5.0 → 5.5 (`MomoReactionDirector.swift:44`) — the lost-boundary stamp behind the MINOR-2 fix |
| Named test that failed | `pressLostBoundaryResolves` — **fatal error: "Unexpectedly found nil while unwrapping an Optional value"** (`MomoReactionCompositeTests.swift:104`): with cap 5.5 the press is unresolved (hold nil) at the test's 6.5 fold, exactly as the pin predicts |
| sha256 pre-bite | `ab120f6cdf140dd2d6a3961c9add46ee70dac17855ce65c5ccad52a2d73fdd2b` |
| sha256 post-restore | `ab120f6cdf140dd2d6a3961c9add46ee70dac17855ce65c5ccad52a2d73fdd2b` — byte-identical |

### Hygiene + discipline

- `git diff --stat Sources/MomoCore Sources/MomoKit` → **empty** (frozen modules untouched through the fix round and this review).
- No `Date(`/`UUID()`/`Timer`/dispatch in any new reaction source (grepped); determinism scanners green.
- Line budgets: largest source `MomoReactionDirector.swift` **792** ≤ 800; probe and temp files removed; working tree contains only the implementation's changeset + task/status docs.
- No leftover `TODO/FIXME/HACK` introduced by the round (grepped the touched files).

### Commands + counts

- `swift test` (run 1, before probes): **789 tests / 79 suites passed**, exit 0, 0 warnings (grep over the full-compile output; only the pre-existing tolerated `ld` search-path diagnostic family absent here).
- `swift test --filter DeltaProbeTask028Fix1`: 15/15 passed (after correcting the reviewer's own arithmetic in A3a — implementation behavior was correct).
- Bite run `swift test --filter pressLostBoundaryResolves`: failed as predicted (fatal nil unwrap).
- `swift test` (run 2, after restore + probe deletion): **789 tests / 79 suites passed**, exit 0 — matches the fixer's claimed 779 → 789 (+10 pins, same suite count).

### What held up under attack (credit where due)

The queue's chain arithmetic (drop-oldest + survivor re-chain) is exact — it survived an adversarial recomputation the reviewer got wrong on the first pass; the release-meets-slot-end law holds at both tempos with the time-warp derivation (the spring's settle lands on the slot end to < 1e-3); the glance-up's per-key report accounting (each 0.5 s beat reports exactly once, meal untouched) is cleaner than the disposition demanded; and the lost-boundary path composes cap-resolution, late boundaries, and GC with no double-emission anywhere.

## Recommended disposition

APPROVED_WITH_MINOR_NOTES — the task may proceed to commit and push per §12/§13. Carry the two NOTEs forward: NOTE-1 (L1 press tracker on a naked lost boundary) → ride the touch-cancel seam or a polish task; NOTE-2 (drop-oldest supersede filter) → one-token hardening, may ride any future touch of `queueReaction` or be closed as accepted (self-healing, bound held).
