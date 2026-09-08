# ADR-001 — Character Visual Direction: "The Round Rabbit"

## Status
ACCEPTED — owner decision (E2 gate, D9), 2026-09-08.

## Context
`docs/design/04-character-system.md` §1 presented three fully-specified visual directions for Momo, held open by an explicit owner sign-off gate (E2) because the character's identity is product-defining. Sections §2–§9 (anatomy, expressions, states, idle choreography, interaction map, timings, assets, engine contract) were deliberately written direction-agnostic so the pick would trigger no downstream rework. The decision gates only §1's per-direction deltas and the §8.5 rig part counts — and, later, EPIC-002 asset production.

## Decision
**Direction C — "The Round Rabbit".** A small, plump rabbit, deliberately not the long-eared cartoon bunny: rounded pear body, thick short-to-medium ears (hard ear-thickness rule: each ear ≥ 12% of body width at base, rounded tips), round cheeks, puff tail. Expression is posture-led — ear angle (both-perked / both-drooped / one-up-one-down curious signature) is a silent second mood channel. Rabbit crepuscularity (active morning/evening, restful midday) natively matches the product's day rhythm (morning hello → day rest → evening tuck-in).

Selected by the owner from the AskUserQuestion E2 gate; the document's recommendation (§1.4) was C.

## Alternatives Considered
- **A — "The Loaf Cat":** strongest universal warmth and calm read; rejected as the most crowded space in virtual pets (genericness is the live PR5 risk; differentiation would rest entirely on execution restraint).
- **B — "Mochi Spirit":** unbeatable glance legibility and the cheapest rig (~7 parts); rejected because the ear/tail movement channel is structurally weak (V1/V7 strained), the idle-variant catalog thins, and premium is hardest to earn (generic-mascot drift risk).

## Consequences
- §1.3's anatomy deltas are now normative: ~11 rig parts, two independent per-ear rotation channels (asymmetry is an expression state), hind feet visible at rest, ear-thickness hard rule.
- §8.5 manifest part counts concrete; per-direction alternates in §5.2/§5 idle catalog (C entries) become the shipped set.
- Watch-glyph legibility carries one obligation: below ~32 pt the glyph merges ears into the head outline, keeping the pear silhouette (§1.3 rule).
- Bunny-stereotype mitigations are binding: rounder/heavier/slower proportions, no bounce-loops anywhere (§7 curve rules).
- A/B subsections remain in the document as the recorded decision trail; they are not build targets.
- No rework was required in `03-ux-architecture.md` or in 04 §2–§9 (verified direction-agnostic by REVIEW-TASK-005).

## Date
2026-09-08 (owner pick via E2 gate; recorded post-TASK-005 approval, commit `ce84811` lineage).
