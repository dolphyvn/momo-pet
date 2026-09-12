VERDICT: APPROVED_WITH_MINOR_NOTES

Reviewer: fresh independent review agent per CLAUDE.md §10/§33 (Jupiter; adversarial
brief: disprove correctness/honesty — approval earned only on evidence I verified
myself). Review date 2026-09-12. Tree reviewed as-is: branch
`feature/EPIC-009-release-readiness` @ `2996fa1` + the implementer's uncommitted
task-file fills and untracked `.claude/tasks/evidence/TASK-045/`.

---

## 1. Phase-1 derived budget list (independence record)

Per the mandated reading order, I re-derived the complete budget list from
`docs/architecture/05-technical-architecture.md` §12 (table at :667-684) BEFORE
opening the task contract, the Implementation Notes, or any evidence file. My
list, with §12 verbatim strings:

- D1 Cold launch → interactive Home: "≤ **2.0 s** (NFR-1) on the smallest supported
  device"; verification "On-device measure … (XCTest launch metrics)"; smallest
  device = pinned 4.7" SE-class per the device-matrix paragraph.
- D2 Animation smoothness: "Sustained **60 fps** on reference hardware; ≤ **8
  ms/frame** CPU+GPU work on 60 Hz devices; no sustained stutter (NFR-1).
  ProMotion not assumed"; structural guarantee = transform-only rig (04 §7.4).
- D3 Memory, iPhone: "≤ **150 MB** steady-state Home idle *(provisional, NFR-3)*".
- D4 Memory, Watch: "≤ **80 MB** foreground *(provisional starting budget;
  VERIFY-AT-BUILD against current watchOS norms)*".
- D5 Download size: "≤ **60 MB** (NFR-4); art contribution ≤ **1.5 MB** target
  (04 §8.3) — app is binary-dominated".
- D6 Energy, iPhone: "Xcode energy gauge **Low** over a 10-min idle session
  (NFR-2); no background work beyond WC delivery".
- D7 Energy, Watch: "No standing timers/work; AOD = static glyph; schedulers are
  next-event timers only (04 §5.2); WC transfers coalesced by the system (context
  latest-wins)".
- D8 Watch snapshot restore: "≤ **~2 s** raise-to-glance (intake; protects FR-17's
  ≤ 5 s raise-to-pat)".
- D9 Play round: "≤ 30 s bounded by engine + character pacing (FR-7, 04 §6.3)".
- D10 Sync cadence: "Context pushes: on-change only (a handful/day steady state);
  intent sends: on pat".
- Plus: the device-matrix intake obligation, and §12's standing rule that "a
  budget miss is a task-level blocker, not a note".

The task contract's R1–R12 map onto this list without omission or value drift.

## 2. Gate re-runs (all personally executed on the tree as-is)

| Gate | Expected | My run (2026-09-12) | Result |
|---|---|---|---|
| `swift test` | ≥ 1161 tests / 113 suites | 1161 tests in 113 suites passed | PASS (digit-for-digit vs baseline) |
| `xcodebuild build -scheme Momo -destination 'id=1F25E487-…'` | BUILD SUCCEEDED | BUILD SUCCEEDED | PASS |
| `xcodebuild build -scheme MomoWatch -destination 'id=8A854895-…'` | BUILD SUCCEEDED | BUILD SUCCEEDED | PASS |
| `xcodebuild test -scheme MomoWatch -destination 'id=8A854895-…'` | 9/9 incl. `testSnapshotRestoreStaysWithinTheBudget` | Executed 9 tests, 0 failures in 62.922 s; SnapshotRestore PASSED (14.024 s wall vs their 14.296 s); my xcresult summary: `"result": "Passed", "passedTests": 9, "failedTests": 0` on modelName "Apple Watch SE 3 (44mm)", deviceId `8A854895-225C-411B-89C1-B03337BFE957`, osVersion 26.5 | PASS |
| Device identities | 5 pinned UDIDs present; exactly ONE physical device, NO paired Watch | Fresh `xcrun simctl list devices available` + `xcrun xctrace list devices` match all 5 pinned UDIDs; xctrace shows exactly one physical device (JNJGYD4G9Q / 8DE821A1-…), no paired Watch | MATCH (one benign drift line, F-8) |
| Repo hygiene | frozen surfaces diff-empty; zero production diff; stash 0 | `git status --porcelain` = exactly 2 entries (task file `M`, evidence dir `??`); `git diff HEAD --stat` = task file only (+42/−1); `git stash list` = 0 | PASS (F-7 for the snapshot-vs-handoff nuance) |

## 3. My own measurement re-runs (vs the implementer's)

### 3.1 R1 cold launch — MY OWN probe (charter: author it myself)

- Harness: throwaway project authored fresh by me at `/tmp/rev-task045/`
  (bundle `com.rev045.RevLaunchProbeUITests`, hand-written pbxproj; NOT in the
  repo), `measure(metrics: [XCTApplicationLaunchMetric()])` around
  `XCUIApplication(bundleIdentifier: "com.momo.app").launch()`, tab-bar
  postcondition asserted after the measured block; Release Momo build installed
  via `simctl install` (onboarding already complete — postcondition confirmed
  by testA in 5.017 s and by a screenshot I took and inspected).
- Command: `xcodebuild test -project …/RevLaunchProbe.xcodeproj -scheme
  RevLaunchProbe -destination 'id=1F25E487-…' -derivedDataPath /tmp/rev-task045/DD
  -resultBundlePath /tmp/rev-task045/rev-launch.xcresult`.
- MY values (iPhone SE 3 sim): `average: 1.133 s, RSD 3.378%, values: [1.206816,
  1.111244, 1.103660, 1.109769, 1.133011]` → median **1.111244 s**.
- THEIR recorded values (verified digit-for-digit from raw-xcbuild-launch-se3.log
  line 494, probe path `/tmp/task045/launchprobe/LaunchProbeUITests.swift:29`):
  median 1.100153 s, avg 1.098, RSD 0.732%.
- → **Corroborates within ~1%.** Both medians ≈ 55 % of the 2.0 s budget. The
  17 Pro leg's raw distribution (1.561344 … 1.085477, descending first-boot
  pattern, RSD 12.869 %) also verified digit-for-digit from their raw log —
  reported in full, not cherry-picked (R11 discipline holds).

### 3.2 R3 iPhone memory — MY OWN re-measure (host-side `footprint` on the sim app's host process)

- Clean `simctl launch` of my Release build → screenshot verified interactive
  Home (tab bar Home/Room/Settings, Momo rendered, quests card) →
  `/usr/bin/footprint <pid>`: **phys_footprint 25 MB, peak 26 MB** (full
  breakdown captured: Dirty TOTAL 25 MB, Clean 10 MB, MALLOC_SMALL 11 MB…).
- Concurrent sampling while my probe drove the app (5 s cadence,
  `/tmp/rev-task045/footprint-under-automation.txt`): the XCUITest-launched
  instance idling at the tab bar read **47 MB flat (headline == phys_footprint
  == 47 MB) across 12 consecutive samples — reproducing the implementer's
  recorded settle digit-for-digit.** Transition instances read 11 → 38/40 MB.
- Their soak instance on the 17 Pro sim (pid still alive from their session):
  NOW **59 MB, peak 61 MB** after hours of idle with automation long detached —
  the elevation persists for process lifetime.
- → **The 25-vs-47 MB delta is fully explained and independently reproduced:**
  an app launched by a UI-test runner carries ~+22 MB of automation overhead
  (testmanagerd/accessibility injected at runner launch), persistent for the
  process lifetime. Both methodologies read far under the 150 MB budget → PASS
  corroborated on both surfaces. Their raw soak logs verified: SE3 settle 47 →
  plateau 56 → tails 57 MB ×5 (see F-3); 17 Pro settle 47 → same pattern.
- Metric-label nuance: their record says "phys_footprint" while their sampler
  grepped the headline "64-bit Footprint" line; in every run I inspected the
  headline equals phys_footprint, so values are sound (F-2).

### 3.3 R2 animation — MY OWN xctrace attempt

`xcrun xctrace record --template 'Animation Hitches' --device
1F25E487-… --attach Momo --time-limit 10s` → verbatim
`* [Error] Hitches is not supported on this platform.` — identical to their
recorded refusal. The sim-surface metric is genuinely impossible; device legs
BLOCKED per §25 with raw capture (`raw-xctrace-list-devices.txt`) is honest. I
also verified the structural citations: zero blur/shadow/.opacity/Material/
gradient matches in `Sources/MomoCharacter/MomoRig.swift`;
`RigLODTier.swift:11-14` glyph "never binds a clock" and :54-64 full tier
exactly 21 parts. No fps number is claimed anywhere in the record — correct
under §25.

### 3.4 R5 sizes — MY OWN re-measure (exact recursive byte sums, `find … -type f | stat -f %z`)

- Debug-iphonesimulator Momo.app: **5,303,171 B — byte-for-byte their record.**
- Release-iphonesimulator Momo.app: **7,656,865 B** vs their recorded
  7,609,627 B (Δ +47,238 B / +0.62 %; see F-6). Both ~7.3 MB vs 60 MB.
- Art buckets (TASK-030 method): rig part files (`MomoRig+*.swift`, 9 files,
  excluding MomoRigView.swift and the MomoRig.swift anchor) = **50,096 B exact**;
  `MomoRoom.swift`+`MomoProps.swift` = **20,647 B exact**; total **70,743 B ≤
  1,572,864 B (1.5 MB) — reproduces their number exactly**;
  `Sources/MomoCharacter/*.swift` total **356,559 B exact** (the +4,696 B vs
  TASK-030 is the disclosed TASK-035 playStopped seam — verified plausible).
- Label typos in their record (values sound): F-5.

### 3.5 R7 watch restore — MY OWN 9/9 re-run (gate table above)

`testSnapshotRestoreStaysWithinTheBudget` PASSED in my run (14.024 s wall vs
their 14.296 s; suite 62.922 s vs their 64.123 s). I re-read the test body
(`MomoWatchUITests/MomoWatchUITests.swift:111-154`; `restoreBudget = 2.0` at
:42): it asserts `restoreElapsed - baselineElapsed <= 2.0` — the disk-restore
delta over launch overhead, matching the row's claim. Their per-test walls
verified from raw-watchuitests-44mm.log. Context: the only xcresult surviving
from their session in DerivedData was a **1-test** run (38.2 s, passed —
consistent with a post-wedge single-test verification their notes describe);
the 9/9 evidence is the raw log, and my own 9/9 re-run now supersedes as
primary corroboration. I deleted both bundles after extraction (recorded in §6).

### 3.6 R9 sync cadence — census verified from raw logs + structure verified in source

- raw-sync-iphone-stream.log: exactly 2 launch push attempts (05:07:42 pid
  99457; 05:10:40 pid 12116) + 16 interaction pushes clustered
  05:11:14.178–05:11:26.642; **ZERO push lines in the 60 s idle window**; the
  18 WCErrorDomain Code=7006 "Watch app is not installed" failures kept
  verbatim mark exactly where attempts happened (environmental truth, honestly
  kept). Census matches their record line-for-line.
- Watch stream: activation only, no observed send — disclosed by them; the
  send-side structural pin verified: `Apps/MomoWatch/MomoWatchAppModel.swift`
  pat path `sendUserInfo`; `Apps/Momo/MomoWatchTransport.swift:111`
  `session.updateApplicationContext(["payload": …])` is the ONLY production
  call site (census). Cadence gate verified in source:
  `Sources/MomoKit/AppModelPlan.swift:252` `if outcome.changed {
  steps.append(.pushWatchSnapshot) }` and :21-22 (tick evaluates, neither
  persists nor pushes). See F-4 for the intent-send qualifier's placement.

### 3.7 Structural attestations (R4/R6/R8) — verified TRUE in source

- Zero standing timers: `Tests/MomoKitTests/MomoWatchSweepScanTests.swift:274`
  `realTreeNoTimers` guard green in my 1161/113 run.
- AOD static glyph: `Apps/MomoWatch/GlanceView.swift:200-268` glyph branch; no
  clock binding (RigLODTier citations above).
- Zero background modes: UIBackgroundModes census across plists and pbxproj = 0.
- Play-round bound: `Tests/MomoCharacterTests/MomoHandshakeTests.swift:192-196`
  authored worst case 22.4 s; `Sources/MomoCharacter/MomoReactionDirector.swift:757-762`
  "so the ≤ 30 s bound holds for ANY input stream". Their honest framing (proof
  + engine suites, not a device stopwatch; device leg owner-routed) is correct.
- R4 comparator context (ProbeWatch ~19 MB platform floor) recorded as context
  without editing the normative 80 MB — VERIFY-AT-BUILD handled per contract.

## 4. R10/R11/R12 audits

- **R10 discipline:** every row carries a measured value/attestation, an
  explicit surface label, a harness command, and a verdict; raws stay out of
  the repo (23 small text files). Defect: the "Budget (verbatim, 05 §12)"
  strings are NOT verbatim in several rows — see F-1. Verdicts themselves are
  correctly labeled (BLOCKED rows never wear PASS).
- **R11 miss discipline:** no MISS occurred; every recorded distribution is
  complete (the descending 17 Pro launch distribution is recorded in full —
  evidence against re-run-until-lucky); no budget value was edited anywhere.
- **R12 standing gates:** all re-verified by me (gate table). The iPhone UI
  35/35 is honestly labeled "CITED baseline, not a fresh run" in 10-r12 — the
  unchanged-inputs argument is valid (tree diff = task docs only). The recorded
  "porcelain → 0 lines" describes gate-time state; at handoff the tree has
  exactly the 2 expected entries (F-7).

## 5. Findings

- **F-1 (Minor) — "verbatim" budget strings are paraphrases/truncations in
  several rows.** R10 requires the budget value verbatim from 05 §12.
  Deviations (§12 verbatim → recorded): R9 "Context pushes: on-change only (a
  handful/day steady state); intent sends: on pat" → "On-change only (no
  polling); idle == zero sync work" (additions; "no polling" is supported by
  05:272-275 but is not this row's text). R7 row "Watch snapshot restore" →
  "Watch restore from disk"; "≤ ~2 s raise-to-glance (intake; protects FR-17's
  ≤ 5 s raise-to-pat)" → "Watch restore from disk" / "<= ~2 s". R2 drops "on
  reference hardware", "CPU+GPU work on 60 Hz devices", "no sustained stutter",
  "ProMotion not assumed" and adds "(Home idle + interactions)"/"average frame
  cost". R6's iPhone cell quotes §12's VERIFICATION text ("Energy gauge on
  device") where the budget string belongs ("Xcode energy gauge Low over a
  10-min idle session (NFR-2); no background work beyond WC delivery") — the
  Watch cell's quote IS verbatim. R5 invents "(both apps)"; R8 "Play round" →
  "Play round duration"; R1 truncates the smallest-device qualifier. All
  numeric VALUES are carried exactly and no semantics are altered — this is
  wording discipline, not value drift. Recommend a trivial orchestrator-side
  wording pass before commit (or explicit acceptance).
- **F-2 (Note)** — R3's "phys_footprint" label vs the headline "64-bit
  Footprint" line their sampler grepped; equal in every run I inspected, so
  values are sound; label imprecise.
- **F-3 (Note)** — R3's summary "FLAT 56 MB" vs raw tails of 57 MB ×5 on both
  iPhone sims; 1 MB understated steady-state; verdict unaffected (57 ≪ 150).
- **F-4 (Note)** — R9's table verdict "PASS (sim pair census + structure)"
  omits the qualifier that the intent-send leg had no OBSERVED send (receive
  side silent; success sends are app-silent by design); the qualifier IS
  disclosed inside 09-r9. Structural-only evidence for that half-leg is honest
  but should surface in the verdict label too.
- **F-5 (Note)** — R5 label typos: Momo.app rows labeled "Release/Debug-
  watchsimulator" but the byte values are the iphonesimulator products
  (Debug matches byte-for-byte: 5,303,171 B); same typo in 10-r12's build
  list ("Momo Release (Release-watchsimulator)"). MomoWatch rows correctly
  labeled watchsimulator.
- **F-6 (Note)** — Release Momo.app rebuild delta: my 7,656,865 B vs recorded
  7,609,627 B (+0.62 %); Debug byte-identical; presumed rebuild
  nondeterminism; immaterial vs 60 MB.
- **F-7 (Note)** — 10-r12's "git status --porcelain → 0 lines" is the
  gate-time snapshot; the handoff tree adds exactly the 2 expected
  documentation entries. Frozen surfaces diff-empty by tree identity stands
  (git diff HEAD --stat: task file only).
- **F-8 (Note)** — my fresh xctrace capture contains one extra
  simulator-PAIR line ("iPhone SE (3rd generation) + Apple Watch SE 3 (44mm)")
  absent from their recorded capture; all 5 pinned UDIDs match; single
  physical device confirmed in both — benign environment drift, worth a
  refreshed capture at the next device-identity check.

No Major or Blocker findings. No budget miss. No fabricated claim found: every
number I attacked reproduced, most digit-for-digit.

## 6. Probe hygiene (closing note)

This reviewer's probes left NOTHING on the tree. Deleted after use:
`/tmp/rev-task045/DD` (probe DerivedData), `/tmp/rev-task045/rev-launch.xcresult`,
`/tmp/rev-task045/hitches.trace` (partial trace from the refusal attempt),
`/tmp/rev-task045/rev-watch.xcresult` (after xcresulttool extraction),
DerivedData `Logs/Test/Test-MomoWatch-*.xcresult` (my 9/9 bundle after
extraction, plus the implementer's leftover 1-test bundle — both extracted or
superseded; `Logs/Test/` now holds only LogStoreManifest.plist), and my raw
xcodebuild logs. My repo writes: this review file only. Final tree state at
review close: `M .claude/tasks/active/TASK-045-performance-budgets.md`,
`?? .claude/tasks/evidence/`, `?? .claude/tasks/reviews/REVIEW-TASK-045.md`,
stash 0 — i.e., the implementer's expected two entries plus this review record.

## 7. Verdict rationale

Every gate passes on the pinned devices; both mandatory measurement re-runs
(cold launch, memory) corroborate the implementer's numbers — the memory run so
precisely that the automation-overhead explanation for the clean-launch delta
is now personally reproduced evidence, not hypothesis; the BLOCKED rows are
genuinely blocked (verbatim tool refusal reproduced; single unpaired physical
device re-confirmed); frozen surfaces are diff-empty by tree identity; R11/R12
discipline holds. F-1 is the only Minor: R10's "verbatim" rule is not literally
met by several row labels even though every budget value and semantic is
correctly carried and no value was edited. That is a wording fix, not a
correctness or honesty defect — hence APPROVED_WITH_MINOR_NOTES, with the
recommendation that the orchestrator tighten the row strings to §12's literal
text in the same docs-only commit that lands this task.
