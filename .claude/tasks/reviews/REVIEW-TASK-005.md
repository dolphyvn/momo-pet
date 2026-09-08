# REVIEW-TASK-005 — Independent Review: Character System

| | |
|---|---|
| Date | 2026-09-08 |
| Reviewer | task-005-reviewer (fresh, independent — CLAUDE.md §10, §33; unprimed; adversarial brief: attempt to disprove) |
| Artifact | `docs/design/04-character-system.md` (TASK-005 deliverable) |
| Inputs used | `project.md`, `docs/product/01-product-review.md` (D1–D20 binding), `docs/product/02-mvp-prd.md` (normative), `docs/design/03-ux-architecture.md` (TASK-004 deliverable, current post-fix state), `.claude/tasks/active/TASK-005-character-system.md`, `CLAUDE.md` |
| Method | Full read of artifact + all five ground-truth/parallel documents; 15-state coverage audit against project.md §4 and FR-4; 8-rule interruption matrix walked against 7 concrete interleaving scenarios; 25-cell comparison of §6.2 against the normative PRD §4 matrix; E2-gate integrity probe in both directions (does the doc lock C? would A/B force rework?); SwiftUI/vector feasibility pass; per-row battery audit; all 40 sample lines + greeting variants swept against FR-12 and the §10.2 banned list; every Appendix B handoff verified against TASK-004's delivered text in both directions; §9 contract race/handshake analysis; Appendix A traceability spot-checks. Read-only review of the artifact; no artifact changes made. |
| Verdict | **CHANGES_REQUIRED** |

---

## Verified Compliant

What was attacked and held. No CRITICAL findings; the three MAJORs (below) are local, fixable defects — not architectural.

- **FR-4 state contract:** the §4.2 table matches the FR-4 minimal set exactly, state for state — idle/breathing, blinking, looking around, sleeping, waking, happy, eating, playing, low-energy — including Waking, which project.md §4 omits but FR-4 requires. All 15 project.md §4 states are accounted for in §4.4 (details in Verification Results); the four deferrals are legitimate under FR-4 AC-4 + K3, not scope-dodging.
- **PRD §10 TASK-005 obligations — all five delivered:** FR-4 minimal set + battery/motion constraints (TR3/TR8/D16) → §4, §7; head/belly zones + eye-follow anatomy (D9) → §2.3, §2.4; tone guide → §10; asset pipeline with budget (TR8) → §8; audio scope decision → §11.
- **Audio-scope authority (checked for escalation per CLAUDE.md §36):** §11's no-audio decision is squarely within delegated authority. FR-19 (`02-mvp-prd.md:365`) states the sound toggle exists "only if Phase 1 ships any audio — audio scope is decided by TASK-005; otherwise the toggle is omitted," and PRD §10 lists the audio scope decision verbatim as a TASK-005 obligation. The decision is reversible (Phase 2 revisit criteria recorded), low-risk, pre-authorized. No owner escalation required. TASK-004's delivered S6 (line 67, post-fix) already carries the row conditionally — it resolves to omitted under §11; no S6 contradiction. Only TASK-004's UX-13 wording is stale (MINOR-8).
- **E2 gate integrity:** the gate survives adversarial probing. Three fully specified directions; explicit sign-off box (line 105); §2.1's Direction-C landmarks are disclosed as such ("A and B substitute their §1 ratios — the landmark *roles* are identical"); §5.2's idle-variant catalog gives per-direction substitutions (C: per-ear asymmetry; A: paw peek; B: round↔oval settle); §8.5's glyph rules are direction-parameterized. The recommendation is honestly weighted: B's V1/V7 weakness is real against §19's "ear/tail movement" requirement and the 4×4 band load; A's genericness (PR5) is the strongest differentiator argument; C's one weakness (glance-size ears) is disclosed with a hard rule + glyph mitigation. The owner gets a genuine decision with named fallbacks (B if glance legibility above all; A if universal warmth). One honesty footnote, not a defect: real cats are also crepuscular, so A's "Moderate" behavioral-fit score reflects design-thesis usage rather than biology — defensible, worth a sentence.
- **Direction-agnostic claim (§2–9):** probed for hidden species assumptions that would force rework under A or B — none found. Per-ear rotation as a base rig channel is harmless on A's small ears and B's nubs; the y=550 partition, eye-follow mechanics, pose system, L0–L4 classes, ReactionID namespace, and Reduce Motion poses are all species-portable. Under B the ear/tail channels *degrade* (disclosed in §1.2's own risk list) but no contract breaks; §3.4's ear-led greeting vocabulary executes more subtly on B without rework. The claim holds.
- **Philosophy compliance:** no bounce loops anywhere (§7.2 forbids repeated bounce; celebrations ≤ 8% single overshoot; the "childish-pole tripwire" is explicit); pupil size deliberately excluded as a mood channel (§3.1) and §6.1's "eye widen" is aperture-based; Wistful is "sleepy-hearted, not sad" with INV-6's "worst visual state = sleeping"; the refusal beat is fully specified to land as "a sated sigh, never a rejection" (§6.2 closing note), matching PRD §4's "cute refusal, zero penalty" and D18; belly long-press is "giggly, but slow — never tickle-frantic." The Drowsy yawn scheduler is state-honest, not pressure.
- **Battery/perf honesty (TR3/§33/NFR-2/3):** every §4.2–4.3 row carries a concrete note; the six §7.4 standing rules are implementable as stated. Checked specifically for hidden standing costs: the L0 tail metronome is *counted* (≤ 3 ambient properties budget, rule 4) and is transform-class like breath; eye-follow tracks only during an active stroke with a bounded 600–900 ms release; L4 sparkles are 1–2 layers for < 2.0 s, bounded; blinking has zero standing cost (next-event timers); "scheduled, never polled" is real. Play as the Phase 1 maximum (two transform groups, ≤ 30 s, fully pausable) is plausible. Verification obligations are honestly marked provisional, not claimed as results.
- **SwiftUI/vector feasibility:** ~17-part transform-only rig (Shape layers + transforms) is standard SwiftUI; clamped pupil offset (30% of eye radius ≈ 3.7 pt travel at a 240 pt stage — stays "well inside the iris" as claimed); pose crossfades, per-ear rotation, and head-follow with trailing delay are all trivially implementable; the repo-local build-time script emitting committed, reviewable Swift `Path` constants is a proven pattern (SwiftGen-class), with tooling correctly marked VERIFY-AT-BUILD. The Lottie rejection is technically fair: runtime pupil tracking via value providers is clunky vs. a native rig ("limited runtime property control" is fair-to-generous), watchOS support overhead is real, and the dependency-posture argument is *honestly hedged* — §8.1's footnote concedes FR-20's "no third-party SDKs" is tracker-framed and rests the rejection on the four contract mismatches plus §21/§31 posture. Pre-rendered frames failing the 60 MB budget is correct.
- **Bond expression (§3.4) — not a covert meter:** the unlocked variants are *stage-gated behaviors*, not within-stage indicators: no progress bar, no numeric hint, no meter; the PRD's mandated stage word + descriptor remain the sole legibility channel, consistent with TASK-004's UX-2 (no within-stage hint anywhere). Greeting quality and latency dials change *response*, not resting posture bands or the body (INV-7's own terms); PRD §3.3's own design uses response-quality changes ("extra-warm responses to care"). One wording defect in the §3.4 intro (NITPICK-8).
- **§9 contract soundness (what holds):** ResponsePlan is a one-way plan — the character never decides warm/cold (D18-clean) and never applies numeric effects; CharacterReport is explicitly idempotent-tolerant ("tolerate late/duplicate delivery"); the seed `hash(petID, localDay, choreographyEpoch)` gives day-stable, cross-day-variable behavior testable without the engine (FR-4 AC-1, FR-13 AC-3 satisfied by construction); pause authority is cleanly assigned to the presentation layer with the engine unaware; schedulers re-schedule rather than replay on resume. The three open engine decisions are correctly fenced to TASK-006 — with one duplication defect (MINOR-1) and one missing handshake case (MAJOR-3).
- **Reverse-check — what TASK-004 delivered that presumes character specifics:** (a) zone geometry ("geometry TASK-005", line 213) — delivered as y=550; (b) head=soothing / belly=playful registers (line 213) match §6.1's reaction characters across all seven gesture×zone rows; (c) meal/tray visual (line 477) — delivered as the §2.2 food prop (the refusal's "tray fades" beat is supported by the prop system but unstated in §4.3 — one clause would close it, NITPICK-level); (d) play motion art (line 477) — §6.3 proposes a structurally different round instead of the §5.3 shell; cleanly fenced but must be explicitly ruled at reconciliation (see cross-doc results); (e) Watch display snapshot (NFR-9/TR9) — the LOD-glance rig + AOD glyph supply the renderable static state; (f) VoiceOver state template (line 428) — §3.5's *example* matches it verbatim but §3.5's *formula text* does not (MINOR-2); (g) TASK-004 §11.3's tone-guide ask covers "reactions per family" — directly contradicted by §10.1 rule 7 (MAJOR-2).

## Findings

Severity legend: CRITICAL/MAJOR block commit; MINOR should be fixed before commit; NITPICK is advisory. **3 MAJOR, 8 MINOR, 8 NITPICK.** Line numbers refer to `docs/design/04-character-system.md` unless prefixed `03:` for `docs/design/03-ux-architecture.md` (current post-fix state).

### MAJOR-1 — §6.2 Tuck-in row is energy-band-gated; the PRD gates tuck-in by clock (FR-8 AC-1)
- Location: line 385 (§6.2, Tuck in row): `| **Tuck in** (20:00+) | — (not offered in waking daytime per FR-8) | settling → sleeping | settling → sleeping | blanket-adjust (still counts) | unaffected |`.
- Evidence: FR-8 AC-1 (`02-mvp-prd.md:282`): "Tuck-in is absent (or visibly not offered) during daytime waking hours; **present from 20:00**." The gate is local time, not the energy band. Per PRD §3.2, energy at 20:00–22:00 is typically 45–65 (start 85, decline ~1–2/hr) — i.e., Relaxed. Under this table a waking Relaxed Momo at 20:30 has no defined tuck-in response: the cell is "—" and the footnote only covers "waking daytime." The PRD's own matrix (`02-mvp-prd.md:169`) contributes to the ambiguity by placing the offer text in the Sleeping column with dashes in the waking-band columns, but TASK-005 — which adds the finer `.settling` wakefulness — inherited and amplified it by assigning "settling" only to the Drowsy/Exhausted cells. As written, the table contradicts FR-8 AC-1 for the most common evening case.
- Correction: Make the row time-gated: window closed → not offered (all bands); window open → "settling → sleeping" in **all** waking bands (Energetic/Relaxed/Drowsy/Exhausted), "blanket-adjust" while asleep, "unaffected" just-fed. The "(20:00+)" row label alone is insufficient; the cells must not contradict FR-8 AC-1.

### MAJOR-2 — §10 copy-surface rule contradicts TASK-004's delivered VoiceOver design and omits delivered surfaces
- Location: line 618 (§10.1 rule 7: "Micro-reactions carry **no text** — the animation speaks"), line 687 (§10.4 keys `momo.line.<slot>.<nn>` only), line 741 (Appendix B item 4: "Home contextual line + greeting + care moments only") vs. `03:241` and `03:433` (UX-8: "every reaction also announces a short spoken line ('Momo nuzzles into your hand') so the delight channel is not visual-only"), `03:477` (TASK-004 §11.3 asks TASK-005 for a tone guide covering "**reactions per family**, sleeping lines, celebration lines"), `03:306` (M2 banner copy), `03:297` (M3 "Momo had a lovely day.").
- Evidence: TASK-005 rule 7's copy-surface enumeration (contextual line, greeting, tuck-in/refusal care moments) excludes three copy classes TASK-004 has already delivered: (1) VoiceOver spoken reaction lines — TASK-004's accessibility answer to a visual-only delight channel, explicitly requested of TASK-005; (2) the M2 stage banner ("{name} and you are now {Stage}. {descriptor line}."); (3) the M3 all-done line. §10.4's String Catalog namespace has no slot class for any of them. Committing §10.1 rule 7 as written would enshrine a cross-document contradiction governing which strings get built — the exact parallel-run hazard Appendix B itself flags for reconciliation.
- Correction: Reconcile explicitly, recommended as (a): VoiceOver spoken reaction lines are an **accessibility-only copy class** (not visual body copy) — amend rule 7 to say so, add a catalog class (e.g., `momo.line.react.<family>.<nn>`), and extend the surface enumeration to M2 (stage banner, PRD-normative descriptor) and M3 (all-done line). Option (b) — overruling UX-8 — instead requires a TASK-004 revision note, since spoken reaction lines are that document's accessibility contract. Either way the two documents must agree before either commits.

### MAJOR-3 — Handshake preemption is undefined: no cancellation path for settling or an in-flight play round
- Location: lines 574–576 (§9.2 handshakes), line 565 (`CharacterReport` — no cancellation case), line 385 (§6.2 — no Settling/Waking columns), line 273 (§4.1 rule 6 covers app-hide mid-round but not interaction-preemption mid-round).
- Evidence: §9.2: "engine sets `wakefulness = .settling` → character runs settling → `settleFinished` → engine sets `.asleep`." Scenario: user taps Tuck in at 20:10, then taps Feed 1 s into the 2.5–3.5 s settling animation. Feeding is always available (D18); per §4.1 rule 2 the new L2 replaces settling via crossfade — eating starts — but `settleFinished` never fires, and the engine, which flips to `.asleep` *only* on that report, is stranded in `.settling`. The idempotency note ("accept the report arriving late or after a newer state change") covers late/incorrect reports, not absent ones. Same shape for play: §9.2 applies round effects at `playRoundFinished`; a Tuck-in tapped mid-round yields no report and no effect application point (rule 6 defines only the app-hide case). §6.2 also has no columns for the `.settling`/`.waking` values of §9.2's own `Wakefulness` enum — Feed/Play/Touch during those windows is undefined (Waking is half-covered by §4.2's "new L2 may follow immediately on completion," which implies queueing but states it only for waking).
- Correction: Add to §9.2 either (a) a `handshakeCancelled(...)` report emitted when a handshake is preempted, plus a §6.2 note defining responses during `.settling`/`.waking` (recommended: interactions during settling produce the warm target-state response — e.g., feed → gentle decline or queued-until-wake; TASK-006 confirms); or (b) an explicit rule that settling/waking are non-interruptible ≤ 3.5 s beats with interactions queued during them. Either is implementable; the document must pick one, and the preemption question should join the §9.6/Appendix B open-decisions list.

### MINOR-1 — Two conflicting proposals for the same open play-effect decision
- Location: line 273 (§4.1 rule 6: "the round's effects are applied **as of the interruption moment**") and line 601 (§9.6 item 4, same proposal) vs. line 576 (§9.2: "Effects are applied **at round end** (proposed)") and line 744 (Appendix B: "end-of-round proposal").
- Evidence: Both are fenced to TASK-006, but a fresh TASK-006 agent reading §9.2 then §9.6 receives contradictory defaults for what is one decision (effect application point for a backgrounded/ended round).
- Correction: Merge into a single open-decision entry stating both candidate rules, or align on one proposal.

### MINOR-2 — VoiceOver formula text contradicts its own example, the PRD's quoted label, and TASK-004's template
- Location: line 245 (§3.5). Formula: "*{Name} feels {mood word} and {energy phrase}*"; energy phrases listed: "is full of energy / is relaxed / is getting sleepy / is very sleepy" → "Momo feels content and is full of energy." The same line's example: "Momo feels content **and has plenty of energy**."
- Evidence: FR-20 (`02-mvp-prd.md:372`) quotes "Momo feels content and has plenty of energy" as the audit string; TASK-004's template (`03:428`) is "feels {mood word} and **has** {energy phrase}." The example matches PRD/TASK-004; the formula text does not. §3.5 is declared binding — as written it fails FR-20 AC-2's audit string by construction.
- Correction: Align the formula to the "has {energy phrase}" construction and re-list the four energy phrases accordingly ("has plenty of energy / is relaxed / is getting sleepy / is very sleepy"), so PRD FR-20, TASK-004's template, and this document agree verbatim.

### MINOR-3 — "Chest-only" breathing is not implementable from the §2.2 part list
- Location: line 406 (§7.1: "chest-region scaleY 1.5–2.5% (chest only, never whole-body — whole-body breathing reads cartoonish)") vs. lines 137–144 (§2.2: Body group = body shape + belly patch; animatable channels are body-level scaleY/X; no chest layer exists).
- Evidence: Scaling the body shape from its bottom anchor moves the entire silhouette — exactly the whole-body breathing §7.1 forbids. The two sections are mutually unsatisfiable as written.
- Correction: Either add a chest/upper-body sublayer to §2.2 (part count 18) or amend §7.1 to accept bottom-anchored body scaleY at reduced amplitude with a note on why it does not read whole-body. One or the other.

### MINOR-4 — Custom-action vocabulary diverges from TASK-004's delivered VoiceOver model
- Location: line 165 (§2.3: "pet/feed/play/care are exposed as custom actions") vs. `03:241` (canvas custom actions are "Pat" / "Cuddle" only; long-press analog) and `03:433` (feed/play/care are labeled Home action-row buttons).
- Evidence: Exposing feed/play/care as pet-canvas custom actions would duplicate the action-row buttons in the VoiceOver rotor — noise against the document's own stated goal ("per-zone targets create rotor noise").
- Correction: Align on TASK-004's model (canvas actions = gesture analogs only; feed/play/care remain action-row buttons), or explicitly justify the duplication; record the resolution in Appendix B item 1.

### MINOR-5 — Color-token values have no owner
- Location: line 496 (§8.4: "TASK-004's design system assigns values"), line 741 (Appendix B item 3) vs. TASK-004's header (`03:5`: scoped to §30 items 7–11, no design system delivered) and TASK-005's own header (line 5: claims "§30 items 12, 14–16" — item 14 *is* Design system).
- Evidence: The token *slots* are well-designed and sufficient for the rig (R4 honored), but token *values* are routed to an owner (TASK-004's design system) that has not scoped that work, while TASK-005's own header claims the design-system item. The routing contradicts both headers.
- Correction: Fix Appendix B item 3 to route token values to a named owner (a design-system pass inside TASK-006 build work, or an explicit TASK-004 follow-up task), and reconcile the two documents' §30 item claims.

### MINOR-6 — Voice-rule drift inside the sample lines themselves
- Location: lines 637–685 (§10.3) vs. line 613 (rule 3: "present tense / present progressive") and line 611 (rule 1: "name-led").
- Evidence: Five samples violate rule 3 in simple past/future: M6 "was dreaming" (line 643), E3 "had a good day" (line 664), E6 "Momo yawned" (line 667), N3 "ear twitched" (line 676), N9 "will be ready" (line 682), plus the greeting "Momo looked up right away" (line 685). Two lines carry no name (rule 1): M3 "A soft start to the day." (line 639), N10 "Sweet dreams are in progress." (line 683). Tone-wise all are clean (see tone audit) — the defect is that the *binding* voice rules contradict the catalog seeded from them, so a String Catalog built from these lines bakes the drift.
- Correction: Either amend rule 3 ("present for current states; simple past permitted for day-recap and just-observed events") or rewrite the five lines; amend rule 1 to "name-led where the line carries an action" or name the two lines.

### MINOR-7 — Watch pat reaction diverges from TASK-004's state-distinct spec
- Location: line 396 (§6.4: "Reaction: stir-or-happy micro-burst (**a single small heart + ear twitch**, ≤ 1 s)") vs. `03:339` ("micro-animation (distinct per pet state: happy bounce when awake; **stir + tiny heart, stays asleep** at night)").
- Evidence: TASK-005's parenthetical describes heart+twitch as the form of both cases; TASK-004 distinguishes bounce (awake) from stir+heart (asleep), and iPhone-side awake pats (§6.1) never produce hearts.
- Correction: Restate §6.4 as state-distinct to match TASK-004/PRD §4, or justify a Watch-only heart-while-awake beat as a deliberate delight difference.

### MINOR-8 — Stale "sound" reference in TASK-004 after §11's decision
- Location: §11 (lines 695–705) vs. `03:462` (UX-13: "Settings values (haptics, **sound**) are app-wide and sync to Watch").
- Evidence: With §11's no-audio decision, the FR-19 sound toggle does not exist in Phase 1 (TASK-004's S6 conditional row at `03:67` correctly resolves to omitted), but UX-13 still names a sound setting that will never exist. TASK-004's own §11.3 (`03:479`) anticipated the update; it was never recorded because the documents ran in parallel.
- Correction: Record in the reconciliation that UX-13 reduces to "haptics" for Phase 1 (no TASK-004 text change strictly required beyond a reconciliation note).

### NITPICK-1 — Wrong pointer for per-direction deltas
Line 105: "only the per-direction deltas in §1.4 apply" — the deltas live in §1.1–1.3 ("Anatomy deltas vs. §2 base contract"); §1.4 is the comparison/recommendation. Fix the pointer.

### NITPICK-2 — Rig part-count bookkeeping uses two different bases
§1's per-direction counts (~10/~7/~11, lines 56/69/82) vs. §2.2/§8.5's "~17" (lines 146/503): the 17 counts the mouth as one slot (3 swappable poses), eyes as 6, cheeks as 2; the per-direction counts appear to be body-side only. One clarifying sentence prevents TASK-006 confusion.

### NITPICK-3 — Unexplained "N2" label in Appendix A
Line 729 cites "PRD §10 TASK-005 obligations, N2" for the audio decision. No "N2" label exists in the PRD (NFR-2 is battery). The adjacent PRD §10 citation is the correct anchor; TASK-004's original "(N2)" was already corrected in its own review for the same reason. Drop the alias.

### NITPICK-4 — §6.2 Sleeping column drops the PRD's "(night window)" qualifier
Line 380 header vs. `02-mvp-prd.md:164`. The document binds D11 elsewhere; the qualifier costs nothing and prevents a literal reader from treating any sleep as the matrix's Sleeping column.

### NITPICK-5 — Rapid-pat wording overstates what the coalescing rule implements
Lines 270/376: the 500 ms coalescing rule implements the *visual* softening of FR-5 AC-3; the same-day effect-diminishing half ("later pats simply have smaller effect") is engine-owned under §4/D18. One clarifying clause avoids implying the character layer alone satisfies AC-3.

### NITPICK-6 — E10 nudges user behavior
Line 671: "Tonight looks good for an early night" softly directs the user's own bedtime. P2's persona (healthy-rhythm anchor) supports it and no rule bans it; confirm it is intended as a user-directed line.

### NITPICK-7 — Deferred states lack trigger/duration rows
§4.4 (lines 312–328) gives dispositions but not the trigger/duration/interruption detail the task AC literally requests for "every §4 state." Defensible under FR-4 AC-4 (the full inventory is explicitly not required), but add one line stating full specs ship with the phase that ships each state, making the deviation explicit rather than silent.

### NITPICK-8 — §3.4 intro overstates its own invariant
Line 231: bond "never [changes] how Momo rests" vs. line 238: Soul Companions unlocks "calm-coexist idle (rests with eyes half-closed, facing you)." INV-7 is *not* violated (calm-coexist is behavior-level expression — aperture + orientation — with posture bands and body unchanged, exactly what INV-7's "expressed through behavior" permits), but the intro sentence, read alone, forbids what the table delivers. Tighten to the parenthetical's actual scope ("never alters resting posture bands or the body").

## Verification Results

### State coverage — 15/15 accounted; deferrals legitimate

| project.md §4 state | §4.4 disposition | Verdict |
|---|---|---|
| idle | SHIPPED (§4.2) | ✓ |
| blinking | SHIPPED (§4.2 L1) | ✓ |
| breathing | SHIPPED — folded into idle as L0 | ✓ legitimate (FR-4 names "idle/breathing" as one) |
| looking around | SHIPPED (§4.2 L1) | ✓ |
| happy | SHIPPED (burst + §3.2 Joyful) | ✓ |
| excited | Deferred | ✓ legitimate — outside FR-4 minimal set; no Phase 1 PRD interaction requires it |
| sleepy | SHIPPED (covered) | ✓ **genuinely complete, not asserted**: Drowsy/Exhausted overlays (§3.3) + yawn (§4.3) + low-energy state (§4.2) + settling (§4.3) do compose the pre-sleep arc |
| sleeping | SHIPPED (§4.2) | ✓ |
| eating | SHIPPED (§4.2) | ✓ |
| playing | SHIPPED (§4.2) | ✓ |
| walking | Deferred | ✓ legitimate — needs locomotion + room scale; K4; FR-4 excludes it |
| surprised | Deferred | ✓ legitimate — startle trigger is noise-risk; outside FR-4 set |
| receiving affection | SHIPPED (covered) | ✓ **genuine**: the §4.3 + §6.1 touch family (7 gesture×zone reactions) *is* this state |
| celebrating | SHIPPED (restrained) | ✓ the restrained form fully satisfies the Phase 1 obligations that exist (FR-10 AC-4 one-time stage celebration; §5.4 sparkle); the "fuller celebration" has no Phase 1 requirement to satisfy |
| low energy | SHIPPED (§4.2 overlay) | ✓ |

The four deferrals (excited, walking, surprised, fuller celebration) are all outside the FR-4 minimal nine, and no Phase 1 PRD interaction requires any of them — this is FR-4 AC-4/K3 working as designed, not scope-dodging; the deferral rationales are additionally philosophy-correct. FR-4's nine-state set is matched exactly, including Waking (which project.md §4 omits and FR-4 adds — the document got this right in both directions). Residual: NITPICK-7.

### Interruption-matrix walk — 8 rules × 7 scenarios

| Scenario | Result | Rule path |
|---|---|---|
| Tap during blink | ✓ coherent | Rule 1: L1 yields, ≤ 100 ms fade, L3 plays over idle |
| Feed while settling (tuck-in) | ✗ **undefined** | Rule 2 replaces settling with eating, but `settleFinished` never fires → engine stranded in `.settling`. No cancellation report exists (§9.2). **MAJOR-3** |
| Tuck-in while eating | ✓ coherent | Rule 2: settling (L2) replaces eating via crossfade; prop fades |
| App-hide mid-celebration | ✓ coherent | Rule 7 pause/resume is consistent with rule 8 (pause ≠ cancel); completes on return |
| Rapid pats 1–10 | ✓ coherent | Rule 3: per-500 ms window — 1–2 full, 3–4 abbreviated, 5+ coalesced; no lock/penalty (FR-5 AC-3's visual half; wording nit NITPICK-5) |
| Touch during sleeping | ✓ coherent | Rule 4 → stir L3 only, stays asleep; consistent across §4.1/§4.3/§6.2/PRD §4; all gestures correctly collapse to stir via §6.1's sleeping override |
| Drowsy play + tuck-in mid-round | ✗ **undefined** | No `playRoundFinished`, no effect application point, no cancellation path for interaction-preempted rounds (rule 6 covers only app-hide). **MAJOR-3** |

No rule is unimplementable as stated; the failures are omissions (one MAJOR-3), not contradictions — except the rule-6/§9.2 proposal split (MINOR-1).

### §6.2 vs. PRD §4 normative matrix — 24/25 cells conform

| Row | Result |
|---|---|
| Touch × 5 columns | ✓ all match ("soft, slower", stir+heart, unaffected) |
| Feed × 5 | ✓ all match (eating / sleepy nibbles / sleepy nibbles smaller / gentle decline / politely full zero-penalty — FR-6 AC-1 satisfied) |
| Play × 5 | ✓ all match (full round / low-key + yawn / gentle stir / gentle stir / unaffected) |
| Nap × 5 | ✓ all match (not offered / offered / offered / asleep / unaffected — FR-8's Drowsy-or-Exhausted gate honored) |
| Tuck-in × 5 | ✗ Energetic/Relaxed cells defective — "—" contradicts FR-8 AC-1's 20:00 time gate for a waking Relaxed Momo (the modal evening case). **MAJOR-1**. Sleeping cell (blanket-adjust, still counts) ✓; Drowsy/Exhausted cells ✓ in isolation |

Header claim "mirrors PRD §4 response matrix — normative semantics" fails on the one row until MAJOR-1 is fixed.

### E2-gate judgment — INTACT
Nothing in the document locks Direction C. Verified in both directions: (a) C-flavored content is either disclosed as such (§2.1 landmarks), direction-parameterized (§5.2 catalog, §8.5 glyph rules), or generic (§7.3 poses, §9 ReactionIDs); (b) A and B force no §2–9 rework — under B the ear/tail channels degrade (disclosed in §1.2) but every contract still executes. The recommendation is honestly weighted (B's V1/V7 structural weakness is real; A's genericness is the live PR5 risk; C's ear-thickness weakness is disclosed with mitigation) and the fallbacks give the owner a real decision. One footnote: A's "Moderate" behavioral-fit score under-credits that real cats are also crepuscular — the score is defensible on design-thesis grounds (the loaf concept doesn't *use* the rhythm) but deserves a sentence.

### Tone audit — 40 lines + 2 greeting classes: 0 violations
Every line swept against FR-12 and the §10.2 banned list (forgot · lonely · sad · waiting for you · hurry · don't forget · last chance · only X left · streak · miss out · failed · penalty). Zero hits. The three flagged-by-brief lines are clean: "Momo missed you" is FR-12 AC-2-sanctioned verbatim and project.md §3 P4's own good example ("Missed you" is the §10.2-sanctioned single absence reference); "Momo wouldn't mind a little company" uses the exact construction of PRD-normative Q7 ("Momo wouldn't mind some pats") — PRD's own wish register, not neediness; "Sweet dreams are in progress" and "You two have a whole day ahead" contain no banned vocabulary, urgency, obligation, or neediness. No exclamation mark appears in any of the 40 lines (rule 4 satisfied). "Shhh… Momo is sleeping" matches the §8/PRD-sanctioned night copy; "Momo is getting sleepy" (E2) matches Q6's normative framing; "All done — see you soon" matches the §5.5 cascade copy. Wistful's VoiceOver rendering as "quiet" is a deliberate clarity choice, permitted. Defects are rule-consistency only (MINOR-6). §10.1's copy-surface restraint vs. TASK-004's delivered surfaces: contradiction — MAJOR-2.

### Cross-document reconciliation (Appendix B, both directions)

| Appendix B item | Result |
|---|---|
| 1. Touch zones + single VO element | ✓ **consistent in substance**: y=550 partition fills TASK-004's explicit "geometry TASK-005" deferral (03:213); head=soothing/belly=playful registers match §6.1's reaction characters across all 7 rows; single-element model matches 03:241/433. Defect: custom-action *contents* diverge (MINOR-4) |
| 2. Drifting Pom vs. UX-3 | ✗ **contradicts as written, cleanly fenced**: toy-led (§6.3) vs. fingertip-led (UX-3, 03:266) are opposite agency models. The fence is correct and complete — "TASK-004 owns the interaction UX surface and must confirm or replace it; the character-side contract (round duration bounds, start/finish handshake §9.2) holds either way" — and the contract genuinely holds under UX-3's timings (≤3 + 10–20 + ≤5 s ⊆ 15–30 s). Required follow-ups: a recorded sign-off ruling; if UX-3 wins, drop the pom from the §8.5 manifest; explicitly reconcile §6.3 against §5.3's three-phase shell (TASK-004 03:477 asked for art *inside* the shell; §6.3 never maps onto it) |
| 3. Color-token slots | ✓ slots well-formed, R4 honored — but value ownership is unrouted (MINOR-5) |
| 4. Copy surfaces | ✗ **contradiction** (MAJOR-2) |
| 5. Glyph defined but not wired | ✓ **consistent**: TASK-004 §7 is reservation-only (no widgets/complications in Phase 1 per §27/§8.3); TASK-005 wires nothing; TASK-004 §7 point 5's Phase 2 "pet face" presumption is exactly what the §8.5 glyph variant supplies later. No leak in either direction |

**Reverse-check (TASK-004 → TASK-005):** zone geometry delivered ✓; soothing/playful registers honored ✓; meal/tray visual delivered as the food prop ✓ (refusal's tray-fade unstated in §4.3 — one clause, NITPICK-level); play motion art not mapped to the §5.3 shell (fold into item 2's ruling); Watch display snapshot supplied by LOD-glance + AOD glyph ✓; VoiceOver state template matched by §3.5's *example* but not its *formula* (MINOR-2); TASK-004 §11.3's "reactions per family" tone-guide ask contradicted by rule 7 (MAJOR-2); TASK-004's post-review S6 ("sound conditional on TASK-005 audio-scope decision", 03:67) resolves cleanly to omitted under §11 ✓, leaving only UX-13's wording stale (MINOR-8).

### §9 contract soundness
Handshake structure, idempotency, seed injection, and pause authority are sound (see Verified Compliant). Defects: the missing preemption/cancellation case (MAJOR-3); the duplicated, conflicting play-effect proposal (MINOR-1). The three legitimately-open engine decisions (satiety window value; backgrounding-mid-play rule; effect application point) are correctly fenced to TASK-006. One race checked and cleared: momentRequest (L4) arriving while an L3 queue is pending is unspecified but implementation-bounded — L4's class table already gives it preemption rights over L2; a one-line note would close it (covered by MAJOR-3's §6.2/§9.2 pass).

### Section completeness — 9/9 required sections present and substantive
1. Visual direction (§1 — three directions + E2 gate; task rule "recommend one and justify, decision flag if product-defining" satisfied) · 2. Anatomy constraints (§2) · 3. Expression inventory (§3) · 4. Animation state inventory with interruption rules — the task's literal question "can a blink be interrupted by a tap?" is answered explicitly at §4.1 rule 1 (§4) · 5. Idle choreography (§5) · 6. Interaction→reaction map (§6) · 7. Motion timings + Reduce Motion (§7) · 8. Asset requirements & production plan incl. the named SwiftUI-native recommendation, budgets, naming, manifest (§8) · 9. Engine contract (§9). Plus §10 tone, §11 audio, Appendices A/B. Task rules honored: battery note on every animation (§4.2–4.3 rows + §7.4); audio noted as a scoped decision with revisit criteria; Phase 1 only (INV-8, §8.5 exclusions).

**Appendix A spot-check (6 rows):** 5 accurate (eye-follow→§2.4; FR-4 AC-4/K3→§4.2; Reduce Motion→§7.3; VoiceOver formula→§3.5/§2.3; 15-state accounting→§4.4); 1 cites the unexplained "N2" label (NITPICK-3; the adjacent PRD §10 citation is correct).

## Verdict Evidence

The review attempted to disprove the document on every axis in the brief and it held most of them under real pressure: the 15-state inventory is genuinely accounted for rather than asserted (the sleepy/affection/celebrating composition claims each check out piece by piece), the FR-4 nine-state contract is matched exactly in both directions including the Waking state project.md itself omits, the four deferrals all fall outside the FR-4 minimal set with philosophy-correct rationales, the E2 gate survives a two-directional probe with the C recommendation honestly weighted against disclosed weaknesses, all 40 tone samples pass FR-12 with zero violations (the three suspicious-looking lines are each sanctioned by the PRD's own normative text), the battery rules contain no hidden standing costs, the Lottie rejection is fairly argued with its weakest claim explicitly hedged, and the §9 contract's determinism and idempotency machinery is genuinely testable as specified. What blocks commit is three concrete, reachable-case defects rather than any architectural flaw: the §6.2 table claims to mirror the normative PRD matrix but gates tuck-in by energy band where FR-8 AC-1 gates it by clock, leaving the modal evening case (waking, Relaxed, after 20:00) undefined-or-wrong; §10.1 rule 7 contradicts the parallel deliverable's already-reviewed accessibility contract (UX-8 spoken reaction lines) and omits two copy surfaces TASK-004 ships, which would codify a cross-document contradiction governing what strings get built; and the §9.2 handshakes lack any preemption path, so the ordinary sequence "tuck in, then feed" strands the engine's state machine with no report ever arriving. Each has a small, local, well-defined fix; none requires restructuring. With the three MAJORs and the eight MINORs applied — most of a few lines each — this document is ready, and its quality baseline is high enough that the fix pass should be quick.

---

**Final status: CHANGES_REQUIRED — 3 MAJOR + 8 MINOR + 8 NITPICK. The three MAJOR findings (§6.2 Tuck-in row vs. FR-8 AC-1; §10 copy-surface conflict with TASK-004 UX-8 + M2/M3 omission; §9 handshake preemption/cancellation gap) must be resolved, and the MINORs should be applied, before the task may proceed to commit per CLAUDE.md §10/§11. Cross-document reconciliation items (play-round ruling, copy classes, token-value routing, UX-13 note) must be recorded against TASK-004/TASK-006 in the same pass. Review performed by an independent fresh agent; artifact unmodified by the reviewer; no commit made.**

---

## Disposition (orchestrator)

All 19 findings were applied by a fresh fix agent (`task-005-fixer`) under explicit orchestrator rulings for every multi-option finding, then verified line-by-line by an independent fresh verification agent (`task-005-verifier`, read-only, adversarial — regression sweeps + failure-scenario re-walks included).

### Fix disposition table

| Finding | Ruling given to fixer | Fix applied | Verification |
|---|---|---|---|
| MAJOR-1 §6.2 tuck-in energy-gated | Option (a): clock-gate per FR-8 AC-1 | Tuck-in row now clock-gated — absent before 20:00 in every band; window open → settling→sleeping in all waking bands; blanket-adjust asleep; just-fed unaffected; §6.2 header claim now true | VERIFIED (line evidence + FR-8 AC-1 cross-check) |
| MAJOR-2 §10 rule 7 vs UX-8 | Option (a): spoken reaction lines = accessibility-only copy class | Rule 7 rewritten; `momo.line.react.<family>.<nn>` + `momo.line.moment.<nn>` classes; §8.4 naming; M2/M3 surfaces added; UX-8 stands (no TASK-004 edit) | VERIFIED (class keys consistent across §8.4/§10.4/App. B) |
| MAJOR-3 handshake preemption | As specified: cancellation path in contract | `handshakeCancelled(HandshakeKind)` (`.settle`/`.wake`/`.play`), idempotent, §9.2 cancellation paragraph, §6.2 transitional-wakefulness note, §9.6 items 3+8, L4/L3 race note | VERIFIED (both strand-scenarios re-walked — no stranded path) |
| MINOR-1 play-effect point | Unified single statement at §9.6 item 4 | Effects applied at the single instant the round ceases; stated once; competing statements removed | VERIFIED (grep clean) |
| MINOR-2 energy phrases | Verb phrases exactly matching FR-20 | "has plenty of energy / is relaxed / is getting sleepy / is very sleepy"; renders FR-20 audit string verbatim | VERIFIED (verbatim 3-doc agreement) |
| MINOR-3 breath rig | Reviewer option (b) | Bottom-anchored body scaleY 1.5–2.5%, chest-sublayer fallback (18 parts) marked VERIFY-AT-BUILD | VERIFIED (arithmetic consistent) |
| MINOR-4 canvas actions | Per TASK-004 | Canvas = Pat/Cuddle only; feed/play/care = labeled action-row buttons | VERIFIED |
| MINOR-5 token values | Route to EPIC-002 design-system pass | Header scope note + §8.4 + App. B item 3 + TASK-006 intake | VERIFIED |
| MINOR-6 rule consistency | Sanctioned-class mechanism | Rules 1/3 amended (name-led where line carries action/state; past tense sanctioned list + N9 as the one forward-looking night line); all 40 lines untouched | VERIFIED (spot-checks comply) |
| MINOR-7 Watch pat | State-distinct per TASK-004/PRD | Awake → happy micro-bounce; asleep → stir + tiny heart, stays asleep | VERIFIED |
| MINOR-8 UX-13 | Record-only; TASK-004 untouched | App. B item 6: UX-13 reduces to haptics; git confirms 03-ux-architecture.md unmodified | VERIFIED |
| NITPICKS 1–8 | As specified | §1.1–1.3 pointer, count-basis sentence (2+1+2+1+6+1+2+2=17), "N2" removed, "(night window)", visual-half clauses, E7/E10 persona footnote, deferred-rows footnote, INV-7 intro | ALL VERIFIED |
| §6.3 play rewrite | UX-3 shell governs (TASK-004 committed) | Mapped onto invite ≤3 s / follow 10–20 s / payoff ≤5 s (max 28 s ⊆ FR-7's ≤30 s); pom withdrawn to static room decor (`momo.room.pom`, manifest cleaned); Drowsy/Exhausted variants per PRD §4; ruling recorded in App. B item 2 | VERIFIED (regression sweep: no stale interactive-pom or "Drifting Pom" references outside the withdrawal record) |

### Fixer judgment calls — verifier rulings

1. Rule-3 extension to N9 + return greeting — **ACCEPTED** (N9 was in the violation list; one sanctioned forward-looking line is the minimal mechanism).
2. `HandshakeKind` includes `.wake` "for contract totality" — **ACCEPTED** (waking never cancels per §4.2/§9.2; the case is deliberately dead; exhaustive enum is right for a TASK-006 interface).
3. Props = 4 (food, blanket, 2 sparkles) with sparkles booked into §2.2 — **ACCEPTED** (closes a real bookkeeping gap; consistent across §2.2/§4.3/§8; external props don't touch INV-4/R2).

### Verification verdict

**ALL_FIXES_VERIFIED.** Regression hunt clean: interactive-pom references gone from §4.2/§7.1/§5/§8/§9; "Drifting Pom" only in the withdrawal record; no stale §-pointers; part/prop counts consistent (~17 + 4); copy-class keys consistent; FR-12/D18/phase discipline/E2 gate all intact post-fix.

### Residual observations (non-blocking, routed to TASK-006 intake)

- **OBS-1:** 03-ux-architecture.md:428's VoiceOver template hard-codes "…and has {energy phrase}." while 04 §3.5's binding formula uses a verb-phrase slot — the FR-20 audit string agrees verbatim in all three docs (the actual AC), but pasting 04's phrases into 03's literal template would misrender for three bands. One clause in 04 §3.5 (or reliance on its binding-formula declaration) closes it; TASK-006-facing.
- **OBS-2:** §10.1 rule 2's 12-word max vs. the M2 banner template (~13 words) — exempt the banner explicitly or scope rule 2 to visual lines in the TASK-006 copy pass.

### Final review status

**APPROVED** — all CHANGES_REQUIRED findings resolved and independently verified per CLAUDE.md §11; residuals are TASK-006 intake notes only. Task cleared for commit.
