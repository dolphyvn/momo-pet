# EPIC-004 — Pet State Engine

## Objective
Implement the pure deterministic engine per 05 §4 and ADR-004: a single `reduce(state, event, clock, rng)` entry point with day-stable seeded randomness, time-fold catch-up (waking/night/midnight/nap), the wakefulness machine and handshakes, the full PRD §4 interaction matrix with satiety and repetition curves, the monotonic bond ledger, the quest generator with Watch cascade, and the DisplayState / CharacterDisplayState read-models — proven by the complete 05 §10.3 domain matrix, determinism properties, and the Core ≥ 90 % coverage floor.

## User / Product Value
This epic *is* Momo's behavior: how she wakes, declines a fourth cookie politely, rewards a first hello once per day, keeps her quests fresh at midnight, and never punishes absence. Correctness here is the product promise (Calm × Alive, no guilt) made executable.

## Scope
- Engine core: `EngineState` / `EngineEvent` / `EngineOutcome`; injected `EngineClock` and repo-owned SplitMix64-class RNG; SHA-256 day-stable seeds (choreography/copy/quest salts) — 05 §4.1, §4.10.
- Time-fold segment catch-up (05 §4.2–4.3): decline −1.5/h, night restore to 85 / ≥ 75 by 07:00, attractor τ = 3 h to 60, energy-coupling pull to 35 (floor 25), midnight/dayKey-keyed once-only resets, DST/TZ folds, absence harmlessness (FR-12).
- Wakefulness machine (05 §4.7, INV-8) + settle/wake/play handshakes with idempotent reports and `handshakeCancelled`.
- Interaction semantics (05 §4.4–4.5): PRD §4 response matrix; counting rules (feed always — incl. refusal/nibble per interpretation I-1; play on round completion only; pats always); satiety 90 min three phases (0–30 `.full` zero effects / 30–90 `.recentlyFed` nibble ×0.25 owner-confirmed / >90 `.hungry`); repetition curve 1.0/0.6/0.25/~0; mood ceiling 92.
- Bond ledger (05 §4.6, FR-10): hello +8 (first touch, device-agnostic, never window-gated), quest +4, variety +6, +20 daily cap clamp-at-award, monotonic, `highestCelebratedStage` once-guard.
- Quest generator + cascade (05 §4.8, FR-14–16): `generate(dayKey, seed, priorTwoSets, questGenEpoch)` with by-construction constraints (consecutive-pair ban, Q6-in-3-day-window, unknown priors force Q6); Q1 < 12:00, Q6 ∈ 20:00–07:00; §5.5 cascade with **amended rule 1 "≥ 20:00 ∨ < 07:00"**.
- Read-models (05 §4.9, §4.11): `makeDisplayState`, `makeCharacterDisplayState`, copy-key selection (`momo.line.*`, day-stable slots, INV-11 — engine composes no sentences).
- Test hardening (TASK-020): every §10.3 matrix row as a named test; meta-determinism property over seeded random interaction sequences; Core ≥ 90 % line coverage recorded.

## Non-Goals
Any I/O, persistence encoding, timers, UI, Watch transport. No `Date()`/`Calendar.current`/system randomness inside the core. No audio, no punishment mechanics, no bond decreases, no streaks.

## Dependencies
- EPIC-003 (TASK-012 types); EPIC-002 (TASK-009/010 harness).
- EPIC-005 runs in parallel (LANE A) once TASK-012/014 land; the epics converge only at EPIC-007.

## Tasks
Branch: `feature/EPIC-004-engine` (from `main`).

| TASK | Title | Size | Depends on |
|---|---|---|---|
| TASK-014 | Implement engine core: reduce, EngineClock, seeded RNG, day-stable seeds (05 §4.1, §4.10) | M | TASK-012 |
| TASK-015 | Implement time-fold catch-up + wakefulness machine + handshakes (05 §4.2–4.3, §4.7) | L | TASK-014 |
| TASK-016 | Implement interaction semantics + satiety + repetition curve (05 §4.4–4.5) | L | TASK-015 |
| TASK-017 | Implement bond ledger (05 §4.6, FR-10) | M | TASK-016 |
| TASK-018 | Implement quest generator + Watch cascade (05 §4.8, FR-14–16) | M | TASK-014 |
| TASK-019 | Implement DisplayState + CharacterDisplayState read-models + copy-key selection (05 §4.9, §4.11) | M | TASK-015, TASK-017, TASK-018 |
| TASK-020 | Add engine test suites — §10.3 matrix + property tests + 90 % floor (05 §10.2–10.3) | L | TASK-014…019 |

(Task granularity follows CLAUDE.md §32's own example split: model → engine → tests are separate tasks; each engine task additionally carries its focused in-task unit tests.)

## Acceptance Criteria
1. `reduce` is pure: identical (state, event, clock, rng-stream) ⇒ identical outcome; import-whitelist scan green (Foundation-only).
2. §4.3 fold table reproduced exactly (decline/restore/attractor/coupling values); rollover keyed by `dayKey`, fires once; DST/TZ cases pass.
3. PRD §4 response matrix complete, including warm refusal (`.full`) with zero effects and the 30–90-min nibble ×0.25; play effects land at the single round-cease instant; interactions during settling/waking decline warm and never queue.
4. Bond ledger cap-by-construction (property over randomized award sequences); 1000 pats bank zero; hello idempotent across devices and post-12:00.
5. Quest generator: determinism, by-construction constraints, window checks at the interaction's own local timestamp; **named test: 02:00 tuck-in with Q1 done selects Q6** (amended cascade rule 1).
6. Read-models produce VoiceOver keys per 04 §3.5; slot selection day-stable; no sentence composition in the engine (INV-11).
7. MomoCore ≥ 90 % line coverage recorded; every §10.3 row exists as a named test.

## Test Requirements
- project.md §32 **Domain matrix (complete)** per 05 §10.3: mood/energy transitions, bond progression, daily reset, quest progression, engine rules (incl. handshakes + play single-instant), deterministic randomness.
- Determinism meta-property (05 §10.2): replaying a seeded random interaction sequence yields identical outcome streams.
- Satiety phase boundaries and the nibble class tested as normative (owner-confirmed).
- All green via `swift test` on macOS.

## Definition of Done
All seven tasks DONE per CLAUDE.md §18; the §10.3 matrix + coverage floor green with recorded evidence; reviews APPROVED; atomic TASK-ID commits on `feature/EPIC-004-engine`, pushed; epic merged to `main`; orchestrator status update. The engine is simulatable headlessly for every §32 edge case before EPIC-007 consumes it.

## Status
TODO
