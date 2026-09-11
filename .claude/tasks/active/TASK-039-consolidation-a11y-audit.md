# TASK-039 — UI test consolidation + per-surface accessibility audit (FR-20 AC-2; NFR-6; 03 §10; size M)

## Parent Epic

EPIC-007 — iPhone Home Experience (`.claude/tasks/epics/EPIC-007-iphone-home.md`), task 9 of 9 — the epic's LAST task before the §14 merge.

## Objective

Close EPIC-007 by (a) landing every routed review item the epic accumulated — verbatim-pin completion, guard hardening with recorded probe re-bites, warning housekeeping — (b) producing the FR-20 AC-2 accessibility-audit evidence on all iPhone surfaces (NFR-6: launch-blocking), and (c) the two TASK-038-born cleanups: the cosmetic rename-field re-sync and the `MomoAppModel.swift` line-budget consolidation. Zero new user-facing copy, zero engine semantics, zero behavior change except the two named cleanups.

## Context

- **Audit normative sources (read them):** PRD FR-20 `docs/product/02-mvp-prd.md:373-378` (the accessibility criteria: Dynamic Type without function loss; VoiceOver state-in-words template; never color alone — glyph + label + text; Reduce Motion D16; targets ≥ 44 pt; contrast ≥ 4.5:1) + FR-20 AC-2 (:381 — the audit scope: onboard, Home, one interaction per family, quest completion, settings) + NFR-6 (:395 — launch-blocking, audit per UI task). UX `docs/design/03-ux-architecture.md` §10 (:425-443) — the per-screen intent matrix (S1–S3, S4 Home with the AC-1a/1b split, S5 Room, S6/S6.1/S6.2) + the state-in-words VoiceOver template. **The Watch-pat audit leg is EPIC-008 scope — record the deferral, do not audit Watch here.**
- **Routed items (each already adjudicated; this task lands them):**
  - **REVIEW-TASK-033 MINOR-1** — no verbatim VALUE pins exist for the TASK-033 landing's slot lines, greetings, status words, and wishes (the mutation experiment: rewriting a slot line passes all catalog-facing tests). Fix sketch (verbatim): extend the `catalogCarriesTheVocabularyVerbatim` enumerate-expected pattern to the full landing. The 12 vocab entries are already pinned; later keyspaces (react.touch, care moments, quest moments, room, tab, settings) are pinned by their own tasks — NOT in scope.
  - **REVIEW-TASK-036 F-2** — R9e's `mentionsMomentFanOut` guard is blind to sink-invocation removal: the negative bite `momentHapticSink(kind)` → `_ = kind` passed 23/23. Fix (verbatim): add `momentHapticSink(kind)` as a FIFTH leg of `mentionsMomentFanOut` + its violation-fixture update, then RE-BITE with the exact original shape — the hardened guard must now fail.
  - **Guard-attachment hardening cluster — REVIEW-TASK-037 N-1 + REVIEW-TASK-038 N-1.** Two recorded probes stayed GREEN through the scan guards: (037) relocating the room a11y legs from the scene Canvas to the outer VStack; (038) wiring `eraseAllData()` onto the Keep (cancel) button. Harden BOTH guards with region/order-scoped legs so each RECORDED probe shape FAILS post-hardening (the recorded probes ARE the re-bite tests). The room guard needs the three a11y legs anchored to the scene Canvas's region; the settings inventory guard needs the erase wiring anchored to the destructive/alert-confirm context and ABSENT from the cancel context. If a structural scan honestly cannot prove a given attachment, disclose the envelope limit explicitly in the guard's header AND pin the glass backstop that covers the shape — a probe left failing-blind with no backstop is NOT acceptable.
  - **TASK-035 F-3** — legacy `MomoUITests/MomoUITests.swift` re-emits 19 pre-existing actor-isolation warnings on every whole-module recompile (latent debt, diff-empty file). Housekeeping: `@MainActor` (or equivalent) eliminating the warnings; zero behavior change.
  - **TASK-034 rendered-motion UI guard** — the attempt rides here: where the view seam exposes it, add an automated glass guard that Reduce Motion actually SUBSTITUTES (static/crossfade instead of the looping idle) on a composed surface; if the seam does not expose rendered motion to UI tests, record the attempt + limitation honestly (a disclosed "not automatable at this seam" is a valid outcome; a faked one is not, §25).
- **TASK-038-born cleanups:** **N-3** — a no-op rename leaves the user's un-trimmed text in the field (identity plan ⇒ `petName` unchanged ⇒ `onChange` never re-syncs). Fix: after a Save attempt, the field always shows the effective (trimmed) name. **N-5** — `MomoAppModel.swift` stands at 948 lines (888 pre-existing + 60 disclosed seams), over the 800 budget: consolidate by splitting along its natural seams into same-target files ≤ 800 lines with ZERO behavior change (the `+Settings` extension already lives separately). Disclose the split map.
- **UI suites today:** 27 tests (Home 17, Onboarding 4, Settings 5, launcher 1). Known shared-shape duplication: fixture launches (`-momo-store-directory` + stage-crossing + `-momo-fixed-clock`), the TASK-038 keyboard-dismiss lesson (`typeText("\n")` + keyboard-gone wait), alert materialization tolerance.

## Requirements

### R1 — Verbatim pins to FULL landing (MINOR-1)

Extend the enumerate-expected `key: text` pattern to EVERY unpinned TASK-033 value: the 40 slot lines, 3 greetings, 8 status words, 7 wishes — byte-exact against the shipped catalog (read values FROM the catalog file into the expected tables honestly; the pin's point is that a future edit FAILS a test). Non-vacuity: the suite must prove the tables are non-empty and cover exactly the intended namespaces (counts pinned: 40/3/8/7). No epoch movement — pinning changes no values.

### R2 — R9e fifth leg + re-bite (F-2)

`mentionsMomentFanOut` gains the `momentHapticSink(kind)` leg + fixture. Verification: the F-2 bite shape (`momentHapticSink(kind)` → `_ = kind`) now FAILS exactly its guard; full-suite attribution exactly-1. Record the re-bite in the task notes.

### R3 — Guard-attachment hardening (037 N-1 + 038 N-1)

Both hardened guards must satisfy: (a) their ORIGINAL bites still fail (room interactivity + flatten removal; settings forbidden-token + erase reorder + missing wiring), AND (b) each recorded NEGATIVE probe now FAILS the hardened guard (037's leg-relocation shape; 038's mis-attachment shape). Region/order scanning idiom is your design — keep it in the `RigDisciplineTests` family (comment-strip discipline, SOME-legs fixtures both directions, non-vacuity pinned). Record every re-bite with sha256 provenance in the task notes.

### R4 — F-3 warning housekeeping

`MomoUITests/MomoUITests.swift` compiles with ZERO actor-isolation warnings (the 19 pre-existing). No test renames unless disclosed; count stays 1.

### R5 — UI-test consolidation (no coverage weakened)

Extract the duplicated fixture machinery (store-directory launch, stage-crossing fixture, fixed-clock, keyboard dismissal, alert materialization tolerance) into a shared helper type/file under `MomoUITests/`. All 27 existing tests pass UNCHANGED in name and assertion strength (diff shows assertions preserved, plumbing deduplicated). New audit tests (R6) reuse the helpers.

### R6 — FR-20 AC-2 audit evidence (iPhone surfaces; launch-blocking)

Produce RECORDED evidence, criterion × surface, against the 03 §10 matrix (S1–S3, S4 Home, S5 Room, S6/S6.1/S6.2):

- **Automated (preferred, committed as tests):** `performAccessibilityAudit()` per reachable surface (iOS 17+ API; the pinned SE runs 26.5) with each audit type enabled that the surfaces can honestly pass — handle/descend the known-acceptable issue types EXPLICITLY (record which types are filtered and why; a blanket catch-all that hides issues is NOT acceptable); 44-pt target assertions on the interactive surfaces (action pills, quest rows, settings rows, onboarding buttons); the state-in-words VoiceOver label assertions (the template "{name} feels {mood word} and has {energy phrase}. You two are {stage}." — extend the existing a11y tests to the FULL template); Dynamic Type AC-1a/1b (existing composition tests remain green); never-color-only (the existing word+glyph+text structural pins remain green).
- **Contrast:** implement the test luminance helper (the standing optional item) pinning the four body-text token pairs ≥ 4.5:1 against both light and dark grounds, or record per-pair computed ratios in the task notes with the same rigor.
- **Manual (recorded, honest):** a Reduce Motion + VoiceOver checklist walked against the 03 §10 rows, recorded per-row as PASS/GAP with the evidence source (test name, code inspection, or explicit gap). Any GAP is a finding in the task notes, not a silent omission. The D16 Reduce Motion automated substitution evidence comes from R-TASK-034's guard attempt above.
- **Watch deferral:** one recorded line — the W1/Watch-pat audit leg is EPIC-008 scope.

### R7 — TASK-038 N-3: rename-field re-sync

After a Save attempt (enabled or not), the field displays the effective trimmed name (typing "  Momo  " over "Momo" and tapping Save clears the padding). Add the glass assertion to the existing rename UI test (extend, don't duplicate) and the plan-level identity behavior stays as TASK-038 pinned it.

### R8 — `MomoAppModel.swift` consolidation (zero behavior change)

Split the 948-line file along its natural seams (e.g. boundary scheduling, transient presentation state, launch path, the settings/erase surface already external) into same-target files each ≤ 800 lines. ZERO behavior change: full package suite + FULL UI suite green with NO assertion edits (R7's extension is the only allowed UI-test delta); `git diff` on the moved code shows move-semantics, not rewrites. Disclose the split map (which members went where) in the task notes. The `+Settings` extension file already exists — fold the split around it, don't duplicate it.

## Files / Areas Likely Affected

- `Tests/MomoCharacterTests/MomoCatalogScaffoldingTests.swift` or a NEW pin suite (R1); `Tests/MomoKitTests/VocabularyKeyTests.swift` (pattern precedent); `Tests/MomoCharacterTests/RigDisciplineTests.swift` (R2/R3)
- `Apps/Momo/MomoAppModel.swift` + NEW same-target split files (R8); `Apps/Momo/SettingsView.swift` (R7, small)
- `MomoUITests/` — NEW shared helper file + audit suite (R5/R6); `MomoUITests/MomoUITests.swift` (R4); `MomoUITests/MomoSettingsUITests.swift` (R7 glass leg)
- `Momo.xcodeproj/project.pbxproj` (new file registrations — deterministic IDs)
- NO catalog edits, NO epoch movement, NO engine/`MomoCharacter`/`MomoCore` touches (ALL expected diff-absent — any touch is a disclosed carveout)

## Dependencies

All of TASK-031…038 (their surfaces, suites, and routed items). EPIC-004 frozen; the copy law and epoch machinery untouched.

## Constraints

- §26: zero TODO/FIXME/HACK/TEMP debt; zero warnings from touched files (the F-3 19 warnings are THIS task's debt to retire — the suite-wide warning census must come back clean of them); Swift 6 strict concurrency clean.
- No new user-facing copy (audit adds tests, not strings). No epoch bump; epoch-4 residue pins stay verbatim (slots `.07`, touch `.02`, pools `.01`, care `.04`/`.01`).
- The audit evidence must be HONEST per §25: an automated check that didn't run, a manual row without evidence, or a filtered audit type without justification = a finding against you. Launch-blocking means gaps surface as findings, not footnotes.
- Mid-cycle discipline: no git commits/pushes/branch ops; no .md edits beyond this task file; status.md/epic untouched (orchestrator's).
- The pinned simulators are yours for the verify gates below: iPhone SE 3rd gen `1F25E487-A78E-464C-95AF-0BD1A9B3E1BE`, Watch SE 3 (44mm) `8A854895-225C-411B-89C1-B03337BFE957`.

## Acceptance Criteria

1. Every unpinned TASK-033 value (40/3/8/7) is byte-pinned; a value rewrite fails exactly its pin (bite one as proof, record it).
2. The F-2 re-bite fails; both recorded negative probes (037/038 shapes) now FAIL their hardened guards; all original bites still fail exactly their own guards.
3. `MomoUITests.swift` compiles warning-free; the 27 pre-existing UI tests pass with names and assertion strength unchanged; shared helpers deduplicate the fixtures.
4. The FR-20 AC-2 audit matrix is recorded per surface with automated + manual evidence and ZERO unexplained gaps; the Watch leg is explicitly deferred to EPIC-008.
5. The N-3 fix is on glass; the 948-line file is split to ≤ 800 per file with zero behavior change; package suite + FULL UI suite + Watch build all green at the final tree with zero warnings from touched files.

## Required Tests

- **Package:** R1 pin tables (40/3/8/7 counts + byte-exact values); R2/R3 guard updates with their re-bite proofs; the contrast helper (R6) if landed test-side; all existing suites stay green (945 + your additions).
- **UI:** the audit suite (R6) with explicit issue-type filtering disclosures; the extended rename assertion (R7); consolidation leaves all 27 names green (R5).
- §19 gate (orchestrator): `swift test`; the FULL UI suite via `-scheme Momo` on the pinned SE; `MomoWatch` build on the pinned Watch; zero warnings from touched files. Run the app-target BUILD before claiming UI results.

## Review Requirements

Fresh independent §10/§33 reviewer (not primed): re-derive the FR-20 criteria + 03 §10 matrix BEFORE comparing the evidence; audit the AUDIT (every claimed PASS traced to a test/inspection; every filtered audit type justified; every GAP surfaced); re-bite the hardened guards incl. one negative probe of the reviewer's own design; verify R8's split is move-semantics (diff-inspect) and zero-behavior; verify R1's pins actually bind (one value-rewrite bite); epoch-4 residue + frozen walls; §25 disclosure audit.

## Git Requirements

Atomic commit (§12): `test(audit): TASK-039 consolidation + accessibility audit evidence + app-model split` (type at orchestrator discretion if the diff reads better as refactor/test split — ONE commit regardless) — the implementation, the review record, and the task file ride ONE commit; push per §13; the orchestrator closeout follows, then the §14 epic merge.

## Status

READY (2026-09-11) — contract authored from the epic's accumulated routings; fresh implementation agent dispatching.

## Implementation Notes

(implementation agent fills)

## Reviewer Findings

(reviewer fills)

## Completion Evidence

(orchestrator fills at closeout)

## Handoff

Use the §28 format; end with the marker `HANDOFF-COMPLETE TASK-039` on its own line at line start.
