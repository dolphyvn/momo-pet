# TASK-009 — Create the Local Swift Package + App Targets with Placeholder Shell

## Parent Epic
EPIC-002 — Foundation & Build Baseline

## Objective
Create the real product skeleton per ADR-005: a local Swift package defining `MomoCore` (Foundation-only), `MomoCharacter`, and `MomoKit` with **zero external dependencies**, plus the `Momo` (iOS) and `MomoWatch` (watchOS) app targets consuming it — both launching in their simulators with a placeholder shell, applying the TASK-008 pins, and proving `swift test` hostability.

## Context
05 §2 fixes the module map and dependency rules D-R1–D-R6 (`MomoCore` ← `MomoCharacter`/`MomoKit`; app targets may import all three; Core imports Foundation only). The repo currently contains **no code and no Xcode project**. ADR-005 ratified the local-SPM packaging. The first vertical slice's "Launch" leg begins here (delivery plan §4.2). The Xcode-*project* authoring mechanism is a build-tooling choice (not a product dependency): prefer a committed, text-diffable project description (e.g., XcodeGen `project.yml`) so reviews see diffs; if that tool is unavailable, a hand-authored project file is acceptable — record the choice and rationale in Implementation Notes (product's zero-third-party rule D-R6 applies to app code, not build tooling).

## Requirements
1. `Package.swift` (or equivalent package manifest) defining:
   - `MomoCore` — Foundation imports only (D-R1); no other imports, no resources yet.
   - `MomoCharacter` — depends on `MomoCore`; may import SwiftUI (empty placeholder source for now).
   - `MomoKit` — depends on `MomoCore`; empty placeholder source.
   - Zero external package dependencies (D-R6).
2. App targets consuming the package (pins from ADR-008 applied):
   - `Momo` (iOS): placeholder Home with the 3-tab structure Home · Room · Settings (UX-1) and a placeholder pet-canvas rectangle; tab bar real, content placeholders.
   - `MomoWatch` (watchOS): a single placeholder glance view in the W1 spirit (static placeholder, no logic).
   - Both targets: correct bundle IDs, deployment targets per ADR-008, app icons may be placeholders.
3. Verification (record evidence):
   - `xcodebuild -scheme Momo -destination <pinned iPhone>` builds; same for `MomoWatch` on a pinned watch simulator.
   - Both apps launch in their simulators showing the placeholder shells (screenshots or simulator boot evidence).
   - `swift test` runs on macOS with empty-but-present test targets (hostability VERIFY item from 05 Appendix B resolved or explicitly re-owned to TASK-010 if the test targets land there — do not silently drop it).
4. Resolve the swift-test-hostability VERIFY-AT-BUILD item (05 Appendix B): package test targets runnable via `swift test` on macOS. If a toolchain limitation appears, record it and re-own the item explicitly to TASK-010 with rationale.

## Files / Areas Likely Affected
- Creates `Package.swift`, `Sources/MomoCore|…`, `Sources/MomoKit|…`, `Sources/MomoCharacter|…` (placeholder sources)
- Creates the Xcode project (or `project.yml` + generated project) with `Momo` and `MomoWatch` targets
- Creates top-level app source folders (`Apps/Momo`, `Apps/MomoWatch` or per the project layout the agent records — layout decision documented in Implementation Notes)

## Dependencies
- TASK-008 (pins must exist; ADR-008 is the source for targets/devices).

## Constraints
- Jupiter model, fresh agent, no commit by agent.
- No domain logic, no persistence, no sync, no real UI beyond placeholders (scope: EPIC-002 Non-Goals).
- No third-party runtime dependencies (D-R6). Build tooling choice allowed per Context.
- Every module boundary must already respect D-R1 (TASK-010's import-whitelist scan will enforce it mechanically next).

## Acceptance Criteria
- AC-1: Package defines `MomoCore`/`MomoCharacter`/`MomoKit` with the ADR-005 dependency edges and zero external dependencies.
- AC-2: `Momo` builds and launches on the pinned iPhone simulator with the 3-tab placeholder shell; `MomoWatch` builds and launches on the pinned watch simulator with its placeholder glance.
- AC-3: Deployment targets match ADR-008 exactly.
- AC-4: `swift test` runs green on macOS (empty suites); swift-test-hostability VERIFY item resolved or explicitly re-owned with rationale.
- AC-5: Build-tooling and project-layout decisions recorded in Implementation Notes.

## Required Tests
- Build verification for both simulators (05 §10.1) + `swift test` (empty suites) — evidence recorded.
- No functional tests yet (no logic exists); TASK-010 adds the harness.

## Review Requirements
- Fresh reviewer verifies: module map vs ADR-005/05 §2; zero-dependency rule; pins applied; placeholder scope not exceeded (no smuggled domain/UI logic); build evidence genuine (CLAUDE.md §25). Record in `.claude/tasks/reviews/REVIEW-TASK-009.md`.

## Git Requirements
- Branch: `feature/EPIC-002-foundation`
- Commit: `feat(bootstrap): TASK-009 create Swift package and app targets with placeholder shell`
- Push to origin after orchestrator commit; record hash in Completion Evidence.

## Status
DONE — implemented, verified, REVIEW-TASK-009 **APPROVED** (0 MAJOR / 0 MINOR / 3 NITPICK; all substantive claims survived adversarial re-execution), committed and pushed 2026-09-08.

## Implementation Notes

### Build-tooling choice
- `which xcodegen` → not found (exit 1), so per the task Context fallback, the Xcode project is **hand-authored** and committed: `Momo.xcodeproj/project.pbxproj` (objectVersion 56, classic explicit groups).
- Rationale: a committed, text-diffable project needs no codegen tool in the loop — fresh clones build with zero setup, and reviews see plain pbxproj diffs. The generate-don't-commit pattern was rejected because generated projects would be missing from fresh clones.
- Two shared schemes hand-authored (`xcshareddata/xcschemes/Momo.xcscheme`, `MomoWatch.xcscheme`) so `xcodebuild -scheme` works headlessly.
- Both targets use `GENERATE_INFOPLIST_FILE = NO` with real `Apps/Momo/Info.plist` / `Apps/MomoWatch/Info.plist` so app identity is explicit and reviewable.

### Layout decision
- `Package.swift` + SwiftPM-standard `Sources/<Module>/` and `Tests/<Module>Tests/` at repo root; app sources under `Apps/Momo/` and `Apps/MomoWatch/`; project at `Momo.xcodeproj/`.
- Package is wired into the project via `XCLocalSwiftPackageReference` (`relativePath = "."`) plus `XCSwiftPackageProductDependency` entries for MomoCore/MomoCharacter/MomoKit shared by both targets' Frameworks phases. App sources currently only `import SwiftUI`; the module edges are product dependencies (build-time wiring), with imports to arrive with real code.

### Package manifest (Requirement 1)
- `// swift-tools-version: 6.2` — 6.2 is the **minimum** manifest API exposing the `.v26` platform pins required by ADR-008 (tools 6.0 rejected `.iOS(.v26)`/`.watchOS(.v26)` as unavailable).
- `platforms: [.iOS(.v26), .watchOS(.v26), .macOS(.v26)]`. `.macOS(.v26)` is **not** a shipping platform: it is declared so `swift test` can host all three targets on this Mac. Without it SwiftPM's low default macOS floor broke availability (`'EmptyView' is only available in macOS 10.15 or newer`) when compiling the SwiftUI-importing `MomoCharacter`.
- Dependency edges: MomoCore → (none, Foundation only, D-R1); MomoCharacter → MomoCore (has a minimal SwiftUI placeholder view proving the D-R2 edge); MomoKit → MomoCore; `dependencies: []` (zero external, D-R4/D-R6).

### App targets (Requirement 2)
- **Bundle IDs** (no value pre-recorded in docs; chosen and recorded here): `com.momo.app` (iOS) and `com.momo.app.watchkitapp` (watchOS, companion-prefix convention).
- Pins: `IPHONEOS_DEPLOYMENT_TARGET = 26.0`, `WATCHOS_DEPLOYMENT_TARGET = 26.0`, `TARGETED_DEVICE_FAMILY` 1 / 4, `SWIFT_VERSION = 6.0` (ADR-008 exact).
- **Momo**: `RootTabView` is a real native `TabView` — Home (`house`) · Room (`door.left.hand.open`) · Settings (`gearshape`) per UX-1; each tab's content is a placeholder (Home: rounded-rectangle pet-canvas placeholder + caption; Room/Settings: `ContentUnavailableView` with neutral copy). No domain logic, no persistence, no sync, no real UI beyond placeholders.
- **MomoWatch**: single static W1-spirit glance (`PlaceholderGlanceView`) — status headline, static canvas rectangle, quest footnote, inert "Pat" capsule. No logic.
- **D-R3 standalone-watch decision**: grep of docs found no guidance on embedding. MomoWatch is a **standalone watch application target** (`productType application`, `WKApplication = true`) with **no PBXTargetDependency Momo→MomoWatch** (`dependencies = ()` in both targets) — satisfying D-R3's literal "no target dependency between Momo and MomoWatch". The iPhone-companion relation is declared for EPIC-008 WatchConnectivity work via `WKCompanionAppBundleIdentifier = com.momo.app` in the watch Info.plist. If a later decision wants an embedded watch app inside the iOS product, that is a deliberate follow-up.

### Verification evidence (Requirement 3) — commands verbatim, all exit 0
Toolchain: Xcode 26.6 (17F113), Apple Swift 6.3.3, `Target: arm64-apple-macosx26.0`.

1. iOS build: `xcodebuild -project Momo.xcodeproj -scheme Momo -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation),OS=26.5' build` → ** BUILD SUCCEEDED **, exit 0.
2. watchOS build: `xcodebuild -project Momo.xcodeproj -scheme MomoWatch -destination 'platform=watchOS Simulator,name=Apple Watch SE 3 (40mm),OS=26.5' build` → ** BUILD SUCCEEDED **, exit 0.
3. iPhone launch: `xcrun simctl install 1F25E487-A78E-464C-95AF-0BD1A9B3E1BE <DerivedData>/Debug-iphonesimulator/Momo.app` then `xcrun simctl launch 1F25E487-A78E-464C-95AF-0BD1A9B3E1BE com.momo.app` → PID 91593, exit 0; process-liveness re-check `xcrun simctl spawn 1F25E487-… launchctl list | grep momo` → `91593  0  UIKitApplication:com.momo.app[165a][rb-legacy]` (app running, not springboard).
4. iPhone screenshot: `xcrun simctl io 1F25E487-… screenshot /tmp/momo_task009_iphone_se3_home.png` → 750×1334 px (`sips -g pixelWidth -g pixelHeight`), matching the ADR-008 SE 3 (3rd gen) canvas exactly.
5. Watch launch: `xcrun simctl install F0A75761-CB62-4812-A1C4-8E682A3F02FB <DerivedData>/Debug-watchsimulator/MomoWatch.app` then `xcrun simctl launch F0A75761-CB62-4812-A1C4-8E682A3F02FB com.momo.app.watchkitapp` → PID 96043, exit 0; liveness re-check → `96043  0  UIKitApplication:com.momo.app.watchkitapp[7149][rb-legacy]`.
6. Watch screenshot: `/tmp/momo_task009_watch_se3_glance.png` → 324×394 px, matching the ADR-008 Apple Watch SE 3 (40mm) canvas exactly.
7. `swift test > /tmp/momo_swift_test.log 2>&1` → exit 0; `✔ Test run with 0 tests in 3 suites passed after 0.001 seconds.` (MomoCore/MomoKit/MomoCharacter placeholder suites, Swift Testing, empty by design).

**Visual confirmation method (honest record)**: inline PNG rendering failed in this agent's session (Read returned upload notices), so both screenshots were verified through a vision-model analysis of the uploaded PNGs plus the independent `launchctl` liveness checks above. Vision descriptions verbatim-confirmed: iPhone — floating pill tab bar with three tabs "Home" (house icon, selected) / "Room" (door icon) / "Settings" (gear icon), large rounded-rectangle placeholder block, caption "Home — placeholder", app screen not iOS home screen. Watch — headline "Feeling happy", canvas placeholder shape, footnote "Wish placeholder", pill-shaped "Pat" button, app screen not watch face/home. Screenshot PNGs are in `/tmp` (ephemeral, outside the allowed change set); dimensions recorded here are the durable evidence.

**swift-test platform banner nuance**: the log's legacy compat line `↳ Target Platform: arm64e-apple-macos14.0` comes from the XCTest shim banner inside the SwiftPM test runner, not from our targets; the toolchain itself targets `arm64-apple-macosx26.0` and the manifest pins `.macOS(.v26)`. Compile success of the SwiftUI-importing target is the hostability proof. Also benign in log: `ld: warning: search path '/opt/extra/lib' not found` (host environment search path, not project-configured).

### VERIFY item disposition (Requirement 4) — RESOLVED
swift-test-hostability (05 Appendix B): **resolved in this task**. `swift test` compiles and runs all three test targets on macOS, including the SwiftUI-importing MomoCharacter; exit 0 with 3 empty suites passing. No re-owning to TASK-010 needed. TASK-010 adds the real tests and the D-R1 import-whitelist scan on top of this working harness.

### Simulator inventory delta (device matrix from ADR-008)
- Created for this task: **iPhone SE (3rd generation)** — UDID `1F25E487-A78E-464C-95AF-0BD1A9B3E1BE`, runtime iOS 26.5.
- Pre-existing (untouched, available for TASK-045): iPhone 17 `941BE7AB-0EF6-4C0E-A9D6-59B6780DC7DE`, iPhone 17 Pro Max `C582030E-92FC-4178-920D-3AF570E70F32`, Apple Watch SE 3 (40mm) `F0A75761-CB62-4812-A1C4-8E682A3F02FB`, Apple Watch Series 11 (46mm) `C77D11D9-951A-4DFB-A2ED-CE7844F2AE38`. Apple Watch Ultra 3 (49mm) `2A9AE1A8-9D4F-400F-B3E9-CB6D48BF768F` is also provisioned (part of the default toolchain device set; optional ADR-008 upper bound — left untouched). *(Correction 2026-09-08, REVIEW-TASK-009 NITPICK-1: an earlier revision of this line wrongly said Ultra 3 was not provisioned.)*
- Both used simulators left booted; the pinned runtimes are the iOS 26.5 / watchOS 26.5 pair.

### Files changed by this task
- Created: `Package.swift`; `Sources/MomoCore/MomoCorePlaceholder.swift`; `Sources/MomoCharacter/MomoCharacterPlaceholder.swift`; `Sources/MomoKit/MomoKitPlaceholder.swift`; `Tests/MomoCoreTests/MomoCorePlaceholderTests.swift`; `Tests/MomoKitTests/MomoKitPlaceholderTests.swift`; `Tests/MomoCharacterTests/MomoCharacterPlaceholderTests.swift`; `Apps/Momo/{MomoApp.swift, RootTabView.swift, PlaceholderHomeView.swift, PlaceholderRoomView.swift, PlaceholderSettingsView.swift, Info.plist}`; `Apps/MomoWatch/{MomoWatchApp.swift, PlaceholderGlanceView.swift, Info.plist}`; `Momo.xcodeproj/project.pbxproj`; `Momo.xcodeproj/xcshareddata/xcschemes/{Momo.xcscheme, MomoWatch.xcscheme}`.
- Modified: `.gitignore` (minimal: `.build/`, `DerivedData/`, `xcuserdata/`, `*.xcuserstate`; the committed project is deliberate).

## §28 Handoff

### Completed
- Requirements 1–4 complete: package manifest with the three ADR-005 modules and zero external deps; iOS app with real 3-tab shell + placeholder content; watchOS app with static W1-spirit glance; ADR-008 pins applied exactly; both apps built, installed, launched, screenshotted on pinned simulators; `swift test` green; VERIFY item resolved.

### Files Changed
- See "Files changed by this task" above (all new except `.gitignore`).

### Tests Run
- `xcodebuild … -scheme Momo …` (iPhone SE 3rd gen, iOS 26.5)
- `xcodebuild … -scheme MomoWatch …` (Apple Watch SE 3 40mm, watchOS 26.5)
- `swift test` (macOS host)

### Test Results
- All three exit 0. Builds: BUILD SUCCEEDED both. swift test: `Test run with 0 tests in 3 suites passed after 0.001 seconds.`

### Known Issues
- None blocking. Notes: `/opt/extra/lib` ld warning (host env, benign); XCTest-shim banner reports macos14.0 triple (cosmetic, see nuance above); screenshots are `/tmp`-ephemeral (dims recorded in task file); watch sim state after evidence run is booted.

### Decisions Made
- Hand-authored committed pbxproj (xcodegen absent). Layout: SwiftPM-standard `Sources/`+`Tests/` plus `Apps/Momo`/`Apps/MomoWatch`. Bundle IDs `com.momo.app` / `com.momo.app.watchkitapp`. Standalone watch target honoring D-R3, companion relation via `WKCompanionAppBundleIdentifier` (EPIC-008). tools-version 6.2 (minimum for `.v26` pins). `.macOS(.v26)` platform declared solely for `swift test` hosting.

### Reviewer Status
- pending — REVIEW-TASK-009 required (fresh reviewer per §10/§33; verify module map vs ADR-005/05 §2, zero deps, pins, placeholder scope, genuine evidence).

### Commit
- none by this agent (constraint: no git commits).

### Push
- none (nothing committed).

### Recommended Next Step
- Orchestrator: spawn REVIEW-TASK-009 review agent; on APPROVED, commit `feat(bootstrap): TASK-009 create Swift package and app targets with placeholder shell` on `feature/EPIC-002-foundation`, push, record hash, then dispatch TASK-010 (pet model) which inherits this working `swift test` harness.

## Reviewer Findings
REVIEW-TASK-009 (fresh adversarial reviewer, 2026-09-08): **APPROVED** — 0 MAJOR / 0 MINOR / 3 NITPICK. Record: `.claude/tasks/reviews/REVIEW-TASK-009.md`.

| ID | Disposition | Fix |
|---|---|---|
| NITPICK-1 (Ultra-3 inventory line factually wrong) | FIXED (orchestrator, mechanical) | Simulator-inventory line corrected: Ultra 3 (49mm) is provisioned and untouched; runtime wording clarified. |
| NITPICK-2 (standalone-watch packaging decision lives only in task notes) | ACCEPTED AS FOLLOW-UP | Not a TASK-009 change. Promoting the D-R3 standalone-watch + `WKCompanionAppBundleIdentifier` decision to an ADR is recorded in status.md as due by EPIC-008 start (ADR-009 candidate); the just-in-time TASK-040 task file will carry it. |
| NITPICK-3 (schemes carry no TestAction/ArchiveAction) | ACCEPTED AS NOTED | Informational only — `swift test` is the unit runner (AC-4); scheme-level `xcodebuild test` not required. Already documented in the task file's Known Issues/nuance notes. |

## Completion Evidence
- Commit: (this commit) `feat(bootstrap): TASK-009 create Swift package and app targets with placeholder shell` on `feature/EPIC-002-foundation` — hash recorded in status.md by the orchestrator.
- Push: to origin (recorded in status.md with the push output).
- Review chain: REVIEW-TASK-009 **APPROVED** — reviewer independently re-ran both pinned builds (exit 0), `swift test` (byte-identical pass line), a tools-6.0 downgrade probe (authenticating the 6.2-minimum claim), and its own app launches (fresh PIDs + liveness) and screenshots (exact ADR-008 canvases, vision content matching point for point).
