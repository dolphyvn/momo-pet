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
BLOCKED (Xcode is not installed on the build machine — see Implementation Notes; orchestrator informed 2026-09-08)

## Implementation Notes

### Verdict
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

## Reviewer Findings
- (orchestrator records)

## Completion Evidence
- (commit hash + push, by orchestrator)
