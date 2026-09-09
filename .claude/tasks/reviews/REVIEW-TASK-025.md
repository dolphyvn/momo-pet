# REVIEW-TASK-025 — Asset export pipeline + generated Path constants

- **Task:** `.claude/tasks/active/TASK-025-asset-pipeline-path-constants.md`
- **Reviewed:** working tree of `feature/EPIC-006-character` @ `6a5fe4b` (implementation uncommitted, tree DIRTY as disclosed)
- **Reviewer:** independent fresh adversarial agent (CLAUDE.md §10/§33) — unprimed, no implementer context, commit-less
- **Date:** 2026-09-09

## Verdict

**CHANGES_REQUIRED — 2 MAJOR / 1 MINOR / 1 NITPICK / 8 OBSERVATIONS**

Per §10/§17, the task must not be committed while CHANGES_REQUIRED. Both MAJORs are fixable without redesigning the deliverable: M1 is measurement-side only (the shipped art complies), M2 is a winding fix in two compound tables plus regenerated output/evidence. Recommended: fresh fix agent addresses M1+M2+m1, material delta re-reviewed, then commit.

---

## Method

Every claim below was re-derived or re-measured independently; implementer claims were treated as unverified. Steps executed:

1. Re-derived the part inventory from 04 §2.2 + ADR-001 **before** opening the generated constants (below).
2. Recomputed the ADR-001 ear rule from the exported numbers using the pipeline's own `width_at_y`, then stress-tested the shipped pin's measurement basis with a counterexample (M1).
3. Re-ran `python3 Tools/character-pipeline/generate.py --check` (green under python3 3.12.13 **and** /usr/bin/python3 3.9.6, both pre-compaction and again post-mutation-restore); audited the reproducibility test for teeth.
4. Verified budgets byte-by-byte (`shasum`/`stat` over the §8.3 buckets), not by reading `--report`.
5. Judged the three evidence PNGs via an independent vision model with adversarial prompts; separately proved PNG provenance by re-rendering the committed constants and byte-comparing.
6. Winding/fill-rule audit of **every** multi-subpath shipped constant (shoelace signed areas + a grid scan of nonzero winding numbers) — this found M2.
7. One sanctioned mutation bite with sha256-proven restore (below).
8. Scope check (`git status --porcelain` vs the disclosed file set), TODO/FIXME/HACK scan (clean; the `HEADER_TEMPLATE` hit in `emit_swift.py` is a false positive on the word "TEMP"), test-count arithmetic, warning corroboration.

---

## Independent re-derivations (stated before comparison)

**Part inventory (derived from 04 §2.2 + ADR-001 before reading any generated file).** §2.2's counted rows: body+belly (2), head (1), ears (2), tail (1), eyes (6), mouth **counted once as a 3-pose slot** (1), cheeks (2), front paws (2) = **17**. ADR-001's Direction-C delta: hind feet at rest (+2) = **19 counted parts**. The full rig must emit **21 Path constants** because the mouth slot ships its 3 pre-built poses (R1: crossfaded, never re-tessellated) → 21 ≠ 19 is correct accounting. Variants per §8.5: LOD-glance, glyph, room, props.

**Comparison result: exact match.** Shipped: full rig 21, LOD-glance 11, glyph 3, room 5, props 4 = 44; the §2.2 role set (21 names incl. per-eye base/pupil/lid, 3 mouth poses, hind feet) matches name-for-name (`MomoRigInventoryTests.sectionPartRoles` pins the same set and I re-derived it independently). §8.4 naming law holds on all 44; all 11 generated files carry the GENERATED header + regenerate command; hand-written `MomoRig.swift` anchor is correctly separated.

**Ear rule (recomputed from exported numbers before judging the pin).** Body width (bbox of the committed `body`): 535.63 units. Using the pipeline's own `width_at_y`:
- at the ear-root landmark line y=250: **64.93 units = 12.12% of body width** — over the ≥12% floor by ~0.12pp;
- at the head-outline crossing (~y=224): 94.36 units = 17.62%;
- the ear's bounding-box width: 120.46 units = 22.49% — this is the ear's mid-shaft maximum, **not** its at-base width.

The shipped **art complies** with ADR-001 under the strictest reading (12.12% ≥ 12%). The shipped **pin does not measure at-base width** (M1).

---

## MAJOR findings

### M1 — The ADR-001 ear-rule pin measures the wrong quantity (bbox width, not at-base width) and the task file misreports the number

- `Tools/character-pipeline/verify_geometry.py:133`: `base_width = box[2] - box[0]` — the ear's **bounding-box** width.
- `Tests/MomoCharacterTests/MomoRigGeometryTests.swift:116`: `let baseWidth = Double(box.width)` in `earRule`, labeled "base width" in the failure message.
- **Proven false-negative class:** an ellipse with rx=20, ry=200, 10° tilt has bbox width 79.9 = 14.91% of 535.63 → the shipped pin **passes**, while its true at-base chord is ≈36.1 = **6.73%** — a gross ADR-001 violation the pin cannot catch. bbox width overstates base width precisely because the Direction-C ears are tilted (`EAR_TILT_DEG = 10.0`).
- **Misreported claim:** task file line 93 — "The ear-thickness rule measures **22.5%** of body width (120.5 / 535.6) against the ≥ 12% floor". That number is the mid-shaft maximum. The actual at-base margin over the floor is ~0.1pp, not ~10.5pp — materially different headroom for future geometry edits. Three inconsistent "ear base width" numbers coexist: 116 (parts.py:44 comment), 120.46 (both checkers), 64.93 (true at-base).
- The shipped art itself complies (12.12% ≥ 12%) — **no re-geometry required**. Fix: measure `width_at_y` at the ear-root landmark line in **both** checkers (the helper already exists on both sides), pin with a stated margin, and correct the task-file number.

### M2 — Compound constants carry unintended nonzero-fill cancellation holes; the glyph's "merged" silhouette is not actually merged at its seams

Root cause: subpaths contributed by different builders wind inconsistently inside one compound `Path`. Under the nonzero rule, any point inside both a CW and a CCW subpath has winding number 0 and renders unfilled — a hole.

Measured on the committed source (shoelace signed areas; y-down screen convention):

| constant | subpath windings | verdict |
|---|---|---|
| `glyphSilhouette` (6) | head −114,698, body −218,604 (CW); earLeft +19,992, earRight +19,992, hindFootLeft +8,097, hindFootRight +8,097 (CCW) | **MIXED — defect** |
| `food` (4) | bowl body −4,080 (CW); mound +1,786, 2 kibble +175 (CCW) | **MIXED — defect** |
| `window` (4) | mixed | intentional hole — correct |
| `lodPawPair` (2), `pomPuff` (5), `blanket` (2) | uniform | safe |
| all remaining 38 constants | single loop | n/a |

Grid scan (3-unit step, winding-number classification) of `glyphSilhouette`: **442 hole points** —
- **ear/head seams: ~3,924 sq units of holes spanning x[404..596], y[228..267]** — two lens-shaped holes at the ear bases, exactly where ADR-001 requires the ears to read as merged into the head;
- foot/body seams: ~54 sq units of slivers at y[927..930].

Three independent lines of evidence agree: (1) the shoelace windings, (2) the grid scan, (3) the independent vision judge on `rig-glyph.png`: *"at the base of each ear there is a distinct white notch/wedge where the ear and head outlines fail to overlap cleanly, producing two small V-shaped gaps"*, feet with *"concave seams"*. (I initially read those as background junctions of a union outline; the scan disproves that — they are fill holes.) The same judge saw the food/`room-scene` artifact class less clearly, but the mound∩body overlap band y[946..957] is proven geometrically (7/17 sampled mound points inside the body → cancellation).

`geometry.py`'s own docstrings show the mechanism was known in-repo: `ellipse_subpath` "sweeps clockwise on screen (y-down space)" (the ears) while the head/body chains wind the other way, and `rounded_rect_subpath(ccw=True)` exists specifically to *"reverses the winding so the shape can punch a hole in an enclosing nonzero-filled path (used for the room window opening)"*. The window's hole is deliberate; the glyph's and food's are accidental inheritance.

**Contract breach:** ADR-001/§8.5 require the glyph to be *silhouette-preserving with ears merged into the head outline* — the merge seams are literal holes, and the food prop ships the same artifact class. The existing glyph pins are blind to it: they check no-separate-ear-part, extent above the head line, ground contact, and subpath count — none probes overlap-region filledness.

**Fix (one mechanism):** emit all non-hole subpaths of a compound with consistent winding (reverse the ear/foot emission in `glyph_parts` and the mound in `prop_parts`; leave the window's intentional ccw hole alone), regenerate, re-render SVG + PNG evidence, and add a pin that samples points inside the ear∩head lens (e.g. (455, 245)) asserting they are **inside the filled compound**. Reproducibility tests will correctly fail until output is regenerated — that is the pin working.

---

## MINOR findings

### m1 — `__pycache__/` not gitignored; the orchestrator's atomic commit would sweep .pyc binaries into the repo

`Tools/character-pipeline/__pycache__/` holds 5 `.pyc` files; `.gitignore` has no `__pycache__`/`*.pyc` entry; the whole pipeline tree is currently untracked (`?? Tools/`). Add `__pycache__/` to `.gitignore` before the TASK-025 commit.

---

## NITPICK

### n1 — The window's reversed subpath relies on implicit current-point carryover

The ccw builder emits no `move` and a **leading `closeSubpath()`** (the reversed segment list starts with `Z`); in the emitted `MomoRoom.swift:85-108` the opening's curves continue from the outer frame's start point under CoreGraphics' "new subpath from current point" semantics. It renders correctly on the verified host (frame ring filled, opening holed — confirmed visually in both SVG and PNG), but the structure is obscure and fragile. When the pipeline is next touched (the M2 fix), give reversed subpaths an explicit `move`.

---

## OBSERVATIONS

1. **The double-entry design is load-bearing — demonstrated, not assumed.** With `eye_left` moved 25 units, the pipeline exited 0 (its verify measures the source against the same `LANDMARKS` it emits from — self-consistent), while the Swift pin failed by name. The Swift pins are the only real landmark authority; keep treating pipeline-side verification as a self-consistency gate, as its docstring claims.
2. **Eyes read drowsy to an independent judge** ("decidedly sleepy/heavy-lidded… dark half-moon shapes… no highlight or pupil differentiation") even after the disclosed lid fix. §1.3's "calm" is arguably satisfied, but the margin between calm and asleep is thin — verify the expression on real device surfaces in TASK-026+.
3. **Tail reads weak** at evidence scale ("barely legible — a thin crescent… could be mistaken for a lump") vs the task file's "puff clearly visible". Geometry complies (anchor pin, ~10% sizing); refinement candidate.
4. **Glyph legibility must be re-judged at true 24–32 pt** in the complication surfaces — the vision judge also flagged junction concavities and low eye-dot contrast at the debug canvas's large scale. Secondary to fixing M2, but the real-size check is still owed.
5. **Room composition nits:** the top-left sparkle overlaps the window frame (reads accidental); rug/window contrast is so low they nearly vanish; tail/blanket clearance is tight. Sparkles are consumer-transformed per contract, but the committed canvas composition should not ship a collision.
6. **§3.1 lower-lid pose shapes** (relaxed/upturned/flattened) are not shipped as constants — not contracted for TASK-025; confirm they land in the animation-layer tasks.
7. **"No bounce-loops anywhere" is an animation-layer rule**; TASK-025 ships no motion, so it is not yet applicable — carry the pin forward explicitly so it isn't lost.
8. **Budget-bucket basis:** rig bucket counts `MomoRig+*` only; the hand-written `MomoRig.swift` anchor (1,810 B) sits outside all buckets. Defensible ("generated-source bytes") and immaterial at current sizes, but the basis should be understood when reading the numbers. Related: Swift `widthAtY` pairs sorted crossings vs Python's max−min (equivalent on convex loops), and Swift's normalized-grid scan checks flattened samples rather than control points (slightly weaker than pipeline-side). Both differences are documented in-code; no action needed now.

---

## Mutation bite (sanctioned, restored with proof)

**Mutation:** `geometry.py` `LANDMARKS["eye_left"]` (430.0, 390.0) → (455.0, 390.0) — a 25-unit offset against the 20-unit `eyeCenter` tolerance.

**Observed:**
1. `python3 Tools/character-pipeline/generate.py` → **exit 0**, rewrote the 11 Swift files — the pipeline's own verify cannot catch a moved landmark (it checks the source against the moved landmark itself; see O1).
2. `swift test --filter MomoRigGeometryTests` → **the named pin failed**:
   `✘ Test "eye bases sit on the §2.1 landmarks at the landmark radius" recorded an issue at MomoRigGeometryTests.swift:93:13` — `eyeLeftBase center (455.0, 390.0) off landmark (430.0, 390.0) (tol 20.0)` — 1 suite failed / 9 other pins stayed green.

**Restore proof:**
- Pre-bite sha256 of `geometry.py` + all 12 generated Swift files recorded (`/tmp/bite-before.txt`); `geometry.py` backed up to `/tmp/geometry.py.orig` before mutation.
- Restored via `cp` back, regenerated; **all 13 post-bite hashes byte-identical** to pre-bite (`diff /tmp/bite-before.txt /tmp/bite-after.txt` empty).
- `generate.py --check` green after restore; tracked-file `git status` unchanged (only the implementer's task-file edit + the two disclosed placeholder deletions).
- `PYTHONDONTWRITEBYTECODE=1` used throughout; scratch confined to /tmp.

---

## Verified sound (with evidence)

- **Reproducibility pin has real teeth:** `MomoPipelineReproducibilityTests` re-runs the pipeline into a temp dir and byte-compares all 11 Swift + 4 SVG files, no skip path (a host without python3 fails loudly — a nondeterministic generator would too). `--check` green under python3 3.12.13 and /usr/bin/python3 3.9.6.
- **Budgets by measurement:** rig 50,096 B (≤307,200), room+props 20,647 B (≤256,000), total 70,743 B (≤1,572,864; 1024-byte KB basis as pinned). Anchor file 1,810 B outside buckets (O8).
- **Test claims:** full run captured: **547 tests / 59 suites passed**, exit 0. Arithmetic exact: 515 − 1 (deleted placeholder, exactly 1 `@Test`) + 33 new (10+6+7+4+3+3) = 547; 54 − 1 + 6 = 59.
- **Warnings:** the only warning observed in any of my direct compilations (swiftc of all 13 character sources) is the pre-existing host noise `ld: search path '/opt/extra/lib' not found`; none in the filtered-suite runs. My full-run capture was tail-truncated to the test phase, so "zero new warnings" is corroborated rather than exhaustively proven.
- **Hex confinement:** clean (token purity suite + the new discipline pin with its own regex + non-vacuity + my grep).
- **namespaceAnchors re-pin is sound,** not weakened: it pins the `HAND-WRITTEN FILE` marker, absence of the regenerate command, and all three namespace declarations — machinery, not prose.
- **PNG provenance proven:** recompiled `render_evidence.swift` against the committed constants; all three committed PNGs byte-identical to the fresh render (sha256 `b6b11a…`, `73d9e8…`, `167314…`). The earlier mtime ordering (PNGs 15:56 vs SVGs 16:07) is immaterial — `parts.py` was unchanged between them.
- **Visual judgment vs §1.3/ADR-001:** `rig-full.png` reads as a plump rabbit with pear silhouette, thick short rounded-tip ears, round cheeks, hind feet at rest, premium/calm register — passes the contract's judgment bar. Glyph and room render structurally correctly apart from M2/O4/O5.

## Scope & hygiene

`git status` matches the disclosed file set exactly (pipeline, 12 generated Swift, 6 test suites + 2 supports, evidence, 2 disclosed deletions, task file). No TODO/FIXME/HACK debt. No new scan exemptions. No status.md or other task files touched by this review beyond the sanctioned one-line finding below.
