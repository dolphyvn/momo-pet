# TASK-015 — Time-Fold Catch-up + Wakefulness Machine + Handshakes

## Parent Epic
EPIC-004 — Pet State Engine

## Objective
Implement the engine's relationship with time (05 §4.2–4.3): segment-fold catch-up over waking/night/midnight/nap segments, the dayKey-keyed once-only day rollover, harmless absence, the §4.7 wakefulness state machine, and the settle/wake/play handshakes with idempotent reports — so Momo's state is always correct no matter when the engine next runs, with no timers (ADR-004).

## Context
TASK-014 ships the engine skeleton (`reduce`, `EngineState`, `EngineClock`, seeds) with bookkeeping-only semantics; this task replaces that honesty with real time semantics. Normative sources: 05 §4.2 (tick model/triggers are app-layer — here only the fold inside `reduce`), §4.3 (fold-rule table — numbers normative), §4.7 (wakefulness + handshakes), 04 §9.2 (character-facing handshake contract). PRD anchors: §3.2 energy day (start 85, decline 1–2/h → engine uses −1.5 starting value, ≥ 75 by 07:00), §3.1 attractor 60 τ=3 h, coupling target 35 floor 25, FR-11/D20 (dayKey-keyed reset), FR-12 (absence harmless), INV-8 (wakefulness transitions), FR-4 (morning wake beat). All numbers from `Thresholds.swift`/fold constants — no duplicated PRD literals (single-source rule; new fold constants like τ=3 h and −1.5/h are engine-owned starting values per §4.3 and live once in a constants home).

## Requirements
1. Segment folding (§4.3): decompose elapsed time since `lastEvaluatedAt` into segments (waking hours / night windows 22:00–07:00 / local-midnight boundaries / nap intervals) using the injected calendar; apply each segment's rule once, in order — passive decline −1.5 pts/h waking only; night restore ramping linearly to 85 at 07:00 with wake value clamped ≥ 75; mood attractor `mood += (target − mood) × (1 − e^(−Δt/τ))`, τ = 3 h, target 60 (35 with floor 25 while energy ∈ Drowsy/Exhausted during waking hours); nap restores per PRD care rules where §4.3 defines.
2. Day rollover (FR-11, D20): at local midnight generate the new day's `DayRecord`-keyed state, reset counters/quests — keyed by `dayKey` so exactly once ever (a day is reset once, structurally; backward clock changes re-derive an awarded dayKey and find it present ⇒ no double reset, no double hello).
3. Absence (FR-12, D3/D4): folds apply no penalty — drift targets are calm attractors, bond untouched; absent days get no DayRecord (silently empty); a 7-day absence folds correctly (this is a named test).
4. Night/morning transitions (§4.3 closing paragraph): folding past 22:00 lands `wakefulness = .asleep` directly (no handshake — nothing listening); folding past 07:00 lands `.waking` and the next in-session evaluation emits the waking stretch via handshake.
5. Wakefulness machine (§4.7, INV-8): the legal-transition reduction over the 4 states with the §4.7 diagram as normative; illegal transitions unrepresentable or rejected.
6. Handshakes (§4.7, 04 §9.2): settle/wake/play issue tokens into `pendingHandshake`; `CharacterReport` completes them idempotently (late/duplicate reports tolerated); `handshakeCancelled` clears; interactions during settling/waking decline warm, never queue (ADR-004).
7. Clock edge cases as named tests (§32 matrix): DST fall-back/spring-forward segment arithmetic; timezone change mid-day ⇒ at most one rollover to the new day's key; manual backward clock change ⇒ no double hello/reset.

## Files / Areas Likely Affected
- `Sources/MomoCore/` (fold + wakefulness + handshake engine files; `reduce`'s `.evaluate` path becomes real)
- `Tests/MomoCoreTests/` (fold, rollover, absence, wakefulness, handshake suites)

## Dependencies
- TASK-014 (engine skeleton + clock + seeds).

## Constraints
- Jupiter model, fresh agent, no commit by agent.
- D-R1 (Foundation-only), D-R6 (no deps), purity scan from TASK-014 stays green and extended if new engine files appear.
- Scope control (§22): interaction response matrix/satiety (TASK-016), bond ledger (TASK-017), quests (TASK-018) — record, do not implement.

## Acceptance Criteria
- AC-1: §4.3 fold table implemented with its exact starting values, segment rules in order, and PRD anchors honored; no duplicated literals (fold starting values defined once).
- AC-2: dayKey-keyed once-only rollover proven (midnight ×1 test; backward-clock no-double test).
- AC-3: absence folds harmlessly (7-day absence named test; no penalty anywhere).
- AC-4: wakefulness machine per §4.7 with INV-8 pinned; night-fold lands `.asleep` handshake-free; morning fold lands `.waking` with the waking stretch emitted at the next in-session evaluation.
- AC-5: handshakes idempotent (late/duplicate reports tolerated, `handshakeCancelled` clears, warm declines during settling/waking).
- AC-6: full `swift test` green (TASK-014 baseline + new suites recorded); standing scans green.

## Required Tests
- Fold tests: night onset (22:00), morning wake (07:00), midnight rollover ×1, DST fall-back/spring-forward, timezone change mid-day, backward clock, 7-day absence, wake-value clamp ≥ 75, attractor convergence τ=3 h, coupling 35/floor 25 during waking Drowsy/Exhausted.
- Handshake tests: late report, duplicate report, cancelled handshake, interaction-during-settle warm decline.
- Verbatim `swift test` output recorded.

## Review Requirements
- Fresh reviewer verifies: fold segment decomposition correctness (boundary instants: 22:00, 07:00, midnight, nap edges); once-only rollover structural argument; attractor formula exactness; wakefulness diagram fidelity vs §4.7; handshake idempotency honesty; no TASK-016+ creep. Record in `.claude/tasks/reviews/REVIEW-TASK-015.md`.

## Git Requirements
- Branch: `feature/EPIC-004-engine`
- Commit: `feat(engine): TASK-015 time-fold catch-up, wakefulness machine, handshakes`
- Push to origin after orchestrator commit; record hash in Completion Evidence.

## Status
READY (after TASK-014)

## Implementation Notes
- (agent fills in)

## Reviewer Findings
- (orchestrator records)

## Completion Evidence
- (commit hash + push, by orchestrator)
