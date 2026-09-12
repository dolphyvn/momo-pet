# ADR-015 — Watch Pat Presentation: Reaction Binding + Completion-Haptic Estimation

## Status

Accepted (2026-09-11, TASK-042 contract; owner-authorized orchestration decision per §36 — presentation-layer bindings over the FROZEN EPIC-006 art vocabulary, reversible, follows the ADR-014 adjudication pattern).

## Context

TASK-042 must ship the Watch pat (FR-17 AC-1/2; UX §6.2–6.4; 04 §6.4): an immediate local micro-reaction, state-distinct per wakefulness — "awake → happy micro-bounce; asleep → stir + tiny heart, stays asleep (≤ 1 s)" — plus subtle haptics per UX §6.3 exactly (pat = single soft tick; quest completed *by an on-wrist action* = gentle celebratory double; anything else = nothing). The Watch runs NO engine (EPIC-008 AC-5) and EPIC-006's character art/motion surface is FROZEN: `Sources/MomoCharacter/` edits are forbidden except where a consumer surface genuinely lacks a seam (disclosed + minimal).

Three facts pin the design space (all verified at source 2026-09-11):

1. `MomoRigView` already exposes the reaction-motion seam — a `reactionMotion: (Double, Bool) -> MomoReactionMotion` sampler parameter defaulting to `.identity` (the TASK-028 overlay seam; the iPhone's Home rig drives it through the director). W1's canvas passes no sampler today; binding one is ADDITIVE at the call site — no MomoCharacter edit.
2. The authored clip vocabulary already contains both reactions: `.tap` (`react.tap`, the touch family — the pet's own reaction to a tap) and `.stir` (`react.stir`, AUTHORED 1.0 s baseline, channels bodyScale/tailRotation/headRotation — it stays DOWN; its clip-spec comment pins it as "the asleep" reaction). The docs' "tiny heart", however, has NO art: `MomoProps` is GENERATED ("DO NOT EDIT") and contains exactly food, blanket, and two sparkles — no heart shape exists anywhere in the frozen vocabulary.
3. The Watch cannot KNOW at pat time whether a pat completes the pat-quest: quest truth lives iPhone-side (the Watch renders the last-synced cascade output). The snapshot DOES carry `questLine` and `questInputs` (id/progress/target), and the Watch knows its own pending journal count — so a LOCAL ESTIMATE is derivable, but it can disagree with the iPhone.

## Decision

**D1 — Reaction binding (no new art).** The W1 pat micro-reaction binds the EXISTING clips through the rig's existing sampler seam: awake pat → the `.tap` clip's motion (the "happy micro-bounce"), asleep pat → the `.stir` clip's motion (the "stir, stays asleep"), sampled over elapsed time and reverting to `.identity` past the clip window (≤ 1 s holds by the authored baselines). The glyph/AOD tier binds NO sampler (static by construction), and the resolved Reduce Motion flag returns a static pose per MomoReduceMotion's render-only law. **The docs' "tiny heart" is NOT shipped**: no heart shape exists in the frozen art vocabulary, and authoring one (regenerating the GENERATED `MomoProps`) is an EPIC-006 frozen-surface violation for a glance surface. The visual delta is disclosed in the task notes and recorded in the backlog for the owner (visual-design pass, Phase 1.5+); it gates nothing.

**D2 — Completion haptic by local estimation.** At pat time the Watch estimates completion from the HELD snapshot: the quest line is `.wish(.q7)` ∧ Q7's `questInputs` progress + this Watch's pending journal pats + 1 == the quest's target → the celebratory double REPLACES the soft tick (ONE haptic carries the moment — two back-to-back watchOS haptics read as one messy buzz, against the calm ethos); otherwise the single soft tick. The estimate decides WHICH HAPTIC PLAYS and nothing else: no state moves, the engine is never told, and a disagreement is benign by construction.

The estimate's disclosed failure mode: if iPhone-side activity advanced Q7 after the last sync, the Watch may play a celebratory double for a pat the iPhone does not count as completing (the completion already celebrated silently iPhone-side per UX §6.3). False negatives cannot arise from staleness alone (the held view can only UNDER-count), so the on-wrist completing pat always celebrates. This is the honest minimum: UX §6.3's own example ("3rd pat completes Q7") is phrased from exactly this on-wrist perspective, and the alternative — a "this completed a quest" wire flag — adds schema for a haptic nuance and still cannot fire at pat time (the Watch is offline by definition in the journaled case).

**D3 — Haptic type choice, VERIFY-AT-BUILD.** The two watchOS haptic kinds play through an injectable seam over `WKInterfaceDevice.play(_:)`; the exact `WKHapticType` values are resolved against the real SDK headers at build time (the TASK-040 VERIFY-AT-BUILD discipline) and recorded in the task notes. Haptic FEEL is not observable in simulators — device-feel judgment is TASK-044's paired-hardware obligation or BLOCKED evidence (§25; §27's "no simulated-device claims"). Both haptics gate on the CURRENT snapshot's `hapticsEnabled` at pat time (the TASK-036 delivery-time discipline).

## Alternatives Considered

- **Author a heart prop / new stir-heart clip**: requires regenerating GENERATED art files — EPIC-006 frozen surface, out of TASK-042's scope (rejected; backlog).
- **Port MomoReactionDirector to the Watch**: the director folds engine presentation events; the Watch runs no engine, so it would drive nothing. A full presentation engine for two one-shot reactions is scope creep (rejected).
- **Synthesize a momentRequest (`.questCompleted`-style moment) for the reaction**: `CharacterMoment` has no pat case, and minting a fake moment would misrepresent engine state on a "derives nothing" surface (rejected).
- **Snapshot-flag completion notice**: a "this snapshot's completion came from your pat" wire flag — schema growth (OBS-3-adjacent) for a haptic that still could not fire at pat time offline (rejected; D2 estimates locally instead).
- **Play tick AND double on the completing pat**: two haptic events inside a second read as noise on watchOS (rejected; D2 replaces).

## Consequences

W1's pat is fully specified over the frozen vocabulary: zero `Sources/MomoCharacter/` and zero `Sources/MomoCore/` edits. The heart delta is a visible, documented gap until the owner's visual pass — the reaction remains state-distinct and calm without it. The completion estimate is presentation-only with a pinned benign false-positive window, and the reviewers' acceptance criterion is the ESTIMATE'S MATH (pure, headlessly testable), not cross-device truth. The D2 replacement rule (double REPLACES tick) must be pinned by a named test.

## Date

2026-09-11
