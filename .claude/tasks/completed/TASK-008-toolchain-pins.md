# TASK-008 — Verify Toolchain & Pin Deployment Targets (ADR-008)

## Parent Epic
EPIC-002 — Foundation & Build Baseline

## Objective
Resolve TR10 and OPEN-3 before any build work: verify Xcode (and simulator runtimes) are actually available on the build machine, pin the iOS/watchOS minimum deployment targets and the concrete device-matrix device names per ADR-006, and record all of it as **ADR-008** — the first decision record of the build phase.

## Context
ADR-006 deliberately deferred deployment-target pins to EPIC-002 bootstrap ("current shipping OS generation", expected iOS 26 / watchOS 26, VERIFY-AT-BUILD; N-1 re-evaluated at release planning). OPEN-3 bundles: pins, device names, test framework. TR10 (01 §Technical Risks) warns Xcode availability was never verified — status.md lists it as a Known Issue. 05 §12 defines the device-matrix *shape* (small/mid/large iPhone; watch SE-class + flagship) but not device names. This task owns all of it; nothing in EPIC-002+ may start until it lands (delivery plan risk R1). The TASK-007 Intake Obligation's **import-whitelist scan wiring (05 §10.2) is owned by TASK-010** (same epic, later in the batch) — not in scope here.

## Requirements
1. Verify the toolchain and record actual outputs as evidence:
   - `xcodebuild -version` and `xcodebuild -showsdks`
   - `xcrun simctl list runtimes` / `xcrun simctl list devices available` (confirm both iOS and watchOS simulators exist)
   - `swift --version`
   - If Xcode or a watchOS runtime is missing: **STOP** — record BLOCKED in this task file's Implementation Notes and report to the orchestrator (CLAUDE.md §3: no substitution, no silent downgrade; status.md is updated by the orchestrator).
2. Determine the **current shipping OS generation** (verify against Apple's current releases at execution time — do not assume the documents' examples).
3. Pin, and record in ADR-008:
   - Minimum iOS deployment target and minimum watchOS deployment target (current shipping generation, per ADR-006).
   - The iOS↔watchOS pairing rule implied by those pins.
   - Concrete device names for the 05 §12 matrix: small/mid/large iPhone (one must be the smallest supported screen — it governs AC-1a no-scroll) and two watch sizes (smallest supported governs the glyph legibility rule, ADR-001 ear-thickness threshold ~32 pt).
   - The test framework pin (OPEN-3 third item — confirm Swift Testing is available in this toolchain; if not, record XCTest and the reason).
   - Explicit note that N-1 widening is *deferred to TASK-050*, not decided here (ADR-006).
4. Write `.claude/tasks/decisions/ADR-008-bootstrap-pins.md` per the CLAUDE.md §21 template (Status / Context / Decision / Alternatives Considered / Consequences / Date). Status: ACCEPTED (bootstrap facts, not product choices — still record alternatives, e.g., pinning N-1 now).
5. List every 05 Appendix B VERIFY-AT-BUILD item this task resolves (pins, pairing, framework) as resolved, with evidence pointers.

## Files / Areas Likely Affected
- Creates `.claude/tasks/decisions/ADR-008-bootstrap-pins.md`
- Updates this task file (Implementation Notes)
- No code, no project files (TASK-009 consumes the pins)

## Dependencies
- TASK-001…007 complete. None outstanding — this is the root of the build DAG (delivery plan §4.1).

## Constraints
- Jupiter model, fresh agent, no commit by agent (orchestrator commits post-review).
- Documentation-only task: do not create the package or any project file.
- Do not modify `status.md` (orchestrator owns it) or any `docs/` file — pins live in ADR-008, not in the architecture docs.

## Acceptance Criteria
- AC-1: Toolchain verification commands executed with outputs recorded verbatim in this task file (or BLOCKED recorded and the orchestrator informed).
- AC-2: ADR-008 exists per the §21 template and states: iOS pin, watchOS pin, pairing rule, device-matrix names, framework pin, N-1 deferral note.
- AC-3: Every OPEN-3 sub-item (pins / device names / framework) has a recorded decision; every 05 Appendix B item owned by this task is marked resolved.
- AC-4: TR10 is retired — either "verified" or "recorded as project blocker".

## Required Tests
- Not applicable (verification + decision record). Evidence = command outputs in Implementation Notes.

## Review Requirements
- Fresh reviewer verifies: ADR-008 completeness vs OPEN-3/ADR-006; that pins follow "current shipping generation" (not the docs' example numbers) with evidence; device names cover the smallest-screen obligations (AC-1a, glyph legibility); no scope creep (no package created here). Record in `.claude/tasks/reviews/REVIEW-TASK-008.md`.

## Git Requirements
- Branch: `feature/EPIC-002-foundation` (first commit on the branch, cut from `main`).
- Commit: `chore(bootstrap): TASK-008 verify toolchain and record deployment pins (ADR-008)`
- Push to origin after orchestrator commit; record hash in Completion Evidence.

## Status
DONE — verified (REVIEW-TASK-008 CHANGES_REQUIRED → fresh fixer applied all six findings → REVIEW-TASK-008-VERIFY: FIXED — CLEARED FOR COMMIT), committed and pushed 2026-09-08. First attempt's BLOCKED record preserved below.

## Implementation Notes

### Verdict — FIRST ATTEMPT, 2026-09-08 (BLOCKED history — preserved verbatim)
**BLOCKED** — Xcode.app is not installed on this machine; only Command Line Tools exist. The STOP condition in Requirements §1 fired (`xcodebuild` and `simctl` fail). Per CLAUDE.md §25 (no fake completion) no pins were guessed and **ADR-008 was NOT created** — the machine's actual toolchain was declared the source of truth for the pins, and it cannot be verified without Xcode. AC-1 is satisfied via its BLOCKED path (outputs below + orchestrator informed).

### Verbatim command outputs (all executed for real, 2026-09-08)

1. `xcodebuild -version` — **exit 1**
```
xcode-select: error: tool 'xcodebuild' requires Xcode, but active developer directory '/Library/Developer/CommandLineTools' is a command line tools instance
```

2. `xcodebuild -showsdks` — **exit 1**
```
xcode-select: error: tool 'xcodebuild' requires Xcode, but active developer directory '/Library/Developer/CommandLineTools' is a command line tools instance
```

3. `xcrun simctl list runtimes` — **exit 72**
```
xcrun: error: unable to find utility "simctl", not a developer tool or in PATH
```

4. `xcrun simctl list devices available` — **exit 72**
```
xcrun: error: unable to find utility "simctl", not a developer tool or in PATH
```

5. `swift --version` — **exit 0** (works: Command Line Tools provides the Swift compiler, but no iOS/watchOS SDK or simulator)
```
swift-driver version: 1.148.6 Apple Swift version 6.3.3 (swiftlang-6.3.3.1.3 clang-2100.1.1.101)
Target: arm64-apple-macosx26.0
```

### Supporting evidence gathered before declaring BLOCKED
- `xcode-select -p` → `/Library/Developer/CommandLineTools`
- `ls -d /Applications/Xcode*.app` → `no matches found`
- `mdfind "kMDItemCFBundleIdentifier == 'com.apple.dt.Xcode'"` → no results (no Xcode bundle anywhere indexed)
- Direct listing of `/Applications/` and `~/Applications/` → no Xcode.app present (full app list otherwise normal: Safari, Keynote, Slack, etc.)

### State of the acceptance criteria
- **AC-1** — SATISFIED via BLOCKED path: commands executed, outputs recorded verbatim above, orchestrator informed.
- **AC-2** — NOT met (ADR-008 not written). Creating it without Xcode evidence would require guessing SDK/pin numbers — forbidden by this task ("do not guess newer versions you cannot see evidence for") and CLAUDE.md §25.
- **AC-3** — NOT met: none of the 05 Appendix B VERIFY-AT-BUILD items owned by this task (pins / pairing / device names / framework) are resolved. They remain VERIFY-AT-BUILD and now also depend on the unblock below.
- **AC-4** — SATISFIED via second path: **TR10 is confirmed real and is recorded as a project blocker** (Xcode availability was warned about in 01 §Technical Risks and status.md Known Issues; this task verified the warning is accurate).

### Unblock path (for the orchestrator; none of this was executed — requires human/admin)
1. Install Xcode (App Store or developer.apple.com). Evidence above (Swift 6.3.3, `macosx26.0` target) indicates the installed CLT is current-generation, so the matching Xcode 26.x release is expected to be the current shipping generation — but the exact iOS/watchOS SDK versions must be read from `xcodebuild -version` / `-showsdks` after install, never assumed.
2. `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` (root required — not attempted by this agent).
3. Launch Xcode once, then install the iOS and watchOS simulator runtimes (Settings → Components) and re-verify with `xcrun simctl list runtimes` / `list devices available`.
4. Re-run TASK-008 (fresh agent): all four evidence commands, then the pins + ADR-008 per the unchanged Requirements.

### Risks / observations for the orchestrator
- The whole of EPIC-002's build DAG is gated on this (delivery plan §4.1 / §7 R1) — no package or project work (TASK-009+) can start until the unblock path completes and TASK-008 re-runs.
- Xcode install is ~multi-GB plus simulator runtimes; scheduling it before the next build session avoids idle agent time.
- Nothing else was touched: no commit made, branch `feature/EPIC-002-foundation` (at `1746a98`), `status.md` and `docs/` left to the orchestrator, no package/project files created (TASK-009 scope intact).

### Successful run (2026-09-08, fresh agent)

After the orchestrator's unblock (Xcode installed, license accepted, iOS/watchOS runtimes downloaded — per its observation, NOT taken on faith), this agent re-ran every verification command for real and recorded its own outputs. All evidence below is verbatim from this session.

#### Verbatim command outputs

1. `xcodebuild -version` — **exit 0**
```
Xcode 26.6
Build version 17F113
```

2. `xcodebuild -showsdks` — **exit 0**
```
DriverKit SDKs:
	DriverKit 25.5                	-sdk driverkit25.5

iOS SDKs:
	iOS 26.5                      	-sdk iphoneos26.5

iOS Simulator SDKs:
	Simulator - iOS 26.5          	-sdk iphonesimulator26.5

macOS SDKs:
	macOS 26.5                    	-sdk macosx26.5
	macOS 26.5                    	-sdk macosx26.5

tvOS SDKs:
	tvOS 26.5                     	-sdk appletvos26.5

tvOS Simulator SDKs:
	Simulator - tvOS 26.5         	-sdk appletvsimulator26.5

visionOS SDKs:
	visionOS 26.5                 	-sdk xros26.5

visionOS Simulator SDKs:
	Simulator - visionOS 26.5     	-sdk xrsimulator26.5

watchOS SDKs:
	watchOS 26.5                  	-sdk watchos26.5

watchOS Simulator SDKs:
	Simulator - watchOS 26.5      	-sdk watchsimulator26.5
```

3. `xcrun simctl list runtimes` — **exit 0** (BOTH iOS and watchOS runtimes present)
```
== Runtimes ==
iOS 26.5 (26.5 - 23F77) - com.apple.CoreSimulator.SimRuntime.iOS-26-5
watchOS 26.5 (26.5 - 23T570) - com.apple.CoreSimulator.SimRuntime.watchOS-26-5
```

4. `xcrun simctl list devices available` — **exit 0** (concrete iOS AND watchOS devices exist)
```
== Devices ==
-- iOS 26.5 --
    iPhone 17 Pro (8E57D4E0-FAA2-499F-8FC6-E0B50AE855BA) (Shutdown)
    iPhone 17 Pro Max (C582030E-92FC-4178-920D-3AF570E70F32) (Shutdown)
    iPhone 17e (75B994B1-AB90-4179-AE12-FC1A659B5C1E) (Shutdown)
    iPhone Air (57607CCD-BC9C-4390-8120-4BF22EF04E5E) (Shutdown)
    iPhone 17 (941BE7AB-0EF6-4C0E-A9D6-59B6780DC7DE) (Shutdown)
    iPad Pro 13-inch (M5) (E9D6BA60-C581-49C7-89BA-C55C0E4F0627) (Shutdown)
    iPad Pro 11-inch (M5) (6F7B6FA9-4589-41F8-A4D1-6A69612FE54E) (Shutdown)
    iPad mini (A17 Pro) (E5393F06-855F-4A63-B65A-B56026A690BB) (Shutdown)
    iPad Air 13-inch (M4) (63178E87-14E0-436E-BCEF-32AA3745DE19) (Shutdown)
    iPad Air 11-inch (M4) (B651EA71-5AA2-485E-A93C-C15A10CBD8D9) (Shutdown)
    iPad (A16) (36105395-E183-413E-A8E1-1CE4EF5088E0) (Shutdown)
-- watchOS 26.5 --
    Apple Watch Series 11 (46mm) (C77D11D9-951A-4DFB-A2ED-CE7844F2AE38) (Shutdown)
    Apple Watch Series 11 (42mm) (EB5715E3-E528-4139-B768-2898AF583EC5) (Shutdown)
    Apple Watch Ultra 3 (49mm) (2A9AE1A8-9D4F-400F-B3E9-CB6D48BF768F) (Shutdown)
    Apple Watch SE 3 (44mm) (8A854895-225C-411B-89C1-B03337BFE957) (Shutdown)
    Apple Watch SE 3 (40mm) (F0A75761-CB62-4812-A1C4-8E682A3F02FB) (Shutdown)
```

5. `swift --version` — **exit 0** (identical Swift version to the first attempt's CLT output — same Swift ships in Xcode 26.6; it now resolves through Xcode, see supporting evidence 6b)
```
swift-driver version: 1.148.6 Apple Swift version 6.3.3 (swiftlang-6.3.3.1.3 clang-2100.1.1.101)
Target: arm64-apple-macosx26.0
```

6. `xcodebuild -checkFirstLaunchStatus` — **exit 0, no output** (meaning: first launch complete, no pending dialog/license prompt)

#### Supporting evidence

- 6a. `xcode-select -p` — **exit 0**: `/Applications/Xcode.app/Contents/Developer` (resolves the first attempt's root cause, which had `/Library/Developer/CommandLineTools` active).
- 6b. `xcrun --find swift` — **exit 0**: `/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift`
- 6c. **Swift Testing availability probe** — scratch SwiftPM package at `/tmp/swift-testing-probe` (OUTSIDE the repo; no repo project files created — TASK-009 scope intact) with one test file containing `import Testing` and `#expect(true)`; `swift test --list-tests` — **exit 0**, key verbatim lines:
```
[8/11] Compiling ProbeTests ProbeTests.swift
/private/tmp/swift-testing-probe/Tests/ProbeTests/ProbeTests.swift:5:13: note: '#expect(_:_:)' will always pass here; use 'Bool(true)' to silence this warning (from macro 'expect')
Build complete! (5.10s)
ProbeTests.swiftTestingFrameworkIsAvailable()
```
(The `#expect` macro-expansion note + listed test prove `import Testing` compiles and runs under this toolchain.) A companion search `find …/iPhoneSimulator26.5.sdk -maxdepth 3 -iname "*Testing*"` returned **no output, exit 0** — Testing ships inside the toolchain rather than as a top-level SDK framework dir at that depth; the positive host run above is the evidence, and in-target wiring is re-confirmed by TASK-009/010 per delivery-plan §9 ownership.
- 6d. **Device-size probe** — booted the six candidate matrix simulators by UDID, captured a full-screen screenshot from each (`xcrun simctl io <udid> screenshot`), read dimensions with `sips` (verbatim), then shut each down cleanly:
```
/private/tmp/momo-device-probe/iPhone-17-Pro-Max.png
  pixelWidth: 1320
  pixelHeight: 2868
/private/tmp/momo-device-probe/iPhone-17.png
  pixelWidth: 1206
  pixelHeight: 2622
/private/tmp/momo-device-probe/iPhone-17e.png
  pixelWidth: 1170
  pixelHeight: 2532
/private/tmp/momo-device-probe/Watch-SE-3-40mm.png
  pixelWidth: 324
  pixelHeight: 394
/private/tmp/momo-device-probe/Watch-Series-11-46mm.png
  pixelWidth: 416
  pixelHeight: 496
/private/tmp/momo-device-probe/Watch-Ultra-3-49mm.png
  pixelWidth: 422
  pixelHeight: 514
```

#### Chosen pins (each with one-line evidence)

| Pin | Value | Evidence |
|---|---|---|
| Minimum iOS deployment target | **iOS 26.0** | Shipping generation visible to the toolchain is 26 (iOS 26.5 SDK in Xcode 26.6, evidence 1–2); pinned at the generation floor per ADR-006 |
| Minimum watchOS deployment target | **watchOS 26.0** | watchOS 26.5 SDK + 26.5 runtime (evidence 2–3); generation floor per ADR-006 |
| Build SDKs (consumed by TASK-009) | iOS 26.5 / watchOS 26.5 | `xcodebuild -showsdks` (evidence 2) |
| iOS↔watchOS pairing rule | Both floors ≥ 26.0 — the current-generation floor (26): iPhone ≥ 26.0 + Watch ≥ 26.0 (within Phase 1 every supported pair is same-generation); no generation-25 support in Phase 1; formal matrix re-checked only if N-1 widening approved at TASK-050 | Pins above + ADR-006's pairing-matrix gate |
| Device matrix — iPhone small (governs FR-2 AC-1a no-scroll) | **iPhone SE (3rd generation)** | Smallest device the pinned iOS 26.5 runtime runs: 750×1334 px (375×667 pt) — created explicitly via `simctl create` (SE-class devices are absent from the default device list); fix-pass probe below. 05 §12's "expected 4.7\" SE-class" expectation confirmed |
| Device matrix — iPhone mid | **iPhone 17** | 1206×2622 px (evidence 4 + 6d) |
| Device matrix — iPhone large/flagship | **iPhone 17 Pro Max** | 1320×2868 px (evidence 4 + 6d) |
| Device matrix — Watch small (governs ADR-001 ~32 pt glyph rule) | **Apple Watch SE 3 (40mm)** | Smallest visible watch: 324×394 px (evidence 4 + 6d) |
| Device matrix — Watch flagship | **Apple Watch Series 11 (46mm)** | 416×496 px (evidence 4 + 6d); Ultra 3 (49mm, 422×514 px) noted as largest observed |
| Test framework | **Swift Testing** (unit/property tests); XCUITest (XCTest-based) for UI automation per 05 §10.6 | Probe 6c compiled and ran `import Testing`/`#expect` in this toolchain |
| N-1 widening | **DEFERRED to TASK-050** (not decided here) | ADR-006 policy; delivery plan §7 R4 / §8.3 |

Physical screen diagonals are deliberately not asserted (CLAUDE.md §25 — no memory-based hardware claims); the 05 §12 budgets are measured on the named smallest devices at TASK-045 regardless.

#### 05 Appendix B (VERIFY-AT-BUILD register) — items resolved by this task

1. **OPEN-3** (pins / device names / framework) — **RESOLVED**: ADR-008 Decisions 1–5 (evidence 1–4, 6c, 6d).
2. Consolidated VERIFY item "**deployment-target versions and iOS↔watchOS pairing rules** (§2.4)" — **RESOLVED**: ADR-008 Decisions 1–3 (evidence 1–3).
3. Consolidated VERIFY item "**device-matrix composition** (§12)" — **RESOLVED**: ADR-008 Decision 4 (evidence 4 + 6d + fix-pass probe below). §12's "expected 4.7\" SE-class" expectation is confirmed by recorded evidence (smallest = iPhone SE (3rd generation), 750×1334 px / 375×667 pt).
4. 05 §10 "Framework: **Swift Testing** (current-native — VERIFY-AT-BUILD)" — **framework side RESOLVED**: ADR-008 Decision 5 (evidence 6c). In-target wiring remains TASK-009/010 (delivery plan §9 ownership — not this task's scope).

Explicitly NOT resolved here (owners unchanged, delivery plan §9): `swift test` hostability of the package targets (009/010); Swift `Clock` idioms (014); export tooling (025); WC behaviors + background capability (040/044); watchOS memory norms (045); required-reason APIs (048); Phase-2 items (§7–§9).

#### State of the acceptance criteria (this run)

- **AC-1** — SATISFIED: all verification commands executed; outputs recorded verbatim above.
- **AC-2** — SATISFIED: ADR-008 written (`.claude/tasks/decisions/ADR-008-bootstrap-pins.md`, ACCEPTED) stating iOS pin, watchOS pin, pairing rule, device-matrix names, framework pin, N-1 deferral note.
- **AC-3** — SATISFIED: every OPEN-3 sub-item has a recorded decision (table above); every 05 Appendix B item owned by this task is marked resolved with evidence pointers.
- **AC-4** — SATISFIED: **TR10 retired as VERIFIED** (Xcode 26.6 present, first launch complete, both runtimes + concrete devices). Delivery-plan risk R1 mitigated. Orchestrator action pending (this agent must not touch those files): update status.md Known Issues / TR10 and 01 §Technical Risks if its format requires it.

#### Handoff (CLAUDE.md §28)

- **Completed**: toolchain verified end-to-end; pins + pairing rule + device matrix + framework pinned; ADR-008 created; this task file updated (BLOCKED history preserved).
- **Files Changed**: `.claude/tasks/decisions/ADR-008-bootstrap-pins.md` (new); `.claude/tasks/active/TASK-008-toolchain-pins.md` (this file). Nothing else.
- **Tests Run**: verification commands 1–6 + supporting probes 6a–6d (verification task — these are the evidence, per Required Tests "Not applicable").
- **Test Results**: all exit 0; all six candidate simulators booted, screenshotted, shut down cleanly.
- **Known Issues**: none blocking. Swift Testing in-target wiring re-confirmed at TASK-009/010. Scratch probes live in `/tmp` (outside the repo, ephemeral).
- **Decisions Made**: generation-floor pins (26.0/26.0) over point-release pins (26.5); Series 11 (46mm) as watch flagship (Ultra 3 recorded as alternative); Swift Testing over XCTest (evidence-backed). All recorded in ADR-008 Alternatives. Fix pass (2026-09-08): iPhone-small re-pinned to **iPhone SE (3rd generation)** — the smallest device the pinned iOS 26 generation actually runs (reviewer MAJOR-1; fixer probes recorded in the Fix pass subsection); "current-generation hardware only" recorded in ADR-008 Alternatives as a rejected alternative / available owner lever, not taken (§36).
- **Reviewer Status**: REVIEW-TASK-008 **CHANGES_REQUIRED** → fix pass applied (2026-09-08, fresh fixer agent; disposition recorded under Reviewer Findings) → awaiting fresh verifier (CLAUDE.md §11).
- **Commit**: none by this agent (orchestrator commits post-review) — suggested message per Git Requirements.
- **Push**: none by this agent.
- **Recommended Next Step**: orchestrator spawns REVIEW-TASK-008; on approval, commit `chore(bootstrap): TASK-008 verify toolchain and record deployment pins (ADR-008)` on `feature/EPIC-002-foundation` (branch at `80a859a` at execution time), push, update status.md (TR10/R1), then unblock TASK-009.

#### Fix pass (2026-09-08, fresh fixer agent)

REVIEW-TASK-008 returned **CHANGES_REQUIRED** (1 MAJOR / 2 MINOR / 3 NITPICK). The reviewer authenticated this task's evidence byte-for-byte, but refuted one inference: ADR-008 had claimed the iPhone 17e "supersedes" 05 §12's "expected 4.7\" SE-class" smallest-iPhone expectation, reasoning from the default auto-created simulator list — a list that contains only current-generation devices. The reviewer booted an iPhone SE (3rd generation) on the pinned iOS 26.5 runtime at 750×1334 px (375×667 pt), smaller than the 17e's 390×844 pt, proving the SE class DOES run the pinned generation: 05 §12's expectation was right, and the smallest-supported-device pin was wrong. Per the orchestrator's ruling, the fix is the reviewer's option 1 — re-pin iPhone-small to iPhone SE (3rd generation); option 2 (support current-generation hardware only) is a product-scope decision reserved to the owner (CLAUDE.md §36) and is recorded in ADR-008 Alternatives as a rejected alternative / available owner lever, not taken. Min iOS stays 26.0 either way. The fix record below carries this fixer's own probes (CLAUDE.md §25 — the fix is evidenced by fresh evidence, not the reviewer's).

**Fix-pass probes (executed by this fixer, 2026-09-08; device-type IDs first confirmed against the toolchain).**

Device-type IDs confirmed present (trimmed list — verbatim head/middle lines, ellipses mark elided rows):
```
$ xcrun simctl list devicetypes | grep -iE "iPhone SE|Watch SE"
iPhone SE (3rd generation) (com.apple.CoreSimulator.SimDeviceType.iPhone-SE-3rd-generation)
iPhone SE (2nd generation) (com.apple.CoreSimulator.SimDeviceType.iPhone-SE--2nd-generation-)
...
Apple Watch SE (40mm) (2nd generation) (com.apple.CoreSimulator.SimDeviceType.Apple-Watch-SE-40mm-2nd-generation)
...
```

Probe 1 — iPhone SE (3rd generation) on the pinned iOS 26.5 runtime:
```
$ xcrun simctl create "MomoFixProbe-SE3" "com.apple.CoreSimulator.SimDeviceType.iPhone-SE-3rd-generation" "com.apple.CoreSimulator.SimRuntime.iOS-26-5"
E6DE6F93-9A00-42BC-B44E-150A858EA20A
```
```
$ xcrun simctl boot E6DE6F93-9A00-42BC-B44E-150A858EA20A && xcrun simctl bootstatus E6DE6F93-9A00-42BC-B44E-150A858EA20A
(exit 0; boot/migration progress log elided — terminal line verbatim:)
[2026-09-08 17:14:27 +0000] Status=4294967295, isTerminal=YES, Elapsed=00:46.
	Finished
```
```
$ xcrun simctl io E6DE6F93-9A00-42BC-B44E-150A858EA20A screenshot /tmp/momo-fixprobe-se3.png && sips -g pixelWidth -g pixelHeight /tmp/momo-fixprobe-se3.png
Detected file type from extension: PNG
Note: No display specified. Defaulting to display: 33689263-9E4A-4BDA-9A8C-5EE53D546BE0 (screenID: 1, name: LCD)
Wrote screenshot to: /tmp/momo-fixprobe-se3.png
/private/tmp/momo-fixprobe-se3.png
  pixelWidth: 750
  pixelHeight: 1334
```
→ **750×1334 px = 375×667 pt @2x** — matches the reviewer's measurement exactly; materially smaller than the 17e's 1170×2532 px (390×844 pt).
```
$ xcrun simctl shutdown E6DE6F93-9A00-42BC-B44E-150A858EA20A && xcrun simctl delete E6DE6F93-9A00-42BC-B44E-150A858EA20A
(exit 0, no output)
```

Probe 2 — Apple Watch SE (2nd generation) 40mm on the pinned watchOS 26.5 runtime:
```
$ xcrun simctl create "MomoFixProbe-WatchSE2" "com.apple.CoreSimulator.SimDeviceType.Apple-Watch-SE-40mm-2nd-generation" "com.apple.CoreSimulator.SimRuntime.watchOS-26-5"
B1143552-70D9-444E-B251-46F19396DA21
```
```
$ xcrun simctl boot B1143552-70D9-444E-B251-46F19396DA21 && xcrun simctl bootstatus B1143552-70D9-444E-B251-46F19396DA21
(exit 0; boot log elided — terminal line verbatim: "	Finished")
```
```
$ xcrun simctl io B1143552-70D9-444E-B251-46F19396DA21 screenshot /tmp/momo-fixprobe-watchse2.png && sips -g pixelWidth -g pixelHeight /tmp/momo-fixprobe-watchse2.png
Detected file type from extension: PNG
Note: No display specified. Defaulting to display: A9FA7FA8-0EED-499F-BF84-FECDC5F5575E (screenID: 1, name: LCD)
Wrote screenshot to: /tmp/momo-fixprobe-watchse2.png
/private/tmp/momo-fixprobe-watchse2.png
  pixelWidth: 324
  pixelHeight: 394
```
→ **324×394 px** — pixel-identical to Apple Watch SE 3 (40mm); the ADR-001 ~32 pt glyph geometry is stable across the supported SE-class watches.
```
$ xcrun simctl shutdown B1143552-70D9-444E-B251-46F19396DA21 && xcrun simctl delete B1143552-70D9-444E-B251-46F19396DA21
(exit 0, no output)
$ xcrun simctl list devices | grep -c "MomoFixProbe"
0
```
→ both probe devices deleted and verified absent (`grep -c` → 0).

**Edits made in this fix pass:**
- ADR-008 Status — "supersedes 05 §12's SE-class expectation" replaced: the expectation is **confirmed**; smallest supported device = iPhone SE (3rd generation).
- ADR-008 Decision 3 — pairing label reworded (NITPICK-1): "both floors ≥ 26.0, the current-generation floor (generation 26)"; TASK-050 formal-matrix gate sentence kept.
- ADR-008 Decision 4 — header evidence-source corrected (default list ≠ supported set); iPhone-small bullet → iPhone SE (3rd generation) 750×1334 px (375×667 pt); watch-small bullet gains the SE (2nd generation) 324×394 stability sentence; trailing paragraph's "superseded" claim → confirmation plus root-cause note (default simulator list vs supported-device set).
- ADR-008 Decision 6 — TASK-007→TASK-050 cross-reference note added (MINOR-2).
- ADR-008 Alternatives Considered — "Support current-generation hardware only" added as rejected (owner product-scope decision, §36; would loosen AC-1a/§12 obligations; preserved as an owner lever, not taken).
- ADR-008 Consequences — "five named matrix devices (3 iPhone + 2 Watch)" with Ultra 3 as optional upper bound (NITPICK-2); AC-1a check and §12/TASK-045 measurement referents → iPhone SE (3rd generation).
- This task file — pin-table pairing row and iPhone-small row aligned with the above; Appendix B item 3 corrected (smallest = iPhone SE (3rd generation)); this fix-pass subsection appended; Reviewer Findings disposition recorded below; Handoff Decisions Made / Reviewer Status updated.
- Verified in place, not edited further (orchestrator-owned fixes): MINOR-1 — ADR-006 Status reconciled to ACCEPTED with REVIEW-TASK-006 pointer; NITPICK-3 — `.gitignore` created (`.DS_Store` entry) and `.DS_Store` removed from the repo root.

## Reviewer Findings

REVIEW-TASK-008 (2026-09-08, fresh adversarial reviewer): **CHANGES_REQUIRED** — 1 MAJOR (iPhone-small pin: the "supersedes 4.7\" SE-class" claim refuted by the toolchain — iPhone SE (3rd generation) boots the pinned iOS 26.5 runtime at 750×1334 px / 375×667 pt, smaller than the 17e's 390×844 pt) / 2 MINOR (stale ADR-006 status; silent TASK-007→TASK-050 correction) / 3 NITPICKS (pairing wording; "six named devices"; untracked `.DS_Store`). Evidence authenticity was verified and is not in dispute. Full record: `.claude/tasks/reviews/REVIEW-TASK-008.md`.

Disposition (fix pass 2026-09-08, fresh fixer agent — per the orchestrator's rulings):

| Finding | Disposition |
|---|---|
| MAJOR-1 — iPhone-small mis-pinned (iPhone 17e) | **FIXED** — re-pinned to iPhone SE (3rd generation), the reviewer's fix option 1, per orchestrator ruling; this fixer's own probes reproduce 750×1334 px (375×667 pt) iPhone-side and 324×394 px watch-side (see Fix pass above). Option 2 (current-generation-hardware-only) recorded in ADR-008 Alternatives as a rejected owner lever (§36), not taken. Min iOS remains 26.0. |
| MINOR-1 — ADR-006 Status stale (PROPOSED) | **FIXED (orchestrator)** — ADR-006 Status reconciled to ACCEPTED with REVIEW-TASK-006 pointer; verified in place during this fix pass; file not edited further by the fixer. |
| MINOR-2 — silent TASK-007→TASK-050 correction | **FIXED** — one-line note added to ADR-008 Decision 6 (ADR-006 / 05 §2.4 say "TASK-007" — pre-delivery-plan numbering; the backlog of record, delivery plan §3 EPIC-009 / §7 R13, owns the re-evaluation as TASK-050). |
| NITPICK-1 — pairing wording vs the ≥ formulation | **FIXED** — ADR-008 Decision 3 and the pin-table pairing row now read "both floors ≥ 26.0 — the current-generation floor (26)"; the TASK-050 formal-matrix gate sentence kept. |
| NITPICK-2 — "six named devices" | **FIXED** — ADR-008 Consequences now name the **five matrix devices (3 iPhone + 2 Watch)**; Ultra 3 explicitly the optional upper bound. |
| NITPICK-3 — untracked `.DS_Store` at repo root | **FIXED (orchestrator)** — `.gitignore` created with the `.DS_Store` entry; `.DS_Store` removed from the repo root; verified during this fix pass. |

Status remains IN_PROGRESS pending the fresh verifier (CLAUDE.md §11 review/fix loop).

## Completion Evidence
- Commit: (this commit) `chore(bootstrap): TASK-008 verify toolchain and record deployment pins (ADR-008)` on `feature/EPIC-002-foundation` — hash recorded in status.md by the orchestrator.
- Push: to origin (recorded in status.md with the push output).
- Review chain: REVIEW-TASK-008 (CHANGES_REQUIRED, 1 MAJOR / 2 MINOR / 3 NITPICK) → fresh fixer pass with own §25 probes (750×1334 / 324×394) → REVIEW-TASK-008-VERIFY (FIXED — CLEARED FOR COMMIT; third independent probe pair agrees). Disposition recorded in REVIEW-TASK-008.md.
