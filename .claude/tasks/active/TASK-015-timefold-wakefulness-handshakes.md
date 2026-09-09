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
APPROVED (REVIEW-TASK-015: APPROVED_WITH_MINOR_NOTES; both MINORs + NITPICK-1/2/3 disposed pre-commit; post-fix suite 164/23 green — see Reviewer Findings below)

## Implementation Notes

### File layout

Production (all Foundation-only, D-R1):
- `Sources/MomoCore/FoldRules.swift` (NEW) — the fold constants home (decision 1 below).
- `Sources/MomoCore/TimeFold.swift` (NEW) — segment decomposition (`FoldSegment`, `segments`), the fold engine (`apply` → `FoldResult`), night ramp, attractor, keyed rollover, nap completion.
- `Sources/MomoCore/HandshakeMachine.swift` (NEW) — report application under INV-8 + module-internal `EngineState.with(...)` functional-copy helpers.
- `Sources/MomoCore/Reduce.swift` (REWRITTEN) — signature now `reduce(_ state:, _ event:, clock:, calendar:, rng:) -> EngineOutcome`; real fold / mint / INV-10 belt / report semantics (supersedes TASK-014's bookkeeping-only honesty, as this task's contract directs).
- `Sources/MomoCore/CharacterInterface.swift` (EDITED — disclosed, one case): added `case wakeFinished` to `CharacterReport`. 04 §9.2's sketch omitted it, but 04 §9.2's wake prose ("report → engine sets `.awake`") and 05 §4.7's diagram ("`waking ──wakeFinished──► awake`") both name it, and 04 §9.2 delegates exact-type finalization ("TASK-006 finalizes exact types"). Doc comment cites both sources.

Tests:
- `Tests/MomoCoreTests/TimeFoldTests.swift` (NEW) — decomposition units + all named fold tests.
- `Tests/MomoCoreTests/WakefulnessHandshakeTests.swift` (NEW) — INV-8 transitions, idempotency, cancellation, mint, never-stranded.
- `Tests/MomoCoreTests/FoldRulesPinnedTests.swift` (NEW) — every fold constant pinned to its §4.3/PRD literal (anti-echo discipline).
- `Tests/MomoCoreTests/EngineReduceTests.swift` (EDITED — disclosed reshapes, each commented in place): `calendar:` added at every call site; `evaluateTouchesOnlyStamps` narrowed to the fold-foreign fields (`state`/`days` are fold-owned now — the TASK-014 pin's premise was bookkeeping-only evaluate); `handshakeCarrier` round-trip made zero-elapsed (a wakefulness-transitioning fold now proactively un-strands orphans); `interactionPassThrough` now pins the INV-10 belt (fresh ids recorded, duplicate = total no-op, pet identity/bookkeeping untouched) instead of full-state pass-through; `characterReportPassThrough` gained `.wakeFinished`. All other TASK-014 tests unchanged and passing.

### Decision 1 — constants home: `FoldRules` (separate from `Thresholds`)

New `enum FoldRules` in its own file. Rationale: `Thresholds` is PRD §3-normative cut-offs (bands/bond/quests — TASK-012's single source); the fold table's numbers are engine-owned §4.3 starting values (−1.5/h decline, τ = 3 h, ramp anchor, nap +20) with two PRD-normative members (attractor 60, coupling 35, floor 25, restore 85, clamp 75 are PRD; τ/decline/nap are engine). One home for ALL fold numbers keeps §4.3 auditable as a unit; the header labels which entries are PRD-normative vs engine-owned. `FoldRulesPinnedTests` is the only place the raw literals reappear (TASK-013 discipline).

### Decision 2 — calendar injection: third injected parameter on `reduce`

`reduce(state, event, clock:calendar:rng:)` — the documented §4.1 deviation. The fold needs the user's calendar (segment bounds + `dayKey` locality). Alternatives rejected: carrying it in `EngineState` (persisted state must stay calendar-free — INV-9's spirit — and `Calendar` is environment, not domain); per-event payload (every event kind folds, so it would only restate a parameter). Full rationale is in `Reduce.swift`'s header; determinism tuple is exactly (state, event, clock, calendar, seed).

### Decision 3 — handshake seeding: caller's DaySeed `.choreography`, engine draws only

Tokens are minted from two draws of the injected rng (16 bytes big-endian into the deterministic `UUID(uuid:)` initializer — no ambient `UUID()`). Seed lineage: the app layer seeds the generator per §4.10 `DaySeed.make(…, salt: .choreography)`; the engine performs no DaySeed derivation of its own, so the determinism tuple stays exactly (state, event, clock, calendar, seed) and tokens remain day-stable-seeded. Documented in `Reduce.swift`'s header; `tokensAreDeterministicPerSeed` pins same-seed ⇒ same token, different-seed ⇒ different token.

### Fold semantics (interpretations pinned in `TimeFold.swift`'s header, for review)

1. **Segment resolution** — segments alternate at 22:00/07:00 only (midnight is interior to the night window; rollover is `dayKey`-keyed, not segment-arithmetic). Coupling reads the energy band at segment START; a band crossing takes effect next segment (finer splitting rejected — §4.3's segment set is waking/night/midnight/nap, and coupling is self-healing).
2. **Night ramp slope** — anchored to the containing local night's FULL duration (real seconds, DST-correct), NOT endpoint-anchored: entering mid-night anchors the fold-carried energy at the night's nominal onset (the fold never invents history), so partial nights restore proportionally and the PRD "≥ 75 by 07:00" clamp stays meaningful (an endpoint-anchored ramp would make it vacuous — always exactly 85). Ramp never drains (> 85 holds), never overshoots. The 07:00 crossing unconditionally clamps energy to ≥ 75 and lands `.waking`.
3. **Nap spans the fold** — the model has no nap-start instant (05 §3.1), so a fold starting with `activity == .napping` suppresses waking decline, lets night ramps apply, and completes the nap at fold end (+20 clamped ≤ 100, activity cleared, wakefulness `.waking`, or `.asleep` if it landed in the night window — slept through).
4. **Landing-day rollover** — only the fold's landing day gets a `DayRecord` (appended newest-last when the key is absent); absent days stay silently empty (FR-12 AC-1). Keyed lookup makes exactly-once structural: a backward clock re-deriving an awarded key finds it present — no double reset, no double hello. Placeholder quest set [Q1, Q2, Q6] zero-progress + `questGenEpoch: 0` is the documented TASK-018 seam (DayRecord requires exactly 3 distinct quests).
5. **Fold-side un-stranding** — a fold transition that orphans the pending handshake clears it (§4.7 "never left waiting"); a `.wake` token SURVIVES a landing in `.waking` (it IS the wake stretch's token). Reports arriving after the clear are tolerated no-ops.
6. **Forward-only folds** — `lastEvaluatedAt` is a high-water mark (`max(old, target)`); backward folds apply no dynamics and never regress the mark (`.evaluate` still stamps `lastOpenedAt` to the event instant — the open happened at that wall time).
7. **Reports fold to `clock.now()`** — reports carry no instant, so they are the one event kind that reads the injected clock (§4.2 trigger table).
8. **Kind-matching reports** — 04 §9.2's `CharacterReport` is token-less (normative shape), so reports match the single `pendingHandshake` by KIND; a stale report (kind matches, pet past the source state) is rejected per INV-8 and un-strands the dead token. **Residual race recorded for review:** a cancelled generation's report arriving after a NEWER same-kind handshake was issued applies the newer handshake one report early (warm, state-consistent); eliminating it requires token echoes in report payloads — a character-contract change this task does not make.
9. **Same-event re-mint on cancellation** — `handshakeCancelled(.wake)` while `.waking` clears the stale token, and the same event's mint check immediately re-issues a fresh generation (engine never strands, never queues; the app layer owns pause-on-hide semantics per 04 §9.2). Pinned by `cancelledWakeRecovers`.

### Wake-stretch mint

Fold landing `.waking` issues NO handshake (nothing was listening at 07:00, §4.3 closing); the NEXT event processed while the pet is still `.waking` with nothing pending mints `.wake` (FR-4's in-session emission). Pinned: the landing fold consumes ZERO rng draws; the minting event consumes exactly two (`wakeStretchMintDefersPastTheFold`).

### Scope control (§22) — documented seams, NOT implemented

- TASK-016: interaction response matrix (`response` stays `nil`), warm-decline plan, satiety derivation (fold carries `satietyPhase` through untouched), play-round effects (the machine clears the token + activity at the unified application point; effects land there in TASK-016), round authorization that mints `.play` tokens.
- TASK-017: bond ledger (fold never touches `bond`; interactions record ids only).
- TASK-018: seeded quest generation (placeholder zero-progress set above).
- TASK-019: read-models (none added; `makeCharacterDisplayState` remains future work).

### Disclosed out-of-letter edits (all minimal)

1. `CharacterInterface.swift`: +`case wakeFinished` (normative citations above).
2. `EngineReduceTests.swift`: reshapes listed above (premise supersessions, each commented in place).
3. `Reduce.swift`/`TimeFold.swift` wording constraints: the purity scan bans the `Date(` and `UUID(` substrings (deliberately blunt, TASK-014's design), so the code uses `Calendar.enumerateDates` + component arithmetic instead of `nextDate`/backward search, and reaches the deterministic 16-byte UUID initializer via `.init`. No exemptions were added to the scanner; behavior is identical (Foundation probe confirmed `date(from:)` resolves fall-back/spring walls correctly).
4. A real bug was caught by the named DST tests during bring-up: `nightBounds` initially read `.hour` from components that only requested year/month/day (always `nil` → wrong night anchor on DST and mid-night entries). Fixed to `calendar.component(.hour, ...)`. The exact-value DST pins are what exposed it.

### Purity + hygiene evidence

- Standing purity scan GREEN over all `Sources/MomoCore` (new files auto-covered), non-vacuous per TASK-014's layered self-tests.
- Scratch RED run (recorded, then reverted): added `Sources/MomoCore/ScratchViolation.swift` containing `UUID()`; verbatim output:
  ```
  ✘ Test "MomoCore as it stands is engine-pure (non-empty source set)" recorded an issue at EnginePurityScanTests.swift:119:9: Expectation failed: (violations → [MomoCoreTests.EnginePurityScan.Violation(file: "Sources/MomoCore/ScratchViolation.swift", literal: "UUID(")]).isEmpty → false
  ↳ engine-purity violation: ["Sources/MomoCore/ScratchViolation.swift: UUID("]
  ✘ Test run with 1 test in 1 suite failed after 0.020 seconds with 1 issue.
  ```
  File deleted; full suite re-run green after.
- D-R1 import whitelist scan green; no `print(`; no TODO/FIXME/HACK/TEMP; zero `var` stored properties (function-local accumulation only); immutability via `EngineState.with(...)` copies.

### Verbatim test results

Baseline (TASK-014 handoff): `Test run with 126 tests in 20 suites passed`.

Final:
```
✔ Test run with 163 tests in 23 suites passed after 0.369 seconds.
```
(+37 tests, +3 suites.) Notable new named tests: night onset 22:00 (`nightOnsetLandsAsleepHandshakeFree`), morning wake (`morningWakeClampsEnergy` + `wakeStretchMintDefersPastTheFold`), midnight ×1 (`midnightRolloverExactlyOnce`), DST fall-back (`dstFallBackNightIsTenHours` — 36000 s night), DST spring-forward (`dstSpringForwardNightIsEightHours` — 28800 s night), timezone change (`timezoneChangeCausesAtMostOneRollover`), backward clock (`backwardClockFoldsNothing`), 7-day absence (`sevenDayAbsenceAddsOnlyLandingDay`), wake clamp (`morningWakeClampsEnergy` — exact 74.625), attractor τ (`attractorConvergenceMatchesTau` — exact `60 − 30/e`), coupling/floor (`couplingAndFloor` — exact `60 − 25(1−e^(−1/3))` and floor lift to 25.0), late report (`lateReportAfterFoldClearance`), duplicate (`settleFinishedAppliesAndIsIdempotent`), cancelled (`cancellationMatchesKindOnly` + `cancelledWakeRecovers`), interaction-during-settle (`interactionDuringSettleDoesNotQueue`), eviction (`processedIntentsEvictOldestAtCapacity` — 70 in, last 64 remain, evicted id replayable by design).

### Judgment calls ranked for reviewer attention

1. Night-ramp full-night anchoring (interpretation 2) — the one place two defensible readings of §4.3 diverge materially; endpoint-anchoring was rejected because it makes the normative wake clamp vacuous.
2. Kind-matching for token-less reports + the recorded same-kind race (interpretation 8).
3. Wake-token survival through a `.waking` landing + same-event re-mint on cancellation (interpretation 9).
4. Landing-day-only rollover (interpretation 4) — vs retro-creating absent days; FR-12 AC-1 decides.
5. Nap-spans-fold (interpretation 3) — forced by the model's missing nap-start instant; TASK-016 may prefer to add one.

### Handoff

### Completed
All 7 requirements; AC-1…AC-6 satisfied; named tests present; scans green.

### Files Changed
Production: `FoldRules.swift`, `TimeFold.swift`, `HandshakeMachine.swift` (new); `Reduce.swift`, `CharacterInterface.swift` (modified). Tests: `TimeFoldTests.swift`, `WakefulnessHandshakeTests.swift`, `FoldRulesPinnedTests.swift` (new); `EngineReduceTests.swift` (modified). No project-file edits needed (package target auto-globs).

### Tests Run
`swift test` (full package).

### Test Results
`✔ Test run with 163 tests in 23 suites passed after 0.369 seconds.` (baseline 126/20)

### Known Issues
None open. One fixed during bring-up (nightBounds hour-component bug — §Disclosed edits item 4).

### Decisions Made
Decisions 1–3 + interpretations 1–9 above, all documented in source headers.

### Reviewer Status
Not yet reviewed — IN_REVIEW. Suggested scrutiny: fold decomposition boundaries (22:00/07:00/midnight/DST), once-only rollover structural argument, attractor exactness (tests restate the formula independently), §4.7 diagram fidelity, idempotency honesty, TASK-016+ creep check, and the five ranked judgment calls.

### Commit
None (agent makes no commits per CLAUDE.md §9).

### Push
None.

### Recommended Next Step
Orchestrator spawns the fresh review agent (REVIEW-TASK-015); after APPROVE, commit as `feat(engine): TASK-015 time-fold catch-up, wakefulness machine, handshakes`, push, update status.md.

## Reviewer Findings
Fresh adversarial reviewer (independent re-derivation: hand arithmetic on every pinned number, OS probes for DST durations 36000 s/28800 s, from-scratch equilibrium re-derivation, a probe where the reviewer's adversarial expectation was wrong and the code was right). Full record: `.claude/tasks/reviews/REVIEW-TASK-015.md` — **APPROVED_WITH_MINOR_NOTES**, zero MAJOR.

- **MINOR-1** — coupling band timing: header documented segment-start coupling, code computed it segment-end (materially observable: mood 47.8354 vs 60.0 over a crossing segment); no shipped test discriminated.
- **MINOR-2** — §4.7's `settling ──handshakeCancelled(.settle)──► awake` preemption edge unimplemented, and a shipped pin asserted the contrary without a recorded deferral (unreachable pre-TASK-016, hence MINOR).
- NITPICK-1 — `interactionPassThrough` legitimately mints a wake handshake mid-loop (noted for TASK-016). NITPICK-2 — two authority-label drifts in `FoldRulesPinnedTests`. NITPICK-3 — unused-result warnings. NITPICK-4 — coverage unrecorded (reviewer measured: TOTAL 97.77 % lines). Observation — `days` ledger pruning has no named owner (retention is EPIC-005 §5.4's; TASK-018 reads the tail).
- All five ranked judgment calls adjudicated benign; landing-day-only rollover adjudicated CORRECT against FR-11/FR-12.

### Orchestrator disposition (all applied pre-commit; details in REVIEW-TASK-015 §Disposition)
- MINOR-1 **FIXED**: code restored to the documented segment-start reading (band read moved before the waking decline) + the reviewer's probe adopted NOW as the discriminating pin `couplingBandReadsSegmentStart` (not deferred to TASK-016).
- MINOR-2 **FIXED (option a)**: the 3-line edge implemented (`complete(kind: .settle, from: .settling, to: .awake)`); the contradicting pin flipped to assert `.awake` + idempotent re-cancellation.
- NITPICK-1 commented for TASK-016; NITPICK-2/3 fixed; NITPICK-4 on record in the review file; ledger-pruning owner (EPIC-005) recorded in status.md.
- Post-fix verification: `swift test` → **164 tests / 23 suites passed** (163 + the new discriminating pin).

## Completion Evidence
- (this commit) — `feat(engine): TASK-015 time-fold catch-up, wakefulness machine, handshakes` on `feature/EPIC-004-engine`; hash recorded in `.claude/tasks/status.md` by the housekeeping commit that follows.
- Final verbatim: `✔ Test run with 164 tests in 23 suites passed after 0.376 seconds.` (TASK-014 baseline 126/20 → +38 tests / +3 suites across impl + disposition).
