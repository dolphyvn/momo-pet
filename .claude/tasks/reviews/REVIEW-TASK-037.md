# REVIEW-TASK-037 — Room tab (FR-3; UX §1.2 S5)

Reviewer: fresh independent §10/§33 review agent (Jupiter), dispatched by the orchestrator.
Date: 2026-09-11 · Branch: `feature/EPIC-007-iphone-home` · HEAD: `2b486b3` (working tree dirty with the TASK-037 implementation)
Review inputs: CLAUDE.md §10/§19/§25/§32/§33 · TASK-037 contract + Implementation Notes + Handoff · status.md · EPIC-007 epic · PRD FR-3/FR-19/FR-20(D12) · UX §1.2 S5 / §2 / §10 row 435 · 04 §8.5 / §11 · 05 §4.9 (OBS-D) / §4.10 · the working-tree diff · the read-only consumed surfaces (MomoRoom.swift, MomoRigView.swift, MomoCopyText.swift, tokens/palette, HomeView precedents).

## Verdict

**APPROVED_WITH_MINOR_NOTES** — three observation-grade notes (N-1/N-2/N-3), **none requiring changes before commit**. All seven requirements implemented and evidenced; all six acceptance criteria satisfied to the depth this lane can reach (package gate reproduced ×2 by this reviewer; the UI suite + Watch build are the orchestrator's §19 glass gate per dispatch, not run here).

## Scope audit

`git status --porcelain` at review time = exactly the contract surface. Tracked diff: **10 files changed, 368 insertions(+), 46 deletions(-)**, plus the two disclosed NEW files (untracked): `Apps/Momo/RoomView.swift` (121 ln), `Tests/MomoKitTests/RoomCopyKeyTests.swift` (64 ln). Per-file: task file +77 (Implementation Notes/Handoff), PlaceholderRoomView −13 (deleted), RootTabView +17/−? (host + D12 labels), catalog +60 (5 entries), pbxproj 8 lines (4 slots × add/remove), UI tests +54, HomeCopyKeys +36, CatalogCopyLawTests +17/−?, MomoCatalogScaffoldingTests +69/−?, RigDisciplineTests +63/0.

**B walls (no-touch) — CLEAN, grep-proven against `git diff --name-only`:**
- `Sources/MomoCharacter/` — absent from the diff (MomoRoom.swift byte-identical; GENERATED header intact).
- `Sources/MomoCore/` — absent (CopyRules.swift and LineSelection.swift live here; both diff-absent).
- `Sources/MomoKit/` — only `HomeCopyKeys.swift` in the diff (the sanctioned accessor surface).
- All Watch targets — absent.
- `Apps/Momo/PlaceholderSettingsView.swift` — untouched (TASK-038's placeholder correctly survives).

**Epoch-4 residue pins — VERBATIM, files diff-absent, green:**
- `CopyRules.copyEpoch = 4` (Sources/MomoCore/CopyRules.swift:65, unmodified).
- `CopySelectionPinnedTests.rawKeysPinned` (unmodified): slots `.07` (×4), touch `.02`, feed/play/care pools `.01` ×3 — CopySelectionPinnedTests.swift:104-116.
- `CareInteractionTests` (Tests/MomoCoreTests, unmodified): 2026-09-09 day draws `react.care.04` (:57, :61); the 2026-09-08 day pins `.01` (in-file comment :52-54).
- All green inside the reviewer's 931/95 full-suite runs.

## Findings

| # | Severity | Finding | Evidence | Disposition |
|---|----------|---------|----------|-------------|
| N-1 | NOTE | The R5 presence check (`mentionsRoomSceneAccessibility`) is file-text-wide: it proves the three legs exist SOMEWHERE in RoomView.swift, not that they attach to the scene Canvas. Attachment semantics are outside the guard's envelope (the scan family's known trade, cf. REVIEW-TASK-035 N-3 comment-entombment). | Reviewer's own negative probe (below): relocating all three legs from the Canvas to the outer VStack leaves the guard GREEN. The glass backstop catches that shape: the UI test pins `scene.label == "Momo’s cozy room"` and the caption as a separate `room.caption` element, both of which break under the relocation. | Accepted — no change required. Optional hardening (assert leg ORDER/attachment, e.g. `.ignore` appears after the Canvas line) may ride TASK-039's guard-hardening list with REVIEW-TASK-036 F-2. |
| N-2 | NOTE | The contract's literal R7 assertion `app.buttons.count == 0` is unsatisfiable as written — the shell's TabView always carries 3 tab-bar buttons on any tab. | The implementation's disclosed adaptation scopes the zero to the room namespace (`identifier BEGINSWITH "room."`) and proves non-vacuity on the same screen (`app.tabBars.buttons.count == 3`). | Accepted — faithful adaptation, correctly disclosed in the task file; preserves FR-3 AC-1/AC-2 intent. |
| N-3 | NOTE | The task file says RoomView follows "the `RigCanvas.gridSide` convention"; MomoRigView scales via `.frame(gridSide).scaleEffect(...)` while RoomView scales inside the Canvas (`min(w,h)/1000` + centering `translateBy`/`scaleBy`). Same convention (1000-unit design space, aspect-preserving, centered), different mechanism — arguably more robust for a non-square region. | MomoRigView.swift:163-164 vs RoomView.swift:69-73; disclosed in the task notes as "the min(w,h)/gridSide scale". Centering math verified correct. | Accepted — accurate as disclosed. |
| — | Checked, clean | Static discipline: no Button/onTapGesture/gesture/allowsHitTesting/TimelineView/withAnimation/.animation/scenePhase/director/clock/MomoRigView/MomoProps/CharacterClock references in RoomView.swift (grep; sole hit is the header's own prose). Scene = EXACTLY the five generated paths (`MomoRoom.floor/rug/window/pomString/pomPuff` — the generated file's complete public surface, MomoRoom.swift:33-207); fill idiom matches MomoRigView.swift:152-159 verbatim; zero hex/color literals. | see scope audit commands | — |
| — | Checked, clean | A11y construction per row 435: Canvas flattened `.accessibilityElement(children: .ignore)` + `.accessibilityAddTraits(.isImage)` + composed label + `room.scene`; caption its own `Text` (`room.caption`); region container `.contain` (`room`) — the Home app-views' region precedent (HomeStatusRowView:57, HomeQuestCardView:72, HomeActionRowView:34). Caption uses `MomoTypography.caption` = `Font.system(.footnote)` → Dynamic Type scaling is automatic; the scene scales with its region. VoiceOver label composition safe: the name is `String(format:)`'s ARGUMENT, never the format string. | RoomView.swift:78-84, 41-44, 50-51 | — |
| — | Checked, clean | Copy landing: `momo.line.room.01` = `%1$@’s cozy room` (positional, locale-correct reordering; U+2019 per catalog convention), `.02` = "Somewhere soft to come home to." (6 words, calm register, no exclamation) — `momo.tab.home/room/settings` chrome labels. Catalog sort order preserved (quest < room < status; tab class last); no `.00` keys (reserved index holds; room starts at 01). All five values pinned verbatim by the new scaffolding test; the 12-word law now scans the room class (71→73, room.01's `%1$@`-template counts 3 whitespace tokens); tab labels deliberately outside the 12-word body-copy law (chrome — disclosed, sanctioned by R4's own-namespace option). Banned-vocabulary standing scan (`realTreeCatalogsAreClean`) enumerates EVERY catalog in the tree × EVERY localization (allLocalizationsAreScanned proves non-vacuity) → the new values are covered and green. | MomoCopy.xcstrings diff; MomoCatalogScaffoldingTests +40; CatalogCopyLawTests diff; BannedVocabularyScanTests.swift:91-162 | — |
| — | Checked, clean | pbxproj: deterministic-ID scheme maintained — `…0054` appears exactly 4× (PBXBuildFile, PBXFileReference, group children, Sources phase); the four `…0004` PlaceholderRoomView lines removed in the same list slots; IDs verified free before landing. | diff + `grep -c 000000000054` = 4 | — |
| — | Checked, clean | §26 markers: no TODO/FIXME/HACK/TEMP debt in any touched file (only "TEMPLATE" prose matches, as the handoff disclosed). Warnings: `swift build` clean; app-target build emits no warnings attributable to RoomView/RootTabView. | grep + builds below | — |

## Bite table (R5 guard, per dispatch D)

Baseline guard test green pre-bite (`swift test --filter roomSceneIsStaticAndSingleElement` → 1/1 PASS). Pre-bite hashes: RoomView.swift `1286386750d9ba3acf155f76e41d623179bd205961fab0b24d322d652eec01ac`; RigDisciplineTests.swift `9d768dce26639c6488bc27375daaf9525b0377e7c781f49c39d80316c7c98476` (test file never modified by the reviewer — hash verified unchanged at every checkpoint).

| # | Mutation (file sha256 under bite) | Focused result | Full-suite attribution | Restoration proof |
|---|-----------------------------------|----------------|------------------------|-------------------|
| B-1 | Add `.onTapGesture { }` to the scene Canvas (`a7671c0cadb90ef72fb71ca0092712b3d9516deb576f6eb35bdb2c2174443135`) | FAIL — `Expectation failed: (roomInteractiveViolations → [".onTapGesture"]).isEmpty → false` | 931 tests / 95 suites: **exactly 1 failure** — the R5 guard test alone, token attributed | Edit-reverted; sha256 `12863867…` == baseline |
| B-2 | Remove `.accessibilityElement(children: .ignore)` from the scene flatten (`f535f817079974f135b2d4f651c95d0d70cd1a5ed63278d9b23821a74f08092d`) | FAIL — presence check (`mentionsRoomSceneAccessibility`) | 931 tests / 95 suites: **exactly 1 failure** — the R5 guard test alone | Edit-reverted; sha256 `12863867…` == baseline |
| P-1 | Reviewer negative probe (own design): relocate all three a11y legs from the scene Canvas to the outer VStack — legs still present in file text, construction wrong (`da3fde36d0bf5602984f5b8e7711387424f7c6575527d351e862562c7b1338ff`) | **GUARD STAYED GREEN** — the probe confirms N-1 (attachment blindness, scan-family envelope); the glass UI test is the designed backstop (scene label + separate caption both break under this shape) | not escalated (probe, expected-blind) | Edit-reverted; sha256 `12863867…` == baseline |

The guard's own fixtures are non-vacuous per the F-1 rule (verified by reading): fixture (a) carries ALL THREE a11y legs + a Button → the interaction scan fires (SOME-legs, not all-legs for the property under test); fixture (b) is interaction-free but flattened only as `.contain` (no ignore/trait/label) → the presence check fails.

## Test execution (reviewer-run)

| Gate | Result |
|------|--------|
| `swift test` (baseline, pre-bite) | **PASS — 931 tests in 95 suites** (exit 0) — matches the handoff claim exactly (+6/+1 vs the 925/94 TASK-036 baseline: 4 RoomCopyKeyTests + 1 R5 room guard + 1 scaffolding verbatim pin) |
| `swift test` (after ALL restorations) | **PASS — 931 tests in 95 suites** — equal to baseline, byte-proven tree |
| Focused guard runs | 1/1 PASS pre-bite; B-1/B-2 FAIL as predicted; P-1 PASS (recorded) |
| App target compile (§25; package tests cannot see Apps/) | `xcodebuild build -scheme Momo -destination 'generic/platform=iOS Simulator'` → **BUILD SUCCEEDED** (nothing booted; within the dispatch's lane) |
| `swift build` warnings | none (beyond the known machine-env `ld` noise class) |
| UI suite on the pinned SE / Watch build | **NOT RUN** — dispatch reserves the §19 glass gate for the orchestrator; the UI test's logic was verified by reading only (room-namespace zero + non-vacuity bound + exact U+2019 label + caption verbatim + one-element census + no alerts) |

## Requirements roll-up

- **R1** ✓ five paths, token idiom, aspect-preserving, Momo-not-rendered adjudication in the header (FR-3 "MAY").
- **R2** ✓ zero interactivity, structurally enforced, bite-proven (B-1).
- **R3** ✓ one image element + caption, placeholder gone everywhere, Dynamic Type scaling.
- **R4** ✓ FIXED lookups + sanctioned `momo.tab.*` chrome namespace (disclosed), `MomoCopyText.render` everywhere, `%1$@` positional template, NO epoch bump, residue pins verbatim green.
- **R5** ✓ guard + SOME-legs fixtures both directions, family-conformant (MARK-section practice verified against the TASK-035/036 guard commits — the top-of-file header was correctly untouched, matching precedent; the "extend deliberately" contract governs the scanned-set list, which rightly did not grow).
- **R6** ✓ host + catalogized labels + deletion + pbxproj both directions.
- **R7** ✓ scaffolding/law/kit/UI test extensions as contracted (UI test by reading; execution is the orchestrator's gate).
- **AC 1–5** ✓ evidenced above; **AC-6** package gate reproduced ×2 by this reviewer; UI/Watch gates pending the orchestrator's §19 run at this exact tree.

## Reviewer disclosure

No git commits/pushes/branch ops. Repository writes limited to: the three bite/probe mutations of `Apps/Momo/RoomView.swift` (each restored byte-identically, sha256-proven above) and this record. status.md and the task file untouched by the reviewer.

REVIEW-COMPLETE TASK-037
