# TASK-048 — Privacy & security review (05 §11; FR-20 Privacy/AC-1/AC-3/AC-4; NFR-5; CLAUDE.md §27)

## Parent Epic

EPIC-009 — Polish, QA & Release Readiness (epic file `.claude/tasks/epics/EPIC-009-release-readiness.md`, TASK-048 row). Normative sources: `docs/architecture/05-technical-architecture.md` §11 (Privacy Architecture, :641-665 — data inventory, stance, deletion story, entitlements) + `docs/product/02-mvp-prd.md` FR-20 Privacy bullet + AC-1/AC-3/AC-4 (:373-382) + NFR-5 (:394) + CLAUDE.md §27 + project.md §35.

## Objective

Execute the pre-release privacy & security review: every 05 §11 + FR-20 privacy commitment verified with recorded evidence — the only outbound channel is the paired-device link (AC-1), the repo/build carries zero monetization/analytics/location/HealthKit surface (AC-3), all strings resolve from catalogs (AC-4), the privacy-manifest/entitlements/secrets posture matches the "Data Not Collected" stance — with real gaps CLOSED where the freeze allows and frozen-surface needs escalated. DONE requires zero open security blockers.

## Context

- Standing baselines at task start: post-TASK-047's refreshed counts (refresh this contract's numbers at dispatch from `.claude/tasks/status.md` Test/Build Status).
- **Normative 05 §11 content (re-derive at source; orientation only):** §11.1 the complete data inventory (pet name / UUID+createdAt NOT mirrored / band words / bond ledger / settings / the intent journal with its non-identifier `watchSessionEpoch` — "No accounts, no contacts, no location, no health data, no advertising IDs, no device fingerprints"); §11.2 the stance (all on-device; ONLY outbound channel = paired WC link; no third-party SDKs; privacy label "Data Not Collected"; `PrivacyInfo.xcprivacy` no-tracking declaration; required-reason APIs none/minimum — VERIFY-AT-BUILD; file protection = platform defaults complete); §11.3 the deletion story (erase → store-tree deletion + reset marker + Watch wipe; the offline-Watch honest propagation limit); §11.4 entitlements Phase 1 = ZERO (WC transport required nothing — VERIFY-AT-BUILD resolved at TASK-040 R4; no Info.plist permission strings, so no dialog can appear).
- **FR-20 Privacy + ACs:** AC-1 network-traffic audit of a full session (onboard → interact → sync → settings) shows traffic ONLY between paired iPhone and Watch; AC-3 repo/build contains no StoreKit/analytics/location/HealthKit references; AC-4 all user-visible strings from catalogs (no string literals in views); D8 zero monetization code paths (no StoreKit, no paywalls, no ads).
- **NFR-5 verification:** "privacy manifest accurate; disclosures match implementation".
- **Contract-time census (starting pointers + verified facts — VERIFY AT BODY LEVEL at execution, never trust this contract's numbers):**
  - VERIFIED CLEAN 2026-09-12 by the orchestrator: ZERO `import` statements of StoreKit/Firebase/Mixpanel/Amplitude/AppsFlyer/CoreLocation/HealthKit/AdSupport across `Apps/` + `Sources/`; zero `CODE_SIGN_ENTITLEMENTS` in the pbxproj; zero `*.entitlements` files; zero `UsageDescription` keys; both `Apps/Momo/Info.plist` + `Apps/MomoWatch/Info.plist` carry no permission strings; the transport twins import exactly `Foundation` + `WatchConnectivity` + `os` (both files); raw-grep residue is 14 comment/prose mentions (Phase-2 reservation comments) + 18 `breathAmplitude` false-positives against the Amplitude SDK name — **the word-boundary lesson for any standing scan**.
  - Prior evidence to CITE (body-verify pointers): TASK-045 R9's paired-sim WC-only traffic census + `AppModelPlan.swift:252` on-change gate; TASK-040 R4's 7-WC-header sweep (zero entitlement/capability/background-mode requirements; iPhoneOS `WCSession.h` byte-identical to sim SDK); TASK-045 review §3.7's zero-`UIBackgroundModes` census across plists + pbxproj; `Tests/MomoCoreTests/EnginePurityScanTests` (the D-R1 import-purity scanner over MomoCore); the catalog-law family (`CatalogCopyLawTests`, per-feature `*CopyKeyTests`, `BannedVocabularyScan`, `rawKeysPinned`).
- **Candidate REAL GAPS (R0 must verify each; hypotheses, NOT verdicts):**
  - (a) **`PrivacyInfo.xcprivacy` DOES NOT EXIST anywhere in the repo** vs 05 §11.2's manifest requirement — REAL gap, and landing it requires target membership in `Momo.xcodeproj/` (verified: ZERO `PBXFileSystemSynchronizedRootGroup` in the pbxproj — classic explicit file references) which is **FROZEN**. Disposition: draft the manifest content + the exact two-target registration recipe as evidence artifacts, record **BLOCKED-pending-adjudication**; the orchestrator mints the dedicated landing task after review. Never touch the pbxproj in-task.
  - (b) **No named network-traffic audit test exists** vs 05 §11.2's "verified by a network-traffic audit test in EPIC-002" — the citation appears unfulfilled by name (EPIC-002 shipped harness/scanners, no traffic test). This is BOTH an execution gap (AC-1) and a **doc-erratum candidate** (record it; do NOT edit the doc in-task — orchestrator housekeeping per the OBS-C precedent).
  - (c) **AC-3 has no STANDING scan** — the clean census is one-shot greps, unpinned. Candidate: a comment-stripped, word-boundary-precise banned-token guard over `Apps/` + `Sources/` production sources (guard-family discipline).
  - (d) **AC-4's "no string literals in views" has no named scanner** over `Apps/**` view files (the catalog-law tests pin key RESOLUTION, not view-literal absence; `WatchQuestScan.swift:95` shows the house pattern for asserting on view source). Candidate guard.
  - (e) **No secrets scan exists** — CLAUDE.md §27 mandates the check. Candidate: a standing scan (banned patterns: `sk-`, `AKIA`, `BEGIN.*PRIVATE KEY`, `password\s*=`, `api[_-]?key` assignments…) over the repo working tree, excluding `.git/` and fixtures that intentionally embed test constants (document any allowlist).
  - (f) AC-1's RUNTIME leg on this environment: the honest sim-side shape is (i) the structural census — zero networking imports means the app processes cannot open sockets at all, WC is the only channel by construction (load-bearing); corroborated by (ii) a paired-sim runtime capture during a scripted full session (`lsof -i -n -P` on the app PIDs + a `nettop -P -L 1` sample, text evidence) — record exactly what was observed, including that sim radios cannot prove real-network egress; the true-device runtime leg is attempt-then-BLOCKED per §25 → owner device-pass backlog.
- **Deletion story (§11.3) and the data inventory (§11.1)** are verified by mapping to EXISTING tests (the erase/reset E2Es of TASK-044 R2; the not-mirrored fields via the DTO tests of TASK-041) — R0 maps them; no duplication (R5's no-duplicate clause in the epic's test rules).

## Requirements

- **R0 — re-derive the privacy checklist (mandatory first; independence discipline).** From 05 §11 + FR-20 Privacy/AC-1/AC-3/AC-4 + NFR-5 + CLAUDE.md §27 ALONE (before reading Implementation Notes), build the complete checklist: data inventory rows, stance claims, deletion story, entitlements/permissions zero, AC-1/AC-3/AC-4, manifest, secrets. The checklist lands in Implementation Notes. THEN body-verify existing coverage: every ALREADY-COVERED claim carries a name-precise `file:line` pointer whose BODY was read. Verdicts: ALREADY-COVERED / GAP / RUNTIME-LEG (with its §25 disposition) / BLOCKED-pending-adjudication (frozen surface).
- **R1 — close the real gaps the freeze allows (Tests/ only).** Expected shapes (verify, then implement only what is real): the AC-3 banned-token standing guard, the AC-4 view-literal census guard, the secrets scan guard — each comment-stripped, word-boundary-precise, non-vacuous per house style (a violation fixture fails it; one mutation bite exactly-one-red + sha256-restored), with one-line provenance comments citing their FR-20/§11 clause. Word-boundary precision is CONTRACTED (the `breathAmplitude`/Amplitude collision is the named anti-example).
- **R2 — AC-1 execution:** the structural census (imports/APIs) as the load-bearing evidence + the paired-sim runtime capture as corroboration; scripted full session (onboard → interact → sync → settings) on the paired sims; raw capture stays OUT of the repo (commands + summarized evidence committed, per the epic's harness rules); any true-device leg attempt-then-BLOCKED per §25 with raw capture → owner backlog. Record the §11.2 doc-erratum candidate (the EPIC-002 traffic-test citation) as a finding — never edit docs in-task.
- **R3 — the privacy-manifest adjudication package:** draft `PrivacyInfo.xcprivacy` content (no tracking, no collection; NSPrivacyCollectedDataTypes empty per the "Data Not Collected" stance; NSPrivacyAccessedAPITypes per what the VERIFY-AT-BUILD check finds against the CURRENT required-reason list) + the exact pbxproj registration recipe for both app targets, as TEXT artifacts in the task file/evidence. Record BLOCKED-pending-adjudication; the ORCHESTRATOR mints the landing task after review (freeze discipline).
- **R4 — freeze discipline:** `Sources/MomoCore/`, `Sources/MomoCharacter/`, `Apps/Momo/**`, `Apps/Shared/MomoCopy.xcstrings`, `Momo.xcodeproj/` stay diff-EMPTY. A finding that would require touching them is recorded + escalated, never fixed opportunistically. `Tests/` and `Apps/MomoWatch/**` are not frozen (a Watch-side privacy defect may be fixed in-task with full gates — minimum diff).
- **R5 — non-vacuity + honesty (§25):** every new guard carries a violation fixture + a mutation bite exactly-one-red with sha256 restores; every evidence leg surface-labeled (sim + OS; paired-sim topology stated); no device claims; the static-vs-runtime split recorded truthfully per AC.
- **R6 — §19 gates at session end:** `swift test` green (exact counts); both builds BUILD SUCCEEDED; UI suites green if touched. Repo hygiene: porcelain shows exactly the expected task-doc entries + your test files; stash 0.
- **R7 — disk discipline:** `df -h /` before heavy legs; keep evidence text-only and small; below ~200 MiB free, stop and record.

## Files / Areas Likely Affected

- `Tests/MomoKitTests/` or `Tests/MomoCoreTests/` (new scan guards + their Support files), this task file, `.claude/tasks/evidence/TASK-048/`.
- Production surfaces expected UNTOUCHED (all frozen per R4). The privacy manifest lands in a SEPARATE adjudicated task, not here.

## Dependencies

- TASK-039 + TASK-044 DONE (epic row). Runs after TASK-047 in the sequence; its guards inherit the guard-family conventions from the Watch scan family.

## Constraints

- All agents Jupiter. The implementer does NOT commit (§9).
- Scope control (§22/§24): audit + close gaps + adjudication package; no features; no doc edits (errata candidates are findings); the privacy label drafting itself is TASK-050's artifact — this task records the stance + pointers only.
- Verify every claim at source; report actual state (§25).

## Acceptance Criteria

- AC-1: the R0 checklist exists, complete over 05 §11 + FR-20 privacy ACs + NFR-5 + CLAUDE.md §27, every coverage claim body-verified.
- AC-2: FR-20 AC-1 evidenced (structural census + paired-sim runtime capture; device leg honestly BLOCKED if unobtainable), AC-3 evidenced clean by a STANDING green guard, AC-4 evidenced (existing law family mapped + the view-literal guard green if the gap is real).
- AC-3: the manifest adjudication package exists (draft + recipe + BLOCKED record); entitlements/permission-strings zero re-verified with recorded commands.
- AC-4: the secrets scan green with its allowlist documented (or violations escalated immediately — a real secret is a security BLOCKER: STOP, surface, never commit).
- AC-5: the explicit verdict recorded: ZERO OPEN SECURITY BLOCKERS (or the blocker list — which gates DONE and triggers the §11 loop / owner escalation).
- AC-6: all §19 gates green at the final tree; frozen surfaces diff-empty; the §28 handoff complete and truthful.

## Required Tests

- New: the standing guards R1 defines (expected 2-4 tests + Support scanners; each with violation fixture + bite).
- Standing: `swift test`; both builds; UI suites if touched.

## Review Requirements

- Independent fresh §10/§33 reviewer (Jupiter, not primed): re-derives the privacy checklist from 05 §11 + FR-20 BEFORE reading Implementation Notes; body-reads every pointer; re-runs the greps/censuses personally (their own commands, not the implementer's verbatim); verifies each new guard's bite (exactly-one-red, sha256-restored); re-runs all gates. Findings in `.claude/tasks/reviews/REVIEW-TASK-048.md`; CHANGES_REQUIRED/BLOCKED gates the commit.

## Git Requirements

- Implementer: NO commit. Orchestrator: one atomic commit after review approval — `<type>(<scope>): TASK-048 <summary>` — carrying the task record, REVIEW-TASK-048, the evidence set, and the new guards; push; status.md updated. The manifest landing task is minted as a SEPARATE adjudicated task with its own commit.

## Status

READY-pending-dispatch (contract authored 2026-09-12 during the TASK-046 run; dispatch follows the TASK-047 cycle; baselines refresh at dispatch).

## Implementation Notes

(filled by the implementer)

## Reviewer Findings

(filled at review)

## Completion Evidence

(filled at closeout)

## Handoff protocol

End the final report with a freshly-typed marker line: the word HANDOFF-COMPLETE, one space, then TASK-048. Type it fresh in your own final message — exactly once, on its own line, at column 0, as the last line of the handoff.
