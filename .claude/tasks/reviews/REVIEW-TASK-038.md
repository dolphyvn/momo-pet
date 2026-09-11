# REVIEW-TASK-038 — Settings + rename + erase (FR-19; UX §1.2 S6)

Reviewer: independent adversarial review agent (Jupiter), per CLAUDE.md §10/§33 — mandate: disprove correctness; no self-approval; every claim below is evidence this reviewer personally produced.
Date: 2026-09-11
Branch: `feature/EPIC-007-iphone-home` · HEAD at review: `7340cd2` (contract commit). The review subject is the DIRTY working tree.
Inputs: `.claude/tasks/active/TASK-038-settings-rename-erase.md`; `docs/product/02-mvp-prd.md` FR-19 (:367-370); `docs/design/03-ux-architecture.md` (§2 :103 flat-IA; §9 :417 S6.2 verbatim line; §10 :436-438 a11y; :480); 04-character-system §11 (no audio in Phase 1); full diff vs `7340cd2`; `REVIEW-TASK-037.md` (format precedent).
Method: FR-19's inventory + MUST-NOT list and the UX S6 rules were re-derived BEFORE `SettingsView.swift` was first read; alert copy byte-compared against the UX line; plan-core semantics checked against the `onboardingCompleted` precedent field-for-field; erase adjudication re-derived from AC-2/NFR-7 independently; 3 mutation bites + 1 negative probe with sha256 provenance; no simulator driven; UI-suite execution, Watch build left to the orchestrator's §19 glass gate.

## Verdict

**APPROVED_WITH_MINOR_NOTES**

The implementation matches the derived spec on every point the contract pins: the FR-19 inventory is exact (4 groups, sound correctly ABSENT by the requirement's own conditional × 04 §11's no-audio fact), rename and haptics ride the plan core as pre-engine triggers with whole-state `EngineState` preservation and persist-IFF-changed, erase is correctly executor-level with the delete-first → reset-transients → fresh-swap → NO-persist sequence, and the alert copy is byte-verbatim including both `%1$@` name interpolations and U+2019 apostrophes. All three bites proved the R8 guards have teeth; the one negative probe (P-1) exposed a real but designed-for boundary — structural scans cannot see which control carries which action — which the glass UI tests backstop. Findings are NOTE-grade only; none blocks commit.

## Scope audit

Dirty set vs `7340cd2` (git status/diff --stat, verified at review close): 12 modified + 5 new files, exactly the contract's surface —

- `Apps/Momo/SettingsView.swift` (NEW, 161 ln) · `Apps/Momo/MomoAppModel+Settings.swift` (NEW, 82 ln) · `Apps/Momo/MomoAppModel.swift` (888→948) · `Apps/Momo/RootTabView.swift` · `Apps/Momo/PlaceholderSettingsView.swift` (DELETED)
- `Sources/MomoKit/AppModelPlan.swift` (+196) · `Sources/MomoKit/SettingsCopyKeys.swift` (NEW, 73 ln)
- `Apps/Shared/MomoCopy.xcstrings` (+120: 10 keys, 103→113, sorted)
- `Tests/MomoKitTests/` AppModelPlanTests (+158), AppModelOnboardingPlanTests (+16), SettingsCopyKeyTests (NEW) · `Tests/MomoCharacterTests/` RigDisciplineTests (+162), MomoCatalogScaffoldingTests (+68), CatalogCopyLawTests (+19)
- `MomoUITests/MomoSettingsUITests.swift` (NEW, 342 ln) · `Momo.xcodeproj/project.pbxproj` (+16)
- Task file updated (not reviewer's to edit).

**Frozen walls held:** `git diff --stat HEAD` contains ZERO entries under `Sources/MomoCore/` and `Sources/MomoCharacter/` — both diff-absent. Catalog epoch unchanged (no CopyRules epoch touch in the diff): the 10 new keys are FIXED `momo.settings.*` lookups (two carry `%1$@` positional templates), so no epoch movement — AC-5's "NO epoch movement" holds.
**pbxproj:** SettingsView occupies the deleted placeholder's `…0005` slots (3 sections + the swap); `MomoAppModel+Settings` via `…0055` ×4; `MomoSettingsUITests` via `…0045`/`…0035` ×4; zero placeholder residue. MomoKit sources need no pbxproj lines (package-managed).
**Debt (§26):** raw TODO/FIXME/HACK/TEMP grep over every touched file — zero real markers (raw hits are the word "TEMPLATE" inside doc-comment prose).

## Findings

| ID | Severity | Finding | Evidence | Disposition |
|----|----------|---------|----------|-------------|
| N-1 | NOTE | The R8 structural-guard family is **attachment-blind**: `stripLineComments`-based scans verify presence/absence/order of tokens, never WHICH control carries which action. Probe P-1 wired `eraseAllData()` onto the Keep (cancel) button and every guard stayed GREEN. The designed backstop is real: glass UI tests 3+4 (Keep-cancels pin; runner-side store-absence pins) both fail under this mis-attachment. Systemic to the scan approach — same family as REVIEW-TASK-037 N-1; TASK-039 hardening precedent is the natural home. | P-1 row below; `MomoUITests/MomoSettingsUITests.swift` tests 3/4 | open |
| N-2 | NOTE | `mentionsSettingsInventory` pins 8 presence legs but not `aboutVersionLabelKey` — the About section's label key has no structural leg. Residual risk is only a silently-renamed/deleted catalog key, which `SettingsCopyKeyTests.everyKeyResolves` catches (all 10 keys must resolve non-empty against the shipped catalog), and the glass census pins `settings.about` + namespace==5. Defense-in-depth gap, not a hole. | RigDisciplineTests legs vs `SettingsCopyKeys` 10-key table | open |
| N-3 | NOTE | Cosmetic: a no-op rename leaves `nameField` showing the user's un-trimmed text. Typing `␣␣Momo␣␣` over the pre-filled name enables Save (trimmed non-empty); the plan returns identity (trimmed == current) so `petName` never changes and `onChange(of: petName)` never re-syncs the field. State and store stay correct; only the field's displayed text keeps the padding until the next petName change. | `SettingsView.swift:74-75` + `renamePlan` identity arm | open |
| N-4 | NOTE | One fixture listed under `mentionsSettingsInventory`'s two-direction set exercises zero legs (its code sample matches no presence token), so it documents no-false-fire rather than detection. Non-vacuity of the composite is proven regardless — B-3's missing-leg bite failed the AND-composition. | RigDisciplineTests fixtures; B-3 below | open |
| N-5 | NOTE | `MomoAppModel.swift` stands at 948 ln vs the 800-line budget — the overage PRE-DATES this task (888 ln at `7340cd2`); the +60 is the structurally-forced internalization of the five seams the same-target extension rides (`storeDirectory`, `apply(trigger:)`, `debugLoud`, `resetTransientPresentationState()`, `installFreshDefaultState()`). Disclosed in the task contract and the extension's header; already pre-routed as the TASK-039 consolidation candidate. | git diff; `MomoAppModel+Settings.swift:14-21` | open |

**Checked clean (no finding):** the catalog's U+2019 apostrophes vs the UX doc's straight `0x27` in the S6.2 line is a contract-pre-adjudicated normalization — the task file's own copy-conventions constraint mandates U+2019; recorded as compliant, not a deviation. The `String(format:)` interpolation of `petName` puts the name in as an ARGUMENT, so a pet named `%@` or `%1$@` cannot inject format specifiers. `launchOrigin` and other logging-only read-models are stale-but-harmless post-erase. `requiresOnboarding` is derived (`!state.settings.onboardingComplete`), so the fresh-swap routes to S1 with zero new machinery.

## Bite + probe table (R8 guards, per dispatch)

Guard file `Tests/MomoCharacterTests/RigDisciplineTests.swift` was NEVER modified by this reviewer — sha256 `33f4484cd5a066e4a9293e1faf7fa5fc768545ecde2f31318073aca2df381499` constant at every checkpoint.

| ID | File mutated (sha256 UNDER bite) | Mutation | Focused result | Attribution | Restoration |
|----|----------------------------------|----------|----------------|-------------|-------------|
| B-1 | `Apps/Momo/SettingsView.swift` — `2197e6d9e7c699886ea8da5faf1c0588ad229e111ed154bc9358b840f9836244` | injected forbidden token `sound` into executable code | guard failed; violations = `["sound"]` | exactly the `settingsForbiddenViolations` pin failed | sha256 `1a3cb1dd008f3327c13977bf940f2620c79babb6303e0df820cc1168be3a7a4e` == baseline |
| B-2 | `Apps/Momo/MomoAppModel+Settings.swift` — `f1cb1d86dc42e0c7c3fedeb6997f5b7d833e2083988c6f7b2554f26af4bd97ac` | reordered `eraseAllData`: fresh-swap BEFORE delete | `mentionsEraseSequence` order leg failed (`removeItem(at: storeDirectory)` no longer first index) | exactly the sequence pin failed | sha256 `11a4b6f1ed12f36f4fc21e5f40b5f4b65356fad10a5ce99fd957326022df8cc7` == baseline |
| B-3 | `Apps/Momo/SettingsView.swift` — `985f1a3aa12eee2d40ed13f26f6ace82e33676eacb740d1ec36c35ac1e98ca2f` | removed the `appModel.eraseAllData()` call from the destructive button | `mentionsSettingsInventory` missing-leg failed (erase wiring absent) | exactly the inventory pin failed | sha256 `1a3cb1dd…` == baseline |
| P-1 (negative probe) | `Apps/Momo/SettingsView.swift` — `666773aba7a34d63715b85a4bad92bc838a1b1d598ff3d35559d70a2458dd927` | mis-attachment: erase action moved onto the Keep (cancel) button | ALL guards stayed GREEN | n/a — probe result (confirms N-1's boundary; the scan family cannot see attachment) | sha256 `1a3cb1dd…` == baseline |

Bite granularity, stated exactly: bites were verified by running the guard suites under mutation with the named pin failing ALONE (exactly-1-failure within the guard scope); the full 945/96 suite BOOKENDS the bite sequence (baseline pre-bite, final post-restoration, both green). The reviewer could not re-derive from the session log whether any individual bite also carried a full-suite run; this record claims only the bookends plus the named-test attributions.

## Test execution (reviewer-run)

| # | Gate | Command | Result |
|---|------|---------|--------|
| 1 | Baseline package suite | `swift test` | **945 tests / 96 suites PASS**, 0 failures |
| 2 | Pre-bite guards | `swift test` (RigDiscipline family, focused) | green |
| 3 | Bites B-1/B-2/B-3 | guard suites under each mutation | exactly-1 named failure each (table above) |
| 4 | Probe P-1 | guard suites under mis-attachment | all green — blindness confirmed |
| 5 | Final (post-restoration) | `swift test` | **945 tests / 96 suites PASS**, 0 failures; restoration sha256-proven (table above) |
| 6 | App-target build | `xcodebuild build -project Momo.xcodeproj -scheme Momo -destination 'generic/platform=iOS Simulator'` | **BUILD SUCCEEDED**; warnings are the pre-existing environment ones only (`ld: search path '/opt/extra/lib' not found`; AppIntents metadata-extraction note) — none from touched files |
| 7 | Test-target compile (reviewer's addition, disclosed — compiles `MomoSettingsUITests` without executing anything) | `xcodebuild build-for-testing -project Momo.xcodeproj -scheme Momo -destination 'platform=iOS Simulator,id=1F25E487-A78E-464C-95AF-0BD1A9B3E1BE'` | **TEST BUILD SUCCEEDED** — all test targets compile |

NOT executed by this reviewer, per dispatch: the UI suite's RUN, the Watch build, any simulator drive. Those belong to the orchestrator's §19 glass gate.

## Requirements roll-up

| Req | Verdict | Evidence |
|-----|---------|----------|
| R1 exact inventory | PASS | Derived-before-code-read: rename (S6.1) · haptics · Erase all data · About, and nothing else. Sound ABSENT — FR-19 ships it "only if Phase 1 ships any audio" and 04 §11 shipped no audio system. MUST-NOT rows absent, enforced by R8 guards (8 tokens) + glass census (namespace==5, forbidden-vocab scan, tabBars==3, alerts==0). |
| R2 inline rename adjudication | PASS | S6.1 renders inline in the native list despite the IA tree's "sub-screen" wording — §2's flat-IA law (:103) bans push navigation and names the erase alert the product's ONLY modal; adjudication disclosed in the task contract and the view's header. |
| R3 `.petRenamed` trigger | PASS | Dispatched BEFORE engine routing (the `onboardingCompleted` precedent); identity plans on petID mismatch, INV-1 failure (`Pet` failable init rejects whitespace-only), and identical-name (persist-IFF-changed ⇒ no write); happy path carries all 10 `EngineState` fields field-for-field with id + createdAt pinned; steps `[.persist, .pushWatchSnapshot]`. |
| R4 `.hapticsToggled` trigger | PASS | Same plan-core shape; `SettingsState` 2-field carry verified (`onboardingComplete` preserved); the surface performs no haptic work — the TASK-036 sink gate reads the flag at delivery time. |
| R5 erase order + verbatim alert | PASS | Executor-level adjudication independently re-derived and confirmed: a re-persisting plan would (a) leave `prev`/`prev2` rotation bytes (fails AC-2's "deletes every local store") and (b) resurrect a store fresh installs lack (fails NFR-7). Sequence: `removeItem` FIRST → `resetTransientPresentationState()` → `installFreshDefaultState()` (the SAME factory as init — erase ≡ fresh install) → NO persist (first write = onboarding completion, which recreates the directory via `SnapshotStore`'s `createDirectoryIfMissing`, `SnapshotStore.swift:222`). Crash window between delete and swap lands on the fresh fallback → onboarding — FR-13's invisible recovery, the correct landing. Alert byte-verbatim: title `Erase everything?`, message template with `%1$@` in BOTH slots, `Erase` destructive, `Keep %1$@` cancel performing nothing. |
| R6 About | PASS | Version from `CFBundleShortVersionString` (the R6/D11 data-not-copy carveout — a system VALUE, not catalog copy); privacy statement verbatim: `Everything stays on this iPhone. Nothing about Momo ever leaves.` |
| R7 catalog discipline | PASS | 10 FIXED `momo.settings.*` keys (`SettingsCopyKeys.swift`), 103→113 total, sorted; epoch stays 4; key→catalog resolution pinned from both sides (`SettingsCopyKeyTests` kit-side against the shipped file; scaffolding verbatim table character-side). |
| R8 guards | PASS (boundary noted, N-1) | `stripLineComments` structural guards over SettingsView + both app-model files: 8 forbidden tokens, 8 inventory presence legs incl. `appModel.eraseAllData()` + `.alert(`, ORDERED erase sequence, neverPersists (no `store.save`/`.persist` on the erase path), freshFactory pin. Doc-order trap handled (doc comments name helpers before code). Bites B-1/2/3 prove teeth; P-1 marks the attachment boundary; glass UI tests 3/4 are the designed backstop. |
| R9 accessibility | PASS | Native `Form` rows (44-pt targets, Dynamic Type, VoiceOver by construction — UX :436); 5 a11y identifiers; destructive trait on the erase row and the alert's Erase button; field label + Save from catalog copy; erase as the SYSTEM alert per :438. |

| AC (task file) | Verdict | Evidence |
|----------------|---------|----------|
| AC-1 exact inventory | PASS (structural half proven; glass half compiled, run owned by §19 gate) | R8 bites + census test authorship; namespace==5 arithmetic verified by reading `MomoSettingsUITests` test 1 |
| AC-2 rename flows | PASS | Plan tests pin the whole-state carry + id/createdAt stability + identity rejections; UI test 2 pins Home canvas label → "Mochi" and Room label → "Mochi's cozy room" (U+2019); Save-gate disabled-while-empty pinned at the glass |
| AC-3 haptics through plan core | PASS | Flip + preservation tests; persists (persist-IFF-changed write); gates next delivery via the TASK-036 sink gate reading the flag |
| AC-4 erase end-to-end | PASS (statically + test authorship; glass run owned by §19 gate) | Order bites; runner-side `FileManager` PRE-CHECK/absence/still-gone/re-create pins in UI test 4; relaunch-after-erase discriminator in UI test 5; Keep no-op in UI test 3; verbatim composition pinned kit-side (`assembledAlertForMochi` == UX line) |
| AC-5 suite green, no epoch movement, walls diff-absent | PASS | 945/96 green ×2 (reviewer-run); epoch 4 held; `Sources/MomoCore/` + `Sources/MomoCharacter/` diff-absent |

## Handoff-claim audit (§25)

| Handoff claim | Reviewer verification |
|---------------|----------------------|
| `swift test` 945/96 green | **Reproduced personally, twice** (baseline + final post-restoration) |
| App BUILD SUCCEEDED, pre-existing env warnings only | **Reproduced** (gate 6) — warning set matches (`/opt/extra/lib`, AppIntents note) |
| UI suite TEST SUCCEEDED 27/27 (Home 17, Onboarding 4, Settings 5, launcher 1) | **Not re-executed** (orchestrator's §19 gate owns the glass run). Audited arithmetically by reading the four UI files: `func test` counts 17+4+5+1 = 27 ✓; Settings contributes exactly the contract's 5 required tests ✓; all targets COMPILE (build-for-testing) ✓. Residual: glass greenness rests on the implementer's claim + the orchestrator's gate. |
| 10 keys, 103→113, sorted, FIXED lookups | Verified by reading the catalog diff + both key-resolution test files |
| Epoch stays 4 | Verified — no CopyRules epoch touch in the diff |
| Frozen walls diff-absent | Verified — zero `Sources/MomoCore/` / `Sources/MomoCharacter/` entries in `git diff --stat HEAD` |
| pbxproj: SettingsView swaps into placeholder slots, deterministic IDs, zero placeholder residue | Verified pre-record by reading the pbxproj diff |
| Zero TODO/FIXME/HACK/TEMP debt in touched files | Raw grep re-run: zero real markers |

## Reviewer disclosure

Every repository write made by this review, complete:

1. B-1 mutation → `Apps/Momo/SettingsView.swift` → restored byte-identically (sha256 both sides in the bite table)
2. B-2 mutation → `Apps/Momo/MomoAppModel+Settings.swift` → restored byte-identically (sha256 both sides)
3. B-3 mutation → `Apps/Momo/SettingsView.swift` → restored byte-identically (sha256 both sides)
4. P-1 probe mutation → `Apps/Momo/SettingsView.swift` → restored byte-identically (sha256 both sides)
5. This review record.

No commits, pushes, stashes, or branch operations. No edits to the task file, status.md, epics, or any other source file. `Tests/MomoCharacterTests/RigDisciplineTests.swift` never modified (sha256 constant throughout). Final tree verified at 2026-09-11: all three bite-touched files equal their baseline sha256s, and `swift test` is green (945/96) at that final tree. The `build-for-testing` gate (row 7) was a reviewer-added compile-only check — nothing was executed on a simulator.

REVIEW-COMPLETE TASK-038
