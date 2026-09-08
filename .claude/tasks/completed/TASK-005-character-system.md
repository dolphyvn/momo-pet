# TASK-005 — Step 4: Character System

## Parent Epic
EPIC-001 — Product Definition & Delivery Plan

## Objective
Define Momo the character: visual direction, anatomy constraints, expressions, animation/state inventory, interaction→reaction map, motion timings, and asset requirements (project.md §40 Step 4, §30 items 12, 14–16).

## Context
Momo must feel alive even untouched (§4): idle, blinking, breathing, looking around, plus state animations (happy, excited, sleepy, sleeping, eating, playing, walking, surprised, affection, celebrating, low energy). Motion is a core capability, not decoration (§19); subtle over excessive; battery-conscious. Visual language: warm off-white, soft pastels, rounded, minimal (§18). Reduce Motion must degrade gracefully (§20). Phase 1 = ONE production-quality pet.

## Requirements
Read `CLAUDE.md`, `project.md`, `docs/product/01-product-review.md`, `docs/product/02-mvp-prd.md`, then produce `docs/design/04-character-system.md` containing:
1. Visual direction (silhouette-first description; proportions; what makes it read "cute × calm × premium" — spec does not fix a species; recommend one and justify, decision flag if truly product-defining)
2. Character anatomy constraints (rig/parts model that SwiftUI/vector animation can actually implement; what may never change)
3. Expression inventory mapped to Mood/Energy/Bond (the only three user-facing dimensions, §5) — color-independent state communication (§20)
4. Animation state inventory: every state from §4 with trigger, duration, loop behavior, interruption rules (can a blink be interrupted by a tap?)
5. Idle behaviour choreography (how idle feels alive without distraction; variation rules; §8's "controlled variation" with injectable randomness)
6. Interaction→reaction map (head/belly/touch gestures → reactions, per §4)
7. Motion timings & curves (breath cycle, blink rate, transition durations; Reduce Motion fallbacks per §20)
8. Asset requirements & production plan (vector/SVG/Lottie-vs-SwiftUI-native tradeoff; size budgets; naming convention; what Phase 1 actually ships)
9. Character behaviour variance spec (how the Pet State Engine (§23) requests animations; the contract between this document and TASK-006)
Rules:
- Every animation must state its battery/performance consideration (§33).
- No audio design required in Phase 0 unless trivially scoped; note as OPEN-DECISION if it matters.
- Phase 1 only: one pet, no outfits/seasonal content (those are Phase 3, §27).

## Files / Areas Likely Affected
- Creates `docs/design/04-character-system.md`

## Dependencies
- TASK-003 (DONE required). Runs in parallel with TASK-004 (different file, no overlap).

## Constraints
- Jupiter model, fresh agent, no commit by agent.

## Acceptance Criteria
- All 9 sections present; every §4 state covered with trigger/duration/interruption; interaction map consistent with TASK-004 flows; Reduce Motion handled; asset plan is implementable with a SwiftUI-first approach and names a concrete recommendation.
- Review verdict ≥ APPROVED_WITH_MINOR_NOTES.

## Required Tests
- Not applicable (document). Independent review agent required.

## Review Requirements
- Fresh reviewer verifies: §4 state coverage, feasibility of every animation in SwiftUI/vector terms, interruption rules coherence, battery statements, philosophy compliance (subtle, not noisy). Record in `.claude/tasks/reviews/REVIEW-TASK-005.md`.

## Git Requirements
- Commit (orchestrator, post-approval): `docs(design): TASK-005 character system specification`

## Status
DONE (REVIEW-TASK-005: CHANGES_REQUIRED → fresh fix agent applied all 19 findings → fresh verifier ALL_FIXES_VERIFIED → APPROVED. Committed `docs(design): TASK-005 character system specification` as `ce84811`, pushed.)

## Implementation Notes
- (agent fills in)
- 2026-09-08 — Executing agent (fresh Jupiter, TASK-005). Produced `docs/design/04-character-system.md` (~1 doc, all 9 required sections + tone guide §10 + audio scope decision §11 + traceability/handoff appendices). NOT committed (per constraints). Status line unchanged.
- **§1 Visual direction (E2 gate — owner picks, nothing locked):** three fully-specified directions — A "Loaf Cat" (familiar warmth, genericness risk), B "Mochi Spirit" (max ownability + cheapest rig + best glance legibility, weak ear/tail channel), C "Round Rabbit" (ear-based posture expression, crepuscular behavior fits morning/evening energy model). **Recommended: C**, rationale in §1.4; fallbacks noted. Sections 2–9 written direction-agnostic so NO downstream rework regardless of the owner's pick.
- **§2 Anatomy:** 1000×1000 normalized design grid (bottom-center anchor); ~17-part transform-only rig; two-zone touch partition at y=550 (head/belly, no dead zones, testable); eye-follow = clamped pupil offset (gain 0.18, max 30% eye radius) + trailing head tilt; 8 invariants (INV-1..8) incl. "state never by color", "worst visual = sleeping", transform-only motion.
- **§3 Expressions:** mood carries facial warmth (4 PRD bands; Low defined but reserved/not produced — PRD floor 25), energy modulates tempo/posture (lower-energy wins tempo, higher mood wins warmth), bond changes reaction latency + greeting quality + unlocked variants only (never resting state). VoiceOver formula + grayscale-legibility review check.
- **§4 States:** priority classes L0–L4 with an 8-rule interruption matrix (blink interruptible by anything, ≤100 ms fades; sleep accepts only settling/waking; rapid-pat coalescing implements FR-5 AC-3 softening). FR-4 nine-state contract tabled with trigger/duration/loop/interruption/battery per row + 12-reaction vocabulary + full 15-state §4 mapping (11 shipped, 4 explicitly deferred: excited, walking, surprised, full celebration).
- **§5 Idle choreography:** pure-function sequencer, seed = hash(petID, localDay, choreographyEpoch) → day-stable, cross-day variable (FR-4 AC-1); blink/look-around/micro-motion scheduler params; aliveness floor fallback (degrades to breath+blink, never frozen).
- **§6 Interaction map:** 7 distinct gesture×zone reactions; full state-gating table mirroring PRD §4 matrix incl. warm "politely full" refusal spec; "Drifting Pom" play round PROPOSED for TASK-004 sign-off; Watch pat spec.
- **§7 Timings:** master table (breath 3.8–8.0 s per band, blink N(6,2) s, crossfades 300–400 ms, celebrations ≤2 s); curve rules (no bounce loops — childish-pole tripwire); full Reduce Motion static-pose mapping (D16); 6 standing battery/perf rules incl. single-pausable-clock + transform-only + scheduled-not-polled (TR3/NFR-2).
- **§8 Assets:** pipeline comparison → **RECOMMENDED: SwiftUI-native parametric vector rig** (generated Swift Path constants via repo-local build-time script; zero runtime deps — Lottie rejected on eye-follow/dynamic-color/AOD/dependency-posture grounds, frames fail 60 MB budget). Budgets: art ≤1.5 MB download contribution (NFR-4 headroom huge), naming convention (ReactionID namespace = clip names; token slots for TASK-004 palette), Phase 1 manifest (~14 poses, 12 reactions, 9 states, 6 idle variants, room, 5 props, 4 moments).
- **§9 Engine↔character contract (TASK-006 intake, §9.6 checklist):** engine owns what/when (ResponsePlan per PRD §4 matrix — character never decides warm/cold), character owns how (all durations, §7 tables normative), presentation owns pause (single CharacterClock; engine unaware). Event-driven handshakes (settle/wake/play) with idempotent completion reports; day-stable seeded RNG + injected clock; open engine decisions flagged: satiety window value, backgrounding-mid-play rule, play-effect application point (proposed: round end).
- **§10 Tone guide:** 8 voice rules (third-person name-led, ≤8 words, wish-framing, copy-surface restraint: no text on micro-reactions); FR-12 guardrails as 7-row do/don't table + banned-vocabulary hard list; 40 sample lines (10 × morning/day/evening/night, all guilt-free) seeded for String Catalog `momo.line.<slot>.<nn>`.
- **§11 AUDIO SCOPE DECISION: NO audio in Phase 1** (calm identity, zero asset/session cost, haptics suffice) → **FR-19 sound toggle is OMITTED**; Settings = rename, haptics, erase, About. Revisit criteria recorded (Phase 2+, opt-in ambient, never touch chirps).
- **Consistency with TASK-004:** TASK-004 ran in parallel (no doc existed at execution time); consistency flows through PRD §4 normative matrix; 5 explicit reconciliation handoffs listed in Appendix B (zones/VO element, pom proposal, color tokens, copy surfaces, glyph-not-wired).
- All hard constraints honored: battery note on every animation; subtle-over-excessive rules throughout; Phase 1 = one pet, no outfits/seasonal (INV-8, §8.5).

## Reviewer Findings
- REVIEW-TASK-005 (fresh independent agent): **CHANGES_REQUIRED — 3 MAJOR + 8 MINOR + 8 NITPICK**, full record in `.claude/tasks/reviews/REVIEW-TASK-005.md`.
  - MAJOR-1: §6.2 tuck-in gated by energy band, contradicting FR-8 AC-1's clock gate (20:00+) — modal evening case undefined-or-wrong.
  - MAJOR-2: §10.1 rule 7 ("no text on micro-reactions") contradicted TASK-004's committed UX-8 (VoiceOver spoken reaction lines) and omitted M2/M3 surfaces.
  - MAJOR-3: §9 handshakes lacked a preemption path — "tuck in, then feed" strands the engine's state machine (no report ever arrives).
  - 8 MINOR: play-effect application stated twice/conflicting; energy VoiceOver phrases; breath rig realism; canvas-action set; token-value routing unrouted; §10 rules 1/3 exceptions; Watch pat state-blind; UX-13 stale wording.
  - 8 NITPICK: §-pointer, count basis, "N2" label, night-window parenthetical, visual-half clauses, E7/E10 footnote, deferred-rows footnote, INV-7 wording.
  - Reviewer also verified: 15/15 state coverage; 8×7 interruption matrix; E2 gate INTACT in both directions; tone audit — 0 violations across 40 lines; both-direction Appendix B reconciliation.
- Fix pass: fresh fix agent `task-005-fixer` applied all 19 under orchestrator rulings (MAJOR-2 option a; MAJOR-3 cancellation report; MINOR-3 option b; pom withdrawn to room decor per committed UX-3; §6.3 rewritten onto the three-phase shell).
- Verification: fresh verifier `task-005-verifier` — **ALL_FIXES_VERIFIED**; regression sweeps clean; both engine-strand scenarios now defined; 3 fixer judgment calls independently ACCEPTED. Disposition table in REVIEW-TASK-005.md. Final: **APPROVED**.
- Residual non-blocking observations routed to TASK-006 intake: OBS-1 (03:428 template "has {energy phrase}" vs 04 §3.5 verb-phrase slot — FR-20 audit string agrees verbatim, the actual AC); OBS-2 (rule-2 12-word max vs M2 banner ~13 words — exempt banner or scope rule 2 to visual lines).

## Completion Evidence
- Commit: `ce84811` — `docs(design): TASK-005 character system specification` (pushed to origin/main). Note: the rename in `ce84811` captured this file's pre-task bootstrap content because `git mv` moves the index blob; the true record below was completed in the follow-up orchestration commit.
- Push: main → origin — success (`40c4b77..ce84811`).
- Deliverable: `docs/design/04-character-system.md` (~750 lines, §1–§11 + Appendices A/B).
- Review record: `.claude/tasks/reviews/REVIEW-TASK-005.md` incl. orchestrator disposition + verification verdict.
- Tests: not applicable (document); independent review per contract §10 — completed with verification pass.

## Handoff

### Completed
All 9 required sections + tone guide (§10) + audio scope decision (§11, NO Phase 1 audio — FR-19 toggle omitted) + appendices. Post-review: clock-gated tuck-in, accessibility-only react-line class, handshake cancellation, unified play-effect point, UX-3-conformant play round (pom → room decor), 4-prop manifest, direction-agnostic §2–9.

### Files Changed
- `docs/design/04-character-system.md` (new)
- `.claude/tasks/reviews/REVIEW-TASK-005.md` (new)
- `.claude/tasks/active/TASK-005-character-system.md` → `completed/` (this commit)
- `.claude/tasks/status.md`, `.claude/tasks/epics/EPIC-001-product-definition.md`

### Tests Run
Not applicable (document task) — independent review + verification pass instead.

### Test Results
REVIEW-TASK-005: CHANGES_REQUIRED → ALL_FIXES_VERIFIED → APPROVED.

### Known Issues
- OBS-1/OBS-2 (non-blocking) → TASK-006 intake.
- E2 owner pick (A Loaf Cat / B Mochi Spirit / C Round Rabbit — C recommended) still pending; §2–9 are direction-agnostic so no rework regardless of pick.

### Decisions Made
- NO Phase 1 audio (FR-19 toggle omitted; Settings = rename, haptics, erase, About) — within delegated authority per FR-19, reviewer concurred.
- SwiftUI-native parametric vector rig (Lottie rejected) — VERIFY-AT-BUILD items marked.
- HandshakeKind includes `.wake` for enum totality (deliberately dead case).
- Play round = TASK-004's committed UX-3 fingertip-follow shell governs; toy-led proposal withdrawn.

### Reviewer Status
APPROVED (after fix + independent verification).

### Commit
`ce84811` — docs(design): TASK-005 character system specification

### Push
main → origin — success (40c4b77..ce84811)

### Recommended Next Step
Surface E2 character-direction pick to the owner (AskUserQuestion, C recommended), then spawn fresh TASK-006 agent (Step 5 Technical Architecture + ADRs) with the accumulated intake list in status.md.
