# TASK-017 — Bond ledger (05 §4.6; FR-10)

## Parent Epic
EPIC-004 — Pet State Engine (task 4 of 7).

## Objective
Make the bond model executable: the enumerated daily award events (hello +8, quest +4, variety +6) applied through clamp-at-award under the +20 daily cap, by construction (INV-5); bond monotonic everywhere (INV-3) with the 1000 plateau; the family ledger (`familiesUsed`) maintained by the same events that count; and the one-time stage-crossing moment under the `highestCelebratedStage` once-guard (`momentRequest(.bondStageReached)`, UX-10).

## Context
- Normative: **05 §4.6** (Bond ledger — FR-10; cap by construction) — read it whole; it is short and every clause binds. **PRD §3.3** (stage thresholds + earning table + legibility rules + pacing intent), **FR-10 AC-1…5**, **INV-3/INV-5/INV-7** (05 §5 invariants table), **UX-6** (hello device-agnostic, never window-gated; 03 §Appendix "hello idempotency" row: shared trigger with Q1, different windows), **G1/G2** (PRD §4 guarantees), delivery plan §3 TASK-017 row (scope + named tests).
- Domain already in place (TASK-012): `PetState.bond` (0…1000, validated), `DayRecord.helloAwarded` / `DayRecord.bondAwarded` / `DayRecord.familiesUsed: Set<QuestFamily>`, `EngineState.highestCelebratedStage`, `BondStage` + `makeBondStage(_)` (stages 150/400/750 first-value form), `QuestFamily{greet,feed,play,care,pet}` with the doc comment fixing the variety trio as **feed/play/care**, `CharacterMoment.bondStageReached(BondStage)` in the moment vocabulary (05 §4.1: `moments` = greeting / questCompleted / bondStageReached).
- TASK-016 state of the world: `familiesUsed`, `helloAwarded`, `bondAwarded`, and `pet.bond` are **never written** anywhere in the engine (reviewer-verified pass-throughs); `moments` is `[]` on every path. This task starts writing them. The interaction counters and their events are already landed: feed counts on every intent (I-1), play counts ONLY at the unified cease (`InteractionEffects.applyPlayRoundEffects` via `HandshakeMachine.completePlayRound`), care counts at settle-authorization / blanket-adjust / nap-acceptance, pats always.
- The determinism tuple is (state, event, clock, calendar, seed); everything here is pure derivation off it.

## Requirements
1. **Constants home.** New `BondRules` (the §4.6 constants home, `FoldRules`/`InteractionRules` discipline): `helloBondDelta = 8`, `questBondDelta = 4`, `varietyBondDelta = 6`, `dailyBondCap = 20` — each labeled PRD-normative (PRD §3.3 earning table). No raw award literals anywhere else (anti-echo: pinned tests may use literals; the pin files are the sanctioned echo).
2. **Clamp-at-award is the only award mechanism.** One function applies every award: `applied = min(event, dailyBondCap − day.bondAwarded, 1000 − pet.bond)`; then `pet.bond += applied`, `day.bondAwarded += applied`. `applied ≥ 0` by construction (both bounds are monotone). This single formula makes INV-5 (per-dayKey sum ≤ +20), INV-3 (monotonic), and the 1000 plateau (PRD §3.3 "a plateau, not an end") all structural. The day ledger records what was ACTUALLY applied (so the invariant is exact, not nominal).
3. **Hello (INV-7, UX-6).** The first touch (pat) intent attributed to a local dayKey awards +8 once: gated on `!day.helloAwarded`, which the award sets. Device-agnostic (the ledger never reads `intent.source` — pin a `.watch`-sourced first pat awarding identically), never window-gated (a 14:00 first touch after Q1's expiry still awards +8; a 23:50 first touch likewise). The hello rides the existing pat path (`InteractionSemantics.applyPat` → the same event that increments `patCount`); it must not disturb the pat's mood/repetition semantics from TASK-016.
4. **Quest +4 award path (mechanism only — detection is TASK-018's).** The ledger exposes the quest-completed award (callable per completion) but this task implements NO quest ticking, NO window checks, NO completion detection, NO `questCompleted` moments (all §4.8 / TASK-018). Tests drive the award path directly. Cap interplay pins from PRD §3.3/05 §4.6's own arithmetic: a 3-quest day reaches 20 as 8+4+4+4 (variety adds 0); a 2-quest varied day reaches 20 as 8+4+4+4-remaining → 8+8+4 with the +6 truncated to 4 — both sequences pinned exactly.
5. **Variety bonus (+6, feed/play/care trio).** `familiesUsed` records the trio on exactly the events that count (mirrors I-1): feed → every feed intent; play → the unified cease only; care → settle-authorization, blanket-adjust, nap-acceptance. The moment the set becomes all three, the SAME event applies the +6 award ("fired at the moment all three families are used") — set membership makes it once-per-day by construction (a later interaction cannot re-fire). Out-of-window tuck-in and declined nap start no family use (no care count ⇒ no family use).
6. **Expired-dayKey disposition.** An intent whose dayKey has no ledger entry keeps its current-state effects (TASK-016 convention) but earns NO bond: the hello's idempotency flag and the cap context both live on the ledger, and an un-ledgered award would be un-idempotent and un-clampable (INV-5 must stay verifiable). Recorded interpretation — no retroactive `DayRecord` is created (engine stays append-only).
7. **Stage-crossing moment, exactly once (FR-10 AC-4, UX-10).** After any event's state mutation, `reduce` reconciles: if `makeBondStage(pet.bond)` is above `highestCelebratedStage`, the outcome carries `momentRequest(.bondStageReached(newStage))` — appended to `moments` — and `highestCelebratedStage` advances to it. The reconciliation is state-based and runs on every event path (a hello-carrying pat can cross; crossings while the app is closed surface at the next evaluation of any kind — UX-10's deferral). The guard only advances WITH the emission, so each crossing emits exactly once ever. Fresh states (bond 0, guard `.newFriends`) emit nothing.
8. **Bond is read-only everywhere else.** No engine path lowers bond; pats beyond the day's first move nothing (G2/FR-10 AC-3); play/feed/pat mood or energy arithmetic never touches bond; TASK-015/016 pins keep passing unchanged except where this contract names the touch point.
9. **`momentFinished` stays a tolerated no-op** (presentation bookkeeping — already true in `HandshakeMachine`; don't change it).
10. **Determinism.** The ledger draws NO randomness and reads NO clock — the hello/variety detection is a pure function of (state, intent/instant already folded). Whole-state twin equality must continue to hold for identical tuples, now including bond/family fields.

## Files / Areas Likely Affected
- New: `Sources/MomoCore/BondRules.swift`, `Sources/MomoCore/BondLedger.swift`.
- Modified: `Sources/MomoCore/InteractionSemantics.swift` (pat path hello; family-use writes), `Sources/MomoCore/InteractionEffects.swift` (day-updating helper reuse; cease-side family write), `Sources/MomoCore/HandshakeMachine.swift` (cease-side variety composition, if kept there), `Sources/MomoCore/Reduce.swift` (stage reconciliation on every path; moments flow-through).
- Tests: new `BondLedgerTests` (+ property suite), extensions to `EngineReduceTests`; `InteractionFixture` gains whatever state-bending it needs (e.g. a bond preset — it already takes `bond:`).
- Not touched: `TimeFold.swift` (folds never move bond), `CharacterInterface.swift`, scanners, package layout.

## Dependencies
- TASK-016 (interactions/cease/counters) — DONE (`f61093a`). Depends on nothing else in flight.

## Constraints
- MomoCore stays Foundation-only (D-R1); purity scans + import whitelist green with NO new exemptions; zero stored `var`; immutability via `EngineState.with(...)` copies.
- TASK-015/016 pins may be superseded ONLY where this contract names the supersession (it names none — existing pins must keep passing unmodified).
- Scope control (§22/§24): no quest ticking/detection (TASK-018), no greeting moments (TASK-019+), no Watch-specific code (the engine is source-agnostic), no copy keys, no read-models.
- Anti-echo: award constants ONLY in `BondRules`; `Thresholds` keeps the stage thresholds and the 0…1000 range — do not duplicate them.

## Acceptance Criteria
- AC-1 (FR-10 AC-1 / INV-5): no randomized sequence of events on one local dayKey moves bond more than +20; `bondAwarded` equals the sum of applied awards; property test over randomized sequences (seeded, replayable).
- AC-2 (FR-10 AC-2 / INV-3): no engine action, absence duration, or replay decreases bond — property over randomized sequences spanning day rollovers.
- AC-3 (FR-10 AC-3 / G2): 1000 same-day pats move bond by exactly the day's hello (+8 once, then zero); with the hello already awarded, 1000 pats move nothing.
- AC-4 (FR-10 AC-4 / UX-10): each stage crossing emits `.bondStageReached` exactly once, including crossings detected at the next evaluation after the fact; label/descriptor derivation stays `makeBondStage` (no new threshold knowledge).
- AC-5 (FR-10 AC-5 / FR-13): stage transitions deterministic under injected clock + seeded RNG (whole-state twin equality incl. bond fields).
- AC-6 (UX-6 / INV-7): hello idempotent per dayKey, device-agnostic, never window-gated (14:00 / 23:50 first touches award; second touch same day does not).
- AC-7: PRD §4.6's two cap arithmetics (3-quest day; 2-quest varied day with +6 truncated to 4) land exactly; variety fires once at the trio-completing event and never again that day.

## Required Tests
Named per delivery plan: cap-by-construction property over randomized sequences; 1000-pats-zero-bond; hello idempotency incl. post-12:00 first touch. Plus: hello device-agnostic (`.watch` source), variety trio per-family triggers (feed intent / play cease / care authorize·blanket·nap), variety once-only + not re-fired, PRD arithmetic pins (both cap sequences), plateau at 1000 (award truncates; ledger exact), stage-crossing once-guard (incl. crossing-while-closed surfacing at next evaluation, and a pat-hello crossing), expired-dayKey no-award, monotonicity property, out-of-window tuck-in / declined nap start no family use, fresh-state no spurious moment.

## Review Requirements
Fresh independent adversarial review agent (§10/§33) after implementation, per the standing cycle; review record to `.claude/tasks/reviews/REVIEW-TASK-017.md`; the reviewer independently re-derives the cap arithmetic and probes the once-guards.

## Git Requirements
- Branch: `feature/EPIC-004-engine` (current). Implementation agent commits NOTHING.
- Final commit (orchestrator, after review + disposition): `feat(engine): TASK-017 bond ledger, variety bonus, stage moments` — atomic (sources + tests + task file + review file), TASK-ID in the message, then push (§12/§13).

## Status
READY (contract materialized 2026-09-09 from 05 §4.6, PRD §3.3/FR-10, INV-3/5/7, UX-6/UX-10, delivery plan §3; implementation agent dispatch pending).

## Implementation Notes
- (filled by the implementing agent)

## Reviewer Findings
- (orchestrator records)

## Completion Evidence
- (commit hash + push, by orchestrator)
