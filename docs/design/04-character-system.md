# Momo — Character System (Step 4)

| | |
|---|---|
| Task | TASK-005 — Step 4: Character System (project.md §40 Step 4; §30 items 12, 14–16) |
| Date | 2026-09-08 |
| Inputs | `project.md`, `docs/product/01-product-review.md` (D1–D20 binding), `docs/product/02-mvp-prd.md` (normative), `CLAUDE.md` |
| Status | REVISED — post-review fix pass applied (REVIEW-TASK-005); pending verification |
| Scope | Phase 1 only. One pet, no outfits/seasonal content (Phase 3, §27). Nothing here presumes Phases 2–4 scope. |
| Authority | The PRD is the normative product source. Where this document adds character-level specifics (timings, zones, choreography), they are the binding implementation contract for the character layer and inputs to TASK-006. The **species is NOT decided here** — see the E2 gate in §1. |

> **§30 item-14 scope note:** of the design-system item, TASK-005 owns the character-side token *slots* (§8.4); the palette's final **values** are assigned by the **EPIC-002 design-system pass** — one pass covering project.md §18 UI + the character slots together, so the palette coordinates across both (Appendix B item 3).

**OWNER SIGN-OFF GATE (OPEN-DECISION E2, D9):** This document presents 2–3 fully-specified character directions (§1). The human owner picks exactly one. **Nothing in this document locks a species.** Sections 2–9 are deliberately written **direction-agnostic**: whichever direction the owner picks, sections 2–9 stand without rework; only the per-direction deltas in §1.1–1.3 apply.

---

## Table of Contents

1. Visual direction — three character directions (E2 gate)
2. Character anatomy constraints
3. Expression inventory (Mood / Energy / Bond), color-independence
4. Animation state inventory (Phase 1 contract + 15-state mapping, interruption rules)
5. Idle behaviour choreography (seeded, deterministic variation)
6. Interaction → reaction map
7. Motion timings, curves, Reduce Motion, battery & performance rules
8. Asset requirements & production plan (pipeline decision, budgets, naming, Phase 1 manifest)
9. Engine ↔ character contract (the TASK-006 interface)
10. Tone guide (copy voice, guardrails, sample lines)
11. Audio scope decision for Phase 1
- Appendix A — Requirements traceability
- Appendix B — Handoffs & Reconciliation Record

---

# 1. Visual Direction — Three Character Directions

## 1.0 What the direction must achieve (derived constraints, binding on all options)

| # | Constraint | Source |
|---|---|---|
| V1 | Animal form with expressive ears and a tail (movement channel required) | §19 "ear/tail movement"; D9 |
| V2 | Head + belly touch zones must exist as distinct anatomy regions | FR-5 AC-4, D9 |
| V3 | Eye-follow capability on iPhone → the face must be **eye-dominant** | §4, D9 |
| V4 | Reads "cute × calm × minimal × alive × premium"; must not read childish or generic-mobile-game | §1, §18, PR5 |
| V5 | Legible as a still glyph at complication size (~24–32 pt) and as an animated pet at iPhone stage size (~220–280 pt) and Watch stage size (~60–80 pt) | §12, §13 |
| V6 | Implementable as a SwiftUI-native parametric vector rig (pipeline decided in §8) | TR8 |
| V7 | Expresses the PRD band system (Mood 4 bands, Energy 4 bands) without color dependence | §20, §3 |

## 1.1 Direction A — "The Loaf Cat"

**Concept.** Momo as a small, plump, short-haired cat at permanent rest — a loaf. The design thesis is restraint: this is *not* the big-eyed cartoon kitten. Ears are small triangles, eyes are large but calm and heavy-lidded by default, limbs disappear into the loaf (front paws peek), tail is short and thick with a soft curl. The cat slow-blink — the real-world feline signal of contented trust — becomes Momo's signature reaction.

- **Silhouette:** a smooth dome with two small ear nubs and a curled tail wrap. Reads instantly at any size; the most universally parseable animal silhouette.
- **Proportions (seated):** width : height ≈ 1.1 : 1; head ≈ 45% of total mass; each eye ≈ 25% of face width; ears ≤ 18% of head height (deliberately small — the anti-"kawaii kitten" move); tail ≈ 20% of body length, thick.
- **Expression strengths:** eye-led expression (aperture + lower-lid curve carry almost everything); the tail is a mood metronome (slow sway = content, quick small wag = joyful, wrapped tight = wistful); the slow blink is a premium, wordless affection beat.
- **Anatomy deltas vs. §2 base contract:** ears small/pointed; whiskers: **none** (whisker spikes read cheap — a deliberate omission); muzzle minimal to absent (flat face, mouth a 2–4 px curve used only while eating / refusing food).
- **Asset complexity: MEDIUM.** ~10 rig parts; loaf poses are geometrically simple (few limb states — cheapest possible locomotion-free body); ear/tail rigs straightforward.
- **Watch legibility: STRONG.** Dome + ear nubs survives 24 pt trivially; tail curl may be dropped in the glyph variant with no identity loss.
- **Cute × Calm × Premium read:** high calm (the loaf *is* the visual definition of calm); high cute via eye dominance; premium achieved through restraint (no giant pupils, no open-mouth smiles).
- **Risks:** the most crowded space in virtual-pet products — genericness is the failure mode (PR5). Differentiation must come entirely from execution restraint; if it drifts one notch toward "cute kitten sticker", it reads childish. No species-behavioral tie to the product's morning/evening rhythm beyond the generic.

## 1.2 Direction B — "The Mochi Spirit"

**Concept.** Momo as a species-ambiguous soft round spirit — a mochi/dango-like creature with two tiny ear nubs and a puff tail. Nobody knows what Momo is; Momo is just Momo. Maximum ownability: the design references no real animal, so it can never be compared to one, and its softness is structural (squash-and-stretch *is* the body language).

- **Silhouette:** near-perfect circle with two nubs and a puff. The most glance-legible option possible — survives 16 pt complications.
- **Proportions:** 1 : 1 circle (resting); face occupies the upper 55%; ears minimal nubs (≤ 12% of height); eyes ≈ 28% of face width each (largest of the three — the whole vocabulary is ocular); body has no limbs at rest (limb nubs appear only during play).
- **Expression strengths:** perfect squash-and-stretch (softness reads through deformation, not facial distortion); cleanest eye signals; the "whole-body change" (round ↔ slightly oval) is a full-body mood channel unique to this direction.
- **Anatomy deltas vs. §2 base contract:** ears are vestigial nubs (V1's "ear movement" channel is weak — nubs barely move); tail is a static puff (same weakness); belly zone is the entire lower half.
- **Asset complexity: LOW.** Fewest parts (~7); no limb rig; all animation is transform-level. Cheapest to build and cheapest to keep consistent.
- **Watch legibility: STRONGEST.** Unbeatable at glyph size.
- **Cute × Calm × Premium read:** high cute (roundness), high calm (stillness reads naturally), but **premium is the hardest to earn** — abstraction plus minimal anatomy trends toward "generic startup mascot" if the execution is not exceptional.
- **Risks:** expression range for four Mood × four Energy bands leans almost entirely on eyes + body deformation (no ear/tail nuance — V1 and V7 both strained); species behaviors (grooming, kneading, ear flicks) unavailable as idle variants, which thins the idle choreography catalog (§5); may read as abstract rather than alive to some users ("what *is* it?").

## 1.3 Direction C — "The Round Rabbit"

**Concept.** Momo as a small, plump rabbit — and deliberately *not* the long-eared cartoon bunny. Rounded, thick, short-to-medium ears; round cheeks; compact pear body; puff tail. The behavioral thesis is the strongest fit to the product: rabbits are quiet, gentle, and crepuscular — most active in morning and evening, resting through the day — which *is* the app's rhythm (morning hello → day rest → evening tuck-in). Expression arrives through **posture**, not facial distortion: ear angle is a second, silent mood channel.

- **Silhouette:** rounded pear with two thick ear ovals and a puff tail. Reads at small sizes **conditional on the ear-thickness rule** (see below).
- **Proportions (seated):** width : height ≈ 1.05 : 1 (ears excluded from the height ratio); ears ≈ 55–70% of head height, and **each ear ≥ 12% of body width at its base, with rounded tips** — thin ears are the one thing that breaks small-size legibility, so thickness is a hard rule, not a style choice; each eye ≈ 25% of face width; muzzle minimal; mouth a 2–4 px curve (eating / refusal only); tail a puff ≈ 10% of body width.
- **Expression strengths:** the ear system is the differentiator — both-perked (alert/joyful), both-drooped (wistful/rest), one-up-one-down (curious — the signature asymmetry), fast twitch (noticing you). Posture-led expression is the premium register: mood information through body language, never through exaggerated faces. Rabbit behaviors (ear flicks, slow blink, cheek-press rest, the "flop") map directly onto the idle choreography catalog.
- **Anatomy deltas vs. §2 base contract:** ears large enough to be a first-class rig channel; hind feet visible as rounded shapes at rest; belly zone is the natural lower-front curve.
- **Asset complexity: MEDIUM-HIGH.** ~11 rig parts; the two-ear rig needs independent per-ear rotation channels (worth it — asymmetry is an expression state, not a bug).
- **Watch legibility: STRONG with one rule.** At glyph size, ears render as two short thick ovals (the thickness rule keeps them from vanishing); below ~32 pt the glyph variant may merge ears into the head outline while keeping the pear silhouette.
- **Cute × Calm × Premium read:** the strongest *combined* profile — cute (round, soft), calm (still, quiet species register), premium (expression via subtle posture rather than cartoon exaggeration is exactly the restraint §18/PR5 demand).
- **Risks:** the bunny-cuteness stereotype (bouncy, hyper, pink-bowed) — mitigated by the proportions above (rounder, heavier, slower) and by §7's motion rules (no bounce-loops anywhere); glance-size ear legibility — mitigated by the thickness rule + glyph variant.

## 1.4 Comparison and recommendation

| Criterion | A — Loaf Cat | B — Mochi Spirit | C — Round Rabbit |
|---|---|---|---|
| Glance legibility (V5) | Strong | Strongest | Strong (with ear-thickness rule) |
| Expression range for 4×4 bands (V7) | Strong (eyes + tail) | Moderate (eyes + deformation only) | **Strongest (eyes + ears ×2 + tail + posture)** |
| Eye-follow face dominance (V3) | Strong | Strongest | Strong |
| Ear/tail movement channel (V1) | Strong | Weak | **Strongest** |
| Behavioral fit to day rhythm (wake/rest/tuck-in) | Moderate | Neutral | **Strong (crepuscular)** |
| Differentiation / ownability | Low (crowded space) | High | High |
| Asset complexity (V6) | Medium | **Low** | Medium-high |
| Childish-drift risk | Medium | Medium | Low (posture-led expression) |
| Premium register | Achievable | Hardest | **Natural** |

**Recommendation: Direction C — "The Round Rabbit".**

Rationale: it is the only option that is simultaneously distinctive, behaviorally coherent with the product's morning/evening energy model, and natively premium — mood expressed through ear angle and posture is quiet body language, which is the "calm × premium" register, while the cat reads as familiar-but-generic and the spirit reads as ownable-but-technically thin on the required ear/tail movement channel (V1) and expression range (V7). Its one real weakness (glance-size ears) is closed by a hard design rule and a glyph variant, at near-zero cost. If the owner weighs glance legibility above all, Direction B is the fallback; if the owner weighs instant universal warmth, Direction A. **The pick is the owner's (E2).**

> **OWNER SIGN-OFF GATE (E2 — D9): RESOLVED.** The owner picked **Direction C — "The Round Rabbit"** (2026-09-08). Recorded as ADR-001 (`.claude/tasks/decisions/ADR-001-character-direction-round-rabbit.md`). Sections §2–§9 were written direction-agnostic and required no rework; with sign-off, §1.3's deltas and the §8.5 part counts (~11 rig parts, per-ear rotation channels) are now concrete. Downstream documents consume C's values; A/B subsections remain as the recorded decision record.

---

# 2. Character Anatomy Constraints

This section is the **direction-agnostic rig contract**. It defines what any chosen direction must provide so that animation (§4–§7), interaction (§6), and the engine interface (§9) are species-portable.

## 2.1 Normalized character space

All geometry is defined in a **1000 × 1000 normalized design grid**, character anchored **bottom-center** (x = 500 at spine, y = 1000 at ground contact). Every render surface maps this space to its stage:

| Surface | Stage size | Space mapping |
|---|---|---|
| iPhone Home stage | 220–280 pt tall | full grid, 1:1 aspect maintained |
| Watch stage (foreground) | 60–80 pt | full grid |
| Complication / AOD glyph | 24–32 pt | simplified glyph variant (§8.5), silhouette-preserving |

Direction-dependent geometry (head size, ear shape) is expressed **as ratios within this grid**, so zone definitions and the eye-follow math below are invariant across directions.

Reference landmarks (Direction C values; A and B substitute their §1 ratios — the landmark *roles* are identical):

- Ground contact line: y = 1000; body center ≈ (500, 640), body radius ≈ 300
- Head center ≈ (500, 400); eye centers ≈ (430, 390) and (570, 390), eye radius ≈ 52
- Ear roots ≈ (440, 250) and (560, 250); tail anchor ≈ (720, 800)

## 2.2 Parts / rig model (what SwiftUI vector animation can implement)

The rig is a small tree of **pre-built vector layers** animated by transforms only (§7.4 performance rule):

| Layer group | Parts | Animatable channels |
|---|---|---|
| Body | body shape (1), belly patch (1) | scaleY/X (breath, squash), rotation (lean/rock), position (hop, settle) |
| Head | head shape (1) | rotation (tilt ±6°), position (bob, lean-in), scaleY (settle squash) |
| Ears | ear L, ear R (2) | rotation per ear (−25° … +25°), scaleY (twitch) |
| Tail | tail (1) | rotation (metronome ±10°), scaleY (flick) |
| Eyes | eye L, eye R: base + pupil + lid (6) | lid scaleY (blink/aperture), pupil offset (gaze, clamped), lower-lid curve (pre-built pose shapes, crossfaded) |
| Face details | mouth poses (3 pre-built: neutral, eat, refuse), cheek accents (2, celebration-only) | opacity/swap |
| Front paws | paw L, paw R (2) | position/rotation (peek, pat, refuse-raise) |
| Props (interaction-scoped) | food (1), blanket (1), sparkle (2 — celebration/moment-scoped) | position/rotation/opacity |

Total ≈ 17 character parts + 4 props — comfortably under any complexity ceiling for a SwiftUI `Shape`-layer rig, and small enough that every part is individually pausable. *(Count basis: §1's per-direction figures — ~10 / ~7 / ~11 — are body-side estimates over the direction-varying body/head/ear/tail/paw groups; the ~17 here is the full direction-agnostic rig: those groups plus the 6-part eye group, the mouth counted once as a 3-pose slot, and the 2 celebration cheek accents.)*

**Hard rig rules (binding on implementation):**
- R1. Motion is **transform-only** on pre-built layers; no per-frame Path re-generation. Pre-built pose shapes (lower-lid curve, mouth) are crossfaded, never re-tessellated.
- R2. The character is **one continuous creature**: parts never detach, scatter, or become particles. Expressiveness comes from part transforms, not from flying pieces.
- R3. Every channel is **independently pausable** through the single CharacterClock (§9.5), so "pause everything" (TR3) is one call, not per-animation bookkeeping.
- R4. All colors come from **semantic design-system tokens** (§8.4); the rig contains no hex values, so light/dark and any future palette work need zero rig changes.

## 2.3 Touch zones (FR-5 AC-4)

The whole character is one tappable surface; internally it is partitioned into exactly **two zones** by a horizontal rule at y = 550 in normalized space (≈ the neck base):

- **Head zone:** tap point with y < 550.
- **Belly zone:** tap point with y ≥ 550.

The two-zone partition (rather than overlapping circles) removes dead zones and ambiguity, is trivially testable, and scales to all three directions. Visual anchors for illustration: head zone ≈ circle c(500, 380) r 260; belly zone ≈ ellipse c(500, 760) rx 250 ry 190 — the y = 550 rule is authoritative, the shapes are indicative.

- Zone hit-testing is a pure function of normalized coordinates → deterministic and unit-testable.
- The character stage always renders ≥ 88 pt tall on iPhone so both zones exceed a comfortable touch area; the overall element satisfies the ≥ 44 pt target (FR-20).
- **Accessibility:** the character is **one** VoiceOver element (not per-zone targets — per-zone targets create rotor noise). State is announced by formula (§3.5). The canvas exposes **gesture analogs only** as custom actions — "Pat" and "Cuddle" (the long-press analog), per TASK-004's delivered model (UX-8); feed/play/care are **not** canvas custom actions — they are the Home action-row buttons, which VoiceOver reaches as labeled buttons. Zone-based direct touch remains available to sighted interaction; VoiceOver users get the canvas reaction vocabulary through the gesture analogs.

## 2.4 Eye-follow mechanics (iPhone only)

- **Target acquisition:** the last touch/pointer position inside the character stage is mapped into normalized space → gaze target. While a touch moves (stroke), the target tracks it continuously.
- **Pupil offset:** `offset = clamp(vectorToTarget × 0.18, max = 30% of eye radius)`. Pupils stay well inside the iris at all times — wide "googly" tracking is explicitly forbidden (childish pole).
- **Head follow:** head tilt follows at 10% gain, max ±4°, with a ~120 ms trailing delay after the eyes — the soft, slightly-late head follow that reads as attention rather than tracking software.
- **Release:** on touch end, gaze eases back to forward over 600–900 ms; the head settles last.
- **Watch:** no eye-follow; static forward gaze (FR-17 scope; also an AOD-safety simplification).
- **Reduce Motion (D16):** continuous tracking is disabled; a touch produces a single static "looks toward you" pose (one gaze step toward the touch side, no motion), released on touch end.

## 2.5 Invariants — what may never change

| # | Invariant | Why it must never change |
|---|---|---|
| INV-1 | Two eyes, upper-forward on the face, eye-dominant | Eye-follow (§2.4) and the entire expression system (§3) assume it |
| INV-2 | Head-above-body topology; the y = 550 zone partition | §6's interaction map and all task code assume stable zones |
| INV-3 | Silhouette survives 24 pt as a still glyph | §12/§13 glance surfaces |
| INV-4 | One continuous creature; transform-only motion (R1/R2) | Performance rules (§7.4); scattered-particle motion reads game-y |
| INV-5 | Body/base color is constant; **state is never communicated by color** | §20 color-independence; restraint. Cheek accents appear only inside celebration moments (§4 L4), never as a state channel |
| INV-6 | The worst visual state is **sleeping**. No illness, distress, injury, or death visuals exist in any state | §3 P4 no-punishment philosophy; FR-12 |
| INV-7 | Anatomy does not grow or age; Bond is expressed through behavior only (§3.4), never body change | §5: progression is relational, not physical |
| INV-8 | One pet, no outfits/accessories/seasonal variants in Phase 1 | §27 Phase 3; MVP protection |

---

# 3. Expression Inventory (Mood / Energy / Bond)

## 3.1 Expression components

Expression is composed from a small, fixed vocabulary of rig channels (§2.2). Pupil **size** is deliberately *not* a mood channel (constant near-neutral; enlarging pupils reads cartoonish) — mood is carried by aperture, lid shape, ears, tail, posture, and motion tempo.

| Component | Channel | Range |
|---|---|---|
| Eye aperture | lid scaleY | 0 (closed) → 1.0 (open); half-lid 0.5–0.7 as baseline overlays |
| Lower-lid curve | pre-built pose swap | relaxed (neutral) / upturned (warm) / flattened (subdued) |
| Ear angle | per-ear rotation | −25° (droop) … +25° (perk); asymmetric = curious/alert |
| Tail behavior | rotation/tempo | still · slow metronome · quick small wag · wrapped tight |
| Mouth | pose swap | absent (default) · tiny content curve · eat · refuse |
| Posture | body scaleY/lean | +3% tall … −5% slouch |
| Breath | rate/amplitude | see §7.1 |

## 3.2 Mood-band expressions (PRD §3.1 bands — normative band names)

| Band | Eyes | Ears | Tail | Posture | Tempo |
|---|---|---|---|---|---|
| **Joyful** (75–100) | 100% aperture, upturned lower lids (warm arcs) | perk +8…+25° | slow wag | +3% tall, eager micro weight-shifts toward user | breath ~4 s; idle events more frequent |
| **Content** (45–74; attractor 60) | ~90% aperture, relaxed lids | neutral ±5° | slow metronome or still | neutral | breath ~5 s; baseline scheduling |
| **Wistful** (20–44) | ~70% aperture, flattened upper lid (soft, heavy look) | droop −10…−25° | still, curled close | −4% slouch | breath ~6 s; slower blinks; **extra-warm response to care** (PRD: care lands harder here) |
| **Low** (0–19) — **reserved; not produced by any Phase 1 mechanic** (PRD floor 25) | ~60% aperture, long slow blinks | settled down | wrapped | resting slump (never distress — reads as "quiet, resting") | minimal motion. Defined now so the presentation scale is complete and future-proof; shipping it requires a PRD revision |

**Hard rule:** no expression in any band may read as suffering (INV-6). Wistful is "sleepy-hearted", not sad.

## 3.3 Energy modulation (PRD §3.2 bands — normative band names)

Energy modulates the *activity level* on top of the mood expression; where they conflict (e.g., Joyful + Exhausted), the **lower-energy signal wins on tempo, the higher mood wins on facial warmth** — Momo can be happy but too tired to move much, which is both honest and endearing.

| Band | Overlay |
|---|---|
| **Energetic** (75–100) | idle variation frequency ×1.5; anticipation lean when interaction buttons appear; slightly faster tempo |
| **Relaxed** (45–74) | baseline |
| **Drowsy** (20–44) | half-lid baseline overlay (aperture ×0.7); all scheduler intervals ×1.4; yawn idle event; occasional head-nod micro-motion; nap offered per PRD |
| **Exhausted** (0–19) | near-sleep resting posture while awake (lying, eyes half-open); movements minimal and slow; nap offered per PRD; play becomes a gentle stir (PRD §4) |

## 3.4 Bond expression behavior (PRD §3.3 stages — normative names)

Bond changes **how Momo responds to you** — it never alters resting posture bands or the body (INV-7); bond expression is behavior-level (aperture, orientation, response), so the calm-coexist idle below stays inside that scope. Three dials: greeting quality, reaction latency, and unlocked reaction variants.

| Stage | Greeting on arrival | Reaction latency | Unlocked variants |
|---|---|---|---|
| **New Friends** (0–149) | curious look + small single-ear lift | ~0.6 s | — |
| **Getting Close** (150–399) | two-ear perk + warm eyes | ~0.4 s | double-tap tail-double-wag variant |
| **Best Friends** (400–749) | visible whole-body brightening + approach lean | ~0.25 s | slow-blink-back on long-press (the trust signal) |
| **Soul Companions** (750–1000) | "recognizes you" sequence — eyes find you first, then the warm reaction | ~0.25 s | calm-coexist idle (rests with eyes half-closed, facing you) |

Bond stage text is presented by the UI as stage name + descriptor line per PRD legibility rules; these expressions supplement, never replace, that text.

## 3.5 Color-independence and accessibility (§20, FR-20)

- **State is never communicated by color alone** (INV-5). Mood/energy reach the user through: expression + motion (character), glyph + label + contextual line (UI, TASK-004), and words (VoiceOver).
- **VoiceOver formula (binding):** *"{Name} feels {mood word} and {energy phrase}"* + bond stage when relevant — the {energy phrase} slot carries a verb phrase, so the formula renders verbatim as "Momo feels content and has plenty of energy." Mood words: joyful / content / quiet (for Wistful — "wistful" announced as "quiet" for clarity) / low. Energy phrases: "has plenty of energy" / "is relaxed" / "is getting sleepy" / "is very sleepy".
- **Grayscale legibility check (review obligation):** every expression state in §3.2–3.3 must remain distinguishable rendered in pure grayscale (aperture/ear angle/posture differences must survive with no hue information). The pipeline recommendation (§8) makes this cheap to verify in SwiftUI previews with a `.grayscale(1)` modifier.

---

# 4. Animation State Inventory

## 4.1 Structure: states, layers, reactions, moments

The character distinguishes **states** (exclusive, sustained), **layers** (blended, concurrent), **reactions** (short one-shots), and **moments** (rare system events). This vocabulary is the interruption model's backbone.

**Priority classes:**

| Class | Kind | Contents | Preemptible by | Fade on preemption |
|---|---|---|---|---|
| **L0** | ambient layers | breathing, tail metronome | never (always blending underneath) | n/a |
| **L1** | micro-events | blink, ear twitch, look-around, gaze shifts | any input, any state change | ≤ 100 ms |
| **L2** | states | idle (variant of the moment), low-energy rest, settling, sleeping, waking, eating, playing, napping | a new L2 (engine-driven), L4 | 300–400 ms crossfade |
| **L3** | reactions | all touch reactions, feed refusal, sleep-stir, yawn, feed/sleep-decline | newer L3 (queue ≤ 2), an L2 change, app-hide | ≤ 120 ms |
| **L4** | moments | stage celebration, quest-complete sparkle, greeting sequences | app-hide only (pauses, resumes, then completes) | — (short by design; §7.1 caps durations) |

> *L4 vs. a pending L3 queue:* a `momentRequest` (L4) arriving while an L3 queue is pending needs no extra arbitration — the table already grants L4 preemption rights over L2, and the queued L3s either complete (each ≤ 1.2 s) or fade under the L4-backed state change. No unbounded case exists.

**Coherence rules (the interruption matrix reviewers should test against):**

1. *Can a blink be interrupted by a tap?* **Yes — always.** L1 yields to anything; an interrupted micro-event fades out within ≤ 100 ms so nothing pops.
2. A new L2 always replaces the current L2 via crossfade; L2 changes preempt L3 (an interrupted reaction simply fades — the state change is the priority).
3. L3 never modifies the underlying state; it plays over it. Identical L3 reactions within 500 ms **coalesce** (visual softening) — this is how "10 rapid pats produce no lock and no penalty, later pats simply soften" (FR-5 AC-3) manifests visually: repeats 1–2 full, 3–4 abbreviated, 5+ coalesced into a single gentle response per 500 ms window. (This is the character's **visual** half of AC-3; the same-day effect-diminishing half is engine-owned — D18; TASK-006.)
4. **Sleeping** rejects all L2 transitions except *settling* (into it) and *waking* (out of it, engine-driven). Touch during sleep produces only the L3 stir (FR-5 AC-2 — petting is never refused, Momo stirs and stays asleep).
5. **Eating** continues through taps; a tap mid-eat earns only a brief L3 glance-up. No state thrash from interaction spam.
6. **Playing** (≤ 30 s; §6.3) runs to completion; extra taps during play produce small cheer reactions (L3) and do not reset or extend the round. If a newer L2 or app-hide ceases the round mid-flight: pause clock; the round ends gracefully — never half-frozen — and its effects are applied at the single instant the round ceases (the unified application point; stated once at §9.6 item 4, referenced from §9.2 — TASK-006 confirms), so backgrounding and interaction-preemption are the same deterministic case.
7. L4 moments pause (not cancel) on app-hide and complete on return; with Reduce Motion they render as a static moment pose (§7.3).
8. app-hide (scenePhase ≠ active) pauses **everything** (L0–L4) via CharacterClock zeroing — TR3/D16/FR-4 AC-2. On Watch, AOD renders a static snapshot (FR-17 AC-5).

## 4.2 The Phase 1 contract: the FR-4 minimal state set

FR-4 AC-4 makes this set the **binding Phase 1 contract**. Battery note per row (TR3/§33/NFR-2).

| State | Trigger | Duration | Loop behavior | Interruption rules | Battery / performance note |
|---|---|---|---|---|---|
| **Idle / breathing** | default awake state | sustained | breathing loop (L0) + L1 schedulers + idle-variant catalog (§5); variant changes every 14–30 s | any L2 change replaces it; L3 overlays freely | cheapest state: 1 transform loop (breath, GPU-composited) + low-frequency scheduler timers; no per-frame work |
| **Blinking** | scheduler, wakeful states only | 240–340 ms total | re-fires per §7.1 interval distribution | anything preempts (rule 1) | zero standing cost between blinks (timer scheduled for next event only) |
| **Looking around** | scheduler (§5) | 1.5–4 s hold + 0.2–0.3 s gaze shift | part of idle variant rotation | anything preempts; gaze returns to forward | transform-only eye/pupil offsets; negligible |
| **Sleeping** | night window (D11) or after settle handshake | sustained through night | breath at sleep rate; rare ear-twitch L1 only; **no blink** | only settling/waking per rule 4; touch → stir L3 only | lowest-cost state: breath loop only, amplitude reduced |
| **Waking** | engine: night window ends, or nap end | 1.8–2.5 s one-shot (unhurried stretch = premium beat) | none | completes unless app hidden; new L2 may follow immediately on completion | one-shot; no residual timers |
| **Happy** (burst) | engine ResponsePlan after warm interactions; Joyful-band idle accent | 0.6–1.2 s one-shot | none (recurs via reactions) | L3-class rules | one-shot transform sequence |
| **Eating** | feed interaction (hungry class) | 2.5–4 s one-shot (2–3 bite cycles) | none | taps → glance-up only (rule 5); completes into content idle | pre-built mouth pose crossfades + paw/head transforms; no path re-generation (R1) |
| **Playing** | play interaction round | 15–30 s per round (PRD FR-7) | round-internal cycle (three-phase follow shell, §6.3) | rule 6; Drowsy → low-key variant ending in yawn; Exhausted/sleeping → stir only | highest-cost Phase 1 animation: two moving transform groups (Momo + follow system) — still transform-only; bounded ≤ 30 s; fully pausable |
| **Low-energy** (rest overlay) | Drowsy/Exhausted during waking hours | sustained while band holds | breath at drowsy rate; posture overlay per §3.3 | band change (engine) removes overlay | cheaper than idle (fewer L1 events scheduled) |

## 4.3 Phase 1 reaction vocabulary (required to satisfy the PRD interaction FRs)

| Reaction | Class | Duration | Serves | Battery note |
|---|---|---|---|---|
| Touch set — tap·head / tap·belly / double-tap / long-press·head / long-press·belly / stroke·head / stroke·belly (7 distinct) | L3 | 0.4–1.2 s | FR-5 AC-1 | one-shot transforms |
| **Stir** (asleep, any touch) | L3 | 0.8–1.2 s (ear twitch + tiny heart float + settle) | FR-5 AC-2, PRD §4 | one-shot; heart is a single small shape drift |
| **Politely full** (feed while full) | L3 | 1.2 s (head-turn + eyes-close + refuse mouth pose) | FR-6 AC-1 | one-shot |
| **Gentle decline** (feed while asleep) | L3 | 1.0 s (half-turn away, eyes stay closed) | PRD §4 "gently declines, sleepy" | one-shot |
| **Sleepy nibbles** (feed, Drowsy/Exhausted) | L2-variant | 3–4 s (slower eat, smaller) | PRD §4 | eat rig, slower |
| **Yawn** (Drowsy play ending; idle event) | L3 | 1.4 s | PRD §4 | one-shot |
| **Settling** (tuck-in) | L2 | 2.5–3.5 s (yawn → lie down → blanket settles) | FR-8 AC-3 | one-shot into sleeping |
| **Blanket-adjust** (tuck while already asleep) | L3 | 1.5 s (blanket nudge + deeper settle) | PRD §4 care row | one-shot |
| **Quest-complete sparkle** | L4 | 0.9–1.2 s (single small sparkle drift above Momo) | PRD §5.4 (no modal) | 1–2 additional shape layers, < 1.5 s |
| **Stage celebration** | L4 | 1.6–2.0 s (perked ears + happy bounce + soft sparkle ring + cheek accents) | FR-10 AC-4 | bounded one-shot; restrained by design — a warm beat, not fireworks |

## 4.4 Full 15-state mapping (project.md §4) → Phase 1 vs later

Every §4 state is accounted for; nothing is silently dropped (FR-4 AC-4: the minimal set is the Phase 1 contract; the full inventory is not).

| §4 state | Disposition | Where / when |
|---|---|---|
| idle | **SHIPPED** | §4.2 base state |
| blinking | **SHIPPED** | §4.2 L1 layer |
| breathing | **SHIPPED** | folded into idle as the L0 layer (never a separate state) |
| looking around | **SHIPPED** | §4.2 L1 event |
| happy | **SHIPPED** | §4.2 burst + §3.2 Joyful expression |
| excited | Later — Phase 2/3 | would need triggers that risk noise; folded into Joyful play intensity only if a Phase 2 need emerges |
| sleepy | **SHIPPED** (covered) | Drowsy/Exhausted expressions (§3.3) + yawn + low-energy state + settling — §4's "sleepy" is the pre-sleep drowsiness arc, fully covered by these four pieces |
| sleeping | **SHIPPED** | §4.2 |
| eating | **SHIPPED** | §4.2 |
| playing | **SHIPPED** | §4.2 |
| walking | Later — Phase 2/3 | needs locomotion + a room scale Phase 1's static room doesn't justify (K4) |
| surprised | Later — Phase 2/3 | requires a startle-trigger concept; high noise risk; deferred by design |
| receiving affection | **SHIPPED** (covered) | the touch-reaction family (§4.3 + §6.1) is exactly this state; recorded explicitly so §4 coverage is auditable |
| celebrating | **SHIPPED** (restrained form) | stage celebration + quest sparkle (L4); a fuller celebration form returns in later phases |
| low energy | **SHIPPED** | §4.2 rest overlay |

*Deferred rows carry disposition only; their full trigger/duration/interruption specs ship with the phase that ships each state. This is the explicit — not silent — reading of the task's "every state" requirement, sanctioned by FR-4 AC-4 (the minimal set is the Phase 1 contract; the full inventory is not).*

---

# 5. Idle Behaviour Choreography

## 5.1 Layered sequencer

Idle is not one animation; it is the L0 breath layer + a **deterministic event sequencer** driving L1 events and idle-variant swaps. The sequencer is a pure function: given (seed, timeline), it yields the full event schedule. This is what makes FR-4 AC-1 testable and §23's "deterministic where tests require" literal.

**Seed derivation (contract with TASK-006):** `idleSeed = hash(petID, localDay, choreographyEpoch)` where `choreographyEpoch` changes only when the app's idle-variant catalog changes. Consequence: a given day's idle behavior is **stable within the day** (consistent personality) and **varies across days** (FR-4 AC-1: five mornings in a row are observably different). The engine derives and injects the seed; the character consumes it (§9.4).

## 5.2 Scheduler parameters

| Scheduler | Interval distribution | Event |
|---|---|---|
| Blink | N(6 s, σ 2 s), clamped [2.5, 12]; 12% double-blink; interval ×1.4 when Drowsy; none asleep | L1 blink |
| Look-around | every 9–21 s; gaze target drawn from the 5-point set {left, right, up-toward-user, at-user, eyes-close moment}; hold 1.5–4 s | L1 gaze; Joyful raises "at-user" probability ×1.4 |
| Micro-motion / idle variants | every 14–30 s; one variant drawn from the catalog below | L1/L2-accent |
| Yawn | Drowsy only: every 45–90 s | L3 |

**Idle-variant catalog (Phase 1; data, not code — new variants are additive):** weight-shift left/right · single-ear twitch · tail flick · slow full-body look-around · cheek-press rest (species-flavored) · (Direction C: per-ear curious asymmetry; Direction A: paw peek; Direction B: whole-body round↔oval settle). Mood/Energy modulate scheduler frequencies per §3.2–3.3.

## 5.3 Guarantees and fallbacks

- **Determinism:** same (idleSeed, elapsed timeline) ⇒ identical idle event log (testable pure function; clock injected).
- **Aliveness floor:** if the sequencer is interrupted or fails, the base idle (breath + blink) still renders — the character degrades to calm, never to frozen stillness while awake.
- **No distraction:** between events, the only running animation is the breath transform. Idle never approaches "constant excessive motion" (§4): at Content/baseline the stage is motionless ~85–90% of any 30-second window.
- **Pause discipline:** all schedulers are next-event timers; app-hide zeroes the CharacterClock and the entire schedule resumes cleanly on return (no event backlog bursts — timers re-schedule, never replay).

---

# 6. Interaction → Reaction Map

## 6.1 Touch gestures × zones (Content-state baseline — FR-5 AC-1 "distinguishable reactions")

All gestures are available in **every** state (FR-5 AC-2); sleeping overrides per §6.2. Eye-follow accompanies all touch per §2.4.

| Gesture · Zone | Reaction | Duration | Character |
|---|---|---|---|
| Tap · head | tiny ear flick + soft half-blink | 0.4 s | "acknowledged" — quiet |
| Tap · belly | small squash-bounce (scaleY 0.96, damped spring) + brief eye widen | 0.45 s | "boop" |
| Double-tap · either | ear perk + eye brighten + tail wag ×2 | 0.7 s | delight |
| Long-press · head | lean-in + eyes close to 40% and hold for press duration; on release, content exhale (+ slow-blink-back at Best Friends+) | press-length | **"melting" — the premium signature beat** |
| Long-press · belly | gentle side-to-side rock (±2°) + happy squint | 0.9 s | giggly, but slow — never tickle-frantic |
| Stroke · head | eyes close fully in contentment, ears soften down; a 2nd+ stroke in the same touch deepens to a slow blink | ~1.2 s per stroke cycle | deep contentment |
| Stroke · belly | playful rock + bright eyes | ~1.0 s | playful |

**Rapid-pat softening (FR-5 AC-3):** the coalescing rule (§4.1 rule 3) implements the **visual** half of "later pats simply soften" — full reaction for pats 1–2, abbreviated for 3–4, coalesced gentle response beyond, per 500 ms window. The AC's same-day **effect-diminishing** half is engine-owned (D18; TASK-006 per PRD §4), not a character behavior. No lock, no penalty, no mood reduction ever.

## 6.2 State gating (mirrors PRD §4 response matrix — normative semantics; engine owns the plan, §9.2)

| Interaction | Energetic/Relaxed | Drowsy | Exhausted | Sleeping (night window) | Just fed (full) |
|---|---|---|---|---|---|
| **Touch** (any gesture) | full §6.1 reactions | soft, slower versions (tempo ×1.4) | soft, slower | **stir** (§4.3), stays asleep | unaffected (normal reaction) |
| **Feed** | eating state (§4.2), mood+/energy+ | sleepy nibbles | sleepy nibbles (smaller) | gentle decline | **politely full** — cute refusal, zero penalty |
| **Play** | full round | short low-key round, ends in yawn | gentle stir only | gentle stir only | unaffected |
| **Tuck in** — clock-gated (FR-8 AC-1): the offer is **absent before 20:00 local in every band**; from 20:00 through the night window | settling → sleeping | settling → sleeping | settling → sleeping | blanket-adjust (still counts) | unaffected |
| **Nap** | not offered | settle to nap → waking at restore | settle to nap → waking at restore | (asleep) | unaffected |

Every row is warm. There is no rejecting, locking, or punishing response anywhere in the map (D18; INV-6). The **refusal** is the hardest beat to keep warm and is therefore fully specified: head turns slightly away, eyes close, refuse mouth pose, 1.2 s — it must read as a sated sigh, never a rejection.

The PRD §4 matrix's dashes in its Tuck-in row are **offer-column placeholders**; the clock gate above resolves them: FR-8 AC-1 gates the *offer* by local time, not by band — before 20:00 no waking band is offered tuck-in; from 20:00 every waking band settles to sleep.

**Transitional wakefulness (§9.2's `.settling` / `.waking`).** The columns above cover the four bands + sleeping; the two transitional states are defined here. **Waking** (the 1.8–2.5 s stretch): §4.2's completion rule, generalized — interactions arriving during it queue and apply on completion. **Settling** (2.5–3.5 s): interactions produce the **warm target-state response** — feed → gentle decline (sleepy) or queued-until-wake; play → queued or declined-warm; touch → soft stir. Which interactions queue and which decline-warm is TASK-006's confirmation item (§9.6). If the engine lets an interaction preempt settling mid-animation, the character emits `handshakeCancelled(.settle)` (§9.2) so no state is ever stranded.

## 6.3 Play round — character-side motion contract (inside TASK-004's delivered UX-3 shell)

TASK-004 has **delivered** the play UX (decision UX-3): a fingertip-follow round — Momo playfully follows the user's fingertip; participation optional, no score, no timer, no win/lose. This document owns the character-side motion art inside that shell; the interaction UX remains TASK-004's (03-ux-architecture §5.3). The character contract:

| Shell phase (TASK-004 UX-3) | Character motion | Bound |
|---|---|---|
| 1 · Invite | play-ready perk — ears up, anticipation lean (§3.3), bright eyes | ≤ 3 s |
| 2 · Follow | Momo bounds/spins after the fingertip; if the finger rests, Momo performs solo — participation is optional, never demanded | 10–20 s |
| 3 · Payoff | joyful flourish + soft sparkle ring, then settle to idle (celebration curve — single overshoot ≤ 8%, §7.2) | ≤ 5 s |

- **Round total ≤ 30 s** (FR-7 AC-1): the character paces the follow phase so the round always lands in-window regardless of fingertip behavior (handshake, §9.2).
- **Two moving transform groups maximum** — Momo + the follow/gaze system; no third actor, no physics (§7.4 rule 4).
- **State variants (§6.2 rows authoritative):** Drowsy → a low-key, shorter follow ending in the yawn; Exhausted or sleeping → gentle stir only.
- **Handshakes:** starts on engine authorization; finishes via `playRoundFinished` (or `handshakeCancelled(.play)` on preemption — §9.2).
- Reduce Motion: milestone poses only (§7.3) — the round still completes for engine purposes (FR-7 unaffected).

## 6.4 Watch interaction (FR-17)

One interaction: **pat** — tap anywhere on the Watch stage. Reaction is **state-distinct** (matching TASK-004 §6.2 and PRD §4): **awake → happy micro-bounce; asleep → stir + tiny heart, stays asleep** (≤ 1 s) + subtle haptic (Watch-owned). Offline-first: renders locally from last-synced state with no error surface (D5/FR-17 AC-2/3). AOD: static snapshot, no reaction, no animation (FR-17 AC-5, D16).

---

# 7. Motion Timings, Curves, Reduce Motion, Battery & Performance

## 7.1 Master timing table (all character-owned durations; engine never hard-codes these — §9.3)

| Motion | Value | Notes |
|---|---|---|
| Breath cycle — Joyful | 3.8–4.2 s | amplitude: bottom-anchored body scaleY 1.5–2.5% (§2.2's body-level channel). At this amplitude it reads as breath, not whole-body deformation; if SwiftUI previews show it reading whole-body in any direction, the fallback upgrade is a chest/upper-body sublayer (rig becomes 18 parts). Previews check: VERIFY-AT-BUILD |
| Breath cycle — Content | 4.6–5.2 s | default |
| Breath cycle — Wistful | 5.8–6.4 s | |
| Breath cycle — Drowsy / asleep | 6.5–8.0 s | asleep amplitude reduced ~30% |
| Blink | close 140–180 ms + open 100–160 ms | interval per §5.2; Wistful blinks ~1.2× slower |
| Gaze shift / return | 220–320 ms out (ease-out) / 600–900 ms back | |
| State crossfade | 300–400 ms | all L2 transitions |
| Micro-event fade-out | ≤ 100 ms (L1) / ≤ 120 ms (L3) | interruption discipline (§4.1) |
| Reactions | 0.4–1.2 s | §4.3/§6.1 |
| Yawn | 1.4 s | |
| Eating | 2.5–4.0 s | 2–3 bite cycles |
| Waking stretch | 1.8–2.5 s | deliberately unhurried — the premium beat |
| Settling | 2.5–3.5 s | yawn → lie down → blanket |
| Quest sparkle | 0.9–1.2 s | PRD §5.4 — subtle inline, no modal |
| Stage celebration | 1.6–2.0 s | FR-10 AC-4 — one-time, gentle |
| Play round | 15–30 s | PRD FR-7 bound; character paces the follow phase to land in-window (§6.3) |

## 7.2 Curves

| Motion family | Curve | Constraint |
|---|---|---|
| Breathing | pure sine | no easing artifacts across loop boundary |
| Ear / tail | damped spring, damping 0.75–0.85 | soft overshoot only |
| Touch reactions | ease-in-out, or gentle spring (response ~0.35 s) | bounce overshoot ≤ 15% |
| Celebrations | single soft overshoot ≤ 8%, then settle | **no bouncing-ball loops, no repeated bounce** — the childish-pole tripwire |
| Settle / sleep | ease-in (gravity-like), decelerating into stillness | |

## 7.3 Reduce Motion (D16 — binding mapping)

| Normal behavior | Reduce Motion replacement |
|---|---|
| Idle loop (breath + L1 schedulers + variants) | **static pose per state** (Content pose unless state says otherwise); no loops run |
| Blink | none (eyes at natural aperture) |
| Look-around / eye-follow tracking | single static "looks toward you" glance on touch (§2.4), released on touch end |
| State changes | 150–200 ms crossfade (or instant) between static poses |
| Touch reactions | end-pose swap with 150 ms crossfade (the reaction's final pose carries its meaning) |
| Celebrations / sparkles | static moment pose + haptic; no motion |
| Waking / settling | single static pose of the end state |
| Playing | static pose sequence at round milestones (start pose, mid pose, end pose) — the round still completes for engine purposes (FR-7 AC-1/2 unaffected) |

Reduce Motion never removes **information** — every state remains distinguishable via its static pose + the UI's glyph/label/text channels (§3.5).

## 7.4 Battery & performance rules (TR3, §33, NFR-1/2/3 — every animation's standing consideration)

1. **Single clock.** All character animation runs on one CharacterClock (§9.5). `scenePhase ≠ active` ⇒ clock zeroed; Watch AOD ⇒ static snapshot. No exceptions, including L0 layers. (This single rule implements FR-4 AC-2, FR-17 AC-5, D16, and NFR-2.)
2. **Transforms only.** Loops animate position/scale/rotation of pre-built layers (R1); no per-frame Path re-generation anywhere — including the mouth (pre-built pose crossfades).
3. **Scheduled, never polled.** L1 schedulers set a timer for the *next* event only; there is no polling loop and no standing CPU cost between events.
4. **Concurrency budget.** Ambient idle animates ≤ 3 properties concurrently; reactions ≤ 8. Playing is the Phase 1 maximum (two transform groups) and is time-bounded.
5. **Watch tiers.** Watch foreground renders a reduced-layer variant of the rig (LOD-glance, §8.5); AOD renders the pre-composed static glyph. Watch never runs the full rig (watchOS efficiency, NFR-9).
6. **Verification obligations (recorded as evidence in EPIC-002):** Xcode energy gauge "Low" over a 10-minute idle session (NFR-2); Instruments animation soak vs. 150 MB memory (NFR-3); smoothness check on the reference device matrix (NFR-1). *(Starting budgets provisional per PRD; tune with §8.)*

---

# 8. Asset Requirements & Production Plan

## 8.1 Pipeline comparison (TR8 — decide pipeline with a budget before producing assets)

| Criterion | **SwiftUI-native vector rig** | Lottie (lottie-ios) | Pre-rendered frames (PNG/sequence) |
|---|---|---|---|
| App size (NFR-4, 60 MB) | KBs — rig is Swift code | + library MBs + JSON per animation | tens of MB at 3× scales — budget-killer |
| Memory (NFR-3, 150 MB) | trivial (vector layers) | decoder runtime per animation | sprite sheets resident in memory |
| Eye-follow / interactivity (§2.4) | **native** — pupils are rig parts | hostile (limited runtime property control) | impossible |
| Dynamic color / dark mode | token-driven (R4) | partial | none (baked pixels) |
| Reduce Motion variants (§7.3) | poses are code data | separate compositions per pose | separate frame sets — triples asset count |
| Watch / AOD (§7.4 rule 5) | same rig, LOD tiers; glyph trivial | watchOS support overhead | scale explosion |
| Pausability (TR3) | one clock stops all | per-animation control | per-sequence control |
| Dependency policy | **zero runtime dependencies** | third-party runtime dependency — collides with the local-first/minimal-surface posture (§21, §31) and at minimum sits badly against FR-20's "no third-party SDKs" (even under the tracker-SDK reading, the dependency buys nothing §8.1's other rows don't already reject) | none |
| Authoring workflow | vector tool → export → generated Swift path constants (repo-local build-time script) | After Effects → JSON (designer-friendly) | traditional animation pipeline |
| Risk | organic-curve authoring effort (mitigated by the export script + SwiftUI Previews loop) | per-animation JSON sprawl for one pet | resolution/variant explosion |

## 8.2 Recommendation: **SwiftUI-native parametric vector rig**

The character is authored in a vector tool, exported, and checked in as **generated Swift `Path` constants** via a small repo-local build-time script (no runtime dependency; script output is committed and reviewable). Poses and expression parameters are Swift data; animation is SwiftUI transforms driven by CharacterClock. Rationale: it is the only option that is simultaneously strongest on eye-follow (a PRD anatomy contract), Reduce Motion variants, Watch/AOD tiers, pausability, and the dependency/privacy posture — and for a **single** pet the traditional weakness of code-authored vector art (authoring effort) is bounded and one-time. Lottie's designer-loop advantage does not outweigh four hard contract mismatches (eye-follow, dynamic color, AOD glyph, dependency posture); pre-rendered frames fail the size budget outright. *(Tooling choice for the export script: VERIFY-AT-BUILD.)*

## 8.3 Budgets (TR8)

| Item | Budget |
|---|---|
| Character rig (all LODs, poses, reactions as Swift code) | ≤ 300 KB source contribution |
| Room scene + props (food, blanket, sparkles; pom only as static room decor) | ≤ 250 KB |
| **Total art contribution to download size** | **≤ 1.5 MB target (~0.5 MB realistic)** vs NFR-4's 60 MB — app size is binary-dominated, not art-dominated |
| Animation-soak memory | well under NFR-3's 150 MB (vector layers; verified per §7.4 rule 6) |
| Every animation's battery posture | per-row notes in §4.2–4.3 + §7.4 standing rules |

## 8.4 Naming convention (binding)

- Rig parts (Swift): `MomoRig` + part — e.g., `MomoRig.earLeft`, `MomoRig.eyeLeftPupil`; files `MomoRig+<Group>.swift`.
- Bundled data (if any): lowercase dot-namespaced — `momo.room.base`, `momo.room.pom` (static decor).
- Animation clips / states: `idle.breathe`, `state.sleep`, `react.tap.head`, `moment.stageCelebrate` — identifiers match §4/§6 vocabulary one-to-one (the ReactionID vocabulary of §9.2 **is** this namespace).
- Poses: `pose.<band/state>.<variant>` — e.g., `pose.content.base`, `pose.sleep.side`, `pose.reduceMotion.celebrate`.
- Colors: **token slots only** — the character defines required slots (`momo.fur.base`, `momo.fur.shade`, `momo.ear.inner`, `momo.eye.base`, `momo.eye.highlight`, `momo.cheek`, `momo.blanket`, `momo.sparkle`); the slots are the character's contract (R4), while slot **values** are assigned by the **EPIC-002 design-system pass** — one palette pass covering project.md §18 UI + these character slots together, so the palette coordinates across both (Appendix B item 3). No hex in rig code (R4).
- Copy: String Catalog keys `momo.line.<slot>.<nn>` and `momo.line.react.<family>.<nn>` (§10.4; D12 — no string literals in views, FR-20 AC-4).

## 8.5 What Phase 1 actually ships (manifest)

| Asset group | Contents | Count (approx.) |
|---|---|---|
| Rig — full (iPhone) | all §2.2 parts | 1 rig, ~17 parts |
| Rig — LOD-glance (Watch foreground) | reduced layers (no pupil-tracking split, simplified paws) | 1 variant |
| Rig — glyph (complication/AOD/widget-free surfaces) | silhouette-preserving simplification (Direction-per §1 rules) | 1 variant |
| Poses | per §7.3 mapping: content base ×4 mood poses, drowsy/exhausted overlays, sleep (side), waking end, eat start/end, refuse, settle end + 6 static Reduce Motion poses | ~14 |
| Reactions | §4.3 vocabulary | ~12 |
| States | §4.2 nine-state contract | 9 |
| Idle variants | §5.2 catalog | 6 |
| Room scene | static, charming, non-interactive (FR-3, K4); may include the pom as static decor | 1 |
| Props | food, blanket, 2 sparkles (sparkles moment-scoped) | 4 |
| Moments | stage celebration, quest sparkle, greeting sequences (fresh-morning / welcome-back / missed-you / night-glance) | 4 |
| Copy | §10 line sets, String Catalog | ~50 lines |

**Explicitly NOT in Phase 1** (§27 Phase 3): outfits, accessories, seasonal variants, additional pets, walking/locomotion, interactive room objects.

---

# 9. Engine ↔ Character Contract (the TASK-006 interface)

This section is the interface specification between this document and the Pet State Engine (TASK-006). Division of authority in one line: **the engine owns *what* and *when* (state, gating, effects); the character owns *how it looks* (durations, choreography); the presentation layer owns *whether it runs* (visibility).**

## 9.1 Data flow

```
UI (TASK-004 surfaces)
  │ InteractionIntent (touch zone+gesture | feed | play | tuckIn | nap)
  ▼
PET STATE ENGINE (TASK-006)  — evaluates PRD §4 matrix (D18), applies effects,
  │ ResponsePlan                counters, bond, satiety
  ▼
CHARACTER LAYER (this document) — renders ReactionID + copy key + haptic;
  │ CharacterReport (completion)   runs idle sequencer off injected seed
  ▼
UI renders / haptics fire
```

The character **never decides** whether an interaction "works" — warm or declined, full or hungry (D18) — it executes the engine's plan. The character never applies numeric effects; it only reports completions.

## 9.2 Interface sketch (Swift-shaped; TASK-006 finalizes exact types/placement — *interface definition, not implementation*)

```swift
struct CharacterDisplayState: Equatable, Sendable {
    var moodBand: MoodBand          // .joyful / .content / .wistful / .low (§3.2)
    var energyBand: EnergyBand      // .energetic / .relaxed / .drowsy / .exhausted (§3.3)
    var bondStage: BondStage        // .newFriends … .soulCompanions (§3.4)
    var wakefulness: Wakefulness    // .awake / .settling / .asleep / .waking
    var activity: Activity?         // .eating / .playing / .napping (§4.2)
    var satietyHint: SatietyHint?   // .hungry / .recentlyFed / .full — window owned by engine
    var momentRequest: CharacterMoment? // see below
}

enum CharacterMoment: Equatable, Sendable {
    case greeting(GreetingKind)      // .freshMorning / .welcomeBack / .missedYou(≥36h) / .nightGlance
    case questCompleted              // PRD §5.4 sparkle (no modal)
    case bondStageReached(BondStage) // FR-10 AC-4 one-time celebration
}

struct ResponsePlan: Equatable, Sendable {
    let reaction: ReactionID         // §4.3/§6 vocabulary — the §8.4 namespace
    let lineKey: String?             // optional String Catalog key (§10); nil = animation speaks alone
    let haptic: HapticID?            // presentation-owned vocabulary
}

enum CharacterReport: Sendable {     // character → engine, idempotent (TASK-006: tolerate late/duplicate delivery)
    case reactionFinished(ReactionID)
    case playRoundFinished
    case handshakeCancelled(HandshakeKind) // preemption path — see below (idempotent, same tolerance)
    case settleFinished              // settling → engine flips .asleep (handshake)
    case momentFinished(CharacterMoment)
}

enum HandshakeKind: Sendable { case settle, wake, play }
```

**Handshakes (event-driven, never timer-based on the engine side):**
- *Tuck-in:* engine sets `wakefulness = .settling` → character runs settling (§7.1) → `settleFinished` → engine sets `.asleep`. Engine must accept the report arriving late or after a newer state change (idempotent).
- *Wake:* engine sets `.waking` → character runs the stretch → report → engine sets `.awake`.
- *Play:* engine authorizes round → character paces it within ≤ 30 s (§6.3) → `playRoundFinished` → engine applies round effects. Effects are applied at the **single instant the round ceases** — completion (`playRoundFinished`) or preemption (`handshakeCancelled(.play)`) — so backgrounding mid-round (§4.1 rule 6) and interaction-preemption are one deterministic application point (the unified proposal, stated once at §9.6 item 4).

**Cancellation (the preemption path).** A handshake can be preempted before its report fires: a newer L2 replaces settling mid-animation (e.g., Feed tapped 1 s into the 2.5–3.5 s settle — §6.2's transitional-wakefulness note), or the app hides before a round completes. In every such case the character emits `handshakeCancelled(kind)` (idempotent — the same late/duplicate tolerance as above) so the engine is never stranded in an intermediate `wakefulness` waiting for a report that will never arrive; effects for a cancelled play round apply at the same unified instant (§9.6 item 4). Waking is expected never to cancel — app-hide pauses it and it completes on return (§4.1 rule 8); the `.wake` case exists for contract totality.

## 9.3 Timing authority

| Concern | Owner |
|---|---|
| Band/stage/wakefulness changes; interaction gating & numeric effects (D18); night window (D11); daily reset | **Engine (TASK-006)** |
| All animation durations, loop rates, crossfades, curves | **Character (§7.1–7.2 tables — normative)** |
| Play-round pacing within the 15–30 s bound | Character paces; engine validates the bound |
| Satiety window ("recently fed → politely full") | **Engine** — character renders only the hint it is given |
| Pause/resume on visibility / AOD | **Presentation layer** (scenePhase / AOD observers) — engine unaware |

## 9.4 Randomness (§23, FR-4 AC-1, FR-13 AC-3)

The engine injects a **seeded RNG** and a **Clock**; the character's idle sequencer is deterministic given (idleSeed, timeline) per §5.1. The engine must inject a *day-stable* seed (`hash(petID, localDay, choreographyEpoch)`); the character never calls system randomness. Character-side determinism is testable without the engine; engine-side determinism is testable without the character.

## 9.5 Pause authority

One `CharacterClock` (or equivalent) gates L0–L4; presentation stops/starts it on scenePhase and AOD transitions. The engine is never involved in pausing. Schedulers re-schedule on resume (§5.3 — no backlog replay).

## 9.6 TASK-006 obligation checklist (from this document)

1. Implement ResponsePlan evaluation per the PRD §4 matrix (D18) with ReactionIDs from §8.4's namespace.
2. Own and define the satiety window (recently-fed → full) driving `SatietyHint`.
3. Implement settle/wake and play-round handshakes with idempotent completion reports **and the cancellation path** (`handshakeCancelled`, §9.2).
4. **Play-effect application point (one open decision, stated once here):** effects for a round are applied by the engine at the **single instant the round ceases** — completion (`playRoundFinished`) or preemption (`handshakeCancelled(.play)`, §9.2) — making backgrounding mid-round (§4.1 rule 6) and interaction-preemption the same deterministic application point. TASK-006 confirms or amends; §9.2 and §4.1 rule 6 reference this item rather than restating the decision.
5. Inject day-stable idle seed + clock (§9.4); guarantee determinism properties (FR-13 AC-3).
6. Provide MoodBand/EnergyBand/BondStage/Wakefulness derivation from engine internals (PRD §3 bands are the source of truth).
7. Carry §7.4 verification obligations (energy gauge, memory soak) into EPIC-002 test plans.
8. Confirm the interaction-during-settling semantics — which interactions queue until wake vs. decline-warm (§6.2's transitional-wakefulness note) — and implement `handshakeCancelled` handling to match (§9.2).

---

# 10. Tone Guide (copy voice for Momo)

## 10.1 Voice rules (binding for ALL Phase 1 user-facing copy)

1. **Third-person, name-led where the line carries an action or state:** "Momo …" — Momo observes and is observed; Momo does not lecture. Nameless ambient lines are permitted in the day/night ambient pools (M3, N10 sanctioned).
2. **Short:** ≤ 8 words typical, ≤ 12 hard max.
3. **Present tense / present progressive for current states:** "Momo is dozing", "Momo perks up". Simple past is permitted for day-recap and just-observed events (sanctioned class: E3, E6, N3, M6, and the return greeting "Momo looked up right away."), as is one gentle forward-looking night line (N9).
4. **Warm, not saccharine:** no exclamation spam — at most one "!" per line, and only for genuine delight moments; most lines end softly.
5. **Soft imperatives only in care-of-Momo context:** "Shhh…" is allowed; commands toward the user are not.
6. **No emoji in body copy.** Dimension glyphs (Mood/Energy/Bond) are UI glyphs (TASK-004), not sentence parts.
7. **Copy surface restraint:** visual body copy appears only in the **Home contextual line**, the **greeting**, and a **few care moments** (tuck-in line, refusal line). Micro-reactions carry **no visual text** — the animation speaks (§4.3). Three reconciled surfaces join these (TASK-004's delivered design — Appendix B item 4): **VoiceOver spoken reaction lines**, an **accessibility-only copy class** — a short line announced per reaction so the delight channel is not visual-only (UX-8); sighted users see only the animation (`momo.line.react.*`, §10.4) — and the two **moment lines**: the M2 stage banner (stage name + the PRD-normative descriptor line, FR-10 AC-4) and the M3 all-done line ("Momo had a lovely day." class). Quest completion itself is silent (§5.4). Restraint here is what keeps the product calm (PR1).
8. **Wish-framing for quests** (§5.1 rule 3): "Momo feels like playing", never "Don't forget to…".

## 10.2 FR-12 guardrails as concrete do/don't (normative; review checklist for every string)

| DO | DON'T | Why |
|---|---|---|
| "Momo missed you." | "You forgot about Momo…" | Absence referenced warmly (PRD §3.3); guilt banned (FR-12) |
| "Momo would like a meal." | "Don't forget to feed Momo!" | Wish, not obligation |
| "Momo is getting sleepy." | "Hurry — tuck Momo in before midnight!" | No urgency, no countdowns |
| "All done — see you soon." | "3 quests left! Keep going!" | No completion pressure, no FOMO |
| "A quiet day. Momo rested lots." | "Momo was lonely all day." | Inactivity is rest, not suffering (D4, INV-6) |
| *(nothing — streaks cannot break because none exist)* | "Your streak is gone." | G3: there is nothing to lose by design |
| "Momo is full and happy." | "Momo refused your food." | A sated sigh, never a rejection (D18) |

**Banned vocabulary (hard list):** forgot · lonely · sad · waiting for you · hurry · don't forget · last chance · only X left · streak · miss out · failed · penalty. ("Missed you" is the single sanctioned absence reference, per PRD §3.3.)

## 10.3 Sample lines — 10 per time-of-day slot (all guilt-free; seed the String Catalog)

**Morning (07:00–11:59)**
1. Good morning. Momo just woke up.
2. Momo is stretching off the sleep.
3. A soft start to the day.
4. Momo perked up the moment you arrived.
5. Morning light suits Momo.
6. Momo was dreaming about breakfast.
7. Slow blinks. Momo is glad you're here.
8. The day is quiet so far. Momo likes it.
9. Momo is doing small morning stretches.
10. You two have a whole day ahead.

**Day (12:00–16:59)**
1. Momo is watching dust drift in the light.
2. A calm afternoon. Momo is content.
3. Momo is dozing with one ear up.
4. Momo wouldn't mind a little company.
5. Momo feels like playing, maybe.
6. Everything is peaceful. Momo approves.
7. Momo is loafed in a warm spot.
8. Momo tilts an ear toward you.
9. A quiet hour. Momo is rested and easy.
10. Momo is saving energy for the evening.

**Evening (17:00–21:59)**
1. The light is going soft. Momo is slowing down.
2. Momo is getting sleepy.
3. Momo had a good day.
4. Momo is winding down beside you.
5. A cozy hour. Momo's ears are at half-mast.
6. Momo yawned. That's an evening signal.
7. Momo wouldn't mind a tuck-in soon.
8. The day is settling. So is Momo.
9. Momo is curled a little tighter.
10. Tonight looks good for an early night.

**Night (22:00–07:00 — night-window lines; shown on night glance, D11)**
1. Shhh… Momo is sleeping.
2. Momo is curled up, fast asleep.
3. Momo's ear twitched. Still asleep.
4. A small snore. Momo is deep in a dream.
5. Momo sleeps best on quiet nights.
6. All tucked in. Momo is warm.
7. Momo stirs, then settles again.
8. The house is quiet. Momo is resting.
9. Momo will be ready for morning.
10. Sweet dreams are in progress.

*Evening rhythm lines (E7, E10 — "Momo wouldn't mind a tuck-in soon", "Tonight looks good for an early night") are deliberate P2 persona anchors: Momo as the healthy-rhythm companion. They are user-directed but pressure-free — no deadline, no streak, no obligation (P2's own jobs-to-be-done ask for exactly this soft anchor).*

**Return greetings (context lines, PRD §3.3):** regular — "Momo looked up right away."; ≥ 36 h — "Momo missed you." (the sanctioned variant class; same +8, never more). Bond stage descriptors are PRD-normative and not restated here.

## 10.4 Line selection rules (for TASK-006 engine + String Catalog keys)

Two catalog classes:

- `momo.line.<slot>.<nn>` — the visual body-copy classes of rule 7 (slots: morning / day / evening / night / greeting / care-moment).
- `momo.line.react.<family>.<nn>` — the **accessibility-only spoken reaction lines** (rule 7; TASK-004 UX-8): `<family>` follows the §6 reaction families (touch · feed · play · care). These strings are never rendered as body copy — VoiceOver announces them; sighted users see only the animation.

The M2 stage-banner line and the M3 all-done line live under their own slots (`momo.line.moment.<nn>`).

Slot selection by local time (D11 windows); within a slot, the engine selects via the seeded RNG (day-stable — same day, same line per context), so Momo does not repeat the identical line daily (§8 controlled variation) while remaining deterministic and testable.

---

# 11. Audio Scope Decision — Phase 1

> **DECISION: Phase 1 ships with NO audio. No sound effects, no ambient loops, no voice.**

**Rationale:**
1. **Calm × Premium is served by silence.** A pet that chirps on every touch trends toward the "Noisy" forbidden pole (§1). Quiet presence is the identity; haptics (kept) already carry tactile feedback (FR-17).
2. **Zero cost, zero risk:** no audio assets (helps NFR-4), no audio-session complexity, no silent-mode/silent-switch semantics to design, no risk of an untimely sound in a meeting or at night — a real failure mode for a bedside/evening companion.
3. **Copy restraint compounds it:** §10 keeps text minimal; adding sound would add a third channel where two (motion + haptic) already carry warmth.
4. **Interaction feedback is complete without it:** every reaction in §6 has a motion answer; haptics answer the rest.

**Consequence for FR-19 (binding):** the Settings **sound on/off toggle is OMITTED** in Phase 1 (FR-19: present only if audio ships). Phase 1 Settings: rename pet · haptics on/off · Erase all data · About.

**Revisit criteria (Phase 2+, requires its own scope decision):** only if qualitative reviews/§44 self-test surface a felt absence; then as a small, **opt-in** (default-off) ambient layer — never touch-reaction chirps — with the same calm review gate. Recorded now so the absence is a decision, not an omission.

---

# Appendix A — Requirements Traceability

| Obligation | Source | Where satisfied |
|---|---|---|
| 2–3 character directions, owner sign-off | E2, D9 | §1 (+ gate box) |
| Head/belly zones | FR-5 AC-4, D9 | §2.3 |
| Eye-follow on iPhone | §4, D9 | §2.4 |
| Anatomy implementable in SwiftUI/vector | TR8, FR-4 | §2.2, §8 |
| Expression inventory on Mood/Energy/Band system | §5, §3, D10 | §3 |
| Color-independent state | §20, FR-20 | §3.5, INV-5 |
| FR-4 minimal state set = Phase 1 contract | FR-4 AC-4, K3 | §4.2 |
| Full 15-state accounting | §4 | §4.4 |
| Trigger/duration/loop/interruption for every state | task file §4 requirement | §4.1–4.3, §7.1 |
| Controlled idle variation, seeded & deterministic | §8, §23, FR-4 AC-1, FR-13 AC-3 | §5, §9.4 |
| Interaction map per FR-5/6/7/8 + PRD §4 matrix | FR-5–FR-8, D18 | §6 |
| Battery statement on every animation | §33, TR3, NFR-2 | per-row notes §4.2–4.3 + §7.4 |
| Pause when hidden / Watch AOD | D16, FR-4 AC-2, FR-17 AC-5 | §7.4 rule 1, §9.5 |
| Reduce Motion → static poses | D16, FR-4 AC-3 | §7.3 |
| Asset pipeline + budget | TR8, NFR-3/4 | §8.1–8.3 |
| Tone guide + guardrails + sample lines | PR1, FR-12, §15 | §10 |
| Audio scope decision (FR-19 dependency) | PRD §10 TASK-005 obligations | §11 |
| Engine contract for TASK-006 | §23, project.md §40 Step 5 dependency | §9 |
| Stage celebration / quest moment | FR-10 AC-4, §5.4 | §4.3 (L4), §6 |
| VoiceOver state formula | FR-20 | §3.5, §2.3 |
| One pet, no outfits/seasonal | §27, MVP protection | INV-8, §8.5 |

# Appendix B — Handoffs & Reconciliation Record

**To TASK-004 (UX) — Reconciliation Record** (TASK-004 is committed; its UX decisions stand; both documents derive from PRD §4, the normative matrix — outcomes recorded here, no TASK-004 edits):

1. Touch zones + VoiceOver: the y = 550 normalized partition (§2.3) fills TASK-004's "geometry TASK-005" deferral; head = soothing / belly = playful registers match §6.1 across all seven gesture×zone rows. **Resolved:** canvas custom actions are gesture analogs only ("Pat" / "Cuddle"); feed/play/care are the Home action-row labeled buttons — no rotor duplication (§2.3).
2. Play round — **ruled:** TASK-004's UX-3 (fingertip-led, committed) governs; this document's earlier "Drifting Pom" toy-led proposal is withdrawn, and §6.3 now specifies the character-side motion art inside UX-3's three-phase shell (invite / follow / payoff). The pom toy is dropped from the Phase 1 interactive manifest (§8.5); it may persist as static room-scene decor (FR-3).
3. Color tokens (§8.4): the slots are the character's contract (R4); token **values** are routed to the **EPIC-002 design-system pass** — one palette pass covering project.md §18 UI + the character slots together, so the palette coordinates across both. TASK-004 delivers no design system (its §30 scope is items 7–11); TASK-005's header item-14 claim covers the character-side slots only.
4. Copy surfaces (§10.1 rule 7) — **reconciled with TASK-004's UX-8, which stands:** VoiceOver spoken reaction lines are an accessibility-only copy class (sighted users see only the animation); the M2 stage banner (stage name + PRD-normative descriptor) and the M3 all-done line are added surfaces. Rule 7 now matches TASK-004's delivered design; catalog class `momo.line.react.<family>.<nn>` added (§10.4).
5. Glyph variant for future complication/widget surfaces is defined (§8.5) but **not wired** — no widgets/complications in Phase 1 (§27 Phase 2); TASK-004 §7 is reservation-only. No leak in either direction.
6. UX-13 ("haptics, sound" settings): with §11's no-audio decision, UX-13 reduces to **haptics** for Phase 1. No TASK-004 text change required — its S6 row was already conditional on the TASK-005 audio decision and resolves to omitted.

**To TASK-006 (Architecture/Engine):** §9.6 checklist is the binding intake. Open engine-side decisions flagged: satiety window value; **play-effect application point** (single unified proposal — effects applied at the instant the round ceases; §9.6 item 4); **handshake-cancellation semantics** + **interaction-during-settling responses** (confirm the §6.2/§9.2 proposals); **EPIC-002 design-system token values** (§8.4 — reconciliation item 3). All VERIFY-AT-BUILD items inherited from TASK-002 (TR1/TR6/TR10) are untouched here.

**Owner (E2):** pick Direction A, B, or C (§1.4). Everything downstream is stable regardless of the pick.
