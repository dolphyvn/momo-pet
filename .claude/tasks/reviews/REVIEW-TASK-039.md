# REVIEW-TASK-039 — Consolidation + FR-20 AC-2 accessibility audit (NFR-6; 03 §10)

Reviewer: independent adversarial review agent (Jupiter), per CLAUDE.md §10/§33 — mandate: disprove correctness; no self-approval; every claim below is evidence this reviewer personally produced.
Date: 2026-09-11
Branch: `feature/EPIC-007-iphone-home` · HEAD at review: `d49fe9d`. The review subject is the DIRTY working tree.
Inputs: `.claude/tasks/active/TASK-039-consolidation-a11y-audit.md`; `docs/product/02-mvp-prd.md` FR-20 (:373-378), FR-20 AC-2 (:381), NFR-6 (:395); `docs/design/03-ux-architecture.md` §10 (:425-443, the per-screen a11y matrix + state-in-words template); full diff vs `d49fe9d`; `REVIEW-TASK-037.md`/`REVIEW-TASK-038.md` (format precedent + the probes this review was required to re-bite).
Method: FR-20's criteria and the §10 matrix were re-derived from the normative docs BEFORE any implementation evidence was read; the audit was audited (every claimed PASS traced to evidence reproduced here; every filtered `performAccessibilityAudit` type justified against a no-blanket-catch-all rule); 6 live mutation bites (the recorded 037/038 probes re-bitten, the F-2 arm re-bitten, R1's pins value-rewrite-bitten, plus 2 probes of this reviewer's own design against the new census and order guards) and 1 aborted no-op probe, every one sha256-proven baseline==restored; baseline `swift test`; app-target build; a compile-only `build-for-testing` on the pinned SE. The FULL UI suite's EXECUTION and the Watch build were NOT run — the orchestrator's §19 glass gate owns those; no simulator was driven beyond compilation.

## Verdict

**APPROVED_WITH_MINOR_NOTES**

Every R1–R8 claim the handoff makes was reproduced personally by this reviewer: the 58-entry verbatim pins byte-match the shipped catalog and provably BIND (B-1); the R9e fifth leg fails with EXACTLY one attributed issue across the 949-test suite (B-2); both recorded probe bites (037 room legs, 038 erase wiring) still have teeth (B-3/B-4); the new census and declaration-order guards bite on probes of this reviewer's own design (P-5/P-6); the 948→775 split is mechanically move-semantics with exactly 7 access-level insertions; the contrast math reproduces to <0.005 on all 8 ratios; the epoch-4 residue and the four frozen walls are intact. Findings are two MINOR and five NOTE — none blocks commit. Two verdict conditions sit with the orchestrator, not this review: the §19 glass gate (FULL UI suite execution 35/35 + Watch build) is the remaining letter of AC-5, and the disclosed "You two are" template delta (F-2 below) is a copy-defining decision correctly routed to the owner per §36 rather than silently patched.

## Scope audit

Dirty set vs `d49fe9d` (git status/diff --stat, verified at review close): 13 modified + 5 new files, exactly the contract's surface —

- `Apps/Momo/MomoAppModel.swift` (948→775) · `MomoAppModel+Canvas.swift` (NEW, 128 ln) · `MomoAppModel+Celebrations.swift` (NEW, 117 ln) · `Apps/Momo/SettingsView.swift` (R7 + R6 label) · `Apps/Momo/HomeStatusRowView.swift` · `HomeContextualLineView.swift` · `HomeQuestCardView.swift` (the disclosed R6 scope extension — adjudicated below)
- `Tests/MomoCharacterTests/MomoCatalogScaffoldingTests.swift` (+142, the R1 table) · `RigDisciplineTests.swift` (+244, R2/R3 + census/order guards; now 1032 ln) · `MomoUIColorContrastTests.swift` (NEW, 105 ln)
- `MomoUITests/MomoAccessibilityAuditUITests.swift` (NEW, 286 ln) · `MomoUITestSupport.swift` (NEW, 113 ln) · `MomoUITests.swift` (doc comment only) · `MomoHomeUITests.swift` · `MomoOnboardingUITests.swift` · `MomoSettingsUITests.swift` (R5 consolidation + R7 extension)
- `Momo.xcodeproj/project.pbxproj` (+16: 4 new files × 4 slots) · task file (not reviewer's to edit)

**Frozen walls held:** `git diff --stat HEAD` contains ZERO entries under `Sources/MomoCore/`, `Sources/MomoCharacter/`, and `Apps/Shared/MomoCopy.xcstrings`, and none under `docs/` — all four diff-absent. Zero copy keys added: AC-1's "zero new user-facing copy" holds; catalog epoch untouched (`copyEpoch = 4` confirmed at `CopyRules.swift:65`).
**Epoch-4 residue:** `CopySelectionPinnedTests.rawKeysPinned` (diff-absent) pins slots `.07` ×4 (morning/evening/night/idle), touch `.02`, feed/play/care `.01`, context `.00` — the epoch-4 mod-draws verbatim.
**pbxproj:** the 4 new files register via deterministic IDs `8A4000000000000000000056–0059` / `8A5000…0056–0059`, 4 list slots each, no placeholder residue.
**Debt (§26):** raw TODO/FIXME/HACK/TEMP grep over every touched file — zero undocumented markers.
**Disclosed by the implementer, verified:** `RigDisciplineTests.swift` at 1032 ln is flagged in the task's own notes as an orchestrator observation (the ≤800 budget is applied to production files; R8/AC-5 scope the 800 to `MomoAppModel.swift`). Recorded, not re-raised.

## Findings

| ID | Severity | Finding | Evidence | Disposition |
|----|----------|---------|----------|-------------|
| N-1 | NOTE | The R1 test's doc comment asserts "The apostrophes are U+2019", but all 7 apostrophe-bearing LANDING values ship straight U+0027 (0 curly). The PIN ITSELF is byte-exact against the catalog and passes — only the test's own comment mis-describes its data. (Distinct file-set from 038's "checked clean" note: the settings ALERT copy is U+2019; the landing set predates that convention and is pinned byte-for-byte to what TASK-033 actually shipped.) | `MomoCatalogScaffoldingTests.swift` landing table vs `MomoCopy.xcstrings` JSON, 58/58 compared | open — one-word doc-comment fix at next touch |
| N-2 | MINOR | No 44-pt glass assertion for the quest rows. Contract R6's letter names "quest rows" in the 44-pt list (§10: "Action pills, card rows ≥ 44 pt"); the audit suite asserts the floor on Say hello / Continue / Begin / feed pill / play pill / erase row — not on a quest card row. Mitigants: quest rows are composited `.accessibilityAddTraits(.isStaticText)` (non-controls — the floor's letter targets tappable controls) and the card is authored stable-height; but a FUTURE interactive element added to the row would escape the glass floor. | `MomoAccessibilityAuditUITests.swift` assert list vs contract R6 (:49) | open — one assert at next touch |
| N-3 | NOTE | The S4 `.textClipped` disclosure row is effectively type-wide on S4: `elementMatch: "Text clipped"` matches ANY clipped-text issue on that surface, not only the quest wishes. Bounded: `RigDisciplineTests.homeLineLimitCensusMatchesDisclosure` pins the lineLimit census over the 5 Home view files, so a NEW capped text fails the census before it could silently ride this row — and P-6 proves that bound bites. | disclosure table row 1; P-6 below | accepted — bounded by the census; noted for the next disclosure-table touch |
| N-4 | NOTE | The census guard's file list is CLOSED — 5 named files (HomeView, StatusRow, ContextualLine, ActionRow, QuestCard). A NEW Home view file would escape the census. Same systemic family as 037 N-1/038 N-2 (scan guards are enumeration-bound). Offset: the S4 glass audit runs over the LIVE surface tree, so a new clipped text in a new file still fails the audit — two nets with offset blind spots. | `homeLineLimitCensusMatchesDisclosure` fixture list | open — systemic; fold into any future guard-family task |
| N-5 | NOTE | Reviewer honesty entry: probe P-6a (v1) was INVALID — the replacement pattern matched zero occurrences, the file was rewritten unchanged, and the suite stayed green. Detected by empty `git diff` + missing grep hit; superseded by P-6. Recorded so the bite table cannot be read as overstated. | P-6a row below | closed (disclosed) |
| N-6 | NOTE | The `fixtureHomeApp` unification changes the store-directory debug prefix (`momo-home-uitest-fixture-`/`momo-settings-uitest-fixture-` → `momo-uitest-fixture-`). Per-launch UUID naming; no test or app logic keys off the prefix. Behavior-neutral. | R5 diff, `MomoUITestSupport.swift` | closed (benign) |

**F-2 — the disclosed template delta (routed, not a silent patch):** §10's template ends "You two are {stage}."; the shipped stage element reads "{stage}. {descriptor}." — "New Friends. Just getting to know each other." — without the "You two are" carrier; the mood·energy half matches the template exactly ("Momo feels content and has plenty of energy" — the "has" arrives via the energy phrase itself, verified in the vocabulary). The implementation pinned the SHIPPED strings (so the audit's evidence is what VoiceOver actually reads), disclosed the delta in the test doc AND the task file as a finding for the orchestrator's copy decision. This reviewer verifies the disclosure is accurate and the routing is per §36 (copy-defining → owner); the content decision itself is not the reviewer's to make. **Orchestrator action:** owner copy decision before EPIC-008 (Watch repeats this template).

**Checked clean (no finding):** the scope extension into `HomeStatusRowView`/`HomeContextualLineView`/`HomeQuestCardView` is IN-REMIT — the R6 textClipped remediation (AX-conditional caps) is FR-20 launch-blocking remediation on surfaces the audit covers, §22-legal (small, directly necessary), and disclosed in the task file. The S6.2 dynamicType disclosure is correctly scoped (UIAlertController owns its labels; §10's S6.2 cell reads "System"; a Dynamic Type issue on ANY app surface still fails — verified by reading the runner's filter logic: surface+type+element all must match). The RM glass limitation and the VoiceOver rotor GAP are honestly disclosed limitations, verified accurate (the unit-level RM pins exist; the rotor walk genuinely cannot be automated through XCUITest here). The ENOSPC event is consistent with the recorded evidence but not independently reproducible — recorded as accepted-on-evidence.

## Bites and probes (every mutation restored BYTE-IDENTICALLY, sha256 baseline==final)

| ID | Target (guard) | Mutation | Expected | Observed | Restore proof (sha256, both sides) |
|----|----------------|----------|----------|----------|-----------------------------------|
| B-1 | R1 pins BIND (contract-mandated value-rewrite) | one `landingVerbatim` row's value rewritten (`morning.02`) | exactly the R1 pin fails, key attributed | `catalogCarriesTheTASK033LandingVerbatim` FAILED at `MomoCatalogScaffoldingTests.swift:448`, key named in the failure | `9c661d9816c30111ffa376873d2eaf9b58dcaceba7762071185cf1ecab163270` |
| B-2 | F-2 arm wiring (R2's re-bite, on the real file) | `MomoAppModel.swift`: `momentHapticSink(kind)` → `_ = kind` | the arm guard fails | FULL suite: 949 tests run, EXACTLY 1 failure — `deliverMomentsArmWiring` at `RigDisciplineTests.swift:690` | `22debca734338cae3e02c78dcefed6ef58bb11aedb7df0e5e306575d34fadffe` |
| B-3 | 037 N-1 hardening (room legs region-scoped) | one a11y leg moved OUTSIDE the Home `Canvas` (before it) | `roomSceneIsStaticAndSingleElement` fails | FAILED as expected (leg-outside-region detected) | `1286386750d9ba3acf155f76e41d623179bd205961fab0b24d322d652eec01ac` |
| B-4 | 038 N-1 hardening (erase anchored to destructive) | `eraseAllData()` call moved after the cancel action | `settingsInventoryIsExactAndWired` fails | FAILED as expected (anchor-order detected) | `8658b960a15e5e23969c3d1559c8669201589d6fa33676af08cc4bbde352559b` |
| P-5 | reviewer's own probe — NEW order pin | stage composite moved BEFORE mood·energy in `HomeStatusRowView` | `homeStatusRowSpeaksMoodEnergyBeforeStage` fails | FAILED directionally (declaration offset compare 3227 < 2442) | `55cdb866707a2905d54dc2510826d2344e73cc008a73b16af527e7f1c99a8bb7` |
| P-6 | reviewer's own probe — NEW census guard | `.lineLimit(2)` inserted on an `HomeActionRowView` text (a genuinely new cap the disclosure doesn't cover) | `homeLineLimitCensusMatchesDisclosure` fails | FAILED with exact file attribution (`HomeActionRowView`) | `eee58e691e4d64e1d6073151cd536559eb525938e3e2f09a08b7ba35301c769f` |
| P-6a | (aborted v1 of P-6) | replace-pattern matched ZERO occurrences — no-op rewrite | (none) | suite green; caught by empty diff + missing grep; superseded by P-6 | file byte-unchanged (hash constant throughout) |

Non-vacuity of the contrast suite was additionally verified by its own design: the documented-baseline equality legs (tolerance 0.005) fail if the math or the tokens drift, independent of the ≥ 4.5 legs.

## Test execution (reviewer-run)

| # | Command | Scope | Result |
|---|---------|-------|--------|
| 1 | `swift test` (package) | full package suite | **PASSED — 949 tests / 97 suites** (matches the handoff claim) |
| 2 | `xcodebuild build -scheme Momo` (generic iOS Simulator destination) | app target | **BUILD SUCCEEDED**; only 4× pre-existing `ld: warning: search path '/opt/extra/lib' not found` + the AppIntents metadata notice — ZERO warnings from any touched file |
| 3 | `xcodebuild build-for-testing -scheme Momo -destination id=1F25E487-A78E-464C-95AF-0BD1A9B3E1BE` (pinned SE; compile-only, nothing executed) | app + UI-test targets | **TEST BUILD SUCCEEDED**, exit 0; 3 warnings total, all environmental (2× ld search path, 1× AppIntents); ZERO warning lines reference `MomoUITests.swift`, `MomoAccessibilityAuditUITests.swift`, or `MomoUITestSupport.swift` — the R4/F-3 warning-census claim verified independently |
| 4–9 | Bites B-1…P-6 (focused runs; B-2 re-run at full-suite scope) | per-row | each produced the attributed failure; post-restore tree green |
| — | **NOT RUN — orchestrator's §19 gate:** FULL UI suite EXECUTION (27 consolidated + 8 audit = 35 tests) and the Watch build | — | this review compiles both targets but executes neither; AC-5's letter is pending on these two gates |

## Requirements roll-up

| Req | Claim | Reviewer verification | Status |
|-----|-------|----------------------|--------|
| R1 | 58-entry verbatim landing pins (counts 40/3/8/7) bind | 58/58 values byte-compared against the catalog JSON (0 mismatches); key-set equality; B-1 proves binding | **PASS** (doc-comment nit N-1) |
| R2 | R9e fifth leg `momentHapticSink(kind)` + F-2 re-bite | leg read in source; B-2 → exactly 1 attributed failure at full-suite scope | **PASS** |
| R3 | Guard-attachment hardening (037 N-1, 038 N-1) | room legs region-scoped inside the Canvas region (verified in source + B-3); erase anchored destructive→erase→cancel (verified in source + B-4); `readAppModelSource()` concatenates all 4 files so guards read the CLASS; both-direction fixtures present | **PASS** |
| R4 | F-3 warning housekeeping | `@MainActor` on all UI-test classes; build-for-testing census: zero warnings from touched files | **PASS** |
| R5 | UI-test consolidation, no coverage weakened | 27 pre-existing tests counted (1+4+5+17) + 8 new = 35; 5 helpers moved VERBATIM (only `private` dropped — the R8 access-level pattern); `fixtureHomeApp`'s two copies unified onto `homeApp` + `clock:` default (N-6 benign); `walkFlowToHome` deleted, replaced by `walkToHome` which preserves every step verbatim (one gains a failure message) and ADDS one terminal assert — strictly more assertion, verified statement-level | **PASS** |
| R6 | FR-20 AC-2 audit evidence, all iPhone surfaces | 8-test audit suite: `XCUIAccessibilityAuditType.all` with a disclosure table of EXACTLY 2 rows (S4 textClipped, S6.2 dynamicType), each with surface+type+element+why; `auditSurface` collects undisclosed issues and fails loudly — NO blanket catch-all; all 5 §10 surfaces covered S1–S6.2; Watch leg explicitly deferred (contract-pre-mandated); contrast suite independently reproduced (all 8 ratios within 0.005 of documented baselines AND ≥ 4.5 both grounds — tokens re-derived from source by this reviewer); template pinned at shipped strings with the delta routed (F-2) | **PASS** (N-2/N-3 notes; FULL-suite execution pending §19) |
| R7 | TASK-038 N-3 rename-field re-sync | Save action trims BEFORE `renamePet(to:)` and writes the trimmed value back to the field (verified in source); glass test types padded text and asserts the trimmed value; R6's field-label fix verified (`renameFieldLabelKey` → `.accessibilityLabel`) | **PASS** |
| R8 | `MomoAppModel.swift` 948→775 + two same-target files, zero behavior change | mechanical move-semantics proof: every removed block compared (normalized) against `+Canvas`/`+Celebrations` — all code lines verbatim; only access keywords (`private` dropped; `internal(set)` → plain `var` where extension writes require it) and doc comments differ; exactly 7 non-comment insertions, ALL access-level; all three files ≤ 800 (775/128/117) | **PASS** |

**AC-1** zero new copy / zero engine semantics / zero epoch movement — verified (walls diff-absent, epoch 4, no catalog keys added). **AC-2** route exactly per §25 — verified. **AC-3** every routed review item landed — verified via R1/R2/R3/R4/R7 + the two TASK-038 cleanups. **AC-4** per-surface audit matrix with zero UNEXPLAINED gaps — the manual checklist is honest per-row (rotor GAP surfaced as a finding, not footnoted); Watch deferral recorded. **AC-5** N-3 on glass ✓; 948→775 ✓; "package suite + FULL UI suite + Watch build all green" — package suite green HERE; FULL UI suite + Watch build pending the §19 gate (compile-verified only).

## Handoff-claim audit (§25)

| Handoff claim | Verification |
|---------------|--------------|
| "949 tests / 97 suites pass" | reproduced (row 1) |
| "Warning census over touched files — CLEAN" | reproduced independently via build-for-testing log grep (row 3) |
| Split map ("which members went where") | verified mechanically; map accurate |
| Disclosure table (2 rows, no blanket catch-all) | read row-by-row; both reasons verified against source and §10; filter logic verified surface+type+element-scoped |
| Template delta disclosed as a finding | accurate; routed per §36 (F-2 above) |
| ENOSPC mid-session event | consistent with the recorded evidence; NOT independently reproducible — accepted-on-evidence, recorded |
| R6 scope extension into 3 Home files | adjudicated in-remit (launch-blocking remediation, §22, disclosed) |
| RigDisciplineTests 1032 ln observation | implementer-disclosed; not re-raised |
| "27 tests unchanged" | counted: 27 pre-existing + 8 new |

## Reviewer disclosure (complete)

1. Six live bite mutations (B-1…P-6) — each restored and proven byte-identical by sha256 (table above). B-1 touched a file under `Tests/` — sanctioned by the bite mandate, restored byte-identically; no test was ever modified to pass.
2. One aborted no-op probe (P-6a) — file byte-unchanged.
3. This record — the ONLY `.md` file written.
4. Scratch under `/tmp/review-039/` (build logs, extraction targets) — outside the repository.
5. NO commits, pushes, stashes, or branch operations. NO edits to permission settings, CLAUDE.md, config, the task file, status.md, epics, or any decision record. No simulator was driven; the UI suite was never executed. Final tree verified 2026-09-11: all six bite-touched files at baseline sha256, `git status --porcelain` exactly the contract's dirty set, 0 stashes, and the package suite green (949/97) at that tree.

REVIEW-COMPLETE TASK-039