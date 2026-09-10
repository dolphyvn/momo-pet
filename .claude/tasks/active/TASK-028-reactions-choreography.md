# TASK-028 — Reaction vocabulary + state choreography + CharacterReport emission

## Parent Epic

EPIC-006 — Character Rendering (`.claude/tasks/epics/EPIC-006-character-rendering.md`), task 4 of 6. Delivery-plan row: "Implement reaction vocabulary + state choreography + CharacterReport emission (04 §4, §6, §9.2)".

## Objective

Make the character RESPONSIVE. TASK-027 made it alive (deterministic idle); this task lands the interaction half of 04-character-system: the L0–L4 priority/coherence model (§4.1), the reaction clip vocabulary rendered per §4.3/§6.1/§7.1–7.2, the settle/wake/play handshake choreographies with `CharacterReport` emission (§9.2), L4 moments, the 8c prop-channel wiring, and the character-side halves of the §4.1 coherence rules (rapid-pat coalescing, eating-glance-up, eye-follow-on-touch). Everything headless-testable and deterministic; the SwiftUI integration composes through the EXISTING single write path.

## Context

- **Engine side is DONE and frozen.** EPIC-004 landed the full §9.2 interface in `Sources/MomoCore/` (`CharacterInterface.swift`: `ReactionID`, `ResponsePlan`, `CharacterDisplayState`, `CharacterMoment`, `HandshakeKind`, `CharacterReport` incl. `wakeFinished`; `ReactionKeys.swift`: the §8.4 namespace) and the PRD §4 response matrix in `InteractionSemantics` (D18, I-1, satiety, unified play cease, §9.6 item 4 confirmed, handshakes in `HandshakeMachine` with idempotent kind-matched reports). **This task is CHARACTER-ONLY. `Sources/MomoCore/` and `Sources/MomoKit/` diffs must be 0 bytes** (verified at every checkpoint; the TASK-023 precedent). The character never decides warm/declined (D18) and never applies numeric effects (§9.1/§9.3) — it executes the plan it is given and reports completions.
- **Character side so far (EPIC-006, commits `7681498`/`d0955e0`/`d26b9d3`, all pushed):** generated rig constants + pipeline (TASK-025); `RigLayerTree` (21 rig + 4 props, anchors, outermost-first stage composition), `CharacterClock` (zero-on-pause), LOD tiers, `MomoCurves` constants, `RigMotionModel` rest-identity + pupil clamp, Content breath (TASK-026); the idle sequencer, `MomoExpressions` (7-band × 8-row), `MomoIdleArbiter` (render-level greedy admission), ADR-009 composition order, ADR-010 resume discipline, ADR-011 body-scaleY composition law, ADR-012 occupancy tiers (TASK-027). Suite: **721 tests / 72 suites green**.
- **The ReactionID vocabulary is a CLOSED SET owned by MomoCore.** The engine mints exactly these 21 (grep-verified over `InteractionSemantics.swift`): `react.tap.head`, `react.tap.belly`, `react.tap` (zone-less Watch path, §8.4's optional-zone form), `react.doubleTap`, `react.longPress.head`, `react.longPress.belly`, `react.longPress`, `react.stroke.head`, `react.stroke.belly`, `react.stroke`, `react.stir`, `react.politelyFull`, `react.gentleDecline`, `react.sleepyNibbles`, `react.settling`, `react.blanketAdjust`, `state.eating`, `react.nibble` (I-2 recently-fed contented nibble), `react.playReady` (§6.3 phase-1 invite beat), `react.cheer` (extra taps during play, §4.1 rule 6), `react.decline` (the generic warm decline: waking-choreography, play-in-flight, nap-not-offered). L4 moments arrive as `momentRequest` on `CharacterDisplayState` (greeting ×4 kinds, `questCompleted`, `bondStageReached`), NOT as ResponsePlans. **The character's clip table must switch exhaustively over the mintable set so a future engine key is a BUILD ERROR** (the TASK-023 exhaustive-case-map pattern); it must NOT mint new keys.
- **Doc anchors (04-character-system.md):** §4.1 L0–L4 table + 8 coherence rules (:258–279); §4.2 nine-state contract (:281–295); §4.3 reaction vocabulary table (:297–310); §6.1 gesture×zone map + rapid-pat softening (:368–382); §6.2 state gating (normative semantics — engine owns it) incl. the transitional-wakefulness paragraph (:384–398); §6.3 play-round character-side motion contract (:400–414); §7.1 master timing table (:424–443); §7.2 curves (:445–453); §7.4 concurrency budget rule 4 (:475); §9.1–9.3 division of authority (:541–613); §8.4/§8.5 manifest (:512–537).
- **TASK-026 review routings discharged by this task (from `.claude/tasks/completed/TASK-026-rig-layer-tree-character-clock.md`):** 8c prop-channel wiring — `RigChannel` carries `propFood`/`propBlanket`/`propSparkleA`/`propSparkleB` (and `RigMotionModel` carries the channels) but the transforms are deliberately unapplied; this task applies them.
- **TASK-027 housekeeping carried here (both reviewers concurred):** two stale no-op `clampedPostureScaleY` wraps in `Tests/MomoCharacterTests/MomoIdleRenderTests.swift` (~line 227 and ~lines 456–459) — under ADR-011 the expression layer pre-clamps the static posture, so the wraps re-clamp an already-clamped value. Delete them in this task; the suite must stay green byte-identically (they are provably no-ops).

## BLOCKING TASK-027 routings (from `.claude/tasks/completed/TASK-027-idle-sequencer-expressions.md`)

1. **R-A — Single write path.** Reaction choreography composes through `RigMotionModel`/`RigChannel` gates exactly like the idle channels — NO second transform stack, NO bypass of `RigLayerTree`'s ADR-009 composition order. If the model needs new inputs (reaction overlay, handshake phase, moment phase), extend the existing pose function's inputs; never fork a parallel writer.
2. **R-B — ADR-011 non-regression.** Reactions are MOTION on top of the (pre-clamped) expression posture: they compose multiplicatively/additively per existing channel semantics, bounded by their own authored magnitudes, never re-clamped through `postureScaleYRange`. The TASK-027 breath-sine-purity sweep and asleep-peak pins must stay green UNTOUCHED.
3. **R-C — Schedule stays doc-exact; gating is render-level.** Reaction arrivals must not mutate `MomoIdleSequencer`'s schedule. Blink-preemptible (§4.1 rule 1) is a RENDER-level interaction: a reaction arrival fades active L1 micro-events within ≤ 100 ms, exactly the pattern `MomoIdleArbiter.admitted` uses for the idle log.
4. **R-D — NOTE-2 housekeeping** (the two stale wraps above) lands in this task's diff.

## Requirements

**R1. Reaction clip table (`§4.3` + `§6.1` + `§7.1`, digit-pinned).** Every mintable ReactionID maps to a clip: baseline duration, curve family (§7.2), enabled channel groups, and a channel-value choreography over the character timeline. Baseline durations digit-for-digit from the doc rows: §6.1 — tap·head 0.4 s, tap·belly 0.45 s, double-tap 0.7 s, long-press·belly 0.9 s, stroke·head ~1.2 s per stroke cycle, stroke·belly ~1.0 s (long-press·head is press-length — see R6); §4.3 — stir 0.8–1.2 s, politely full 1.2 s, gentle decline 1.0 s, sleepy nibbles 3–4 s, yawn 1.4 s (already a `MomoCurves` constant), blanket-adjust 1.5 s; §7.1 — reactions 0.4–1.2 s band, eating 2.5–4.0 s (2–3 bite cycles), waking stretch 1.8–2.5 s, settling 2.5–3.5 s, quest sparkle 0.9–1.2 s, stage celebration 1.6–2.0 s. Authored clips with NO doc row (`react.nibble`, `react.decline`, `react.cheer`, `react.playReady`, greeting moments) carry an explicit `// AUTHORED` label, a chosen duration inside the reaction-family spirit (each disclosed in the clip table), and a distribution or value pin. Author eating at a fixed value inside 2.5–4.0 with a fixed bite-cycle count (2 or 3) so the choreography is deterministic.

**R2. Band tempo law (`§6.2`, character-owned rendering).** The engine picks WHICH reaction; the character owns duration (§9.3). Drowsy touch reactions render "soft, slower versions (tempo ×1.4)" — doc-literal ×1.4 on the §6.1 touch set. Exhausted touch reactions render "soft, slower" (no number in the doc) — author an exhausted tempo multiplier (default ×1.5, `// AUTHORED`, disclosed; the fatigue gradient runs drowsy → exhausted). Stir plays at its §4.3 duration regardless (it is the ASLEEP beat; the ×1.4 prose attaches to the Drowsy column's waking touch row). Record honestly: baseline durations are the §7.1/§4.3/§6.1 values at the Content/awake baseline; a tempo-stretched duration may exceed its row's ceiling (e.g. stroke·head 1.2 × 1.4 = 1.68) — the 0.4–1.2 s row is baseline-scoped, cited in the clip table. The baseline (non-drowsy, non-exhausted) pins must still digit-match the doc rows.

**R3. The L0–L4 coherence director (`§4.1`, the interruption matrix — the heart of the task).** A pure, headless-testable director that consumes (a stream of arrival events — ResponsePlans with character-time stamps, CharacterDisplayState changes, touch-phase events — plus the timeline) and yields, at every timeline instant, the set of ACTIVE choreographies with their fades. Enforce, as executable law:
- Rule 1: L1 yields to anything — an interrupted micro-event fades ≤ 100 ms (render-level, R-C).
- Rule 2: a new L2 replaces the current L2 via a 300–400 ms crossfade (`MomoCurves.stateCrossfadeSeconds`); an L2 change preempts L3s — an interrupted reaction fades ≤ 120 ms.
- Rule 3 (the VISUAL half of FR-5 AC-3): identical L3 reactions within 500 ms COALESCE — pats 1–2 full, 3–4 abbreviated, 5+ one gentle coalesced response per 500 ms window. 500 ms is a named constant. No lock, no penalty, no mood reduction ever (D18).
- Rule 5 (character side): eating continues through taps — while `activity == .eating`, an arriving touch reaction renders as the brief glance-up only (AUTHORED ~0.5 s), never the full §6.1 reaction, and never interrupts the bite choreography.
- Rule 6 (character side): during play, extra taps produce `react.cheer` (L3) and never reset or extend the round — the play pacer ignores them (R7).
- Rule 8: app-hide pauses EVERYTHING via the CharacterClock (already built — this task pins the reaction-layer consequences, see R8).
- L3 queue ≤ 2: a newer L3 displaces queued L3s; an arriving L3 never stacks unboundedly.
- Rule 4's sleeping row is ENGINE-owned (the engine mints only stir during sleep — pinned in MomoCore); the character renders what arrives. Do NOT re-implement semantic gating; DO pin the structural property that the director's active-set at any instant never violates the §4.1 priority table for ANY input stream.
- L4 vs pending L3 (§4.1 note): no extra arbitration — the table's preemption rights suffice; pin the bounded case.

**R4. Handshake choreographies + reports (`§9.2`).** Event-driven, timeline-pure:
- **Settle** (`wakefulness` → `.settling`, plan key `react.settling`): yawn → lie down → blanket settles (§4.3), 2.5–3.5 s, §7.2's ease-in settle curve (`MomoCurves.settleEaseExponent`); blanket prop (R9); `settleFinished` fires exactly once at the end instant.
- **Wake** (`wakefulness` → `.waking`): 1.8–2.5 s unhurried stretch, `wakeFinished` exactly once. Waking is never cancelled — app-hide pauses it and it completes on return (§9.2; the `.wake` HandshakeKind exists for totality).
- **Preemption cancellation:** a newer L2 replacing settling mid-animation, and app-hide during settle, emit `handshakeCancelled(.settle)` exactly once so the engine is never stranded (§9.2 cancellation). ADJUDICATION (attackable, doc-cited): app-hide during SETTLE cancels (the §9.2 cancellation section's spirit — hide preempts the beat; un-strand immediately) while app-hide during WAKE and L4 moments does NOT (§9.2 explicitly pauses waking; §4.1 rule 7 explicitly pauses moments) — cite both clauses.
- **Every report fires exactly once per choreography instance**, at a fixed timeline instant; advancing the clock far past it must not duplicate (idempotency is engine-tolerated but the character still pins exactly-once emission).
- `reactionFinished(ReactionID)` fires at each clip's end instant (including abbreviations and coalesced responses).

**R5. L4 moments (`§4.3` L4 rows + `§8.5` + `momentRequest`).** `momentRequest` on the display state drives: quest sparkle 0.9–1.2 s (single small sparkle drift — `propSparkleA`/`B`, R9); stage celebration 1.6–2.0 s (perked ears + happy bounce + soft sparkle ring + cheek accents, single soft overshoot ≤ 8% via `MomoCurves.celebrationOvershootMax`/`isSingleSoftOvershoot` — NO bouncing-ball loops); greeting choreography per GreetingKind (4 kinds, AUTHORED durations in the L4 spirit ≤ 2.0 s, disclosed). App-hide pauses (ADR-010 replay-from-0 on return — the beat restarts and completes); `momentFinished(moment)` fires exactly once at completion. If the same `momentRequest` value persists after its `momentFinished` (engine hasn't cleared yet), do NOT re-trigger — dedupe on request identity; pin it.

**R6. The §6.1 touch set in full**, including the two composite beats: long-press·head — eyes close to 40% aperture and HOLD for the press duration (press-length is an input, not a constant); on release, the content exhale, PLUS the slow-blink-back ONLY at bondStage `.bestFriends` / `.soulCompanions` (verified case set: `newFriends` / `gettingClose` / `bestFriends` / `soulCompanions`, `Bands.swift:22` — pin the boundary at exactly `.gettingClose` → absent, `.bestFriends` → present). Stroke·head — a 2nd+ stroke within the same touch deepens to the slow blink (same-touch stroke count is an input). Eye-follow accompanies all touch (§2.4/§6.1): the reaction choreography includes the pupil glance toward the touched zone through `clampedPupilOffset` (≤ 30% clamp; iPhone full tier — the Watch glance tier has no pupil split, LOD governs).

**R7. Play round (`§6.3`).** The character-side motion contract inside TASK-004's delivered UX-3 shell: phase-1 invite (`react.playReady`, perk + anticipation lean) ≤ 3 s; phase-2 follow 10–20 s (Momo bounds after the fingertip; finger-at-rest → solo performance; participation optional, never demanded); phase-3 payoff ≤ 5 s (joyful flourish + soft sparkle ring, celebration curve — single overshoot ≤ 8%); round total ≤ 30 s ALWAYS — the pacer paces the follow phase to land in-window for ANY fingertip behavior (pin: adversarial sequences — never-moves, always-moving, resting-mid-round — all land ≤ 30 s). Two moving transform groups maximum (§7.4 rule 4). Drowsy → a low-key SHORTER follow ending in the yawn; Exhausted/sleeping → the engine mints stir-only (render what arrives). Handshake: engine authorizes → character paces → `playRoundFinished` at the cease instant; preemption (newer L2 or app-hide) → `handshakeCancelled(.play)` at the SAME instant — the engine applies effects at that unified point (§9.6 item 4, discharged engine-side; the character's obligation is only that the report lands AT the cease). The fingertip track is UI-owned input: model it as a typed pure input to the pacer (phase clock + fingertip activity), no UIKit/SwiftUI imports in the pure layer.

**R8. Pause discipline (`§4.1` rule 8 + ADR-010).** The CharacterClock already zeroes on app-hide. Pin the reaction-layer consequences: in-flight L3 reactions fade at hide and their `reactionFinished` reports emit (engine tolerates); settle/play cancel per R4; waking and L4 moments RESTART from timeline 0 on return (replay-from-0 — the ADR-010 consequence of the zeroing clock; they complete, never cancel) and their reports fire once at completion. Determinism: given the same arrival log and display-state timeline, the director's output (active sets, fades, report log) is IDENTICAL across runs — whole-trajectory twin-equality property test (the TASK-020 meta-suite pattern).

**R9. 8c prop wiring (the TASK-026 routing).** `propFood` animates only during eating/nibble/sleepyNibbles choreography (the food mound present + bite-cycle motion); `propBlanket` during settling (blanket settles), blanket-adjust (nudge + deeper settle), and sleeping (draped); sparkles during questCompleted, stage celebration, and the play payoff only. Everywhere else the prop channels are IDENTITY. Flip the TASK-026 regression expectation: the old "props inert" pins become "props inert WHEN UNUSED" pins with new applied-path pins (named per prop).

**R10. Curves (`§7.2`).** Touch reactions: ease-in-out or the gentle spring (response ~0.35 s — `MomoCurves.touchSpringResponseSeconds`), overshoot ≤ 15% (`touchOvershootMax`); celebrations: single soft overshoot ≤ 8% then settle, `repeatedBounceAllowed == false` enforced on every celebration/payoff path; settle/sleep: ease-in decelerating (`settleEaseExponent`); ear/tail: damped spring within `springDampingRange`, soft overshoot only (`isSingleSoftOvershoot`). No new curve families without a §7.2 row.

**R11. Concurrency + battery (`§7.4`).** Reactions ≤ 8 channels concurrently at every instant of every clip (pin per clip); the ambient idle budget (≤ 3, TASK-027) is unchanged and the two budgets are pinned independently. Scheduled, never polled — no polling loops in the director (the pure API makes this structural; keep it that way).

**R12. Integration + scope walls.** `MomoCharacter` only; `MomoCore`/`MomoKit` diffs 0 bytes; no new geometry, no hex (token slots only — R4 purity), no copy or haptic consumption (lineKey/haptic are the UI's — the character animation layer ignores them); no Watch-specific UI (§6.4 pat renders through the same vocabulary in EPIC-008); Reduce Motion is TASK-029 — build nothing RM-shaped now, but keep the director's output as static-pose-reachable data (the channel-gate architecture already guarantees this; do not special-case). NOTE-2 housekeeping (R-D) rides this diff. Many small files (200–400 lines typical, 800 max): suggested split — `MomoReactionClips.swift` (R1/R2/R10 table), `MomoReactionDirector.swift` (R3/R8 arbitration), `MomoHandshakeChoreography.swift` (R4/R7 settle/wake/play + pacing), `MomoMoments.swift` (R5), overlay application in/next to `RigMotionModel` (R-A), prop wiring (R9). Naming follows the existing Momo*/Rig* split. Each suggested file is free to land differently if the structure is cleaner — the REQUIREMENTS are binding, the file names are not.

## Files / Areas Likely Affected

- NEW: `Sources/MomoCharacter/MomoReactionClips.swift`, `MomoReactionDirector.swift`, `MomoHandshakeChoreography.swift`, `MomoMoments.swift` (or equivalents — R12).
- MODIFY: `Sources/MomoCharacter/RigMotionModel.swift` (overlay inputs + prop wiring, single write path), possibly `RigPose.swift` (overlay fields), `MomoRigView.swift` (compose director output), `MomoCurves.swift` (ONLY if a genuinely missing constant emerges — cited, disclosed).
- MODIFY (housekeeping): `Tests/MomoCharacterTests/MomoIdleRenderTests.swift` (delete the two stale wraps, ~:227, ~:456-459).
- NEW tests: clip-table digit pins, director coherence matrix, coalescing, handshake reports/cancellations, moments + dedupe, play pacing bounds, prop wiring, twin-equality determinism, ≤ 8 budget.

## Dependencies

- TASK-027 (DONE, `d26b9d3`): sequencer/expressions/arbiter/ADR-009…012 — the foundation this task composes onto.
- EPIC-004 (DONE, merged): the frozen MomoCore interface + engine semantics this task consumes.

## Constraints

- `Sources/MomoCore/` and `Sources/MomoKit/` 0-byte diffs (verify with `git diff --stat` at every checkpoint; a 1-line touch is a STOP and disclose).
- All agents Jupiter (omit model override); implementer does NOT commit (orchestrator commits after review per §10/§12).
- Determinism: no system randomness (§9.4), no ambient time (the discipline scanners enforce — keep them green with no new exemptions), timeline-injected everywhere.
- Suite floor: 721/72 green baseline; new suites added; zero NEW warnings; art budgets re-measured and recorded (rig bucket was 51,906/307,200 B; MomoCharacter sources 204,789/1,572,864 B).
- Scope control (§22): everything not in R1–R12 is a follow-up note, not code. In particular: no Reduce Motion (TASK-029), no watch surfaces (EPIC-008), no engine changes, no new ReactionIDs, no greeting COPY (catalog keys exist; §10 copy is presentation).

## Acceptance Criteria

1. Every mintable ReactionID renders a clip whose baseline duration digit-matches its doc row (R1), with authored clips disclosed and pinned (R1), band tempo ×1.4/×1.5 pinned (R2).
2. The §4.1 coherence matrix is executable: blink-preemptible ≤ 100 ms, L2 crossfade 300–400 ms + L3 fade ≤ 120 ms, identical-L3 coalescing 500 ms (1–2 full / 3–4 abbreviated / 5+ coalesced), L3 queue ≤ 2, no unbounded active set — for ANY input stream the active set satisfies the priority table (R3).
3. Settle/wake/play run to their §7.1 durations with §7.2 curves, emit exactly-once reports at fixed instants, and every preemption path emits `handshakeCancelled(kind)` exactly once (R4, R7); waking never cancels (R4).
4. L4 moments render (sparkle 0.9–1.2 / celebration 1.6–2.0 ≤ 8% overshoot / 4 authored greetings), pause on app-hide, complete on return, dedupe persistent requests, `momentFinished` exactly once (R5).
5. The play round lands ≤ 30 s for adversarial fingertip sequences; drowsy shortens and ends in yawn; extra taps cheer without reset (R3 rule-6, R7).
6. App-hide discipline per R8 with twin-equality determinism over (arrivals, display states, timeline) (R8).
7. Props animate exactly on their choreography windows and are identity elsewhere (R9).
8. Composite beats work: long-press hold + release exhale + Best-Friends slow-blink-back; same-touch stroke deepening; eating glance-up; eye-follow on touch (R6).
9. Reaction clips ≤ 8 concurrent channels each; idle ≤ 3 unchanged (R11). MomoCore/MomoKit diffs 0 bytes; NOTE-2 wraps deleted; 721-baseline suites all still green (R12, R-D).

## Required Tests

1. **Clip digit pins** — every doc-row duration pinned raw (tap·head 0.4, tap·belly 0.45, double-tap 0.7, long-press·belly 0.9, stroke·head 1.2/cycle, stroke·belly 1.0, stir 0.8–1.2, politelyFull 1.2, gentleDecline 1.0, sleepyNibbles 3–4, blanketAdjust 1.5, eating authored-in-2.5–4.0, settling 2.5–3.5, waking 1.8–2.5, sparkle 0.9–1.2, celebration 1.6–2.0, yawn 1.4 reuse) + authored clips pinned with AUTHORED labels; exhaustive-switch build-error proof over the 21-key mintable set.
2. **Tempo pins** — drowsy ×1.4 on a named reaction (raw ×1.4 in the test), exhausted ×1.5 AUTHORED, stir exempt.
3. **Coalescing matrix** — pat arrival sequences (2 / 4 / 6 pats at sub-500 ms spacing) yield full / abbreviated / coalesced render sets per the 1–2/3–4/5+ law; > 500 ms spacing does NOT coalesce; determinism across runs.
4. **Coherence matrix** — for generated adversarial arrival streams: blink interrupted → ≤ 100 ms fade; L2 change during L3 → ≤ 120 ms fade + 300–400 ms crossfade; queue never exceeds 2; active set never violates the priority table; the §4.1 bounded-case note (L4 vs pending L3) pinned.
5. **Handshake reports** — settle end → `settleFinished` exactly once; wake end → `wakeFinished` exactly once; settle preempted mid-animation → `handshakeCancelled(.settle)` exactly once; play preempted → `handshakeCancelled(.play)` at the cease instant; clock far-past-end does not duplicate any report.
6. **Play pacing** — adversarial fingertip sequences (never-move / always-move / rest-mid-round / drowsy) all land `playRoundFinished` ≤ 30 s; drowsy round shorter and ends in yawn; cheer during play never shifts phase boundaries.
7. **Moments** — sparkle + celebration durations + ≤ 8% single overshoot (`isSingleSoftOvershoot`); app-hide mid-moment → replay-from-0 on return → completes; same request persisting → no re-trigger; `momentFinished` exactly once.
8. **App-hide reaction consequences** — in-flight L3 → fade + report at hide; settle → cancelled; wake → restarts and completes on return (never cancelled); twin-equality property over full trajectories.
9. **Props** — food during eat-family windows only; blanket during settle/adjust/sleep only; sparkles during moments + payoff only; identity elsewhere (the flipped TASK-026 pins named per prop).
10. **Composite beats** — long-press 40% hold at arbitrary press lengths + release exhale; slow-blink-back present at Best-Friends+, absent below (boundary pinned on the exact adjacent stages); stroke 2nd-in-touch deepening; eating glance-up replaces full reaction; pupil glance within the ≤ 30% clamp.
11. **Budgets** — per-clip max concurrent channels ≤ 8 (worst instant pinned); idle ≤ 3 pins from TASK-027 untouched; suite-wide green; no NEW warnings; budgets re-measured.

## Review Requirements

Fresh adversarial reviewer per CLAUDE.md §10/§33 (independence — not primed; must re-derive the §4.1/§4.3/§6.1/§7.1 tables from the doc BEFORE comparing; try to disprove the coherence matrix with its own adversarial streams; sanctioned mutation bites with sha256-proven restoration; every finding personally verified by the orchestrator before disposition — the standing rule). Review record: `.claude/tasks/reviews/REVIEW-TASK-028.md`.

## Git Requirements

- Branch `feature/EPIC-006-character`. No commit by the implementer. One atomic commit after review approval: `feat(character): TASK-028 reaction vocabulary, state choreography, CharacterReport emission`.

## Status

READY — contract authored 2026-09-10. Fresh implementation agent to be dispatched.

## Implementation Notes

(Implementer fills in: decisions, deviations with doc citations, measurements, test evidence.)

## Reviewer Findings

(recorded in `.claude/tasks/reviews/REVIEW-TASK-028.md`)

## Completion Evidence

(to be recorded: suite counts before/after, budgets, MomoCore 0-byte verification, test evidence)

## Handoff

(to be completed by the implementing agent per CLAUDE.md §28)
