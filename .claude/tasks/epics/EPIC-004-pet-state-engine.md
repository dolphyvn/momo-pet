# EPIC-004 — Pet State Engine

## Objective
Implement the deterministic pure engine per 05 §4 (ADR-004): one evaluation entry point `reduce(state, event, clock, rng)`, event-driven time-fold catch-up (never a timer), interaction semantics implementing the PRD §4 matrix, the bond ledger capped by construction, the quest generator with by-construction constraints + the §5.5 Watch cascade, and the read-model derivations — so the whole product's dynamics are executable and headlessly provable (domain before UI).

## User / Product Value
No UI yet by design. This epic makes Momo *alive headlessly*: every PRD behavior — mood attractor, energy day arc, satiety, bond pacing, quests, greetings — becomes a testable fact. EPIC-005 (store), EPIC-006 (character), EPIC-007 (Home) all consume this engine.

## Scope
- Engine core per 05 §4.1/§4.10 (TASK-014): `EngineState`/`EngineEvent`/`EngineOutcome`, pure `reduce`, `EngineClock`, repo-owned SplitMix64-class seeded RNG, SHA-256-seeded day-stable seeds (`choreography`/`copy`/`quest` salts).
- Time-fold catch-up + wakefulness machine + handshakes (TASK-015): §4.3 fold rules (decline −1.5/h waking; night restore to 85, wake ≥ 75; attractor τ=3 h target 60; coupling target 35 floor 25; dayKey-keyed once-only rollover; harmless absence), §4.7 wakefulness states + settle/wake/play handshakes (INV-8).
- Interaction semantics + satiety + repetition (TASK-016): PRD §4 response matrix; counting rules; satiety 90-min window (0–30 refusal, 30–90 nibble ×0.25 owner-confirmed I-2); same-family repetition curve 1.0/0.6/0.25/~0; mood ceiling 92.
- Bond ledger (TASK-017): hello +8 / quest +4 / variety +6 / cap-clamp +20 (§4.6, FR-10, INV-3/5/7).
- Quest generator + Watch cascade (TASK-018): §4.8 by-construction constraints (consecutive-pair ban, Q6 3-day window, non-empty candidates), window checks, amended cascade rule 1 ("≥ 20:00 ∨ < 07:00").
- Read-models (TASK-019): `makeDisplayState` + `makeCharacterDisplayState` + copy-key selection (§4.9/§4.11, INV-11, OBS-1/2).
- Engine test suites (TASK-020): full §10.3 domain matrix as named tests, meta-determinism property, MomoCore ≥ 90 % line coverage floor (05 §10.2).

## Non-Goals
No persistence/sync (EPIC-005); no character rendering (EPIC-006); no UI, no app-layer wiring (tick triggers, scheduling — EPIC-007); no HealthKit/notifications (Phase 2); no new external dependencies (D-R6); MomoCore stays Foundation-only (D-R1).

## Dependencies
- EPIC-003 complete (domain model + `Thresholds` on `main`).

## Tasks
Branch: `feature/EPIC-004-engine` (from `main` @ `bf2dcb7`).

| TASK | Title | Size | Depends on |
|---|---|---|---|
| TASK-014 | Engine core: reduce, EngineClock, seeded RNG, day-stable seeds (05 §4.1, §4.10) | M | TASK-012 |
| TASK-015 | Time-fold catch-up + wakefulness machine + handshakes (05 §4.2–4.3, §4.7) | L | TASK-014 |
| TASK-016 | Interaction semantics + satiety + repetition curve (05 §4.4–4.5) | L | TASK-015 |
| TASK-017 | Bond ledger (05 §4.6; FR-10) | M | TASK-016 |
| TASK-018 | Quest generator + Watch cascade (05 §4.8; FR-14–16) | M | TASK-014 |
| TASK-019 | DisplayState + CharacterDisplayState read-models + copy-key selection (05 §4.9, §4.11) | M | TASK-015, TASK-017, TASK-018 |
| TASK-020 | §10.3 domain matrix + property tests + coverage floor | L | TASK-014…019 |

## Acceptance Criteria
1. The entire PRD §3–§5 dynamic behavior is executable via pure `reduce` — no timers, no I/O, no ambient clock/randomness in the engine core (ADR-004).
2. Full §10.3 domain matrix green as named tests; meta-determinism property (seeded random interaction sequences replay identically) green.
3. MomoCore ≥ 90 % line coverage recorded (05 §10.2 floor; TASK-020).
4. Engine simulatable for all §32 domain edge cases (DST, timezone change, midnight rollover ×1, backward clock, absence, handshakes).
5. Every PRD number flows from `Thresholds.swift` / §4 starting values — no duplicated literals.

## Test Requirements
- Per-task focused tests (each task file lists them); TASK-020 closes the matrix + coverage floor.
- `swift test` green throughout; D-R1 + banned-vocabulary standing scans green in-suite.
- Determinism properties: identical (state, event, clock, seed) ⇒ identical outcome (FR-13 AC-3).

## Definition of Done
All seven tasks DONE per CLAUDE.md §18 (implemented → independently reviewed → findings addressed → atomic TASK-ID commits on `feature/EPIC-004-engine` → pushed). §10.3 matrix green; coverage floor recorded. Epic branch merged to `main` (direct merge per CLAUDE.md §14 owner rule). `.claude/tasks/status.md` updated.

## Status
IN_PROGRESS (0/7) — branch cut 2026-09-08 from `main` @ `bf2dcb7`; TASK-014/015 task files materialized; TASK-014 dispatching.
