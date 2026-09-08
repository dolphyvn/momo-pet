# TASK-010 — Test-Target Scaffolding + Import-Whitelist + Banned-Vocabulary Harness

## Parent Epic
EPIC-002 — Foundation & Build Baseline

## Objective
Stand up the five-target test architecture per 05 §10.1 and wire the two standing static scans from 05 §10.2: the import-whitelist scan enforcing D-R1 (MomoCore imports Foundation only) and the banned-vocabulary scan enforcing the 04 §10.2 tone guide over String Catalogs — both as mechanically failing tests, self-tested against fixtures, so the guardrails exist before any logic or copy is written.

## Context
05 §10.1 defines: `MomoCoreTests` (package, `swift test` on macOS), `MomoKitTests`, `MomoCharacterTests` (same), plus `MomoUITests` and `MomoWatchUITests` (app-project test targets on simulators). 05 §10.2 mandates the two static scans and the coverage floors (Core ≥ 90 %, Kit ≥ 80 % — enforced later per task, not here). TASK-009 delivered the package + app targets; this task adds the test targets and the scans. The scans are structural guarantees for FR-12 (tone) and D-R1 (purity) — they must fail loudly, and their failure modes must themselves be tested.

## Requirements
1. Package test targets `MomoCoreTests`, `MomoKitTests`, `MomoCharacterTests`, runnable via `swift test` on macOS; each contains one smoke test so the suites are non-empty.
2. App-project UI test targets `MomoUITests` (hosting `Momo`) and `MomoWatchUITests` (hosting `MomoWatch`), each with one trivial smoke test, runnable on the pinned simulators via `xcodebuild test`.
3. Test framework pinned per ADR-008 (expected Swift Testing; fall back per its note). Resolve any remaining framework VERIFY-AT-BUILD item and record it resolved in Implementation Notes.
4. **Import-whitelist scan** (D-R1, 05 §10.2): a test in `MomoCoreTests` that scans the `MomoCore` sources and fails if any `import` other than Foundation (and standard-library modules on the whitelist — whitelist itself committed and documented) appears. Implement the scan logic as a pure, fixture-testable function.
5. **Banned-vocabulary scan** (FR-12, 04 §10.2): a test that loads the String Catalogs (TASK-011 creates them; until then the scan reads whatever catalogs exist, vacuously green) and fails if any banned term from the 04 §10.2 list appears in any value. Same fixture-testable design. If TASK-011 has not landed, the scan still ships and passes vacuously — coordinate ordering with the orchestrator if simpler to invert.
6. Self-tests for both scanners: unit tests against fixture strings/modules — a violating fixture fails, a clean fixture passes. No scratch-commit tricks: the scanners are tested as functions.
7. Coverage measurement wired (report generated locally; floors are *recorded* in later tasks, not enforced here).

## Files / Areas Likely Affected
- `Tests/MomoCoreTests/…`, `Tests/MomoKitTests/…`, `Tests/MomoCharacterTests/…` (package)
- `MomoUITests/…`, `MomoWatchUITests/…` (app project)
- Scan sources + fixtures (suggest `Tests/MomoCoreTests/Support/`)

## Dependencies
- TASK-009 (package + app targets exist).

## Constraints
- Jupiter model, fresh agent, no commit by agent.
- No product logic in this task — harness only.
- Scans must be fast and deterministic (no network, no subprocess flakiness).

## Acceptance Criteria
- AC-1: `swift test` runs all three package test targets green on macOS.
- AC-2: `xcodebuild test` runs both UI-test targets green on the pinned simulators.
- AC-3: Import-whitelist scan fails on a violating fixture (non-Foundation import) and passes `MomoCore` as it stands; whitelist documented.
- AC-4: Banned-vocabulary scan fails on a fixture containing a banned term and passes clean fixtures; the banned list is sourced from 04 §10.2 verbatim.
- AC-5: Framework pin resolved; any 05 Appendix B item owned here (swift-test hostability if re-owned from TASK-009, framework) marked resolved with evidence.

## Required Tests
- The scanner self-tests (AC-3/AC-4) + the five smoke tests. Evidence: `swift test` and `xcodebuild test` outputs in Implementation Notes.

## Review Requirements
- Fresh reviewer verifies: target set matches 05 §10.1; scanners enforce exactly the documented rules (no extra vocabulary, no missing whitelist entries); self-tests genuinely exercise failure paths; no product logic smuggled in. Record in `.claude/tasks/reviews/REVIEW-TASK-010.md`.

## Git Requirements
- Branch: `feature/EPIC-002-foundation`
- Commit: `test(bootstrap): TASK-010 scaffold test targets with import-whitelist and banned-vocabulary scans`
- Push to origin after orchestrator commit; record hash in Completion Evidence.

## Status
DONE — implemented, all verifications green, REVIEW-TASK-010 **APPROVED** (0 MAJOR / 0 MINOR / 2 NITPICK, both mechanical and applied), committed and pushed 2026-09-08.

## Implementation Notes

### Source-of-truth path correction (banned-vocabulary list)
The dispatch named `docs/design/04-ux-architecture.md §10.2`; the UX architecture doc in this repo is `03-ux-architecture.md` and has no banned-vocabulary list. The list's true source of truth is **`docs/design/04-character-system.md` §10.2** ("Banned vocabulary (hard list)") — as cited by 05 §10.2 ("04 §10.2's banned-vocabulary list"), 05 §4.9, and delivery-plan §9/§22 ("04 §10 tone guide"). The 12 entries were consumed **VERBATIM and in document order**, byte-verified with `hexdump` (ASCII apostrophe in "don't forget", U+00B7 separators): forgot · lonely · sad · waiting for you · hurry · don't forget · last chance · only X left · streak · miss out · failed · penalty. ("Missed you" is the sanctioned absence reference per PRD §3.3 — deliberately NOT on the list.)

### Scan architecture (Requirements 4–6)
- Both scanners are **pure functions** in `Tests/MomoCoreTests/Support/` (`ImportWhitelistScan.swift`, `BannedVocabularyScan.swift`, `TestRepo.swift`): text/JSON in, violations out. No subprocesses, no network, no scratch commits — fixture self-tests feed literal strings/catalog JSON. Compiled into the `MomoCoreTests` target (no `Package.swift` change needed; SwiftPM auto-includes the `Support/` subtree).
- `TestRepo` derives the repo root from `#filePath` (deterministic, independent of the test process's cwd) and enumerates `Sources/MomoCore/**.swift` and the tree's `**.xcstrings` (skipping `.git`/`.build`/`.claude`/`DerivedData`/`xcuserdata`/`*.xcodeproj`).
- **Import whitelist** (committed + documented, one-line rationale per entry): exactly one entry — `Foundation` (D-R1 names it as MomoCore's single permitted import; Swift stdlib needs no import). The scanner strips `//` and `/* */` comments while preserving string literals (a quoted `"https://…"` cannot mute a line; a commented-out `// import UIKit` cannot fake a violation — the conservative parser can only over-report; no realistic accidental import escapes, since imports at line start — the effectively universal real-world form — are always caught; a same-line `; import X` after a statement is outside the line-oriented model, per REVIEW-TASK-010 NITPICK-2), and handles `@testable`/`@_exported`/scoped forms (`import struct Foundation.Date` → `Foundation`). The real-tree test asserts the source set is **non-empty** so a missing/renamed `Sources/MomoCore` can never green the scan vacuously.
- **Banned vocabulary**: values-only scanning (Requirement 5's wording — catalog keys are developer identifiers, not copy); case-insensitive substring matching (deliberately aggressive — hard list fails loudly, human re-words false positives); typographic apostrophe U+2019 normalized to ASCII before matching (a matching rule, not an extra term); "only X left" is the doc's own placeholder form, mechanically read as `only … left` with a bounded 0–2 word gap; **unparsable catalog JSON fails the scan loudly** (returns an `<unparsable catalog>` violation) rather than silently skipping. A list-integrity test pins the 12 entries verbatim in document order.
- Fixture self-tests prove both directions: violating fixtures fail with full attribution (file/catalogKey/language/term/value); clean fixtures, the sanctioned "Momo missed you.", a banned term in a KEY only (passes — keys not scanned), and non-source localizations all behave per the documented rules.
- **Self-test red→green honesty (§25):** during this task's own implementation the self-tests caught two genuine defects before any review: (a) `BannedVocabularyScan.entries` was missing `.substring("last chance")` (list-integrity test: count 11 ≠ 12); (b) `TestRepo.repoRoot` resolved one path component short (to `<root>/Tests`, so the MomoCore scan would have thrown on a nonexistent directory). Both fixed; final run green. The failure modes the tests exist for were exercised for real.

### UI-test targets (Requirement 2) — hand-authoring precedent continued
- `MomoUITests` (hosts `Momo`) and `MomoWatchUITests` (hosts `MomoWatch`), `productType com.apple.product-type.bundle.ui-testing`, added to the hand-authored committed pbxproj (TASK-009 precedent) with the same `8A…` 24-hex ID scheme: Sources phases, Debug/Release config lists (pins: `IPHONEOS/WATCHOS_DEPLOYMENT_TARGET = 26.0`, `SWIFT_VERSION = 6.0`, device-family 1 / 4, bundle IDs `com.momo.app.MomoUITests` / `com.momo.app.MomoWatchUITests`), `PBXContainerItemProxy` + `PBXTargetDependency` on the hosted apps, and `TestTargetID` in the project's `TargetAttributes`. `TEST_TARGET_NAME = Momo` / `MomoWatch`.
- Deliberate difference from the app targets: test bundles use `GENERATE_INFOPLIST_FILE = YES` (no hand-maintained plist needed for test runners; the apps keep their real plists).
- Smoke tests are trivial per dispatch: launch + one element exists (`testLaunchShowsTabBar` → tab bar of the UX-1 3-tab shell; `testLaunchShowsGlanceText` → any static text of the W1 glance).
- **Scheme TestActions added to both shared schemes** (Momo → MomoUITests, MomoWatch → MomoWatchUITests, `shouldAutocreateTestPlan = YES`) — directly necessary for AC-2's `xcodebuild test` and resolving REVIEW-TASK-009 NITPICK-3 ("schemes carry no TestAction") as the dispatch directed.

### Verification evidence — commands verbatim (Toolchain: Xcode 26.6 (17F113), same machine/state as TASK-009)
1. `swift test` → **exit 0**; `✔ Test run with 20 tests in 5 suites passed after 0.006 seconds.` (suites: MomoCore placeholder, MomoKit placeholder, MomoCharacter placeholder, "D-R1 import-whitelist scan", "FR-12 banned-vocabulary scan" — 3 smoke tests + 15 scan/self tests).
2. `xcodebuild test -project Momo.xcodeproj -scheme Momo -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation),OS=26.5'` → `** TEST SUCCEEDED **`, **exit 0**; `Test Case '-[MomoUITests.MomoUITests testLaunchShowsTabBar]' passed (6.032 seconds).`
3. `xcodebuild test -project Momo.xcodeproj -scheme MomoWatch -destination 'platform=watchOS Simulator,name=Apple Watch SE 3 (40mm),OS=26.5'` → `** TEST SUCCEEDED **`, **exit 0**; `Test Case '-[MomoWatchUITests.MomoWatchUITests testLaunchShowsGlanceText]' passed (6.797 seconds).` **No watchOS UI-testing toolchain limitation was hit** — XCUITest runs against the standalone watch target as configured (D-R3).
4. Coverage (Requirement 7, local measurement only): `swift test --enable-code-coverage` (exit 0) → `.build/debug/codecov/default.profdata`, then **`xcrun llvm-cov report .build/arm64-apple-macosx/debug/MomoPackageTests.xctest/Contents/MacOS/MomoPackageTests -instr-profile .build/debug/codecov/default.profdata`** → per-file line/region table, TOTAL line cover 90.81%. **Tooling nuance recorded:** `xcrun xccov view --report` on the raw SwiftPM `.profdata` fails with `Error: unrecognized file format` — xccov consumes `.xcresult`/xccovarchive bundles; SwiftPM's profdata is the `llvm-cov` input, so llvm-cov is the wired command (recorded here per the dispatch's "record the command"). Numbers are informational only: placeholder product sources carry almost no executable lines (e.g. `MomoCorePlaceholder` is a compile-time `static let`), so the total is dominated by test-support code. Floors (Core ≥ 90 %, Kit ≥ 80 %) remain **not enforced** — they are recorded per task at TASK-020/024 per the dispatch and status.md.

### VERIFY dispositions (Requirement 3 / AC-5)
- **swift-test-hostability** (05 Appendix B, owner TASK-009/010): already **RESOLVED by TASK-009** (task file §"VERIFY item disposition"); nothing re-owned into this task.
- **Test-framework pin** (ADR-008 Decision 5: "TASK-009/TASK-010 wire the frameworks into the project's test targets and re-confirm in-target"): **RESOLVED with evidence.** Swift Testing confirmed in-target — all 20 package tests run under the Swift Testing runner (`@Suite`/`@Test`/`#expect`; runner glyph lines in the `swift test` log). XCUITest confirmed in-target — both UI bundles (`import XCTest`) built and executed on the pinned simulators (evidence items 2–3). Zero third-party test dependencies (D-R4). No Appendix B item owned by this task remains open.

### Constraints compliance
- Harness only: no product logic added; smoke tests assert only the TASK-009 placeholder anchors and one UI element each.
- Scans fast/deterministic: pure Foundation text/JSON functions, no subprocess, no network, no sleeps; full `swift test` ≈ 0.006 s.
- No debug print statements left behind. `Package.swift` untouched (wiring required none). Files changed: `Tests/MomoCoreTests/{MomoCorePlaceholderTests.swift, ImportWhitelistScanTests.swift (new), BannedVocabularyScanTests.swift (new), Support/ (new: ImportWhitelistScan.swift, BannedVocabularyScan.swift, TestRepo.swift)}`, `Tests/MomoKitTests/MomoKitPlaceholderTests.swift`, `Tests/MomoCharacterTests/MomoCharacterPlaceholderTests.swift`, `MomoUITests/MomoUITests.swift` (new), `MomoWatchUITests/MomoWatchUITests.swift` (new), `Momo.xcodeproj/project.pbxproj`, `Momo.xcodeproj/xcshareddata/xcschemes/{Momo.xcscheme, MomoWatch.xcscheme}`, and this task file.

## §28 Handoff

### Completed
- Requirements 1–7 complete: three package suites non-empty (smoke tests); two native UI-test targets with trivial smoke tests runnable via `xcodebuild test` on the pinned simulators; scheme TestActions added (closes REVIEW-TASK-009 NITPICK-3); import-whitelist scan shipped with documented one-entry whitelist, failing on a violating fixture and passing real MomoCore with a non-empty-source guard; banned-vocabulary scan shipped consuming the 04 §10.2 hard list verbatim (12 entries, byte-verified), vacuously green on today's catalog-less tree; self-tests for both scanners prove failure and success paths (and caught two real defects during implementation); local coverage measurement wired and the working command recorded; framework-pin VERIFY item resolved with in-target evidence.

### Files Changed
- See "Constraints compliance" bullet list above (7 modified, 7 new files/directories; `Package.swift` and all product sources untouched). *(Count corrected per REVIEW-TASK-010 NITPICK-1 — an earlier revision said 8.)*

### Tests Run
- `swift test` (macOS host, Swift Testing)
- `xcodebuild test -project Momo.xcodeproj -scheme Momo -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation),OS=26.5'`
- `xcodebuild test -project Momo.xcodeproj -scheme MomoWatch -destination 'platform=watchOS Simulator,name=Apple Watch SE 3 (40mm),OS=26.5'`
- `swift test --enable-code-coverage` + `xcrun llvm-cov report … -instr-profile .build/debug/codecov/default.profdata`

### Test Results
- All four exit 0. `swift test`: 20 tests / 5 suites passed. Both UI runs: `** TEST SUCCEEDED **` (1 test each, 6.032 s / 6.797 s). Coverage report generated (TOTAL 90.81 % lines, informational).

### Known Issues
- None blocking. Notes for the reviewer/orchestrator: (1) `xccov` cannot read SwiftPM's raw `.profdata` ("unrecognized file format") — llvm-cov is the wired local-measurement command; (2) the banned-vocabulary scan is values-only by Requirement 5's wording — catalog keys are deliberately not scanned; (3) "only X left" is enforced as the documented template reading (0–2 word gap), not a literal "only X left" substring; (4) real-tree coverage numbers are placeholder-dominated until real logic lands (expected; floors enforced at TASK-020/024).

### Decisions Made
- Banned list sourced from `docs/design/04-character-system.md` §10.2 (the dispatch's "04-ux-architecture.md" was a path slip; 05 §10.2/§4.9 and the delivery plan all cite 04 as the tone source) — consumed verbatim, byte-verified.
- Scanners live in `Tests/MomoCoreTests/Support/` per the task-file suggestion; pure functions, no Package.swift change.
- UI-test targets hand-authored into the committed pbxproj (TASK-009 precedent); test bundles generate their Info.plists; TestActions added to both shared schemes.
- Typographic-apostrophe normalization and the "only X left" template reading are documented matching rules, not list alterations — flagged for reviewer adjudication under AC-4's "verbatim" check.

### Reviewer Status
- pending — REVIEW-TASK-010 required (fresh reviewer per §10/§33; independently try to disprove: target set vs 05 §10.1, scanner rule fidelity vs the documented lists — including grepping the committed list against 04 §10.2 — genuine failure-path coverage, no product logic, no scope creep, and genuine re-execution of the four verification commands).

### Commit
- none by this agent (constraint: no git commits). Suggested message per task file: `test(bootstrap): TASK-010 scaffold test targets with import-whitelist and banned-vocabulary scans`.

### Push
- none (nothing committed).

### Recommended Next Step
- Orchestrator: spawn the fresh REVIEW-TASK-010 reviewer; on APPROVED, commit (message above) on `feature/EPIC-002-foundation`, push, record hash, update status.md, then dispatch TASK-011 (String Catalogs — at which point the banned-vocabulary scan stops being vacuous and scans real catalogs).

## Reviewer Findings
REVIEW-TASK-010 (fresh adversarial reviewer, 2026-09-08): **APPROVED** — 0 MAJOR / 0 MINOR / 2 NITPICK. Record: `.claude/tasks/reviews/REVIEW-TASK-010.md`. Reviewer independently re-ran `swift test` (20 tests / 5 suites, exit 0), both `xcodebuild test` runs (TEST SUCCEEDED on the pinned sims), reproduced the coverage pipeline (llvm-cov TOTAL 90.81 % identical; xccov profdata limitation reproduced), byte-verified the 12-term banned list against 04-character-system §10.2, and proved the scanners' real-tree failure paths and vacuous-green engagement via planted-tree mutation probes in /tmp.

| ID | Disposition | Fix |
|---|---|---|
| NITPICK-1 (Handoff says "8 modified"; actual 7) | FIXED (orchestrator, mechanical) | Count corrected to 7 modified / 7 new; correction annotated in place. |
| NITPICK-2 (docstring overclaims "never miss a real import") | FIXED (orchestrator, mechanical — wording only, no code change) | Docstring + task-file echo reworded per the reviewer's suggested language: same-line `; import X` documented as the known model limit; line-start imports always caught. |

## Completion Evidence
- Commit: (this commit) `test(bootstrap): TASK-010 scaffold test targets with import-whitelist and banned-vocabulary scans` on `feature/EPIC-002-foundation` — hash recorded in status.md by the orchestrator.
- Push: to origin (recorded in status.md with the push output).
- Review chain: REVIEW-TASK-010 **APPROVED** — all substantive claims survived adversarial re-execution; both nitpicks were documentation-accuracy items applied mechanically post-review (no code-behavior change; no re-review required).
