# TASK-045 — Performance budget verification (05 §12; NFR-1/2/3/4/9)

## Parent Epic

EPIC-009 — Polish, QA & Release Readiness (`.claude/tasks/epics/EPIC-009-release-readiness.md`). Branch: `feature/EPIC-009-release-readiness`.

## Objective

Measure — never assume (project.md §33) — every budget row of 05 §12 on the pinned device matrix, record the raw evidence in this task file and `.claude/tasks/evidence/TASK-045/`, and resolve every environment-limited row honestly per CLAUDE.md §25. **A budget miss is a task-level blocker, not a note** (06 §3 TASK-045 row): a miss stops the measurement phase and triggers the fix loop.

## Context

- **Baseline (merged `main` @ `244b7ea`, post-EPIC-008):** `swift test` 1161/113 green (re-verified on the merged state before the §14 push); MomoKit coverage 90.84 % lines; both app builds BUILD SUCCEEDED on pinned sims; `MomoWatchUITests` 9/9 (includes the restore-within-budget timing test from TASK-041); app UI suite 35/35; frozen surfaces diff-EMPTY.
- **Normative budget source (verbatim authority):** 05 §12 — cold launch ≤ 2.0 s (NFR-1, smallest supported device; the synchronous KB-scale store read is the only sanctioned launch I/O); sustained 60 fps, ≤ 8 ms/frame CPU+GPU on 60 Hz devices, no sustained stutter (transform-only rig 04 §7.4 is the structural guarantee); iPhone ≤ 150 MB steady-state Home idle (provisional, NFR-3); Watch ≤ 80 MB foreground (provisional, VERIFY-AT-BUILD against current watchOS norms); download ≤ 60 MB (NFR-4) + art ≤ 1.5 MB (04 §8.3); energy gauge Low over 10-min idle both devices (NFR-2; no background work beyond WC delivery); Watch energy (no standing timers, AOD static glyph, next-event timers only, WC coalesced); Watch snapshot restore ≤ ~2 s raise-to-glance; play round ≤ 30 s (FR-7/04 §6.3); sync cadence on-change only (context pushes a handful/day steady state; intent sends on pat only).
- **Pinned device matrix (simulator identities verified 2026-09-12 via `xcrun simctl list devices available`):**
  - iPhone SE (3rd generation) `1F25E487-A78E-464C-95AF-0BD1A9B3E1BE` — the "smallest supported" iPhone (4.7"); ALL primary budget legs run here (§12: "the §12 launch/energy budgets are measured on the smallest devices").
  - iPhone 17 Pro `8E57D4E0-FAA2-499F-8FC6-E0B50AE855BA` — the flagship leg (launch + memory; the mid-tier role is covered by recording both ends).
  - Apple Watch SE 3 (40mm) `F0A75761-CB62-4812-A1C4-8E682A3F02FB` — the §12 "SE-class, smallest case" Watch; primary Watch budget legs.
  - Apple Watch SE 3 (44mm) `8A854895-225C-411B-89C1-B03337BFE957` — the standing build/UI-test baseline (watchOS 26.5, build 23T570); keep for the §19 gates.
  - Apple Watch Series 11 (42mm) `EB5715E3-E528-4139-B768-2898AF583EC5` — the flagship Watch leg (memory).
- **§25 environment reality:** NO paired physical Watch; exactly ONE physical device, iPhone-class (raw capture: `xctrace list devices`, recorded at TASK-044 R5). Legs that require physical hardware — energy-gauge sessions, sustained-fps device traces, thermal — are attempted-then-BLOCKED-recorded (re-run `xctrace list devices`, paste raw output, record what was attempted) and routed to the owner device-pass backlog. NEVER present a simulator number as a device number; label every row's measurement surface explicitly.
- **Prior art to reuse (do not duplicate):** ADR-008 (device matrix + deployment targets, TASK-008); TASK-030's art-budget re-measure method (exact byte counts via the generated-assets bucket); TASK-041's `MomoWatchUITests` restore-within-budget test (the §12 Watch-restore row's verifier); TASK-040 R4's zero-background-requirements WC record; the standing zero-timers structural scans (§4.2 law, guard-enforced); 05 §12's note that EPIC-002 was to establish these budgets — they were NOT device-measured then (no hardware); this task is the honest re-measure.
- **Schemes/commands (standing):** `swift test`; `xcodebuild -scheme Momo -destination 'id=1F25E487-…' build`; `xcodebuild -scheme MomoWatch -destination 'id=8A854895-…' build`; UI counts via `xcrun xcresulttool get test-results summary --path <newest DerivedData/Momo-*/Logs/Test/*.xcresult>`.

## Requirements

- **R1 — Cold launch ≤ 2.0 s.** Measure app-cold launch to interactive Home on iPhone SE 3rd gen (primary) and iPhone 17 Pro (flagship leg). Use `xcodebuild test` with a launch-metrics measure block (XCTest `XCTApplicationLaunchMetric`) or the documented equivalent; ≥ 5 runs each, record per-run values + median; state the harness command, the sim identity, and what "interactive Home" was pinned to (first static content draw). Record raw numbers — no rounding up.
- **R2 — Animation smoothness.** Device legs (sustained 60 fps; ≤ 8 ms/frame) → §25 BLOCKED records (attempt + raw capture + owner routing). Sim-side honest evidence: run an Instruments (`xctrace record`) trace over Home idle + one play round on the pinned sims; record the template, duration, and a summary of frame/hitch counters IF the template yields them in sim (h honestly labeled sim-surface), and cite the structural guarantee (transform-only rig, 04 §7.4; the LOD tiers; zero timers) as the primary mechanism. No invented fps numbers.
- **R3 — iPhone memory ≤ 150 MB steady-state Home idle (provisional).** Footprint soak on iPhone SE 3rd gen + iPhone 17 Pro: launch → settle → idle window → scripted Home interactions (pat, feed, play, tab switches) → return to idle → sample. Record peak and steady-state with the tool used (Instruments Allocations/footprint, or `simctl spawn … footprint` if available — label the method). Provisional-budget note: the 150 MB row is NFR-3-provisional; a miss is still a blocker; a large pass margin is recorded as-is.
- **R4 — Watch memory ≤ 80 MB foreground (VERIFY-AT-BUILD).** Same method on Watch SE 3 40mm + Series 11 42mm. The VERIFY-AT-BUILD resolution: measure, then adjudicate AGAINST current watchOS 26.5 norms in the record (what a bare watchOS app + SwiftUI overhead looks like on the same sim — measure a trivial comparator if useful) — but the 80 MB row in 05 §12 stays normative and unedited; record the comparator as context, the measured value as the verdict.
- **R5 — Download size ≤ 60 MB; art ≤ 1.5 MB.** Build an archive or use build products to record each app's installed/download size (state exactly which: `.app` bundle size, or archive export report — label it; App Store thinning deltas recorded as n/a-sim if unreachable). Art: re-measure the MomoCharacter generated buckets with the TASK-030 method (exact bytes) and confirm ≤ 1.5 MB total art contribution.
- **R6 — Energy rows (both devices).** Device legs → §25 BLOCKED (attempt + raw capture). Sim-side structural evidence recorded instead of energy numbers: the zero-timers census (existing guards green), the AOD static-glyph tier (TASK-041 record), the next-event-timer-only scheduling (TASK-031 record), and TASK-040 R4's zero-background-requirements WC record (no background modes beyond WC delivery). These are structural attestations, NOT energy measurements — label them so.
- **R7 — Watch snapshot restore ≤ ~2 s.** Re-run the existing restore-within-budget `MomoWatchUITests` test on the pinned 44mm sim; record the timing assertion's numbers from the xcresult; confirm the ≤ ~2 s bound is asserted in-test (raise-to-glance, protecting FR-17's ≤ 5 s raise-to-pat).
- **R8 — Play round ≤ 30 s.** Re-verify the existing engine core test that pins the bound (name it, cite its numbers); no new test if one exists (no-duplication).
- **R9 — Sync cadence on-change only.** Run a session on the paired sim pair (iPhone SE 3rd gen + Watch SE 3 44mm): launch both, idle, trigger one Watch pat (fixture or interaction seam), and capture the transport log lines / a WC-call census (count `updateApplicationContext` sends and `transferUserInfo` sends with triggers). Verify: context pushes fire on CHANGE only; intent sends fire on pat only. Record the raw log excerpt (trimmed) as evidence.
- **R10 — Evidence discipline.** Every row in the record carries: budget value (verbatim from 05 §12), measured value(s), measurement surface (sim identity / device / structural), harness command, and PASS/MISS/BLOCKED verdict. Raw multi-MB traces stay OUT of the repo (commands + summarized evidence in `.claude/tasks/evidence/TASK-045/` as small text files; note where raws were kept and their sizes).
- **R11 — Miss discipline.** Any MISS: STOP measuring further, record the miss, identify root cause, and report — the orchestrator runs the fix loop (a fresh fix agent + re-measure) before review closes. Never edit a budget value; never weaken a test to pass a budget; never re-run until a lucky number appears (report the distribution, not the best run).
- **R12 — Standing baselines at handoff.** `swift test` ≥ 1161/113 green; both builds green on pinned sims; frozen surfaces (`Sources/MomoCore/`, `Sources/MomoCharacter/`, `Apps/Momo/**`, `Apps/Shared/MomoCopy.xcstrings`, `Momo.xcodeproj/`) diff-EMPTY; zero new entitlements/Info.plist keys; zero timers; D20 clocks clean; catalog law (epoch 4, zero new copy keys); no production source changes expected — if ANY production file must change, surface it to the orchestrator FIRST (it likely means a budget miss or a defect: stop per R11).

## Files / Areas Likely Affected

- `.claude/tasks/active/TASK-045-performance-budgets.md` (this file — Implementation Notes + evidence fills).
- NEW `.claude/tasks/evidence/TASK-045/*.md` (small text evidence files: commands, summaries, trimmed logs).
- Possibly NEW: a launch-metrics UI test (in `MomoUITests/`) or a measurement helper — ONLY if it lives outside the frozen surfaces; prefer harness-free `xcodebuild`/`xctrace`/`xcresulttool` command evidence committed as text. If a new test is added it must be deterministic and not flaky-by-timing (a launch-metrics test asserting the 2.0 s budget on a SIM is acceptable only if honestly labeled sim-surface in its name/docs).
- Likely ZERO production source changes (if any are needed, STOP per R11/R12).

## Dependencies

- TASK-039, TASK-044 (both merged to `main` @ `d460a24`); ADR-008; TASK-030's art-budget method; TASK-041's restore UI test.

## Constraints

- Frozen surfaces diff-EMPTY; no pbxproj edits unless a new test file strictly requires registration (prefer package-side or existing UI-test target membership).
- §25 honesty everywhere; §26 no undocumented TODO debt; §27 zero entitlements/secrets.
- No timers; D20; catalog law; D-R3 (no app-to-app target dependency).
- Do not weaken, skip, or re-pin any existing test.
- Budget values are normative and uneditable.

## Acceptance Criteria

1. All ten 05 §12 rows recorded with budget-verbatim values, measured numbers, surface labels, harness commands, and PASS/MISS/BLOCKED verdicts.
2. R1–R5, R7–R9 measured FOR REAL on the named sims; R2/R6 device legs BLOCKED with raw capture + owner routing (§25).
3. Zero unexplained baseline regressions at handoff (R12's full list green).
4. Any MISS followed R11's blocker discipline (or the task is NOT done).
5. Evidence files committed as small text artifacts; no multi-MB raws in the repo.
6. This task file carries the complete §28 handoff (see Review Requirements for the marker rule).

## Required Tests

- Re-run: `swift test` (expect ≥ 1161/113), both pinned-sim builds, `MomoWatchUITests` (expect 9/9 — R7 rides it), app UI suite 35/35 if the launch-metrics test joined it (otherwise the unchanged-inputs argument, verified not assumed).
- New measurement evidence per R1–R9 as recorded runs (not necessarily new test code — harness commands count as the test when recorded with raw output).
- Coverage floor: unchanged at ≥ 80 % MomoKit lines if no package code changed (expected none).

## Review Requirements

- Fresh independent reviewer (§10/§33), Jupiter, unprimed: re-derive the budget list from 05 §12 BEFORE reading this file; then attack the evidence — spot re-run ≥ 2 measurements personally (at least one launch-metrics and one memory run), verify every device identity claim against `simctl`/`xctrace` output, verify every BLOCKED row's raw capture, and confirm zero production diff + frozen surfaces.
- Any new test code gets the standard guard treatment (both-direction non-vacuity, mutation bite with sha256-restores).
- Handoff marker rule (standing): end the handoff with a line consisting of the word HANDOFF-COMPLETE, one space, and this task's ID (TASK-045) — type it fresh at handoff; contract/template files must never contain the literal assembled marker string (line-anchored monitors grep it and template text causes false fires).

## Git Requirements

- One atomic commit containing this task file's fills + evidence files (+ any new test file): `test(qa): TASK-045 performance budget verification evidence` (or `docs(qa): …` if zero code). TASK-ID in the message. Do not commit raw traces or xcresult bundles.

## Status

READY (contract authored 2026-09-12; not yet dispatched).

## Implementation Notes

(fresh implementer fills — per CLAUDE.md §9 the implementer does NOT commit.)

## Reviewer Findings

(fresh reviewer fills under `.claude/tasks/reviews/REVIEW-TASK-045.md`; this section records only the disposition.)

## Completion Evidence

(orchestrator fills at closeout.)
