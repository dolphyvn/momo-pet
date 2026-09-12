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

DONE-pending-push (2026-09-12): implementation complete (all R1–R12 rows with evidence; no MISS; no budget value edited); review APPROVED_WITH_MINOR_NOTES (REVIEW-TASK-045; F-1 wording fix + F-3/F-4 table precision applied at closeout); orchestrator gates re-verified (swift test 1161/113 personally re-run, all structural citations exact). Atomic commit (this commit); push (this push pending). Final DONE state recorded in the completed/ copy.

## Implementation Notes

Implemented 2026-09-08..09-12 by the fresh TASK-045 agent. Per-row evidence
lives in `.claude/tasks/evidence/TASK-045/` (00-environment + one file per
row + raw logs; no traces/bundles). Summary verdicts:

| Row | Budget (verbatim 05 §12) | Measured (surface) | Verdict |
|---|---|---|---|
| R1 cold launch | `≤ 2.0 s (NFR-1) on the smallest supported device` | iPhone SE 3 sim: median 1.100153 s (5 XCTApplicationLaunchMetric runs, RSD 0.7%); iPhone 17 Pro sim: median 1.500864 s (RSD 12.9%, descending first-boot distribution recorded in full) | PASS (sim legs); device leg BLOCKED per §25, owner-routed |
| R2 animation | `Sustained 60 fps on reference hardware; ≤ 8 ms/frame CPU+GPU work on 60 Hz devices; no sustained stutter (NFR-1). ProMotion not assumed` | NO measured value anywhere: `xctrace` "Animation Hitches" verbatim refuses the sim ("Hitches is not supported on this platform") and no authorized physical device exists (raw-xctrace-list-devices.txt). Supplementary sim signal: ~10.4% of one host core at Home idle. Structural: 21-constant transform-only full rig (zero blur/shadow/opacity in MomoRig.swift), next-event-timer scheduling | BLOCKED (device legs per §25; sim metric impossible) — honest no-claim |
| R3 iPhone memory | `≤ 150 MB steady-state Home idle (provisional, NFR-3)` | phys_footprint soak, both iPhone sims (Release): settle 47 MB -> peak 56 MB -> plateau 56 MB with 57 MB tails x5 on both sims (tails precision per REVIEW F-3) | PASS (sim legs, 62% headroom); device leg BLOCKED, owner-routed |
| R4 Watch memory | `≤ 80 MB foreground (provisional starting budget; VERIFY-AT-BUILD against current watchOS norms)` | Watch SE 3 40mm: 19 MB flat x22; Series 11 42mm: 20 MB steady x22; comparator (empty SwiftUI watch app, same sim): 19 MB — Momo's own memory ~1 MB over the platform floor | PASS (sim legs, ~4x headroom); VERIFY-AT-BUILD recorded, value unedited; physical Watch owner-routed |
| R5 sizes | `≤ 60 MB (NFR-4); art contribution ≤ 1.5 MB target (04 §8.3) — app is binary-dominated` | Momo.app Release 7,609,627 B; MomoWatch.app Release 5,979,174 B (archive products 2,429,051 / 1,921,494 B). Art (TASK-030 exact-bytes method): generated total 70,743 B <= 1,572,864 B; MomoCharacter .swift total 356,559 B (+4,696 B = disclosed TASK-035 playStopped seam) | PASS |
| R6 energy | iPhone `Xcode energy gauge Low over a 10-min idle session (NFR-2); no background work beyond WC delivery`; Watch `No standing timers/work; AOD = static glyph; schedulers are next-event timers only (04 §5.2); WC transfers coalesced by the system (context latest-wins)` | No energy measurement exists or is claimed. Structural attestations recorded: realTreeNoTimers green; AOD glyph binds no clock (GlanceView.swift:200-268); next-event schedulers (04:288/:362); zero UIBackgroundModes anywhere | BLOCKED (device legs per §25, owner-routed); structure recorded, not labeled as energy data |
| R7 Watch snapshot restore | `≤ ~2 s raise-to-glance (intake; protects FR-17's ≤ 5 s raise-to-pat)` | Existing E2E re-run on Watch SE 3 44mm: MomoWatchUITests 9/9 PASS; testSnapshotRestoreStaysWithinTheBudget asserts restore - baseline <= 2.0 s over a measured baseline — PASSED (14.296 s case wall incl. 3 launches) | PASS (sim leg); physical-Watch leg owner-routed |
| R8 Play round | `≤ 30 s bounded by engine + character pacing (FR-7, 04 §6.3)` | Existing proofs cited: authored worst case 22.4 s inside cap (MomoHandshakeTests roundBound); pacer deadline holds for ANY input stream (MomoReactionDirector.swift:757-761); engine PlayRoundTests green — inside the fresh 1161/113 run | PASS (proof+engine); device stopwatch leg owner-routed |
| R9 sync cadence | `Context pushes: on-change only (a handful/day steady state); intent sends: on pat` | Live paired-sim session (SE3 + 44mm): pushes fired 1x/launch + 16x clustered exactly in the interaction window; ZERO during the 60 s idle and 30 s settle windows. Structural: `if outcome.changed` gate (AppModelPlan.swift:252); tick-only evaluates plan no push (:22). 7006 "not installed" failures kept verbatim as environmental truth (they mark exactly when attempts happened) | PASS (sim pair census + structure; intent-send half structural-only — sends app-silent by design, receive-side silent in the window; disclosed in 09-r9); physical pair owner-routed |
| R10 discipline | evidence per row | `.claude/tasks/evidence/TASK-045/` 00..10 + raw-* logs (~150 KB text; no traces/bundles committed) | DONE |
| R11 miss discipline | any MISS -> stop+record | No MISS occurred; every measured row passed with the recorded distributions reported in full (17 Pro descending distribution noted, not cherry-picked) | N/A (no misses) |
| R12 standing gates | swift test >= 1161/113; builds green; frozen surfaces diff-empty; zero entitlements/Info.plist/timer changes; no production changes | fresh `swift test` 1161/113 PASSED; 4 builds SUCCEEDED; watch UI 9/9; `git status --porcelain` = 0 lines and stash = 0 (tree byte-identical to HEAD — frozen surfaces diff-empty BY TREE IDENTITY; zero new entitlements/Info.plist keys; zero timers; no production source changes needed or made); iPhone app UI 35/35 cited as baseline for the unchanged tree (not re-run — stated plainly) | DONE |

Deviations / notes for the reviewer and orchestrator:
- The R1/R3 probe harness is a throwaway /tmp Xcode project (NOT in the repo) —
  it probes the installed Momo app via XCUIApplication(bundleIdentifier:) so the
  frozen surfaces stay untouched; the commit therefore contains only the task
  file + evidence files (docs(qa) shape).
- R4 adjudication used a throwaway comparator watch app to establish the
  watchOS 26.5 sim platform floor (~19 MB) — context for VERIFY-AT-BUILD; the
  80 MB normative value was not edited.
- Disk-pressure incident mid-session (host volume 100%): tooling blocked until
  I removed my own /tmp artifacts (values pre-recorded), this project's
  DerivedData intermediates, and the two probe projects' DerivedData. Sim
  runtime volumes and devices untouched. Remaining free space ~0.5 GB — the
  owner should free disk space before the next heavy session.
- Watch-sim wedge during the R9 session (post-UI-test): rebooted the 44mm,
  reinstalled the app, restarted that stream; pre-reboot watch-stream data
  discarded and the incident recorded in the session notes.
- Handoff (§28): Completed = all R1-R12 rows with evidence. Files Changed =
  task file + evidence dir only. Tests Run/Test Results = 10-r12-gates.txt.
  Known Issues = device-leg rows owner-routed; disk pressure. Decisions =
  comparator method, throwaway-probe method, no budget value edited.
  Reviewer Status = pending fresh reviewer. Commit/Push = orchestrator.
  Recommended Next Step = fresh review agent per §10/§33, then orchestrator
  commit `docs(qa): TASK-045 performance budget verification evidence`.

## Reviewer Findings

Full record: `.claude/tasks/reviews/REVIEW-TASK-045.md` — **VERDICT: APPROVED_WITH_MINOR_NOTES** (fresh independent §10/§33 agent, 2026-09-12). The reviewer re-derived the budget list from 05 §12 before reading this file, personally re-ran the full gate battery (1161/113; both builds; watch UI 9/9 incl. the restore-budget test), re-measured R1 (own probe: median 1.111244 s vs recorded 1.100153 s, ~1 % apart) and R3 (47 MB flat under automation digit-for-digit; clean-launch 25 MB delta explained as automation overhead, personally reproduced), reproduced the verbatim Animation-Hitches sim refusal, and confirmed the census/structure/sizes exactly. Dispositions:

- **F-1 (Minor — FIXED at closeout):** the table's "verbatim" budget strings were paraphrases/truncations in several rows (values and semantics always correct; nothing edited). Fixed in this closeout pass: every row's Budget cell now carries §12's literal text. The "(no polling) / idle == zero sync work" additions were removed from R9's budget cell (supported by 05:272-275, but not this row's text — the structural pins in 09-r9 still carry that evidence).
- **F-2 (Note — accepted):** R3's "phys_footprint" label vs the headline "64-bit Footprint" line — equal in every run the reviewer inspected; values sound. Raw evidence left as-written; correction recorded here.
- **F-3 (Note — FIXED in table):** "FLAT 56 MB" understated the 57 MB tails x5; the R3 measured cell now records plateau + tails.
- **F-4 (Note — FIXED in table):** R9's verdict now surfaces that the intent-send half-leg's evidence is structural-only (sends app-silent by design; receive-side silent in the window), as disclosed in 09-r9.
- **F-5 (Note — accepted, recorded here):** evidence file 05-r5-sizes.txt mislabels the Momo.app rows "(Release/Debug-watchsimulator)" — the byte values are the iphonesimulator products (Debug matches byte-for-byte at 5,303,171 B). Raw evidence left as-written; this record corrects it. Same for 10-r12's build-list label.
- **F-6 (Note — accepted):** Release Momo.app rebuild delta +47,238 B (+0.62 %) between sessions; Debug byte-identical; presumed rebuild nondeterminism; immaterial vs 60 MB.
- **F-7 (Note — accepted):** 10-r12's "porcelain → 0 lines" is the gate-time snapshot; the handoff tree adds exactly the expected documentation entries.
- **F-8 (Note — accepted):** the reviewer's fresh xctrace capture shows one extra sim-pair line vs the recorded capture (benign environment drift); a refreshed device-identity capture rides the next task that checks device identity.

## Completion Evidence

- **Review:** `.claude/tasks/reviews/REVIEW-TASK-045.md` — APPROVED_WITH_MINOR_NOTES; F-1 fixed at closeout (budget strings now §12-verbatim); F-2/F-5..F-8 accepted as recorded corrections; F-3/F-4 folded into the table.
- **Gates at closeout:** `swift test` 1161/113 PASSED (orchestrator re-run, exit 0; reviewer digit-for-digit); Momo + MomoWatch builds BUILD SUCCEEDED (reviewer re-runs on pinned sims); `MomoWatchUITests` 9/9 incl. `testSnapshotRestoreStaysWithinTheBudget` (reviewer re-run, xcresult-confirmed on the pinned 44mm); frozen surfaces diff-EMPTY by tree identity (diff = task docs only); zero production/test-code changes; zero entitlements/Info.plist/timer deltas.
- **Commit:** (this commit) — `docs(qa): TASK-045 performance budget verification evidence` (task file + evidence dir + review record; no traces/bundles).
- **Push:** (this push pending) — `origin feature/EPIC-009-release-readiness`.
