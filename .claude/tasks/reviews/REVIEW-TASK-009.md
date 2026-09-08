# REVIEW-TASK-009 — Local Swift Package + App Targets with Placeholder Shell

- **Task**: TASK-009 (EPIC-002) — `.claude/tasks/active/TASK-009-package-app-targets.md`
- **Deliverables under review**: `Package.swift`; `Sources/{MomoCore,MomoCharacter,MomoKit}`; `Tests/{MomoCoreTests,MomoCharacterTests,MomoKitTests}`; `Apps/{Momo,MomoWatch}`; hand-authored `Momo.xcodeproj`; `.gitignore` additions; task-file Implementation Notes + §28 Handoff
- **Reviewer**: fresh independent adversarial reviewer (did not write the work; CLAUDE.md §10/§33)
- **Date**: 2026-09-08
- **Repo state at review**: branch `feature/EPIC-002-foundation` @ `81be80b` (no commits by the implementation agent); working tree = exactly the task's declared change set (modified: `.gitignore`, task file; untracked: `Package.swift`, `Sources/`, `Tests/`, `Apps/`, `Momo.xcodeproj/`) — re-verified via `git status --porcelain` at review time. No `docs/` or `status.md` edits.

## Review Method (independently re-run — not taken from the task file)

The following were re-executed or independently inspected by this reviewer during the review:

1. **iOS build re-run**: `xcodebuild -project Momo.xcodeproj -scheme Momo -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation),OS=26.5' build` → `** BUILD SUCCEEDED **`, exit 0.
2. **watchOS build re-run**: `xcodebuild -project Momo.xcodeproj -scheme MomoWatch -destination 'platform=watchOS Simulator,name=Apple Watch SE 3 (40mm),OS=26.5' build` → `** BUILD SUCCEEDED **`, exit 0.
3. **`swift test` re-run**: exit 0 with the byte-identical pass line `✔ Test run with 0 tests in 3 suites passed after 0.001 seconds.` (MomoCore/MomoCharacter/MomoKit suites). The log carries the legacy banner `↳ Target Platform: arm64e-apple-macos14.0` (line 9 of `/tmp/review009_swift_test.log`) — matching the task file's characterization: it is the XCTest-shim banner inside the SwiftPM test runner, not a target triple of ours; the manifest pins `.macOS(.v26)` and the toolchain targets `arm64-apple-macosx26.0`. Compile success of the SwiftUI-importing `MomoCharacter` under `swift test` is the hostability proof, and it is real.
4. **tools-version 6.2 claim probed adversarially**: copied `Package.swift` to `/tmp/review009_toolsver/`, downgraded to `// swift-tools-version: 6.0`, ran `swift build` → compile error of the form `'v26' is unavailable in PackageDescription: 'v26' was introduced in PackageDescription 6.2` (for `.iOS(.v26)`). The claim that 6.2 is the **minimum** manifest API exposing the `.v26` pins is authenticated, not asserted.
5. **Independent app launches (my own PIDs, not the recorded ones)**:
   - iPhone: `simctl install` + `simctl launch` on iPhone SE (3rd generation) `1F25E487-A78E-464C-95AF-0BD1A9B3E1BE` → PID 32709; liveness re-check `xcrun simctl spawn … launchctl list | grep momo` → `32709  0  UIKitApplication:com.momo.app[a260][rb-legacy]` (app running, not springboard).
   - Watch: same on Apple Watch SE 3 (40mm) `F0A75761-CB62-4812-A1C4-8E682A3F02FB` → PID 33116; liveness `33116  0  UIKitApplication:com.momo.app.watchkitapp[687c][rb-legacy]`.
   - The recorded PIDs (91593/96043) differ from mine, as they must for genuinely independent launches — a copied-evidence fabrication would have reused them.
6. **Screenshots — dims and content**: my own captures measure **750×1334** px (iPhone) and **324×394** px (Watch) via `sips`, exactly the ADR-008 SE 3 / SE 3 40mm canvases. The implementer's recorded PNGs (`/tmp/momo_task009_iphone_se3_home.png`, `/tmp/momo_task009_watch_se3_glance.png`) exist and re-measure at exactly **750×1334** and **324×394**. Vision-model analysis (inline PNG rendering fails in this environment — the same failure mode the task file honestly documents) of **my own settled captures** returns descriptions that match the task file's recorded vision descriptions point for point:
   - iPhone: app screen (not iOS home/lock screen); floating pill tab bar with **Home** (house, selected/highlighted) / **Room** (door) / **Settings** (gear); large light-gray rounded-rectangle placeholder; caption exactly "Home — placeholder"; "nothing unexpected beyond this minimal scaffold".
   - Watch: app screen (not watch face/home); bold heading exactly "Feeling happy"; static canvas shape; footnote exactly "Wish placeholder"; capsule button exactly "Pat"; "no dynamic imagery, lists, or varied data … beyond this single static placeholder glance".
7. **Capture-timing artifact, disclosed**: my first capture on each simulator caught the launch transition frame (iPhone: blank white screen over the home screen; Watch: transition graphic with no text). Waiting ~2 s and re-capturing produced the settled frames analyzed in item 6. This is a screenshot-timing artifact of any fresh launch, not an implementer defect; the recorded liveness checks and settled vision descriptions are the correct evidence and they check out.
8. **Module map & dependency rules**: read every source file in `Sources/`, `Apps/`, `Tests/`. `Package.swift` declares exactly three products; edges MomoCore → (none), MomoCharacter → MomoCore, MomoKit → MomoCore; **no external `dependencies:` parameter at all** (D-R4/D-R6). `MomoCore` imports Foundation only (D-R1). `.macOS(.v26)` adjudication: grep of `project.pbxproj` finds **no `MACOSX_DEPLOYMENT_TARGET` anywhere**, `SDKROOT` is `iphoneos` (project) / `watchos` (watch target) only, and all products are libraries consumed exclusively by the iOS/watchOS app targets — the macOS platform entry is a host-only affordance for `swift test`, exactly as the task file argues. It does not leak a macOS product or target.
9. **pbxproj structure**: `objectVersion = 56` (line 6); wiring is `XCLocalSwiftPackageReference` (`relativePath = "."`, lines 395–398) + per-target `packageProductDependencies` for MomoCore/MomoCharacter/MomoKit (lines 127–131, 148–152); **both native targets have `dependencies = ()`** (lines 124–125, 145–146) — no `PBXTargetDependency`, no `PBXContainerItemProxy`, no `XCRemoteSwiftPackageReference` anywhere. Pins verified at exact lines: `IPHONEOS_DEPLOYMENT_TARGET = 26.0` (280, 302), `WATCHOS_DEPLOYMENT_TARGET = 26.0` (335, 358), `PRODUCT_BUNDLE_IDENTIFIER` `com.momo.app` (286, 308) / `com.momo.app.watchkitapp` (329, 352), `TARGETED_DEVICE_FAMILY` 1 / 4, `GENERATE_INFOPLIST_FILE = NO` with explicit `INFOPLIST_FILE`, `SWIFT_VERSION = 6.0` in all six build configurations. Shared schemes exist for both targets (`xcshareddata/xcschemes/`), which is why the headless `-scheme` builds in items 1–2 work.
10. **Watch-target shape**: standalone `com.apple.product-type.application` watch target with `WKApplication = true` and `WKCompanionAppBundleIdentifier = com.momo.app` — satisfies D-R3's literal "no target dependency between Momo and MomoWatch" while pre-declaring the EPIC-008 companion relation. Bundle IDs are sanity-checked only (E4 name clearance remains TASK-050's gate, as the brief requires).
11. **Placeholder scope**: `grep -rn "print(" Apps/ Sources/ Tests/` → no matches (re-verified at review time). No persistence, networking, sync, notifications, or HealthKit imports anywhere; app sources import SwiftUI only, `MomoCore`/`MomoKit` Foundation only. The watch glance's "Pat" capsule is inert in source (no action handler), despite the vision model's speculative "implies a tap interaction" — source truth wins, and the W1-spirit static requirement holds.
12. **Simulator inventory & git state re-verified at review time**: `xcrun simctl list devices available` and `git status --porcelain`/`git log` re-run (results in Findings NITPICK-1 and the header above). Both used simulators were found booted, matching the task file's stated end state; this reviewer booted nothing new and deleted nothing — the pinned matrix devices are untouched.
13. Ground truth cross-read: ADR-005 (module map, D-R1–D-R6), ADR-008 (pins + device matrix), 05 §2 (module rules), UX-1 (`03-ux` §2 three tabs Home · Room · Settings), delivery plan §4.2/§9, PRD FR-2.

## Findings

### MAJOR — none.

### MINOR — none.

### NITPICK-1 — "Simulator inventory delta" is inaccurate: Ultra 3 **is** provisioned, and several available devices go unmentioned

`TASK-009-package-app-targets.md:108`: "Ultra 3 (optional row in ADR-008) not provisioned." Re-running `xcrun simctl list devices available` at review time shows `Apple Watch Ultra 3 (49mm) (2A9AE1A8-9D4F-400F-B3E9-CB6D48BF768F) (Shutdown)` — it exists. The section also lists only 4 "pre-existing" devices, while the available set additionally contains iPhone 17 Pro, iPhone 17e, iPhone Air, six iPads, Watch Series 11 (42mm), and Watch SE 3 (44mm). Nothing violates an AC — ADR-008 marks Ultra 3 an *optional* upper bound, and the four named pre-existing devices cited (17, 17 Pro Max, SE 3 40mm, Series 11 46mm) all exist with matching UDIDs — but the delta section states a false provisioning fact (precedent: REVIEW-TASK-008 NITPICK-2's count inaccuracy). **Suggested fix**: one-line correction ("Ultra 3 already provisioned by the default toolchain set; left untouched") when the orchestrator records findings. (Also cosmetic: line 109's "all five runtimes are iOS/watchOS 26.5" reads oddly — there are two runtimes across five named devices.)

### NITPICK-2 — The standalone-watch packaging decision lives only in task notes; promote it to an ADR line by EPIC-008

The D-R3 interpretation (standalone watch target + `WKCompanionAppBundleIdentifier` instead of an embedded watch app) is sound, consistent with every current doc, and well-argued in Implementation Notes (`TASK-009-package-app-targets.md:86`) — but it is a packaging/distribution-shape decision that downstream EPIC-008 sync work and any future App Store packaging will lean on. CLAUDE.md §21 wants meaningful architectural decisions persisted under `.claude/tasks/decisions/`. **Suggested fix**: not for this task's commit — a one-paragraph ADR (or an ADR-005 addendum) recorded when EPIC-008 starts, before the companion/sync design hardens around it.

### NITPICK-3 — Hand-authored schemes carry no TestAction/ArchiveAction

Both `xcscheme` files define only BuildAction/LaunchAction/ProfileAction. Nothing in this task needs more — AC-4 testing runs via `swift test`, and the `-scheme` builds in Review Method items 1–2 prove the schemes work headlessly — and this reviewer did not exercise scheme-level `xcodebuild test`/`archive`. Recorded as informational only: a fresh agent attempting `xcodebuild test -scheme Momo` should be pointed at `swift test` (which the task file already does).

### Verified-benign notes (not findings)

- The recorded `ld: warning: search path '/opt/extra/lib' not found` is host-environment `LIBRARY_PATH` (`:/opt/extra/lib:/opt/extra/lib`, directory absent) — not project-configured, benign, exactly as characterized. It did not recur in this reviewer's cached re-runs (no relink occurred), which corroborates rather than contradicts the record.
- `swift test`'s `arm64e-apple-macos14.0` banner is the XCTest-shim's own compat line, not our targets' — confirmed at line 9 of the reviewer's own log, same shape as recorded.

## Clean dimensions (checked, with the evidence)

- **Module map vs ADR-005 — CLEAN.** Three products, three targets; edges exactly Character→Core, Kit→Core; Core Foundation-only; zero external dependencies (no `dependencies:` parameter exists in the manifest). `.macOS(.v26)` is host-only: no macOS product, no macOS target, no `MACOSX_DEPLOYMENT_TARGET` (Review Method item 8).
- **ADR-008 pins — CLEAN.** 26.0/26.0 exactly, in both Debug and Release (file:line evidence in item 9); `TARGETED_DEVICE_FAMILY` 1/4; `SWIFT_VERSION 6.0` everywhere; bundle IDs recorded and match the built-and-launched apps.
- **Build/launch/test evidence authenticity — CLEAN and strong.** Both `xcodebuild` runs reproduced exit 0; `swift test` reproduced exit 0 with a byte-identical pass line; the tools-6.2-minimum claim survived an adversarial downgrade probe; independent launches produced new PIDs with matching liveness signatures; screenshot dims match ADR-008 canvases on both the recorded PNGs and the reviewer's own captures; vision descriptions match point for point. The task file's honest "Visual confirmation method" note (line 99) describes precisely the workflow this reviewer had to replicate — a good §25 sign, not a weakness.
- **Placeholder scope — CLEAN.** Real 3-tab native `TabView` (UX-1 icons house/door.left.hand.open/gearshape), placeholder content in all three tabs; W1-spirit static glance with an inert Pat capsule; no domain logic, persistence, sync, networking, notifications, or debug prints anywhere; no smuggled features. Placeholder copy strings do not conflict with the momo.line.* localization plan (TASK-011 owns catalogs).
- **Watch-target structure — CLEAN.** Standalone watch app target, no PBXTargetDependency (D-R3 satisfied literally), `WKApplication = true`, companion relation pre-declared for EPIC-008 (NITPICK-2 suggests persisting the decision, not changing it).
- **Project hygiene — CLEAN.** Committed text-diffable pbxproj with shared schemes (verified working headlessly); explicit `GENERATE_INFOPLIST_FILE = NO` with reviewable plists; `.gitignore` additions minimal and correct (`.build/`, `DerivedData/`, `xcuserdata/`, `*.xcuserstate`; the deliberate committing of the project is documented); working tree contains exactly the declared change set; no agent commits (HEAD `81be80b` unchanged); no `docs/`/`status.md` edits; no secrets anywhere in the diff surface.
- **VERIFY item disposition — CLEAN and consumable.** swift-test-hostability RESOLVED in-task with proof, and the handoff tells TASK-010 exactly what it inherits ("adds the real tests and the D-R1 import-whitelist scan on top of this working harness", line 104) — matching delivery plan §9's 009/010 ownership split. Not silently dropped, not over-claimed.
- **§28 Handoff — CLEAN.** All ten sections present and accurate against this reviewer's independent re-runs, including honest Known Issues (the `/opt/extra` note, the banner nuance, `/tmp`-ephemeral screenshots) and a correct Recommended Next Step.
- **Scope/process — CLEAN.** No commit by the agent; scratch artifacts confined to `/tmp` and default DerivedData; both simulators left in the recorded (booted) state; no pinned matrix device created or deleted by this reviewer.

## Acceptance-criteria sweep

- **AC-1 (package with ADR-005 edges, zero external deps) — SATISFIED.** Manifest read in full; edges and zero-dep rule verified; D-R1 holds in `MomoCore` source.
- **AC-2 (both apps build and launch with placeholder shells on pinned sims) — SATISFIED.** Independently re-built, independently launched (new PIDs, liveness proven), screenshotted at exact ADR-008 dims, content vision-confirmed on the reviewer's own captures.
- **AC-3 (deployment targets match ADR-008 exactly) — SATISFIED.** 26.0 / 26.0 in all four app-target build configurations.
- **AC-4 (`swift test` green on macOS; VERIFY item resolved or explicitly re-owned) — SATISFIED.** Exit 0, three empty suites, exact pass line reproduced; VERIFY RESOLVED with a consumable handoff to TASK-010.
- **AC-5 (build-tooling and layout decisions recorded) — SATISFIED.** Hand-authored-pbxproj choice with rationale (xcodegen absent, freshness/diffability argument) and full layout section present in Implementation Notes.

## VERDICT

**APPROVED**

Every substantive claim in the task file survived adversarial re-execution: both pinned-destination builds reproduce exit 0, `swift test` reproduces green with a byte-identical pass line, the tools-6.2-minimum rationale survived a downgrade probe, independent launches produced fresh PIDs with matching liveness, and the reviewer's own screenshots land at exactly the ADR-008 canvases with vision content matching the record point for point. The module map honors ADR-005 with zero external dependencies; the `.macOS(.v26)` entry is proven host-only (no macOS product, target, or `MACOSX_DEPLOYMENT_TARGET` anywhere); the standalone watch target satisfies D-R3 while pre-declaring the EPIC-008 companion relation; placeholder scope is not exceeded anywhere. The three nitpicks are documentation-accuracy and forward-hygiene items (Ultra-3 inventory line is factually wrong; promote the standalone-watch decision to an ADR by EPIC-008; schemes lack TestAction) — none blocks commit, and NITPICK-1's one-line correction can be folded in when the orchestrator records findings. TASK-009 is cleared for commit `feat(bootstrap): TASK-009 create Swift package and app targets with placeholder shell` on `feature/EPIC-002-foundation`, followed by push and the TASK-010 dispatch.

---

## Disposition (orchestrator, 2026-09-08)

Verdict received: **APPROVED** (0 MAJOR / 0 MINOR / 3 NITPICK) — no fix loop required. Findings closed:

| ID | Disposition | Fix |
|---|---|---|
| NITPICK-1 | FIXED (orchestrator, mechanical — per the review's "fold in when recording findings") | Task-file simulator-inventory line corrected: Apple Watch Ultra 3 (49mm) **is** provisioned (default toolchain set, optional ADR-008 upper bound, untouched); "all five runtimes" wording clarified to the iOS 26.5 / watchOS 26.5 pair. Correction is annotated in place. |
| NITPICK-2 | ACCEPTED AS FOLLOW-UP (not a TASK-009 change) | Promoting the standalone-watch packaging decision (D-R3: standalone watch target + `WKCompanionAppBundleIdentifier`) to an ADR is recorded in status.md as due by EPIC-008 start (ADR-009 candidate); the just-in-time TASK-040 task file will carry it. No code or doc change in this commit. |
| NITPICK-3 | ACCEPTED AS NOTED (informational) | Schemes intentionally carry Build/Launch/Profile actions only; `swift test` is the unit runner per AC-4. Already documented in the task file. |

No re-review required (no substantive change since the review — one documentation-line correction). Final: **APPROVED — cleared for commit** `feat(bootstrap): TASK-009 create Swift package and app targets with placeholder shell`.
