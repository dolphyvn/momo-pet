# EPIC-009 — Polish, QA & Release Readiness

Authored 2026-09-12 from the delivery plan's EPIC-009 rows (06 §3, the backlog of record), project.md §32–§35/§44, 05 §10.5/§11/§12, 03 §10, 04 §7.4/§8.3, ADR-006 N-1. Branch: `feature/EPIC-009-release-readiness`, cut from the merged `main` @ `244b7ea` (post-EPIC-008 §14 merge).

## Objective

Certify — by measurement and evidence, never by assumption (project.md §33) — that Phase 1 passes every §35 Definition of Done condition: performance budgets (05 §12), the §10.5 edge-case matrix, the full accessibility audit (03 §10), the privacy/security review (05 §11 + CLAUDE.md §27), the §44 final product test, and the release checklist (gates, E4 name clearance, App Store posture). This epic adds no features; it is the release gate for everything EPIC-002…008 shipped.

## User / Product Value

None of this is visible as a feature — it is the guarantee behind the product: Momo launches fast, stays smooth, sips battery, respects every accessibility setting, collects nothing, and survives every edge the real world throws at it. It is what makes "Cute × Calm × Minimal × Alive × Premium" true at release rather than asserted.

## Scope

| TASK | Title | Size | Depends on |
|---|---|---|---|
| TASK-045 | Performance budget verification (05 §12; NFR-1/2/3/4/9) | L | TASK-039, TASK-044 |
| TASK-046 | §32 edge-case matrix execution (05 §10.5; FR-11 AC-3; NFR-7) | M | TASK-020, TASK-024 |
| TASK-047 | Full accessibility audit — launch-blocking (FR-20 AC-2; NFR-6; 03 §10) | M | TASK-039, TASK-044 |
| TASK-048 | Privacy & security review (FR-20; NFR-5; CLAUDE.md §27; 05 §11) | M | TASK-039, TASK-044 |
| TASK-049 | Philosophy & tone QA — the §44 final product test (FR-12; 04 §10; PR1) | S | TASK-045…048 |
| TASK-050 | Release readiness: gates, name clearance, App Store posture (§35; E4; ADR-006 N-1) | M | TASK-049 |

Execution order follows the dependency graph (06 §4.1): 045/046/047/048 are parallelizable in principle but run sequentially per §9 (one task = one fresh agent; the branch is single-file-domain per task), then 049 → 050. TASK-045 is first (its harness and evidence conventions seed the others).

**Environment honesty (standing, §25/§36):** this environment has NO paired physical Watch and exactly ONE physical device (iPhone-class; `xctrace list devices` raw capture recorded at TASK-044 R5). Legs that require physical hardware — energy-gauge sessions, sustained-fps/thermal device traces, WC-frame-under-suspension re-verification — are attempted-then-**BLOCKED**-recorded with raw capture and routed to the owner's device-pass backlog; they are NEVER sim-claimed. Simulator-measurable legs (launch metrics, memory footprint, bundle/archive size, Watch restore timing, sync-cadence logs, all static/structural audits) are measured FOR REAL on the pinned simulators.

**Owner-gated legs (§36):** E4 name/trademark clearance (TASK-050 escalates with search results), TestFlight build/submission, App Store metadata final submission. The agents prepare artifacts, checklists, and evidence; the owner submits. N-1 deployment widening is re-evaluated once as analysis, owner-decided.

## Non-Goals

- No new user-facing features, no visual redesign, no copy changes (§22/§24; any required fix lands as its own adjudicated task).
- No Phase 2 reservations implemented (HealthKit, widgets, notifications stay reserved; their rows are recorded n/a-Phase-1 where the matrices ask).
- No monetization work (E1 closed for Phase 1, D8/D19).
- No budget-value edits: 05 §12's numbers are normative; a miss is a task-level blocker with a fix cycle, never a relaxed threshold.
- TASK-049's "would removing any feature simplify without losing emotional value?" is ANSWERED with evidence; any actual removal is owner-gated (product-defining, §36).
- No backend/network/analytics surfaces (none exist; TASK-048 proves it).

## Dependencies

- **In:** TASK-039 + TASK-044 merged (`d460a24`); the TASK-020/024 edge/kit suites (TASK-046's base); ADR-008 (device matrix + deployment targets); ADR-006 N-1 (TASK-050 re-eval); the doc chain 01→02(amended)→03→04→05 + 06 §3.
- **Frozen surfaces stay frozen:** `Sources/MomoCore/`, `Sources/MomoCharacter/`, `Apps/Momo/**`, `Apps/Shared/MomoCopy.xcstrings`, `Momo.xcodeproj/` — any audit finding that would require touching them is escalated to a new adjudicated task, not fixed opportunistically (EPIC-008's discipline).
- **Standing baselines at epic start:** `swift test` 1161/113; MomoKit coverage 90.84 % lines (floor 80); both app builds BUILD SUCCEEDED (pinned sims); MomoWatchUITests 9/9; app UI suite 35/35.

## Tasks

- **TASK-045 — Performance budget verification.** Every 05 §12 row measured with recorded evidence on the pinned device matrix: cold launch ≤ 2.0 s (XCTest launch metrics, smallest device); 60 fps sustained / ≤ 8 ms per frame (device legs → §25 BLOCKED; sim-side no-stutter evidence + the transform-only-rig structural guarantee recorded); iPhone ≤ 150 MB / Watch ≤ 80 MB steady-state/foreground memory (provisional budgets; footprint soak per 04 §7.4 rule 6; the 80 MB row's VERIFY-AT-BUILD resolved against current watchOS norms — measured + adjudicated, never silently rewritten); download ≤ 60 MB + art ≤ 1.5 MB (archive/bundle report; 04 §8.3 re-measure); energy rows (device legs → §25 BLOCKED with the structural no-timers/no-background-work census as the sim-side evidence); Watch restore ≤ ~2 s (the existing TASK-041 timing UI test re-run); play round ≤ 30 s (existing engine core test re-verified); sync cadence on-change-only (log-verified session). A budget miss is a task-level blocker (R-loop: root cause → fix → re-measure), not a note.
- **TASK-046 — §10.5 edge-case matrix execution.** Every 05 §10.5 row executed with recorded evidence: timezone change, DST, date rollover, Watch unavailable, offline device, fresh install, upgrade, long inactivity (7-day fold); notification/Health rows recorded n/a-Phase-1. Builds on the existing TASK-020/024 suites; fills real execution gaps rather than duplicating green tests.
- **TASK-047 — Full accessibility audit (launch-blocking).** Core-loop audit across BOTH devices (onboard, Home, one interaction per family, quest completion, settings, Watch pat): every 03 §10 row passes with evidence; state never color-only; VoiceOver state formula verbatim; Reduce Motion honored everywhere; manual + automated audit evidence; zero open blockers.
- **TASK-048 — Privacy & security review.** Network-traffic audit of a full session shows only the paired link (AC-1); repo/build contains no StoreKit/analytics/location/HealthKit (AC-3); all strings from catalogs (AC-4); privacy manifest accurate ("Data Not Collected"; required-reason APIs VERIFY-AT-BUILD-resolved); entitlements zero (beyond WC transport if any — VERIFY-AT-BUILD-resolved); secrets scan clean. Audit scripts + recorded evidence.
- **TASK-049 — Philosophy & tone QA (§44 final product test).** Every §44 question answered with evidence on a release build (idle aliveness, touch delight, Watch independent value, offline posture, no guilt/manipulation, iPhone/Watch consistency, a11y, battery, the removal question); banned-vocabulary scan green; the §15 bad-copy list swept; static tone test green.
- **TASK-050 — Release readiness.** §35 DoD checklist signed item-by-item; E4 name clearance executed (§36 escalation with search results if any risk); ADR-006 N-1 deployment widening re-evaluated once with the pairing-matrix check; App Store metadata + privacy label "Data Not Collected" drafted; screenshots/previews prepared; TestFlight build recorded (submission owner-gated); release checklist recorded.

## Acceptance Criteria

1. Every 05 §12 budget row carries recorded measured evidence — number + harness + device identity — or an honest §25 BLOCKED record with raw capture routed to the owner. No sim-claimed device numbers anywhere.
2. Every 05 §10.5 edge row executed with evidence, including the explicit n/a-Phase-1 records.
3. The 03 §10 accessibility audit passes with zero open blockers; evidence recorded (manual + automated).
4. TASK-048's AC-1/AC-3/AC-4 + manifest/entitlements/secrets checks all evidenced clean.
5. §44 answered question-by-question with evidence; tone scans green; the removal question answered and (if action needed) owner-escalated.
6. The §35 DoD checklist signed item-by-item in the TASK-050 release record.
7. Any budget/audit miss followed the blocker discipline: recorded → root-caused → fixed via the §11 loop → re-measured green.
8. Standing baselines never regress at any task's handoff: 1161/113 (or better), MomoKit ≥ 80 % lines, both builds green, UI suites green, frozen surfaces diff-EMPTY, zero new entitlements/Info.plist keys, zero timers, D20 clean, catalog law (epoch 4, zero new copy keys).

## Test Requirements

- Per-task gates per CLAUDE.md §19 at every handoff; the full §19 battery (suite + both builds + UI suites) at minimum.
- Measurement harnesses: XCTest launch metrics; memory footprint/allocations tooling; archive/bundle size reports; `xcrun xcresulttool` for UI counts; `xctrace` for traces (raw multi-MB traces stay OUT of the repo — commands + summarized evidence committed).
- New structural guards (if any) follow the guard-family discipline: comment-stripped, both-direction fixtures, non-vacuous real-tree runs, exactly-one-red mutation bites with sha256-restores.
- Test-impact rule: an audit that changes no code changes no tests; measurement scripts/commands are recorded in task files as evidence, committed as text.

## Definition of Done

- All six tasks DONE per CLAUDE.md §18 (requirements, acceptance criteria, tests, independent review APPROVED, findings addressed, atomic TASK-ID commits, pushed, status.md truthful).
- Epic acceptance criteria 1–8 satisfied with repo-recorded evidence.
- The §35 DoD checklist signed; release posture recorded; owner-gated items (device-pass legs, E4, TestFlight, store submission) packaged as a single owner handoff in status.md.
- Epic merged to `main` per §14 (fetch-first remainder rule honored).

## Status

**IN PROGRESS (1/6)** — TASK-045 DONE (2026-09-12; review APPROVED_WITH_MINOR_NOTES, 8 findings dispositioned — F-1 fixed at closeout; atomic commit `c43c92b`, pushed `2996fa1..c43c92b`; device legs BLOCKED per §25 → owner device-pass backlog). TASK-046 contract READY (`.claude/tasks/active/TASK-046-edge-matrix.md`); dispatch pending.
