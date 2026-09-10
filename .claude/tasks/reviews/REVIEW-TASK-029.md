# REVIEW-TASK-029 — Reduce Motion mapping + token theming audit

Reviewer: independent fresh agent (CLAUDE.md §10/§33). Did not implement; mandate was to disprove.
Reviewed: the uncommitted working-tree changeset on `feature/EPIC-006-character` — new `Sources/MomoCharacter/MomoReduceMotion.swift`, three new suites (`MomoReduceMotion{Mapping,Twin,EndPose}Tests.swift`), new harness `Tools/character-pipeline/render_reduce_motion_evidence.swift`, 25 new PNGs `docs/evidence/character/rm-*.png`, modified `RigMotionModel.swift`, `MomoRigView.swift`, `MomoReactionOverlay.swift`, `RigDisciplineTests.swift`.
Method: re-derived the §7.3 mapping from `docs/design/04-character-system.md` BEFORE reading the implementation; read every new/changed source in full; verified every constant's doc authority by opening 04 §7.3/§3.2–3.3/§3.5/§8.4 and 05 §10.1–10.2; ran my OWN adversarial streams; performed two sanctioned mutation bites with sha256-proven restores.

## VERDICT: APPROVED_WITH_MINOR_NOTES

No contract violation found. The implementation conforms to the task contract R1–R15 and to my independently re-derived §7.3 table; the R15 render-only law held under every adversarial stream I aimed at it, at both the fold and the pose seam; all disclosed authored values check against their cited doc authority; API compatibility is real (verified at every call site); both mutation bites bit exactly as predicted and restored byte-identically; the evidence PNGs verify with a real decoder. Two MINOR findings (one missing pin for a real behavioral path, one over-stating disclosure phrase) and four NOTEs — all documentation/test-completeness items, none behavioral.

Reproduced: `swift test` → **✔ 823 tests in 82 suites passed after 1.592 s**, zero warnings (matches the implementer's claim of 823/82; baseline 789/79 + 34 tests / 3 suites + 2 discipline tests).

---

## MINOR findings

### MINOR-1 — The tracker's two-changes-in-one-window overwrite path is unpinned, and its render snap is not in the Disclosures register

- Evidence: `Sources/MomoCharacter/MomoReduceMotion.swift:108-128` — `fold(_:)` replaces `pending` on every state CHANGE (`pending = MomoReduceMotionTransition(fromState: state, since: at)`), so a second `.displayState` change inside the 0.15 s window departs from the INTERMEDIATE state. No test fires two in-window changes: `MomoReduceMotionMappingTests.swift:185-199` pins one change + one non-change only, and none of the 11 twin-corpus streams collides two changes inside 0.15 s (nearest pair 0.8 s apart). The code comment (:108-110) says "deterministic; disclosed", and the task file's architecture notes state the rule — but the Disclosures register's 12 items do not carry it, and the RENDER consequence is documented nowhere.
- Render consequence (verified by my PROBE1, below): at the overwrite instant the pose SNAPS from the partial A→B blend to the pure B (intermediate) static — the blend's `amount` resets to 1 toward the new `fromState`. My probe measured an ear-channel jump > 5° (asserted; ~12° by arithmetic: at 5.049 the render is 75 % toward the content static, ≈ 4.1°; at 5.051 it is ≈ 98.8 % joyful, ≈ 16.1°). This is defensible under §7.3's "150–200 ms crossfade (or instant)" reading, and R10/R15 are unaffected (the tracker takes no flag) — but it is a visible discontinuity a reader of the register would not expect.
- Failure scenario: a regression that keeps the OLDER window on a second change (e.g. `guard pending == nil` in `fold`) passes the entire 823-test suite — R5's law for rapid state changes would silently change.
- Suggested disposition: one mapping test — two in-window changes → `transition(at: t2) == Transition(fromState: intermediate, since: t2)`; pose just after the overwrite == the intermediate static; pose just before/after differs — plus one register line naming the snap. Cheap; the behavior itself is fine.

### MINOR-2 — Disclosure 4 over-states what the nine identity-ending one-shots render

- Evidence: task file Disclosure 4 says the nine identity-ending one-shots "render a calm settle-back to the band static". They render NOTHING: for those keys `endPose == .identity` exactly (the suite's own pinned partition, `MomoReduceMotionEndPoseTests.swift`), and `identity.lerped(to: identity, ·).faded(·) == identity` at every t (confirmed against `MomoReactionMotion.lerped/faded` guards, `MomoReactionOverlay.swift`/`MomoReduceMotion.swift`) — the render is the band static for the WHOLE slot, with no crossfade and no settle-back motion. The harness knows this ("the identity-ending nine render the band static — no raster", `render_reduce_motion_evidence.swift:255-256`), which makes the task-file phrasing, not the behavior, the defect.
- Why it matters: the honest statement is "no visible touch acknowledgment under RM for 11 of 15 non-press keys" (the nine, plus `decline`/`politelyFull` whose expressed ends are explicitly neutral == the band static, per Disclosure 5). That is a product-legibility tension with 04 :468's closing law worth an owner-visible line: the acknowledgment currently rides the haptic/line seams (EPIC-007). The render itself follows R6's letter — the end pose IS the band static — so this is a disclosure-accuracy finding, not a code defect.
- Suggested disposition: reword Disclosure 4 to "render nothing — the band static throughout the slot"; add one owner follow-up line (possible future authored acknowledge-static; owner decision, explicitly NOT to be implemented opportunistically, §24).

## NOTE findings

### NOTE-1 — Glance-up exit cut (undisclosed RM artifact)
`reduceMotionSlotMotion` holds the glance-up plateau (aperture ×1.10, head −2, pupils (0,−8)) to the slot's end, where `isVisible` prunes it (`t < end`) — a hard cut from plateau to band static. Full motion's bump has already decayed to ≈ identity by the end (attack 0.12 s / release 0.2 s over a 0.5 s slot, `MomoReactionOverlay.swift:125-127`), so RM introduces a discontinuity full motion does not have. This is consistent with RM's static-swap philosophy (the expressed one-shots cut identically under both flags since both hold the same end pose) but is undisclosed. One register line suffices.

### NOTE-2 — Constant doc-comment arithmetic misstatements in MomoReduceMotion.swift
Against the actual `bump` (seconds-based: `hold = max(duration − attack − release, 0)`, `MomoReactionClipMotion.swift:125-135`): (a) `:41-45` claims inviteMotion's shape "is 1 on [1.2, 2.4)" — the true plateau is [0.5, 1.7]; the authored instant 1.5 still lands inside it and on the wag crest (`sin(2π·1.5/1.2) = 1` ✓), so the VALUE is right and the stated INTERVAL is wrong. (b) `:69-70` claims freshMorning 0.88 is "the perk plateau's last instant (release starts at 0.88)" — release starts at 1.15 (0.88 is mid-plateau) — and "the bright open complete" — bright is smoothstep(0.88/0.96) ≈ 0.98, completing at 0.96. All four authored instants verified valid against the true arithmetic (freshMorning 0.88 ∈ plateau [0.25, 1.15], bright ≈ 98 %; welcomeBack 0.2 on the first wag crest exactly; missedYou 0.875 ∈ plateau [0.25, 1.55] on the second wag crest exactly; nightGlance 0.7 ∈ the soft-close hold [0.5, 0.8]). Relatedly, the task file's R7 row calls these "settled key instant(s)" — welcomeBack (perk at smoothstep(0.8) ≈ 0.9, still in attack) and missedYou (bounce mid-decay) are expressive/PEAK instants; the source's own wording ("its expressive instant", :67-68) is the accurate one. Fix the comments, align the task-file wording to the source. Behavior unaffected.

### NOTE-3 — Evidence metric "23–26 luminance levels" not reproducible as stated
Decoding 5 committed PNGs with ImageIO (real decoder), I count 146–248 distinct gray byte values per image (anti-aliasing blends included) — not 23–26. The substantive claims all verify: 100 % pure grayscale (R==G==B for every pixel), 520×520 fulls / 752×564 zooms, well-painted (38–95 %). Restate the metric's definition (likely distinct palette tones before AA) or drop the number. The BT.709 derivation (`grayTone`, harness :70-76) and the closing "no perceptual/contrast claim" disclaimer both check.

### NOTE-4 — State-crossfade blend composes AFTER the overlay (cosmetic, observed)
`RigMotionModel.swift:331-337` applies the R5 blend last, so during a state-change window with an active overlay the blend scales the overlay's contribution toward the from-state's no-overlay static. Endpoints remain exact (pinned) and the result is deterministic; recording it here so a future reader of the composition order isn't surprised.

---

## Verification appendix

### A. Re-derived §7.3 table (from 04 text, before reading the implementation) vs implementation

| §7.3 row | Doc law (re-derived) | Implementation | Authority verdict |
|---|---|---|---|
| Idle loop | static pose per state — no idle animation | schedule events masked + breath amplitude 0 + slow wag off at the pose seam (`RigMotionModel.swift:130-145ff`) | conformant |
| Blink | the band's natural aperture stands | blink substream contributes nothing; lids = expression base | conformant |
| Look-around | static glance on touch, released on touch end | L1 press glance UNCHANGED (flag-invariant, pinned) ; idle gaze-wander suppressed (pupils zero) | conformant |
| State changes | 0.15–0.20 s crossfade (or instant) between static poses | tracker + pose-seam blend at 0.15 (band floor, AUTHORED, disclosed); `lowerLid` steps at p 0.5 | conformant (in band) |
| Touch reactions | end-pose swap with EXACT 150 ms crossfade; "the final pose carries its meaning" | `identity.lerped(to: holdPose, p_in).lerped(to: endPose, p_out)` at `reactionCrossfadeSeconds = 0.15` (exact) | conformant |
| Celebrations | static moment pose + haptic | quest/celebration settled holds at window edges; greetings at authored per-kind key instants (deviation DISCLOSED; haptic → EPIC-007 seam) | conformant (disclosed) |
| Waking/settling | a single static pose of the END state | settle end static (0.94 / 3° / (0,−14)) from the crossfade on; wake renders the awake static (DISCLOSED — the end state IS awake); reports land at unchanged 3.0/2.0 s instants | conformant (disclosed) |
| Playing | static pose sequence at milestones; the round still completes (FR-7 ACs unaffected) | invite (ears 10 / tail 6) → follow → payoff (cheek 0.85) stills, 0.15 s swaps at pacer boundaries; 12.0/8.0/4.0 pacing; `playRoundFinished` identical (19.4/15.4 pinned) | conformant (stills authored + disclosed) |
| Closing law (:468) | RM never removes information | reports identical under both flags (R15); static set pairwise distinct except the disclosed Content+Energetic collision (R11) | conformant |

Every constant's doc authority verified by opening 04: `0.15` reaction digit (exact row digit), `0.15` state crossfade inside the 0.15–0.20 band, press hold instants 0.8/0.45 = the choreographies' own saturation points, `pressReleaseSeconds` head 0.6 (`MomoReactionClips.swift:149`) / belly 0.45 (`:157`) both `tempoScaled`, handshake durations 3.0/2.0 with the settle end pose {0.94, 3°, (0,−14)} and wake identity recomputed by hand from `MomoHandshakeChoreography.swift:36-80`, play pacing 2.4/12.0/8.0/4.0/16.0 with the ≤ 30 s bound. The R11 collision mechanism verified at source: `MomoExpressions.swift:162-166,170,175` — Energetic's only rendered deltas are the breath multiplier 0.96 (masked: breath amplitude 0) and the variant-interval ×1/1.5 (masked: idle events contribute nothing), so Content+Energetic == Content+Relaxed is real, RM-only, and correctly routed to the owner as an expression-design gap.

### B. My own adversarial streams (temporary suite, 7 tests, all green; deleted after)

1. **State-change storm inside crossfade windows** (changes at 5.0/5.05/5.1/5.14/5.16/5.3): fold twins + report equality; last-window governing pins; the MINOR-1 snap demonstrated (> 5° ear jump; post-snap within 1° of the from-state static); landed t-invariance past the last window; pose-seam RM divergence mid-window. Also learned and verified: a reaction-free displayState storm's OVERLAYS are identical under both flags BY DESIGN — that row's RM effect is entirely at the pose seam (0.15 static crossfade vs full-motion render), which the overlay-level twin probes correctly do not claim.
2. **Press lost-boundary** (no touchEnded until 7.0): resolved-end render sampled across the release boundary; RM divergence real; fold reports equal; **sampling proved side-effect-free** (fold → sample both overlays at 0.1 s steps across the run → state still equals a fresh fold).
3. **Supersede during the entrance crossfade** (tapHead 1.0 → cheer 1.05): fold twins; cheer's finished report exactly once; RM divergence through the entrance window against the superseded slot's unchanged fade.
4. **Hide epoch mid-moment** (quest 1.0, hidden 1.3, shown 5.0, flush 7.0): `momentFinished(.questCompleted)` exactly once at the replayed instant (5.0 + 1.0); fold twins.
5. **Moment during an L3 chain** (taps + cheer, then bondStageReached at 1.6): fold twins; exactly-once; RM divergence.
6. **Fingertip restlessness** (playReady + 10 moving fingertip events at 0.1 s, then rest): fold twins; `playRoundFinished` exactly once; RM divergence across the follow.
7. **Whole-trajectory twin** (L3 + press + settle + hide/show + wake over 0.4–12 s, prefix-walked at 0.05 s): fold/report equality; RM diverges somewhere on every trajectory.

### C. Sanctioned mutation bites (sha256-proven)

Pristine sha256 of `Sources/MomoCharacter/MomoReduceMotion.swift` (recorded before both bites, cross-checked against the implementer's recorded value — identical): `d7b7acf740a4674406a45ac6856a2a2ad0ddc01aad8a81174c549724263bc07f`.

- **Bite A** — `MomoReduceMotion.swift:457`: `let holdElapsed = min(holdKeyInstant(slot.key), hold)` → `let holdElapsed = holdKeyInstant(slot.key)`. PREDICTED before running: exactly `shortPressIsContinuous` fails (a 0.2 s hold must render the pose it earned, not the 0.8 s lean-in); all holds ≥ the key instants unaffected. ACTUAL: exactly 1 failure — "R6 press: a short release crossfades from the pose the touch EARNED (no jump)" at `MomoReduceMotionEndPoseTests.swift:228`; 8/9 green. Restored → sha256 **== d7b7acf7… exactly**.
- **Bite B** — `MomoReduceMotion.swift:39`: `stateCrossfadeSeconds` 0.15 → 0.2 (in the disclosed band, off the authored digit). PREDICTED before running: exactly 3 mapping failures — the `== 0.15` digit pin (:42), the window-close pin at 5.15 (:195), the landed endpoint (:222); monotone path pins and the asleep pin (2.2 = exact end of a 0.2 window) survive. ACTUAL: exactly those 3 failures, 13/16 green, mid-fade value 13.92° vs static 16.5° matching the hand-computed 15.6 % residue. Restored → sha256 **== d7b7acf7… exactly**.
- Post-restore: full `swift test` → 823/82 green, zero warnings.

### D. Commands and counts

- `swift test` — **823 tests / 82 suites passed (1.592 s)**, zero warnings; reproduced before the review, after the probes, and after both bites.
- `swift test --filter MomoReviewProbesTmp` — 7/7 green (file then deleted; tree restored to the implementer's changeset, confirmed by `git status --porcelain`).
- `swift test --filter MomoReduceMotionEndPoseTests` under Bite A — 1 failure as predicted.
- `swift test --filter MomoReduceMotionMappingTests` under Bite B — 3 failures as predicted.
- `shasum -a 256 Sources/MomoCharacter/MomoReduceMotion.swift` — d7b7acf7… before, after Bite A restore, after Bite B restore.
- ImageIO decode of 5 PNGs (`rm-static-mood-content@2x`, its 4× eye zoom, `rm-end-tap-head@2x`, `rm-end-settle@2x`, `rm-static-asleep@2x-eye-zoom4x`) — pure grayscale, dimensions exact.
- Greps: `reactionMotion:` call sites — every existing call site passes a VALUE through the untouched `pose(at:displayState:reactionMotion:)` conveniences (`RigMotionModel.swift:62-92`); no test or app code passes an explicit closure, so the view-closure type change breaks nothing (Disclosure 9 verified, not just asserted). `reduceMotion` references confined to `MomoReduceMotion.swift` / `RigMotionModel.swift` / `MomoReactionOverlay.swift` / `MomoRigView.swift`; the only ambient read is `@Environment(\.accessibilityReduceMotion)` in the view (R1, discipline-pinned). Hex/RGB literals only in `MomoUIColors.swift` + `MomoCharacterPalette.swift` (+ the `MomoColorToken` UInt decoder — not a color literal); the 8 palette tokens match the §8.4 slot names; `momo.ear.inner` unused status matches TASK-026's record.

### E. What held up

- The R15 render-only law, attacked at both seams with my own streams: the fold never forks (structural — `apply(_:)` takes no flag — and behavioral), reports are identical everywhere, and the twin suite's honesty note (fold twins prove determinism; flag-independence is by construction plus the scoping pin) is accurate, not hedging.
- Exact-endpoint arithmetic: `smoothstep` clamps and is exact at 0/1; `lerped`/`blend` guarded endpoints; the nil-pole accent shims are consistent with `faded`'s inverse arithmetic (`faded(1)` nils accents, `faded(0)` returns self; props guard-return at f=0).
- The press release law: `holdElapsed = min(keyInstant, hold)` preserves earned-pose continuity (bitten and proven); `releaseSeconds` respects `pressReleaseSeconds` × tempo; releases before the keyframe instant render continuously (pinned ≤ 0.02 aperture / 0.5°).
- The disclosed approximation (1e-9, belly-rock hold pins only) is justified and scoped: the RM render re-derives elapsed through the slot clock and the cyclical sine carries ~1e-15 ulp dust; end-pose pins remain exact.
- API compatibility, default no-op, environment scoping, theming audit, line/size accounting — all as claimed.

## Recommended disposition

APPROVED_WITH_MINOR_NOTES → proceed per §10/§12: address MINOR-1 (one test + one register line) and MINOR-2 (Disclosure 4 rewording + owner follow-up line), and fold NOTE-1/NOTE-2's one-line corrections into the same touch-up; NOTE-3/NOTE-4 may be recorded as-is. None of these blocks the code; no behavioral change is required. Then the atomic commit per the task's Git Requirements.
