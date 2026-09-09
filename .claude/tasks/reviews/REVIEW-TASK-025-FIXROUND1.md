# REVIEW-TASK-025 — Fix Round 1 Delta Review

- Reviewer: independent adversarial delta-review agent (fresh context; CLAUDE.md §10/§33 — mandate is to disprove, not confirm)
- Date: 2026-09-09
- Scope: the fix-round-1 delta only (REVIEW-TASK-025 findings M1, M2, m1, n1, O5-nudge + the regeneration/re-render/battery claims), on the uncommitted working tree of branch `feature/EPIC-006-character`
- Verdict: **APPROVED_WITH_MINOR_NOTES** (one prose correction recommended; see Findings)

## Method

Everything below was re-measured by the reviewer with independently written tooling, not by reading the implementer's claims:

- a from-scratch Python analyzer (`/tmp/momo-delta/analyze.py`) that parses the **committed Swift text directly** with its own regexes and its own flattening (512 steps/curve), shoelace, winding-number, crossing, and point-to-outline math — no pipeline module imports;
- a compiled Swift harness (`/tmp/momo-delta/harness/measure`) linking the **committed constants** with the **real** `PathMeasuring` and SwiftUI `Path.contains` (nonzero = render truth);
- pixel forensics (`/tmp/momo-delta/harness/probe_pixels`, `analyze_map`) decoding the committed PNG bytes with empirical palette discovery (CoreGraphics color-manages the fills, so nominal constants do not match decoded bytes; background decodes to (252,249,244), furShade to (232,221,205), fur to (241,232,220), sparkle to (243,222,170), windowC to (248,244,237)), ASCII maps, and strict-background rect/row scans;
- the one sanctioned mutation bite (below), with sha256-proven restore.

## M1 — at-base ear rule (verified on both sides, with teeth)

- Own Python parser: body bbox width 535.637; earLeft/earRight chord at the ear-root line y=250 = 64.954 → **12.1265%** of body width (floor 12%); the bounding-box width is 120.489 = 22.4945% — the old, wrong quantity.
- Swift harness over the real `PathMeasuring.widthAtY`: at-base 64.939 = 12.1237%; bbox 120.480 = 22.4930%; body 535.636. Both sides now measure the same correct quantity and agree within flattening tolerance. Task-file claim (64.93 / 12.12% / 535.63, margin ~0.12pp) reconciles.
- `verify_geometry.py` gates `width_at_y(ear, root.y)/body_w ≥ 0.12` and reports at-base numbers + the root line in its failure message; `MomoRigGeometryTests.earRule` uses `PathMeasuring.widthAtY(ear, atY: root.y)` with the same floor. Rounded-tips pins intact and correctly re-labeled (0.50/0.30 of bbox max at 10%/6% from tip).
- **Counterexample teeth (the original review's rx=20, ry=200, 10°-tilt ear), run through BOTH real checkers, both ears:** bbox width 79.858 = 14.909% → the OLD pin would PASS; at-base chord 16.86 = **3.15%** → the NEW pin FAILS (my independent parametric math: 79.85 / 14.908% vs 16.85 / 3.146%). The false-negative class the review described is closed: the at-base pin rejects the shape the bbox pin wrongly accepted. Note: my at-base figure for this construction is 3.15%, not the original review's ≈6.73% — the true chord depends on ellipse anchoring, and my construction mirrors the shipped `_ear()` anchoring (root at the landmark, center up-axis by ry−overlap), which is what the pins gate. Both figures are far below 12% while bbox passes, so the demonstration stands; recorded here for the record.
- No contradictory "ear base width" numbers remain: `grep` for 22.49/22.5% across pipeline/tests/sources/README is clean; the only 22.5% occurrence is the task file's "CORRECTED in fix round 1" historical note (legitimate disposition context).

## M2 — winding uniformity, nonzero fill, and the seam pins

- Shoelace over the committed constants (own parser, 512 steps): `glyphSilhouette` [−115020, −218876, −20049, −20049, −8120, −8120] and `food` [−4091, −1791, −176, −176] are winding-uniform; `window` [+66828, −42921, +6594, +7154] is the one intentional counter-wound hole compound (`HOLE_COMPOUNDS = ("window",)`); `lodPawPair`/`pomPuff`/`blanket` uniform. Swift-side shoelace over the real flattened Paths matches exactly (glyph [−114999, −218859, −20045, −20045, −8118, −8118]; window [66827, −42920, +6594, +7154]).
- Winding numbers at the pins: all four glyph seam points (455,245)/(545,245)/(396,927.65)/(604,927.65) sum ≠ 0 with per-subpath proof of inside-BOTH-overlapping-subpaths (head∧ear, body∧foot, w=−1 each); food (240,952) is inside bowl∧mound. Margins: foot bands 0.76/0.75 to the nearer outline (the claimed ~1.5-unit overlap sliver, ±0.75 pin margins — reconciles); ear lenses 13.40 to the ear arc and 16.20/13.40 to the head arc (see Findings); food 6.00/5.00.
- Pins exist on both sides: `MomoRigVariantsTests.glyphSeamsFill` (4 points, SwiftUI `Path.contains`, nonzero) and `foodMoundFills`; `verify_geometry.check_compound_fill` gates every `generate.py` mode (winding-sign uniformity for non-hole compounds + seam-point nonzero fill).
- Window semantics exact through the real Path (nonzero): pane interiors 0/false (true holes), bar intersection +2/true, frame bands +1/true, outside 0/false.
- Seam-point fill + both-inside proven stable across flatten steps 16/48/96/192/512.

## n1 — explicit subpath emission

Structural audit of all 44 constants in the regenerated Swift: every subpath begins with an explicit `move(to:)`, ends with exactly one `closeSubpath()`, zero violations; the reversed builder emits the original start point as an explicit move (e.g. glyph earL `move(to: CGPoint(x: 481.143, y: 149.326))`); the window opening starts at an explicit `move(to: CGPoint(x: 166.000, y: 136.000))`. The committed `room-scene.png` renders the window frame-filled/opening-holed with mullion bars (pane interiors decode as strict background between `5`-classified frame/bar pixels in the ASCII map).

## m1 — gitignore

`.gitignore:13` contains `__pycache__/`; `git check-ignore -v` confirms pipeline `.pyc` files (which do exist on disk from pipeline runs) are excluded. Load-bearing and correct.

## O5 — sparkle vs window on the evidence canvases

Prop constants untouched: `MomoProps.sparkleA` still centered (230,250), tips at 95; the nudge exists only as composition in `render_svg.py` (`SPARKLE_A_NUDGE = (-100.0, 310.0)`) and `render_evidence.swift` (`gridTranslation: CGPoint(x: -100, y: 310)`). Pixel truth in the re-rendered, byte-identical `room-scene.png`: sparkleA-class pixels occupy map rows 39–49 (grid y ≈ 487–612) vs window bottom at row 27 (grid y ≈ 344) — ≈110 px / ≈137 grid units of clear background; the old authored spot (grid 230,250) now shows window pixels, no sparkle color.

## Evidence PNGs — what I actually saw (mandated visual pass)

Remote vision passes were run on all three PNGs and contradicted both themselves and each other: on `rig-glyph.png` the model claimed "white crescent notches at the ear bases"; on `rig-full.png` (same geometry) it said the ears are seamless but the feet "marginal"; on `room-scene.png` it claimed the sparkle overlaps the window. Per the review mandate, pixel forensics was treated as authoritative over these impressionistic reads:

- Strict-background rect scans over the ear-head lens regions (grid x 440–470 / 530–560, y 235–256) and foot-body bands (x 384–408 / 592–616, y 920–936): **ZERO background-colored pixels on BOTH `rig-glyph.png` and `rig-full.png`**. The silhouettes are pixel-continuous through every disputed junction. The "notches" were the concave silhouette corners outside the union; the "marginal" foot junction is a real but filled ~1.2 px overlap sliver.
- The maps otherwise read correctly as the Direction-C rabbit: fused ear-head-body-foot glyph, low-contrast glyph eye dots (the known cosmetic note, unchanged by this delta), full-rig eyes/cheeks/belly/tail all present; room window panes are true holes; sparkleA clear of the window (above).

## Regeneration, budgets, suite

- `generate.py --check` green ("11 Swift files + 4 evidence canvases reproduce byte-identically") under python3 3.12.13 AND /usr/bin/python3 3.9.6 — verified again after the mutation restore.
- Own byte counts: rig bucket 50,096 B / room+props 20,647 B / total 70,743 B (anchor file 1,810 B outside buckets; evidence SVGs 26,365 B) — exactly the task-file figures, unchanged by the fix (reversal permutes existing coordinates).
- `swift test`: **549 tests / 59 suites passed** — run 1 recorded pre-bite, and again on the restored (hash-identical) tree post-bite; arithmetic 547 + exactly the 2 new seam pins verified (`MomoRigVariantsTests` = 7 pre-existing + `glyphSeamsFill` + `foodMoundFills`). The task file's "×2 consecutive" background run's output file was captured empty (exit 0 only); the claim is nevertheless satisfied by the two direct full-suite greens on identical bytes. `swift build` emits zero warnings.
- PNG determinism independently reproduced: rebuilt `render_evidence.swift` against the committed sources, re-rendered, and byte-compared — all three PNGs match the committed hashes (rig-full `b6b11a19…79fdb950`, rig-glyph `4d1eb52b…59dce6ec47`, room-scene `6c5a2a58…d4508d3e4f4`). The committed PNGs are proven exact projections of the committed constants (which is what makes the pixel forensics above authoritative for the shipped bytes).

## Mutation bite (sanctioned, exactly one) — winding reversal of ONE glyph ear

1. Pre-bite: `sha256(parts.py)` = `8dc233dd…16a812`, matching the recorded pre-bite manifest; backup copied to /tmp.
2. Mutation: `ear_l = g.reversed_subpath(_ear(-1))` → `ear_l = _ear(-1)` in `parts.py` (left ear left plain-wound; right ear and feet untouched).
3. Pipeline gate: `generate.py --check` → **exit 1** with exactly the new named checks:
   - `[compound_fill] glyphSilhouette: compound subpaths wind inconsistently (signed areas -114975, -218838, 20041, -20041, -8117, -8117)` — the mutated ear isolated as the +20041 outlier;
   - `[compound_fill] glyphSilhouette: seam point (455.00, 245.00) (left ear/head overlap lens) is NOT inside the filled compound - cancellation hole`.
4. Swift side (mutated sources written via `emit_swift.write_sources`, the ungated path, proving the pins stand independently of the CLI gate): `swift test --filter MomoRigVariantsTests` → **`glyphSeamsFill` ("glyph overlap seams are filled, not cancellation holes (nonzero union)") FAILED** at `MomoRigVariantsTests.swift:76` on `silhouette.contains((455.0, 245.0))` — "left ear/head lens … is NOT inside the filled silhouette — cancellation hole". The other 8 tests in the suite (including the right-lens point inside the same test? no — the failure list shows only the left-lens expectation failed) stayed green: the bite trips exactly the mutated ear's pin, by name.
5. Restore: `parts.py` restored from backup, sources regenerated through the same path.
6. Proof of restoration: all **12/12 files byte-identical** to the pre-bite manifest (parts.py `8dc233dd…`, MomoRig+Glyph.swift `3742c4b0…`, all 11 Swift sources); `generate.py --check` green under both pythons; variants suite 9/9 and the full suite 549/59 green again on the restored tree.

## Scope and hygiene

- `git status --porcelain` shows only the pre-existing TASK-025 working set (untracked Sources/Tests/Tools/docs-evidence, the placeholder-file deletions from the original implementation, modified `.gitignore` and task file, and the two review files) — **nothing new** beyond the disclosed fix-delta set. Reviewer scratch confined to /tmp; `PYTHONDONTWRITEBYTECODE=1` used throughout the bite.
- No TODO/FIXME/HACK/TEMP introduced in any delta file.
- Sparkle prop constants untouched (O5 is canvas composition only, verified above).
- Scope discipline: the fix delta does exactly M1+M2+m1+n1+O5-nudge + regeneration/re-render and nothing else.

## Findings

- **n2 (minor, prose-only — the one correction recommended before commit):** task file line 113 claims "Measured clearances: ear lenses ≥ 16.0 units to the nearest outline". Measured at 512 steps, the nearest outline to each pinned lens point is the **ear arc at 13.40 units** (symmetric both sides); the head-arc distances are 16.20 (left) / 13.40 (right). Correct wording: "ear lenses ≥ 13.4 units to the nearest (ear) outline". The pins themselves are exact and pass; this is a task-file documentation accuracy fix, not a geometry or testing defect.
- **Note (accepted):** the original review's counterexample at-base figure (≈6.73%) and this review's (≈3.15%) differ by ellipse-anchoring convention; this review's construction mirrors the shipped `_ear()` anchoring. Both are far below the 12% floor while bbox passes — the demonstrated false-negative class is identical.
- **Note (accepted):** background-run 2 of the "×2 consecutive" suite claim produced an empty capture; two direct full-suite greens on hash-identical trees satisfy the claim.
- **Pre-existing, unchanged, already dispositioned:** glyph eye dots render low-contrast on evidence PNGs (default-fur mapping in the evidence renderer only); rug/window contrast noted in the original O-list. Out of delta scope.

## Verdict

**APPROVED_WITH_MINOR_NOTES.** Every fix-round-1 change verifies by independent measurement on both the Python and Swift sides, the sanctioned mutation bite fails the named pin and only it, restoration is sha256-proven, and the committed evidence artifacts are deterministic projections of the committed constants. The single minor finding (n2) is a one-line prose correction in the task file, recommended before the orchestrator commit; it does not block.
