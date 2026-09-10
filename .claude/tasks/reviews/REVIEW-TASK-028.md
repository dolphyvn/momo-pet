# REVIEW-TASK-028 — Reaction vocabulary + state choreography + CharacterReport emission

- **Task**: TASK-028 (`​.claude/tasks/active/TASK-028-reactions-choreography.md`)
- **Reviewed by**: independent adversarial reviewer (fresh agent, Jupiter), per CLAUDE.md §10/§33
- **Date**: 2026-09-10
- **Branch / HEAD**: `feature/EPIC-006-character` @ `283310a` — changeset UNCOMMITTED (8 new sources, 8 new test files, 3 modified sources, 2 modified test files), as required pre-review
- **Method**: spec re-derived from `docs/design/04-character-system.md` (§4.1, §4.3, §6.1, §6.3, §7.1–7.4, §8.4–8.5, §9.2–9.3), `docs/product/02-mvp-prd.md`, `docs/architecture/05-technical-architecture.md` BEFORE reading the implementation; all 8 new sources and all 8 new test files read in full; all modified-file diffs inspected; 6 targeted adversarial stream probes executed against the fold; 2 sanctioned mutation bites (sha256-proven restore); full suite run twice.

## Verdict: CHANGES_REQUIRED

The fold architecture, determinism discipline, digit pins, and test rigor are high quality — but two MAJOR findings are concrete, reproducible breaks of the engine-facing contract (one defeats the engine's documented "settle still completes" intent on a mainstream care flow; one suppresses authored choreography in its most likely firing window). Per CLAUDE.md §10, the task may not commit while CHANGES_REQUIRED.

**Counts**: 2 MAJOR · 3 MINOR · 7 NOTE.

---

## MAJOR findings

### MAJOR-1 — blanketAdjust routed to the exclusive L2 slot cancels the in-flight settle handshake, defeating the engine's warm-reaffirm semantics

- **Evidence**:
  - Routing: `Sources/MomoCharacter/MomoReactionDirector.swift:155–157` routes `.blanketAdjust` to `startL2Clip` → `enter(stateLayer:)`; `enter()`'s displaced-handshake switch (`:278–279`) emits `handshakeCancelled(.settle)` and displaces a running `.settle`.
  - Engine reality: `Sources/MomoCore/InteractionSemantics.swift:357` — a tuck-in during `.settling` mints `blanketAdjust` as a **warm reaffirm**, with the engine's own comment: *"token untouched, settle still completes"*. `Sources/MomoCore/HandshakeMachine.swift:42` — `handshakeCancelled(.settle)` is the preemption edge `settling ──► awake`.
  - Doc: `docs/design/04-character-system.md:308` classes Blanket-adjust as **L3** (1.5 s one-shot); §4.1's L2 contents row (`:261`) does not contain it.
  - Reproduced (adversarial probe ATTACK1): fold `plan(settling, 1.0)` then `plan(blanketAdjust, 2.0)` → `handshakeCancelled(.settle)` at 2.0, stateLayer becomes `react.blanketAdjust`, **no** `settleFinished` ever. The engine transitions settling→awake: the tuck-in dies mid-handshake, then (if a later display-state tick re-fires `.settling`) the settle restarts from 0 — double yawn, ~2× the choreography, and a cancel+finish report pair for one logical settle.
- **Why it matters**: the mainstream tuck-in flow (user re-taps tuck-in while Momo is settling) breaks; the engine consumes a cancellation the engine never intended; the doc's L3 classification is contradicted.
- **Disclosure gap**: impl note 5 lists the settle-cancel paths but never engages the warm-reaffirm consequence; note 11 discusses only blanketAdjust's band classification. `MomoHandshakeTests.settleCancelledByNewerL2` and `settleSurvivesL3` pin neighboring laws but no test exercises blanketAdjust-during-settling (the storm omits it).
- **Fix**: route `blanketAdjust` through the L3 path (`startReaction` — its spec is already fixed-length/non-press/non-cyclical), or special-case: while `stateLayer` is `.settle`, render blanketAdjust additively without displacing the handshake. Re-pin `MomoReactionDirectorTests.rule2L2Crossfade` (which currently uses blanketAdjust as the incoming L2, cementing the wrong routing) and add the settling-stream test.

### MAJOR-2 — Rule 5's glance-up gate over-scopes to ALL L3 reactions; the contract and doc scope it to touch reactions

- **Evidence**:
  - Gate: `Sources/MomoCharacter/MomoReactionDirector.swift:190–194` — while the state slot is the `.eating` clip, **every** arriving L3 key renders as the 0.5 s glance-up (16 keys, including `politelyFull`, `gentleDecline`, `cheer`, `decline`, `nibble`).
  - Contract: TASK-028 file `:37` — *"an arriving **touch reaction** renders as the brief glance-up only"*. Doc: `04-character-system.md:276` — *"a **tap** mid-eat earns only a brief L3 glance-up"*; `:293` — *"taps → glance-up only (rule 5)"*.
  - Reachability: `Sources/MomoCore/InteractionSemantics.swift:225` mints `politelyFull` on feed-while-full — the most likely mid-meal reaction.
  - Reproduced (ATTACK2): fold `plan(eating, 1.0)` then `plan(politelyFull, 2.0)` → a `glanceUp` slot keyed `react.politelyFull`; the authored 1.2 s polite sigh never renders, and the engine later receives `reactionFinished(react.politelyFull)` for a run that displayed a generic glance-up.
- **Why it matters**: the politely-full refusal choreography is suppressed exactly when it should fire (overfeeding during a meal); the render contradicts the plan's identity; the contract's own R-text is violated. The implementation's own disclosure (impl note 9) matches the contract's scoping — the code over-reaches it.
- **Fix**: gate the glance-up branch on the touch family (tapHead/tapBelly/tap/doubleTap/longPress*/stroke*), letting the remaining L3 keys render themselves additively over the meal (impl note 9's additive law already supports this). While re-scoping, key the gate on `displayState.activity == .eating` per the contract (see NOTE-7).

---

## MINOR findings

### MINOR-1 — longPressBelly's slot resolves its end at baseline×tempo (0.9×tempo) while the rendered release is clamped to 0.45 s

- `applyTouchEnded` sets `end = t + spec.duration(tempo:)` (`MomoReactionDirector.swift:484–486`) → hold + 0.9×tempo. The choreography renders the release with `releaseSeconds: min(0.45, duration)` (`MomoReactionClipMotion.swift:77`) → the visible release completes at hold + 0.45 at every tempo. Reproduced (ATTACK3): hold 1.9 → slot end 3.9, motion visually settled ≈3.55, `reactionFinished` lands at 3.9 — a dead tail of ~0.35 s (0.81 s at Drowsy ×1.4) and a report ~0.45 s after the visible exhale. The clip row's two roles collide: the doc's 0.9 is the **rock period** (`:378`), the press-shaped baseline is documented as the **release beat** (`MomoReactionClips.swift:58–62`); the row also claims `tempoScaled: true` while the hardcoded `/0.9` rock (`:236`) and the 0.45 clamp make tempo vestigial for this row.
- **Fix**: split the row into `rockPeriodSeconds` (0.9, doc row) + an authored `releaseSeconds` (0.45), and have the director resolve press ends from the release value the choreography actually renders. Re-pin the authority string to match.

### MINOR-2 — press-shaped slots have no lost-touch-boundary cap: a cancelled press holds forever, never reports, never GC's

- The event vocabulary has no touch-cancel (`MomoReactionDirector.swift:24–25` — only `touchBegan`/`touchEnded`), and system gestures cancel presses without `touchEnded`. Cyclical strokes got `strokeCycleCap = 4` for exactly this hazard (`:67–70`); press-shaped rows got nothing: `end == nil` renders "holding" indefinitely (`MomoReactionOverlay.swift:153`), GC's `end = slot.end ?? .infinity` never reaps it (`MomoReactionDirector.swift:729`), and no report fires (correct for an unfinished press — but the pose sticks). Reproduced (ATTACK4): `touchBegan` + `plan(longPressBelly)` with no boundary → at t = 20 the overlay still holds aperture 0.65; slot retained, unreported. Unbounded slot accumulation across repeated cancelled presses.
- **Fix**: cap press-shaped holds (analogous to `strokeCycleCap`, e.g. resolve as a release at `start + maxHoldSeconds`), or add a `touchesCancelled` event at the seam and document the boundary. Disclose either way.

### MINOR-3 — the L3 queue is dead code and the contract's required queue pin is vacuous

- Slots are only ever created with `start = t` (their fold time — `:227`, `:352–357`, `:364–369`, `:374–379`), so the drop-oldest branch's filter `$0.start > t` (`:324`) can never match and `pendingReactionCount(after:)` (`:410–412`) structurally returns 0 for any post-fold query. The storm test's "queue never exceeds its bound" pin (`MomoReactionDirectorTests.swift:243–245`) therefore cannot fail (ATTACK6: three distinct rapid reactions → pending = 0). The doc's queue model (`04:265` "newer L3 (queue ≤ 2)"; `:268` "the queued L3s either complete … or fade") is unrealized — every arrival supersedes immediately (newest wins). The observable coherence behavior is sound (maxActive L3 = 1, ATTACK6) and the coalescing pins have real teeth — but the contract's required test 4 ("queue never exceeds 2") is satisfied only vacuously, and dead machinery masquerades as a safety property.
- **Fix**: either implement bounded queuing (a superseded-but-queued slot with a future start) or delete the dead branch + accessor and re-word the pin to the honest newest-wins law, recording the §4.1-queue deviation in the task file.

---

## NOTE findings

1. **`longPress` authority cites a nonexistent doc row.** `"04 §6.1 zone-less form, 0.9 s (Watch — no touch tracking)"` (`MomoReactionClips.swift:154`) — the Step-1 re-derivation found no zone-less long-press row in §6.1. The value 0.9 is fine (belly-row digit, in band) but the citation is false, and `authoredDisclosures` cements `longPress` as doc-pinned (`MomoReactionClipTests.swift:204`). Relabel AUTHORED like the `tap`/`stroke` zone-less forms.
2. **Mixed-speed crossfade on settle-displaces-play.** `replaceStateLayer` gives the incoming L2 the 0.12 s L3-preempt entry (`MomoReactionDirector.swift:307`) while the outgoing play still fades over 0.35 (`MomoReactionOverlay.swift:20–23`, `fadeSeconds(for:)` `:738–740`) — an L2→L2 transition handled differently from `enter()`'s 0.35/0.35. Rule 2's band letter is honored by the outgoing half only; pick one semantic and comment it.
3. **Same-touch stroke predicate edge.** `lastTouchEnded < slot.start` (`:179–181`) misclassifies when a boundary lands between `touchBegan` and the stroke plan's mint (e.g., prior tap ends 8.05, new touch begins 8.07, stroke mints 8.1 → a second stroke deepens although the touch is fresh). Compare against the live press's start instead. Narrow cosmetic window; uncovered by tests.
4. **applyShown re-arms a settle from stale display state.** `:610–611` rebuilds `.settle(start: t, reported: false)` on return if the engine's last-known wakefulness is `.settling` — after the engine already consumed `handshakeCancelled(.settle)` for the pre-hide instance. Defensible as render-what-you're-given, but the engine-side consumption of a cancel-then-`settleFinished` pair for one logical settle is unverified — the disposition should confirm TASK-015's handlers tolerate it.
5. **Drowsy round is 14.4 s against §7.1's 15–30 floor.** 2.4 + 8.0 + 4.0 (test pins 15.4 from t = 1.0, `MomoHandshakeTests.swift:237`). Contract R7 mandates the drowsy follow be SHORTER, so the value is defensible — record the doc tension in the task file.
6. **Static always-on sparkles at rest are pre-existing, not a TASK-028 regression.** The old prop slots rendered at the builder's default `opacity: { _ in 1 }` (`RigLayerTree.swift:152`); the new opacity readers return 1 at `.rest` — rest rendering is unchanged. R9's own letter ("everywhere else the prop channels are IDENTITY") holds; sparkle channels animate only in the payoff and moments (`MomoReactionPropsTests.specChannelAgreement` pins no clip claims them). The §8.5 "sparkles moment-scoped" tension (`:146`, `:533`) belongs to the TASK-025/026 room-scene design — flag to the disposition as a doc-clarification candidate, not a TASK-028 defect.
7. **Glance-up gate keys on the state-clip slot, not `activity == .eating`.** `:190–191` checks `stateLayer == .clip(.eating)`; the contract (`:37`) says `activity == .eating`. In the window where activity is `.eating` but the clip slot is empty (clip completed, engine hasn't re-minted), arriving taps render full reactions. Fold into MAJOR-2's fix.

---

## Verification appendix

### Re-derived doc numbers vs implementation (Step 1 — before reading sources)

| Row | Doc value | Impl | Authority |
|---|---|---|---|
| tap·head | 0.4 s (§6.1) | 0.4 ✓ | doc |
| tap·belly | 0.45 s (§6.1) | 0.45 ✓ | doc |
| double-tap | 0.7 s (§6.1) | 0.7 ✓ | doc |
| long-press·belly (rock) | 0.9 s (§6.1 :378) | 0.9 ✓ | doc (release beat 0.45 AUTHORED — see MINOR-1) |
| long-press·head | press-length (§6.1) | pressShaped, 0.6 release ✓ | AUTHORED in band |
| stroke·head / ·belly (per cycle) | ~1.2 / ~1.0 (§6.1) | 1.2 / 1.0 ✓ | doc |
| stir | 0.8–1.2 (§4.3), tempo-exempt | 1.0, tempoScaled=false ✓ | AUTHORED mid, cited |
| politelyFull / gentleDecline | 1.2 / 1.0 (§4.3 :304) | 1.2 / 1.0 ✓ | doc |
| sleepyNibbles | 3–4 (§4.3) | 3.5 ✓ | AUTHORED mid, cited |
| settling | 2.5–3.5 (§4.3 :307) | 3.0 ✓ | AUTHORED mid, cited |
| blanketAdjust | 1.5 (§4.3 :308) | 1.5 ✓ | doc digit — class L3 per doc; impl routes L2 (MAJOR-1) |
| eating | 2.5–4.0, 2–3 bites (§7.1 :293) | 3.2, 3 bites at 0.4/1.4/2.4 ✓ | AUTHORED, cited |
| waking | 1.8–2.5 (§7.1) | 2.0 ✓ | AUTHORED mid |
| play | 15–30 (§7.1 :294) | worst 22.4; drowsy 14.4 (NOTE-5) | AUTHORED, cited |
| quest sparkle / celebration | 0.9–1.2 / 1.6–2.0 (§4.3) | 1.0 / 1.8 ✓ | AUTHORED mids, cited |
| greetings | ≤ 2.0 AUTHORED (contract R5) | 1.6/1.2/2.0/1.4 ✓ | AUTHORED, disclosed |
| L1 fade / L3 preempt fade | ≤ 100 ms / ≤ 120 ms (§4.1) | 0.1 / 0.12 ✓ | doc |
| L2 crossfade | 300–400 ms (§4.1, §7.1) | 0.35 ✓ (inside band; see NOTE-2) | doc band mid |
| coalesce window / classes | 500 ms; 1–2 full, 3–4 abbrev, 5+ coalesced (§4.1 :274) | 0.5; count≤2 full, ≤4 ×0.5, 5th coalesced 0.45 once, 6+ absorbed ✓ | doc |
| tempo | Drowsy ×1.4 (§3.3 doc-literal) | 1.4 ✓ | doc |
| pupil clamp | ≤ 30 % eye radius (§2.4) | clampedPupilOffset, pinned digit ✓ | doc |
| budgets | idle ≤ 3 / reactions ≤ 8 / play 2 groups (§7.4 :475) | per-clip ≤ 8 pinned (eating = 8 exactly); two-group caps pinned per phase ✓ | doc |
| celebration overshoot | ≤ 8 % single soft (§7.2) | `isSingleSoftOvershoot` judged ✓ | doc |
| yawn | 1.4 (§4.3) | `MomoCurves.yawnSeconds` reused ✓ | doc |

### Adversarial probes (temporary file, deleted after the run)

- ATTACK1: blanketAdjust-during-settle → `handshakeCancelled(.settle)` at the cut, no `settleFinished` (MAJOR-1).
- ATTACK2: politelyFull-during-meal → glance-up slot keyed `react.politelyFull` (MAJOR-2).
- ATTACK3: longPressBelly hold 1.9 → slot end 3.9 vs motion settled ≈3.55; report at 3.9 (MINOR-1).
- ATTACK4: press with no boundary → still holding aperture 0.65 at t = 20; unreported, un-reaped (MINOR-2).
- ATTACK5: coalescer boundary — second tap at exactly +0.5 expires (fresh window); at +0.499 coalesces (count 2). `< 0.5` semantics confirmed.
- ATTACK6: three distinct rapid reactions → 3 slots, `pendingReactionCount = 0` (MINOR-3's vacuity), maxActive L3 = 1.

### Mutation bites (sanctioned; sha256-proven)

| Bite | Mutation | Named test that failed | Restore proof |
|---|---|---|---|
| A (clip-table digit) | `tapBelly` baselineSeconds 0.45 → 0.46 (`MomoReactionClips.swift`) | "Baseline durations pin the doc rows digit-for-digit" — `Expectation failed: (baselineSeconds → 0.46) == (seconds → 0.45)` | sha256 restored to `be812cd6ff8458eb…f356a3` |
| B (coherence law) | `abbreviationFraction` 0.5 → 0.4 (`MomoReactionDirector.swift`) | "Rule 3: two identical arrivals run full; 3–4 run abbreviated; 5+ coalesce once per window" — expectation failed at `MomoReactionDirectorTests.swift:125` | sha256 restored to `151e95126b73f09c…51ce1e4` |

Both files byte-identical to pre-bite state after restore (verified by sha256). Temporary attack file deleted; working tree contains only the implementation's changeset.

### Commands + counts

- `swift test` (baseline reproduction, pre-review): **779 tests / 79 suites passed**, exit 0.
- `swift test` (final, after bites restored): **779 tests / 79 suites passed**, exit 0. Matches the implementer's claim (baseline 721/72 → +58 tests / +7 suites).
- `git diff --stat Sources/MomoCore Sources/MomoKit` → **empty** (frozen modules untouched).
- Greps: no `default:` in any of the 8 new sources (exhaustive switches over the 21-key enum in both the spec table and the choreography); no `Date(`/`UUID()`/`Timer` in any new source (determinism holds; twin-equality suite green in both full runs).

### What held up under attack (credit where due)

The fold architecture (pure, timeline-injected, twin-equal), the exactly-once report discipline (storm-wide identity+instant uniqueness over every kind: reactionFinished, playRoundFinished, handshakeCancelled(.settle)/(.play), settleFinished, wakeFinished, momentFinished), the hide/show epoch matrix (cancel-on-hide, replay-from-0, stall-while-hidden), the play pacer's adversarial streams with exact-instant pins (never-moves 19.4, rest-mid-round 17.4, drowsy 15.4, inside-grace no-freeze), the ≤ 30 s structural bound via the sample-less prune, the two-group caps per phase, the coalescing class shapes with exact report instants, the hold-length sweep (0.1–5.0 s, exactly-once each), the bond-gate boundary pinned on the exact adjacent stages, and the 30 % pupil clamp to the digit are all real, falsifiable, and green.

## Recommended disposition

1. Fix MAJOR-1 (reroute blanketAdjust to L3/additive + re-pin `rule2L2Crossfade` + add the settling stream test) and MAJOR-2 (touch-family gate + `activity == .eating` keying, NOTE-7).
2. Address MINOR-1/2/3 in this task or as immediately-following small tasks with the review loop re-run on the delta.
3. Record NOTE-1/2/3/5/7 in the task file; confirm NOTE-4 with the TASK-015 engine handlers; carry NOTE-6 to a doc clarification.
4. Re-run the full suite and a fresh delta review before commit.
