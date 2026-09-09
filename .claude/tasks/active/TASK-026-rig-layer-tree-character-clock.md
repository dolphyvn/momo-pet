# TASK-026 — MomoRig layer tree + CharacterClock + LOD tiers (04 §2, §7.4, §9.5; delivery-plan TASK-026)

## Parent Epic
EPIC-006 — Character Rendering (MomoCharacter), task 2 of 6 (size L). Depends on TASK-025 (DONE — commit `7681498`: the 44 committed `Path` constants + evidence harness) and TASK-012 (the §9.2 interface types, landed in `Sources/MomoCore/CharacterInterface.swift`).

## Objective
Make the rig ALIVE-able: compose TASK-025's pre-built geometry into the §2.2 transform-only layer tree under a single pausable CharacterClock, with per-surface LOD tier selection — the animation foundation every later EPIC-006 task drives:
1. **The layer tree (04 §2.2):** the full rig's 21 constants composed into the seven §2.2 layer groups (Body, Head, Ears, Tail, Eyes, FaceDetails, FrontPaws) + the interaction-scoped props row (food, blanket, 2 sparkles), every part carrying exactly its §2.2 animatable channels, colors applied from the §8.4 token slots (`MomoCharacterPalette` — the first color application of the geometry; R4). At rest it renders the Direction-C rest pose exactly as TASK-025's evidence shows it.
2. **The motion model (pure) + CharacterClock (R3, §9.5):** a headless-pure channel model (transform values only — R1) driven by ONE pausable clock; `pause` zeroes the timeline (scenePhase ≠ active / AOD ⇒ one call, §7.4 rule 1); `resume` restarts from zero — no backlog replay (§5.3); every channel pausable individually, and everything pausable by the single call.
3. **LOD tiers (§2.1 stage table, §7.4 rule 5):** full / LOD-glance / glyph selection as a pure, deterministic function of the render surface — iPhone full; Watch foreground glance (NEVER full — pinned); AOD/complication glyph (static).
4. **The §7.2 curve discipline as pinned constants (O7 discharge):** spring damping band 0.75–0.85 (soft overshoot only), touch-reaction overshoot ≤ 15 %, celebration overshoot ≤ 8 % + the absolute "no bouncing-ball loops / repeated bounce anywhere" law — landed now as test-pinned constants so TASK-027/028 curve helpers consume them, never restate them.
5. **Proof of the aliveness plumbing:** one reference ambient channel — the Content breath (§7.1: 4.6–5.2 s cycle, bottom-anchored body scaleY 1.5–2.5 %, pure sine per §7.2) — wired clock → model → view end-to-end as the executable proof of R1/R3 (a stopped clock visibly freezes it). Mood-band-specific breath rates and all other choreography are TASK-027+.
6. **Evidence at true stage sizes (O2/O3):** size-ladder renders (full rig at iPhone-stage scale, glance at watch-stage scale, glyph at true 24–32 pt) so the calm-vs-drowsy eye margin (O2) and tail legibility (O3) are judged on COMPOSED output, not only TASK-025's flat canvas.

## Context
- **Codebase state:** branch `feature/EPIC-006-character` @ `7681498` (+ the dispatch docs commit); baseline `swift test` = **549 tests / 59 suites green**. `Sources/MomoCharacter/` holds the TASK-011 token/copy layer + the TASK-025 generated geometry: full rig 21 (`MomoRig.body`, `bellyPatch`, `head`, `earLeft/Right`, `tail`, `eyeLeft/Right{Base,Pupil,Lid}`, `mouthNeutral/Eat/Refuse`, `cheekLeft/Right`, `pawLeft/Right`, `hindFootLeft/Right`), LOD-glance 11 (`lod*`), glyph 3 (`glyphSilhouette`, `glyphEyeLeft/Right`), room 5 (`MomoRoom.floor/rug/window/pomString/pomPuff`), props 4 (`MomoProps.food/blanket/sparkleA/sparkleB`). `MomoCharacterPalette` carries the 8 §8.4 token slots (`momo.fur.base` … `momo.sparkle`) as `MomoColorToken` (light+dark).
- **Interface types exist (TASK-012):** `CharacterDisplayState` (moodBand / energyBand / bondStage / wakefulness / activity / satietyHint / momentRequest), `ResponsePlan`, `CharacterReport`, `CharacterMoment`, `ReactionID`/`HapticID`, `HandshakeKind`. TASK-026 consumes `CharacterDisplayState` as the rig view's input (rendered at its rest interpretation; band-specific expression mapping is TASK-027).
- **Authority split (04 §9.1/§9.3):** the engine owns what/when, the character owns how it looks (durations/curves — §7.1–7.2 normative), presentation owns whether it runs (scenePhase/AOD observers). TASK-026 builds the character side + the one-call pause API; the SwiftUI adapter maps scenePhase → that single call (structural pin here; device-level observer verification routes to EPIC-007/EPIC-008 per §9.3). AOD is a Watch surface concern (EPIC-008) — the glyph tier being static IS the AOD posture.
- **Normative tables this task implements:** §2.2 layer/channel table (channels per part — binding); §7.1 master timing table (the breath rows + general bounds); §7.2 curves; §7.4 rules 1–5; §9.5 pause authority; §2.1 surface→stage mapping. INV-1–INV-8 (§2.5) must be preserved structurally (two eyes upper-forward; head-above-body; one creature; state never by color; worst visual state is sleeping).
- **What TASK-026 does NOT build (scope control §22):** no idle sequencer/scheduler/variants (TASK-027); no mood/energy/bond expression poses or §3.1 lower-lid pose shapes (TASK-027 — O6 routing); no reactions, choreography, play pacing, or `CharacterReport` emission (TASK-028); no Reduce Motion mapping (TASK-029 — but per-channel gating must exist so static poses are reachable); no touch handling / §2.3 zone partition / §2.4 eye-follow LOGIC (EPIC-007 surfaces — the pupil channel exists, the follow logic routes); no Watch app surfaces (EPIC-008 — tiers are data + pure selection here); no room composition into a Home layout (EPIC-007); no §7.4 rule 6 device-energy obligations (VERIFY-AT-BUILD register, EPIC-007/008 device tasks); no catalog/copy changes; NO changes to the generated geometry files or the pipeline (read-only consumers — a pipeline touch would be scope creep).

## Requirements
1. **CharacterClock (R3, §9.5, §7.4 rule 1):** a single pausable timeline with an INJECTED time source (deterministic/headless-testable; no ambient `Date()` — engine-era discipline), `pause()` zeroes the accumulated timeline, `resume()` restarts accumulation from zero (no backlog replay), idempotent double-pause/double-resume, elapsed frozen while stopped (query at two later real times ⇒ same value), observable running/stopped state. One instance gates ALL channels — "pause everything" is one call. The clock itself is SwiftUI-independent (pure type; the view observes it).
2. **Pure motion model (R1/R2):** a transform-only channel model per §2.2 — body scaleY/rotation/position; head rotation/position/scaleY; per-ear rotation/scaleY; tail rotation/scaleY; eyes lid scaleY + pupil offset (clamped ≤ 30 % of eye radius, §2.4's clamp law) + a lower-lid pose crossfade slot (the §3.1 pose SHAPES are TASK-027; the slot exists here); mouth pose selection/crossfade across the 3 pre-built poses; cheek opacity; paw position/rotation; prop position/rotation/opacity. Channels are plain values/functions of clock time + display state — NO SwiftUI, NO `Path` construction, NO per-frame geometry (R1); parts never detach or become particles (R2). Per-channel enable/disable exists (TASK-027 choreography + TASK-029 static poses need it); the rest pose is the authored geometry defaults (zero transforms).
3. **Rig view (SwiftUI, token-colored):** composes the 21 full-rig constants into the §2.2 groups in correct topology (INV-1/INV-2), colors ONLY via `MomoCharacterPalette` slots (R4/INV-5 — static token application, never state-driven color), props as channel-bearing layers, `CharacterDisplayState` as input, LOD tier as parameter, and maps scenePhase → the ONE clock pause/resume call. Renders the rest pose correctly with a STOPPED clock (paused ⇒ static — the pause contract made visible).
4. **LOD tiers (§2.1 + §7.4 rule 5):** a pure tier type + selection function: iPhone → full; watch foreground → glance; AOD/complication → glyph. The glance tier renders the 11 `lod*` constants (their TASK-025 pins carry the no-pupil-split/simplified-paws reductions); the glyph tier renders the 3 glyph constants as a static snapshot. **Watch-never-full is a named pin.**
5. **Curve discipline constants (O7):** a small constants home pinning §7.2 verbatim: damped-spring damping 0.75–0.85 (soft overshoot only), touch overshoot ≤ 15 %, celebration overshoot ≤ 8 % + no repeated bounce, settle/sleep ease-in decelerating into stillness, breathing = pure sine (no easing artifacts across the loop boundary), plus the absolute no-bounce-loops law stated as the rule later tasks' reviewers check. Test-pinned — the TASK-020 style: constant-coupled tests follow doc changes; raw-literal pins carry the value teeth (incl. the Content breath 4.6–5.2 s / 1.5–2.5 % figures).
6. **Discipline scans (R1/R4 executable):** rig view + model files contain no `Path {` construction or path mutation (paths come only from the generated namespaces — scan with non-vacuity both directions, TASK-011 precedent) and no hex/RGB outside the two palette files (extend the existing scans to the new files).
7. **Evidence (§25-honest):** committed size-ladder renders under `docs/evidence/character/` — full rig composed at iPhone-stage scale, glance at watch-stage scale, glyph at true 24–32 pt — produced by a committed, re-runnable harness (extend the TASK-025 `render_evidence.swift` approach or a documented equivalent). The reviewer must be able to judge: the composed rabbit reads as ONE creature (R2), eyes calm-not-drowsy at stage sizes (O2), tail legible (O3).
8. **Suite hygiene:** final `swift test` green ×2, zero new warnings; standing scans green with no new exemptions; house file discipline (200–400 lines typical, 800 max — split model/view/clock files naturally).

## Files / Areas Likely Affected
- NEW `Sources/MomoCharacter/`: the clock, the motion model, the rig view(s), the LOD tier type, the curve-discipline constants (names follow the module's plain style; §8.4 namespace discipline applies to anything pose/clip-like — none required yet).
- NEW `Tests/MomoCharacterTests/`: clock tests, motion-model/channel tests, LOD-selection tests, curve-discipline pins; discipline-scan extensions.
- POSSIBLY extended `Tools/character-pipeline/render_evidence.swift` (evidence only) + NEW renders under `docs/evidence/character/`.
- NOT affected: generated geometry files + the pipeline proper, MomoCore, MomoKit, apps, catalogs, token files (read-only consumers).

## Dependencies
- TASK-025 (constants + evidence harness), TASK-012 (interface types), TASK-011 (tokens/palette).
- Downstream: TASK-027 drives the model from the idle sequencer; TASK-028 layers reactions/choreography; TASK-029 maps Reduce Motion onto the per-channel gating.

## Constraints
- Fresh agent, Jupiter, no commit rights; §25 honesty on every claim; zero new runtime dependencies; R1–R4 binding; INV-1–INV-8 preserved; scope control §22 (the routed items above are recorded, never silently dropped); test-first for the pure surfaces (clock, model, LOD, curve constants).

## Acceptance Criteria
1. CharacterClock: zero-on-pause, resume-restarts-from-zero, single-call global gate, idempotence, frozen-while-stopped — all pinned headlessly.
2. Motion model: every §2.2 channel present (name-for-name pin), transform-only, per-channel gating, rest pose == zero transforms, pupil clamp ≤ 30 % eye radius.
3. Rig view composes all 21 full-rig constants + 4 props with palette tokens only (zero hex — scans green, non-vacuous), correct §2.2 topology, static under a stopped clock, scenePhase → the one call.
4. LOD selection pure + pinned (watch-never-full); all three tiers render their TASK-025 constant sets (full 21 / glance 11 / glyph 3).
5. §7.2 curve discipline pinned as constants (damping band, overshoot caps, sine breath, no-bounce law) — O7 discharged with teeth.
6. Size-ladder evidence committed + re-runnable; the O2 eye-margin and O3 tail judgments recorded (accepted, or refinement-routed with reasons).
7. `swift test` green ×2 (exact counts recorded vs the 549/59 baseline), zero new warnings, no new scan exemptions.

## Required Tests
- **Clock:** pause-zeroes; resume-restarts-from-zero; double-pause/double-resume idempotence; frozen-while-stopped; single-gate-stops-all-channels (a driven breath channel freezes exactly when the clock does); resume-without-pause defined behavior.
- **Motion model:** channel inventory pin vs §2.2 (group-by-group); transform-only (no `Path` in the model's public surface); pupil clamp bound; rest pose == zero; per-channel gate stops exactly that channel.
- **LOD:** the §2.1 selection table as pins incl. watch-never-full; tier↔constant-set mapping (full 21 / glance 11 / glyph 3 — reuse the TASK-025 inventory catalog).
- **Curve discipline:** §7.2 values as raw-literal pins; Content breath period/amplitude pins; sine purity on the breath channel (loop-boundary continuity).
- **Discipline scans:** no-Path-construction + hex-confinement over the new files, non-vacuous both directions.
- **Budgets:** re-measure the §8.3 buckets (expected unchanged — new files are hand-written code OUTSIDE the art buckets per the O8 basis note; record actuals anyway).

## Review Requirements
- Independent fresh reviewer (CLAUDE.md §10/§33), adversarial, unprimed:
  - Re-derive the §2.2 channel table BEFORE comparing to the implementation (group-by-group, name-for-name).
  - Try to disprove R1: hunt for per-frame Path construction, dynamic geometry, or any non-transform animation in the rig/view/model code.
  - Try to break the clock contract: pause/resume interleavings, resume-without-pause, ticks after pause, a channel updated after pause — each attempted defect must hit a named pin.
  - Verify the §7.2/§7.1 pins against the doc values digit-for-digit; construct a "bouncing" curve and show exactly what rejects it.
  - Mutation bites with sha256-proven restores (exactly two sanctioned): one clock bite (e.g., resume not zeroing → the named pin fails) and one LOD bite (e.g., flip the watch mapping → watch-never-full fails).
  - Verify token application: every colored part reads a palette slot; hex/RGB grep over the new files.
  - Judge the size-ladder evidence against §1.3/ADR-001/INV-5/INV-6 at true sizes; specifically adjudicate O2 (eyes calm vs drowsy — the TASK-025 review's drowsy read) and O3 (tail legibility) — accept or route with reasons.
  - Review file: `.claude/tasks/reviews/REVIEW-TASK-026.md`.

## Git Requirements
- No commit by the implementation agent. Orchestrator commits after review disposition: `feat(character): TASK-026 rig layer tree, CharacterClock, LOD tiers` — atomic, TASK-ID included.

## Status
READY — contract authored 2026-09-09; impl agent dispatched

## Implementation Notes
(implementation agent fills)

## Reviewer Findings
(reviewer fills)

## Completion Evidence
(filled at cycle close by the orchestrator)
