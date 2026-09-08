# TASK-011 — Design-System Token Pass + String Catalog Scaffolding

## Parent Epic
EPIC-002 — Foundation & Build Baseline

## Objective
Execute the single design-system palette pass from 04 Appendix B item 3: assign all UI tokens (project.md §18) and all 8 character color slots (04 §8.4) in one coherent light/dark system as Swift constants, and scaffold the String Catalogs with the `momo.line.*` copy namespaces — so that no downstream task ever hardcodes a color, a font, or a string.

## Context
04 §8.4 requires the rig to consume named token slots (R4: zero hex in the character pipeline), and project.md §18 defines the calm premium visual language. Doing UI + character palettes in ONE pass (04 Appendix B, "EPIC-002 design-system pass") prevents drift between Momo's body colors and the app chrome. Copy classes (`momo.line.<slot>.<nn>`, `momo.line.react.<family>.<nn>`, `momo.line.moment.<nn>`) are fixed by 04 §10.1; pools are filled by engine/read-model tasks later — here only the catalog structure and lookup exist. The banned-vocabulary scan (TASK-010) consumes these catalogs.

## Requirements
1. Token module (Swift constants living in `MomoCharacter`, which both apps already import):
   - All 8 character slots per 04 §8.4 **exactly as named there** (fur base/shade through sparkle family) — light and dark variants.
   - UI tokens per project.md §18: semantic background/surface/text colors (light+dark), typography styles, spacing scale, corner radii.
   - Single source of truth: hex values allowed ONLY inside the token file; everything downstream resolves tokens (R4).
2. Light/dark correctness: both variants defined for every token; dark values chosen deliberately (not inverted) per the calm-premium intent.
3. Contrast baseline: chosen text/surface pairs recorded with their computed contrast ratios in Implementation Notes (full audit is TASK-047; here we record intent — target ≥ 4.5:1 for body text).
4. String Catalog scaffolding:
   - Catalog file(s) exposing the three copy namespaces with type-safe lookup helpers (a `CopyKey` enum or function resolving `momo.line.*` keys; missing keys fail loudly in DEBUG per String Catalog defaults).
   - Seed a minimal placeholder set ONLY as required to prove lookup (marked clearly, replaced by real tone-guide pools in engine tasks — note which keys are placeholders).
   - Catalogs must parse and be scannable by the TASK-010 banned-vocabulary test.
5. Both app targets compile against the tokens; one placeholder surface per app visibly consumes a token (proves the plumbing).

## Files / Areas Likely Affected
- `Sources/MomoCharacter/DesignTokens.swift` (or the layout TASK-009 recorded)
- String Catalog files (app-level, shared with Watch)
- Lookup helpers in the package; placeholder-consumption touches in `Momo`/`MomoWatch` placeholder shells

## Dependencies
- TASK-009 (targets exist). Should land after/beside TASK-010 so the scans can consume the catalogs.

## Constraints
- Jupiter model, fresh agent, no commit by agent.
- Tone guide rules apply even to placeholder copy (banned list forbidden everywhere; placeholders kept neutral and few).
- Do not design new art or invent a second palette style — this is the single canonical pass (04 Appendix B item 3).
- No copy-writing of real lines (engine/read-model tasks own pools; FR-12 binds them).

## Acceptance Criteria
- AC-1: All 8 character slots + project.md §18 UI tokens exist with light/dark variants, exactly named per 04 §8.4 / §18.
- AC-2: Hex literals exist only in the token file (grep-verifiable); both placeholder shells render via tokens.
- AC-3: String Catalogs exist with the three `momo.line.*` namespaces; type-safe lookup resolves keys; placeholder keys are marked.
- AC-4: TASK-010's banned-vocabulary scan runs green against these catalogs.
- AC-5: Contrast baselines recorded; build green on both simulators.

## Required Tests
- Build verification both simulators; catalog lookup unit test (key resolves, missing key surfaces); token-file purity check (simple test asserting no hex outside the token source — or documented grep evidence). Evidence in Implementation Notes.

## Review Requirements
- Fresh reviewer verifies: slot names vs 04 §8.4 verbatim; single-palette-pass coherence (calm, not garish; dark mode deliberate); no real copy written; lookup API shape sane for engine key emission (05 §4.11 INV-11). Record in `.claude/tasks/reviews/REVIEW-TASK-011.md`.

## Git Requirements
- Branch: `feature/EPIC-002-foundation`
- Commit: `feat(design): TASK-011 design-system token pass and String Catalog scaffolding`
- Push to origin after orchestrator commit; record hash in Completion Evidence.

## Status
DONE (commit `(this commit)` pushed; REVIEW-TASK-011 APPROVED_WITH_MINOR_NOTES, disposition applied — MINOR-1/NITPICK-3 follow-up recorded in status.md, NITPICK-2 comment reword fixed with 35/9 re-run)

## Implementation Notes

### Files changed / created
- `Sources/MomoCharacter/MomoColorToken.swift` (new) — `MomoColorToken` with non-optional `light`/`dark` variants (light/dark existence is compile-enforced), internal `init(light:dark:)` taking `UInt32` hex, `resolve(_ scheme: ColorScheme) -> Color`; private `Color(hexRGB:)` confines hex decoding to this file.
- `Sources/MomoCharacter/MomoCharacterPalette.swift` (new) — the 8 character slots, keys **verbatim** from 04 §8.4 in document order (`momo.fur.base`, `momo.fur.shade`, `momo.ear.inner`, `momo.eye.base`, `momo.eye.highlight`, `momo.cheek`, `momo.blanket`, `momo.sparkle`), plus `allSlots` registry.
- `Sources/MomoCharacter/MomoUIColors.swift` (new) — semantic UI tokens per project.md §18: `background`, `surface`, `border`, `textPrimary`, `textSecondary`, `accent` (accent documented as decorative tint, not a text color).
- `Sources/MomoCharacter/MomoTypography.swift` (new) — `display/heading/body/caption` over system text styles (Dynamic Type preserved), semibold display/heading.
- `Sources/MomoCharacter/MomoMetrics.swift` (new) — `MomoSpacing` 4/8/16/24/32, `MomoRadius` 8/16/24.
- `Sources/MomoCharacter/MomoCopy.swift` (new) — `CopyKey` (type-safe builders for the three namespaces; `Slot`/`Family` string enums incl. `care-moment`; `isInApprovedNamespace` grammar check per 05 §4.9/§4.11 INV-11) and `MomoCopy.lookup/resolve(bundle:table:)`. Bundle is injected (package code never touches `Bundle.main`); missing key → `nil` via a NUL-containing sentinel (cannot be confused with a real value); `resolve` fails loudly in DEBUG (`assertionFailure`) and falls back to the key itself in release.
- `Apps/Shared/MomoCopy.xcstrings` (new) — String Catalog, `sourceLanguage: en`, `version: "1.0"`, exactly 3 seed keys, all `extractionState: manual`: `momo.line.day.00`, `momo.line.moment.00`, `momo.line.react.touch.00`.
- `Momo.xcodeproj/project.pbxproj` — catalog registered in BOTH app targets following the hand-authored ID conventions: PBXBuildFile `8A4000000000000000000051`/`…0052` → PBXFileReference `8A5000000000000000000041` (`lastKnownFileType = text.json.xcstrings`), fileRef added to group `8A6000000000000000000009 /* Shared */` (path `Shared`), build files added to Momo Sources phase `8A200000000000000000000D` and MomoWatch Sources phase `8A300000000000000000000D`.
- `Apps/Momo/PlaceholderHomeView.swift` — rewritten to resolve everything through tokens: background, `momo.fur.base` canvas with §18 subtle border, caption typography/colors, contextual line via `MomoCopy.resolve(CopyKey.line(.day, 0), bundle: .main)`.
- `Apps/MomoWatch/PlaceholderGlanceView.swift` — rewritten: `momo.blanket` canvas strip, text tokens, surface pat capsule whose VoiceOver label comes from the catalog (`CopyKey.react(.touch, 0)` — react lines are announced, never rendered, per 04 §10.1 rule 7). See "watch canvas defect" below for the layout fix made during verification.
- Tests (new target `MomoCharacterTests`): `Support/RepoTree.swift` (`#filePath`-anchored tree scanners), `MomoDesignTokensTests.swift`, `TokenPurityTests.swift`, `MomoCopyTests.swift`, `MomoCatalogScaffoldingTests.swift`.

### Palette (single canonical pass; hex literals exist ONLY in MomoCharacterPalette.swift + MomoUIColors.swift)
Character slots, light/dark: fur.base `F1E3D0`/`E3D1BC`, fur.shade `E0CCB2`/`C6AD90`, ear.inner `EFBFB8`/`D89E96`, eye.base `372F2B`/`272120`, eye.highlight `FFFFFF`/`F7F1E8`, cheek `F2B5AC`/`CE8B82`, blanket `B5CBDA`/`5E7C8F`, sparkle `EFCB7F`/`E3BA60`. UI: background `FAF7F1`/`1B1815`, surface `FFFFFF`/`26221D`, border `E7DFD3`/`3B342C`, textPrimary `2F2822`/`EFE9DF`, textSecondary `6E6459`/`A79C8E`, accent `C98B6F`/`D6A183`.

### Contrast ratios (WCAG relative luminance; target ≥ 4.5:1 body text)
| Pair | Light | Dark |
|---|---|---|
| textPrimary / background | 13.57 | 14.64 |
| textPrimary / surface | 14.51 | 13.09 |
| textSecondary / background | 5.41 | 6.56 |
| textSecondary / surface | 5.78 | 5.86 |
Informational (not text pairs): fur.base / background 1.18 light / 11.88 dark — the low light-mode value is deliberate: the character sits as a calm tonal shape on the warm ground (separation via fur.shade, the §18 border, and 10:1+ eye contrast), per project.md §18; eye.base / fur.base 10.37 / 10.65.

### Placeholder convention
Placeholder keys use index **00** (real pools start at 01), carry a `PLACEHOLDER …` comment prefix and self-describing values; `extractionState: manual`. Seed set is exactly 3 keys (one per namespace) — test-pinned (`strings.count == 3`) so unlisted keys need their own task. The sanctioned "Momo missed you." was deliberately NOT consumed here (ownership: engine/read-model tasks).

### Per-AC evidence (verbatim commands, run 2026-09-08, final state)
- `swift test` → `✔ Test run with 35 tests in 9 suites passed after 0.008 seconds.` — includes AC-1 pins (slot names/order + per-scheme resolve for all tokens), AC-2 purity scan, AC-3 lookup + scaffolding tests, AC-4 TASK-010 banned-vocabulary scan green over the real catalog file (non-vacuous), plus CopyKey namespace grammar tests (8 rejects incl. "Momo missed you." as prose).
- `xcodebuild -project Momo.xcodeproj -scheme Momo -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation),OS=26.5' build` → `** BUILD SUCCEEDED **` (exit 0). Compiled catalog verified in the bundle: `DerivedData/Momo-…/Debug-iphonesimulator/Momo.app/en.lproj/MomoCopy.strings` contains all 3 keys.
- `xcodebuild … -scheme MomoWatch -destination 'platform=watchOS Simulator,name=Apple Watch SE 3 (40mm),OS=26.5' build` → `** BUILD SUCCEEDED **` (exit 0, final post-fix binary); bundle strings verified likewise.
- iPhone UI test `MomoUITests/testLaunchShowsTabBar` → `** TEST SUCCEEDED **` (7.5 s). Watch UI test `MomoWatchUITests/testLaunchShowsGlanceText` → `** TEST SUCCEEDED **` on the final binary — both double as runtime catalog-integration proof (a missing key would `assertionFailure`-crash the surfaces in DEBUG).
- AC-2 rendering proof by pixel sampling of simulator screenshots (`sips -s format bmp` + stdlib BMP reader; screenshots at `/tmp/momo_task011_iphone_se3_home.png` 750×1334 and `/tmp/momo_task011_watch_se3_glance_final.png` 324×394 — exact ADR-008 canvases):
  - iPhone: background corner + below-canvas = `#FAF7F1`, canvas center = `#F1E3D0` — both **exact** token values; vision-model review additionally confirmed the warm off-white ground, cream canvas, and the rendered catalog line "Placeholder line — real lines arrive with the engine."
  - Watch (final): blanket `#5E7C8F` 15,036 px at y 144–207 (the 32 pt canvas strip), pat pill surface `#26221D` y 275–379 (52 pt capsule, 8 pt bezel clearance), textPrimary `#EFE9DF` (heading + Pat), textSecondary `#A79C8E` (quest line) — all exact token values on the watch's true 162×197 pt (@2x) canvas.

### Watch canvas defect found and fixed during verification (§20 root-cause record)
The first watch screenshots showed no `momo.blanket` pixels: `Rectangle().fill(token).aspectRatio(1, .fit)` collapsed to zero height inside the glance VStack. Bisected with temporary literal-color probe rectangles (removed afterwards) and pixel scans — the probes rendered, the canvas collapsed even with `.layoutPriority(1)` (content ideal exceeds the 165 pt available at 162×197, and the flexible aspect-ratio shape starves). Fixed deterministically: rounded-rect strip with fixed `frame(height: 32)`; geometry re-verified by pixels (strip y 72–103 pt, pill ends 189 pt with 8 pt bezel clearance). Also learned mid-verification: `xcodebuild build` does **not** install to the simulator — `simctl launch` runs the previously installed app, so screenshots must follow `simctl install` (or `xcodebuild test`). Early "unchanged" screenshots came from that stale-install state.

## Handoff

### Completed
All 5 ACs implemented and verified (see per-AC evidence): token module (8 §8.4 character slots verbatim + §18 UI tokens + typography/spacing/radius), hex purity structurally enforced and scan-tested, String Catalog scaffolded + registered in both targets, type-safe `CopyKey`/`MomoCopy` lookup with bundle injection and loud missing-key behavior, both placeholder shells consume tokens + catalog visibly (pixel-verified), contrast baselines recorded.

### Files Changed
See "Files changed / created" above — 6 new package sources, 1 new catalog, 5 new test files, pbxproj registration, 2 rewritten placeholder views. No docs/, status.md, task files (other than this one), or decisions/ touched.

### Tests Run
`swift test`; iOS + watchOS `xcodebuild build`; `MomoUITests/testLaunchShowsTabBar`; `MomoWatchUITests/testLaunchShowsGlanceText`; pixel-scan verification of both simulator screenshots; launch PIDs 98599 (iPhone) / 77242 (watch, final).

### Test Results
35 tests / 9 suites passed; both builds `** BUILD SUCCEEDED **`; both UI tests `** TEST SUCCEEDED **`; all four watch token colors + two iPhone token colors verified at exact hex values in rendered frames.

### Known Issues
- Reading a PNG with the Read tool uploads it to a CDN instead of rendering inline in this environment (same as TASK-009); visual confirmation was done via vision-model analysis of the uploaded images + exact pixel sampling (the decisive evidence).
- `MomoCopy.resolve`'s DEBUG `assertionFailure` is not unit-testable (process-fatal); its runtime effect is proven by the UI smoke tests instead.
- The watch glance canvas is a fixed-height placeholder strip pending the EPIC-008 rig; a comment in the view records why (flexible aspect-ratio shapes starve at this size).

### Decisions Made
- `MomoColorToken` carries non-optional light+dark variants — light/dark completeness is a compile-time property, not a test-time hope.
- Bundle injected everywhere in `MomoCopy` (apps pass `.main`; tests synthesize an `en.lproj` bundle — production `Bundle.localizedString` path exercised on-host).
- Lookup vs resolve split: `lookup` returns `String?` (missing keys surface), `resolve` DEBUG-asserts and falls back to the key (INV-11-safe: engine-visible keys, never composed prose).
- Accent token documented as decorative tint only — not for text (contrast not required for it).
- Placeholder convention: index 00 + `PLACEHOLDER` comment prefix, test-pinned seed of exactly 3 keys.

### Reviewer Status
Pending — fresh reviewer needed (REVIEW-TASK-011). Scrutiny suggestions: slot-name fidelity vs 04 §8.4 verbatim; hex-purity allowlist scope; catalog seed minimality vs "no real copy"; `CopyKey`/`MomoCopy` API shape for INV-11 engine emission; deliberateness of dark palette values; remaining inert string literals in shells (documented as placeholder anchors).

### Commit
None — agent does not commit (per dispatch; HEAD untouched at `5389af1`).

### Push
None — agent does not push.

### Recommended Next Step
Orchestrator spawns a fresh Jupiter review agent to produce `.claude/tasks/reviews/REVIEW-TASK-011.md` (status APPROVED / APPROVED_WITH_MINOR_NOTES / CHANGES_REQUIRED / BLOCKED); after findings are addressed and tests re-run, orchestrator commits `feat(design): TASK-011 design-system token pass and String Catalog scaffolding` on `feature/EPIC-002-foundation` and pushes.

## Reviewer Findings
REVIEW-TASK-011 (`.claude/tasks/reviews/REVIEW-TASK-011.md`): **APPROVED_WITH_MINOR_NOTES** (0 MAJOR / 1 MINOR / 2 NITPICK / 6 verified-benign adjudications). Every claim independently re-executed — slot byte-diff vs 04 §8.4 identical; swift test 35/9 reproduced; AC-4 proven non-vacuous in BOTH directions (real catalog 0 violations; planted "Your streak is gone." caught with full attribution; U+2019 path caught); independent hex-purity grep clean; both builds + both UI tests green on ADR-008 sims; reviewer's OWN pixel captures match all token hex exactly (incl. iPhone dark — evidence beyond the claim); all 12 contrast ratios recomputed exact (±0.01); dark palette mechanically proven deliberate (no inversion/uniform-delta transforms; coherent warm-dimmed system); pbxproj/catalog audits clean; zero scope creep.

Disposition (orchestrator, 2026-09-08):
| ID | Disposition | Fix |
|---|---|---|
| MINOR-1 (TokenPurityTests scans hex only; a future `Color(red:)`/named-color escape would evade it — tree clean today) | ACCEPTED AS FOLLOW-UP (per the review's own recommendation: "follow-up task, not a re-run") | Recorded in status.md as a small hardening candidate: extend the purity scan to component initializers + SwiftUI named colors outside the token module, mirroring ImportWhitelistScan's D-R1 enforcement. |
| NITPICK-2 (sentinel comment overstates: "cannot return a value containing NUL") | FIXED (comment reword only) | `MomoCopy.swift` comment reworded to the real property — sentinel-equality implausibility — per the review's suggested language. `swift test` re-run post-edit: 35 tests / 9 suites green (§19). |
| NITPICK-3 (contrast ratios recorded prose, not mechanically pinned) | NOTED — declined for this task, folded into the follow-up | Full audit is TASK-047 per the task contract; mechanically pinning here would require exposing private palette hex or duplicating values in tests (worse encapsulation for an "optional" hardening). Recorded alongside MINOR-1's follow-up so a future task can pin the four body-text pairs with a luminance helper if desired. |

No re-review required (no behavioral change — one comment reword). Final: **APPROVED — cleared for commit** per the review's closing recommendation.

## Completion Evidence
- Commit `(this commit)` — `feat(design): TASK-011 design-system token pass and String Catalog scaffolding` on `feature/EPIC-002-foundation`, pushed to origin (hash recorded in `.claude/tasks/status.md` per the established convention). Review: REVIEW-TASK-011 APPROVED_WITH_MINOR_NOTES → disposition applied → 35/9 green.
