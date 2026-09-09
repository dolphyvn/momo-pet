# TASK-016 — Interaction Semantics + Satiety Window + Repetition Curve

## Parent Epic
EPIC-004 — Pet State Engine

## Objective
Give `.interaction` intents their real engine semantics (05 §4.4–4.5): the PRD §4 response matrix as pure `ResponsePlan` derivation (D18 — state-gated, never limit-gated, always warm), the satiety window derivation (90 min, three phases — 0–30 refusal / 30–90 nibble ×0.25 owner-confirmed I-2), the same-family repetition curve (1.0 / 0.6 / 0.25 / ~0 per family per local day), play-round authorization with effects at the single unified cease instant, and the care (tuck-in / nap) state transitions — so every interaction's answer is deterministic, countable, and warm, with no punishment anywhere.

## Context
TASK-015 shipped the fold, wakefulness machine, and handshakes; the `.interaction` path currently folds to the intent's instant, records the INV-10 belt, and returns `response == nil` (the documented TASK-016 seam — see `Reduce.swift`'s `.interaction` path and `EngineReduceTests.interactionPassThrough`). This task fills that seam. Normative sources: **05 §4.4** (interaction semantics + counting rules + numeric-effects table + I-1/I-2 adjudications), **05 §4.5** (satiety window DECISION + repetition curve), **PRD §4** (the response matrix — normative, incl. the amended feed row), **PRD FR-5–FR-8** (touch/feed/play/care ACs), **04 §6.1–6.3** (gesture×zone reaction map, state gating, play-round contract), **04 §9.2/§9.6** (ResponsePlan vocabulary; items 4 and 8 are TASK-006 obligations this task discharges), **04 §8.4** (ReactionID namespace). PRD anchors: D18 (state-gated never limit-gated; no negative actions — repetition only softens), G2 (petting banks no bond ever), FR-5 AC-2/AC-3 (touch never refused; effect-diminishing half engine-owned), FR-6 AC-3 + §5.1 rule 2 (feed counts always ⇒ Q3 completable ≤ ~2 min), FR-7 AC-2 (play counts on round completion ONLY), FR-8 AC-1 (tuck-in clock gate 20:00 local).

**Carry-ins from TASK-015 (must be honored, not re-litigated):**
- The **settle preemption edge is implemented** (`settling ──handshakeCancelled(.settle)──► awake`) — TASK-016 makes `.settling` reachable via tuck-in, so this edge becomes live code.
- **Single-slot `pendingHandshake` makes queueing unrepresentable** — this IS the engine's answer to 04 §9.6 item 8 (which interactions queue vs decline-warm during settling): *everything declines warm; nothing queues*. Record this as the formal confirmation of §9.6 item 8.
- **Play effects land at the unified application point** (04 §9.6 item 4): the instant the round ceases — `playRoundFinished` OR `handshakeCancelled(.play)` — never at authorization. `HandshakeMachine.complete(kind: .play, …)` is the application site.
- `interactionPassThrough` (EngineReduceTests) legitimately mints a wake handshake mid-loop (REVIEW-TASK-015 NITPICK-1) — waking-interaction handling must NOT cancel the pending `.wake` handshake (wake is never cancelled, 04 §9.2).
- The fold currently carries `satietyPhase` through untouched and never writes `lastFedAt` — TASK-016 owns both.

## Requirements
1. **ResponsePlan derivation (PRD §4 matrix, D18):** every fresh interaction intent produces exactly one `ResponsePlan` (04 §9.2) whose `ReactionID` is chosen from 04 §8.4's dot-namespace per the 04 §6.1 gesture×zone map and §6.2 state gating (asleep → the stir beat, stays asleep; Drowsy/Exhausted → the same reaction keys — tempo softening is character-side per 04 §6.2). `lineKey` stays `nil` and `haptic` stays `nil` — copy-key selection is TASK-019's (§4.9), haptics are presentation-owned; document both seams. There is no rejecting, locking, or punishing response anywhere (INV-6): a state-mismatched interaction yields the qualitatively-different still-warm beat.
2. **Counting rules (05 §4.4, I-1):** feed counts ALWAYS (politely-full refusal and asleep gentle-decline still increment `feedCount`); play counts on ROUND COMPLETION only (a stir-only or declined round counts nothing; a round that never started did not happen); pat counts always, any state; care counts when performed (in-window tuck-in incl. blanket-adjust while asleep; nap). Counter writes land on the intent's `localDayKey` ledger entry when one exists; an **expired-dayKey intent** (05 §4.4's note; no ledger entry after §5.4 pruning or pre-dating the pet) applies current-state effects, drops ALL day-ledger attribution (no counters, no retroactive `DayRecord`). Quest-progress ticking is TASK-018's (seam — record, do not implement).
3. **Numeric effects (05 §4.4 table — engine-owned starting values, all clamped):** play round energy −10 / mood +6; hungry meal energy +6 / mood +4; recently-fed nibble ×0.25 (owner-confirmed I-2, PRD FR-6/§4 amended — normative); full refusal zero state effect; pet/touch mood +2, zero bond ever (G2); tuck-in mood +3 / energy +2; mood ceiling **92** clamps interaction mood gains (PRD §3.1; the fold's attractor can never approach it — apply the clamp to interaction-path mood gains, with "normal play" as the representative case; record as interpretation). All energy/mood writes respect INV-1/INV-2 domains (0–100).
4. **Satiety window (05 §4.5 DECISION):** derive `satietyPhase` from `lastFedAt` at every fold instant (the fold owns time-derived state): no `lastFedAt` or > 90 min → `.hungry`; 0–30 min → `.full`; 30–90 min → `.recentlyFed` (boundaries: 30:00 is recentlyFed's start; 90:00 is hungry's start — half-open intervals per the table). A feed sets `lastFedAt` = the intent's instant and `.full`. The window value (90) and the 30-min split are constants with authority labels (window = engine-owned, PRD-delegated; response-class split = PRD-owned, owner-confirmed I-2).
5. **Repetition curve (05 §4.5):** per family (feed/play/pet/care) per local day, multipliers **1.0 / 0.6 / 0.25 / ~0** for the 1st–4th+ instance (engine-owned starting values; "~0" lands as exact 0.0 — a 4th+ repeat has no numeric effect but still counts and still responds warmly). The Nth instance reads the family's day counter BEFORE the interaction increments it (feed→feedCount, play→playCount, pet→patCount, care→careCount). Independent of satiety (the 2nd meal is softer even 2 h later). Tuck-in and nap carry NO repetition multiplier (care is window/band-gated — 05 §4.4's I-2 note). Expired-dayKey intents: no ledger day ⇒ treat as instance 1 (full effect), no count.
6. **Feed response classes (PRD §4 amended feed row + §4.5):** `.hungry` → full meal (effects × repetition); `.recentlyFed` → contented nibble (effects ×0.25 × repetition); `.full` → politely-full refusal, zero state effect, counts anyway. Asleep feed → gentle sleepy decline (counts, zero state effect). During `.settling` → gentle decline-warm (sleepy), never queues.
7. **Play rounds (04 §6.3, §9.2, §9.6 item 4):** a play intent in Energetic/Relaxed or Drowsy authorizes a round: `activity = .playing`, mint a `.play` handshake token (the same 2-draw deterministic mint — no `UUID(`), and the ResponsePlan carries the round-start beat (the round IS the response). Drowsy gets the short low-key round (same effects — the "short low-key" is round pacing/animation, character-side; record as interpretation). Exhausted / night-asleep → gentle stir only: no round, no token, no count. A play intent while a round is ALREADY active → small cheer reaction, never resets or extends the round (04 §9.2 item 6), no count. Round effects (energy −10 / mood +6, × the play-family repetition multiplier of the cease instant's ledger day) apply at the **single unified cease instant**: `playRoundFinished` or `handshakeCancelled(.play)` — both paths, both counting `playCount` once (idempotent: a report with nothing pending applies nothing).
8. **Care (PRD §4 care rows, FR-8 AC-1):** tuck-in offered from **20:00 local** through the night window (clock gate, every waking band). In-window tuck-in on a waking pet → mood +3 / energy +2, `careCount` +1, wakefulness → `.settling` with a minted `.settle` token (this is what makes settling reachable), warm settling response. While already `.asleep` → blanket-adjust moment (still counts, no wakefulness change, no new token). While already `.settling` → warm reaffirm, no state change, no second token (single slot). **Out-of-window tuck-in (before 20:00)** → gentle warm response, NO settle, NO count (interpretation: "in its window" qualifies when care is performed — record for the reviewer). Nap: offered in Drowsy/Exhausted → `activity = .napping` (the fold completes it: +20, lands `.waking`/`.asleep` per TASK-015) + `careCount` +1 + warm response; in Energetic/Relaxed (not offered) → gentle warm decline, no nap, no count; asleep → the pet is already sleeping (warm no-op).
9. **Transitional wakefulness (04 §6.2 + §9.6 item 8 — formal confirmation):** during `.settling` every interaction declines warm (feed → sleepy decline; play → declined-warm stir; touch → soft stir; tuck-in/nap per Requirement 8) — nothing queues (single-slot structural confirmation, record it). During `.waking` interactions apply normally (band-gated) and MUST NOT cancel or clear the pending `.wake` handshake — the stretch is never cancelled (04 §9.2); the interaction's ResponsePlan still fires.
10. **Determinism:** the full interaction path stays pure — identical (state, event, clock, calendar, seed) ⇒ identical outcome including `response`; tokens remain seeded draws; no ambient anything.

## Files / Areas Likely Affected
- `Sources/MomoCore/` — new interaction-semantics file(s) (response matrix + effects + counting) and a constants home for the §4.4–4.5 numbers (follow the `FoldRules` precedent: one auditable home, authority labels, literals only in the pin tests); edits to `Reduce.swift` (`.interaction` path + play-cease effect application), `HandshakeMachine.swift` (round-cease effects + counters), `TimeFold.swift` (satiety derivation), possibly `FoldRules.swift` untouched.
- `Tests/MomoCoreTests/` — response-matrix suite, satiety suite, repetition suite, care suite, round-lifecycle suite; `EngineReduceTests.interactionPassThrough` must be RESHAPED (its "response stays nil" pin is superseded by this task — narrow it honestly, comment in place, keep the INV-10 belt pin); `WakefulnessHandshakeTests.playRoundFinishedClearsTokenOnly` gains effect assertions (the TASK-016 seam it names).
- Constants home may extend `Thresholds` ONLY if a number is PRD-normative cut-off material (mood ceiling 92 arguably belongs beside the bands — implementer's choice, label it).

## Dependencies
- TASK-015 (fold, wakefulness machine, handshakes, mint) — done, `7b5d735`.

## Constraints
- Jupiter model, fresh agent, no commit by agent.
- D-R1 (Foundation-only), D-R6 (no deps), engine-purity scan stays green with NO new exemptions (no `Date(`/`UUID(` literals; reuse `mintToken`'s pattern).
- Zero `var` stored properties; immutability via `EngineState.with(...)` copies.
- Scope control (§22) — record, do not implement: bond ledger + hello/variety bond awards (TASK-017), quest-progress ticks + quest completion moments (TASK-018), `lineKey`/`SatietyHint`/`CharacterDisplayState`/greeting moments (TASK-019), character rendering (EPIC-006). `moments` stays `[]` on interaction paths.
- TASK-015's pins may be superseded ONLY where this contract names the supersession (the two test reshapes above); everything else stays green.

## Acceptance Criteria
- AC-1: Every PRD §4 matrix cell is realized by a deterministic engine decision, warm in every state (INV-6) — the full matrix is covered by named tests.
- AC-2: Counting rules hold exactly (I-1 asymmetry: declined feeds count; un-started rounds don't; pats always; care when performed; expired-dayKey intents lose ledger attribution but keep current-state effects).
- AC-3: Satiety derivation is exact at the 30/90-minute boundaries (half-open per §4.5's table); feed response classes are refusal / nibble ×0.25 / full meal per the amended normative matrix; the refusal beat is zero-effect and still counts.
- AC-4: Repetition curve 1.0 / 0.6 / 0.25 / 0.0 applies per family per local day, independent of satiety, care exempt; pet never touches bond (G2).
- AC-5: Play rounds authorize with a seeded `.play` token and apply effects + `playCount` exactly once at the unified cease instant (completion AND cancellation); stir-only states never start rounds; mid-round play never resets/extends.
- AC-6: Tuck-in window gate is exact (before/after 20:00 local); in-window settling mints `.settle` and the preemption edge un-strands it; blanket-adjust while asleep counts; nap offered only in Drowsy/Exhausted.
- AC-7: Full `swift test` green (TASK-015 baseline 164/23 + new suites recorded verbatim); standing scans green (engine purity, D-R1, banned vocabulary); no new scanner exemptions.

## Required Tests
- Response matrix: tap/double-tap/long-press/stroke × zones happy path; asleep stir (stays asleep, counts); Drowsy/Exhausted soft touch; refusal beat (zero effect, counts); nibble ×0.25 (exact arithmetic); asleep feed decline.
- Satiety boundaries: 29:59/30:00/89:59/90:00 since lastFedAt (exact phase at each); no-lastFedAt → hungry; feed sets lastFedAt + full.
- Repetition: 1st/2nd/3rd/4th feed same day (1.0/0.6/0.25/0.0 exact); repetition independent of satiety phase; per-family independence (a feed doesn't soften a pat); care exempt; new day resets the curve; expired-dayKey instance-1 reading.
- Play lifecycle: authorize (token minted, activity set, 2 rng draws); Drowsy round authorized; Exhausted stir (no token, no count); asleep stir; mid-round second play (cheer, round intact); completion applies effects+count once; cancellation applies the same unified effects; stale completion (nothing pending) applies nothing; effects exact (−10/+6 × curve, ceiling-92 clamp exercised).
- Care: tuck-in 19:59 vs 20:00 (exact gate); in-window settle + token + counts; blanket-adjust while asleep (counts, asleep preserved); out-of-window warm decline (no count, no settle); settling reaffirm no-second-token; nap in Drowsy vs Energetic; nap-then-fold completes +20 (TASK-015 integration).
- Settling/waking: interaction during settling declines warm, settle token untouched, settle still completes (extends TASK-015's pin); interaction during waking applies AND the `.wake` token survives (the NITPICK-1 carry-in).
- Determinism: identical tuple ⇒ identical response plan; pinned constants in the pin-test file (anti-echo discipline: raw literals only there).

## Review Requirements
- Fresh adversarial reviewer (§10/§33) verifies: matrix-cell fidelity vs PRD §4 + 04 §6.2 (every cell); counting-rule asymmetry honesty (I-1/I-2 as amended); satiety boundary exactness; repetition instance-count derivation (before-increment, per-day, per-family); unified cease-instant application (both paths, once-only); tuck-in window arithmetic (local time via the injected calendar, DST-safe); settling/waking transitional handling vs 04 §6.2 + the §9.6 item 8 confirmation; purity scan integrity (no new exemptions); no TASK-017/018/019 creep (bond, quests, copy keys all absent). Record in `.claude/tasks/reviews/REVIEW-TASK-016.md`.

## Git Requirements
- Branch: `feature/EPIC-004-engine`
- Commit: `feat(engine): TASK-016 interaction semantics, satiety window, repetition curve`
- Push to origin after orchestrator commit; record hash in Completion Evidence.

## Status
READY (contract materialized 2026-09-09 from 05 §4.4–4.5, PRD §4/FR-5–8, 04 §6/§8.4/§9.2/§9.6)

## Implementation Notes
- (implementing agent fills)

## Reviewer Findings
- (orchestrator records)

## Completion Evidence
- (commit hash + push, by orchestrator)
