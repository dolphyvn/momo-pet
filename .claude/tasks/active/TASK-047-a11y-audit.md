# TASK-047 — Full accessibility audit (03 §10; FR-20 AC-2; NFR-6 — launch-blocking)

## Parent Epic

EPIC-009 — Polish, QA & Release Readiness (epic file `.claude/tasks/epics/EPIC-009-release-readiness.md`, TASK-047 row). Normative sources: `docs/design/03-ux-architecture.md` §10 (Accessibility Intent per Screen, :425-441) + `docs/design/04-character-system.md` §3.5 (the binding VoiceOver formula, :244-247) + FR-20 AC-2 (audit scope) + NFR-6 (launch-blocking).

## Objective

Execute the FULL accessibility audit demanded by 03 §10's audit-scope sentence — "full core loop — onboard, Home, one interaction per family, quest completion, settings, Watch pat — passes manual + automated accessibility audit before Phase 1 ships (NFR-6: launch-blocking)" — and land its verdict: every 03 §10 commitment verified per screen with recorded evidence, automated audit suites green, real gaps CLOSED where the freeze allows, and anything requiring a frozen-surface change escalated for adjudication. DONE requires ZERO open blockers.

## Context

- Standing baselines at task start (post-TASK-045): `swift test` 1161/113 + TASK-046's additions; both builds BUILD SUCCEEDED on pinned sims; `MomoWatchUITests` 9/9; app UI suite 35/35 (incl. `MomoAccessibilityAuditUITests` 8/8).
- **Normative 03 §10 content (re-derive at source; this summary is orientation, not authority):** global commitments (never color-only; ≥ 44 pt targets; ≥ 4.5:1 text contrast on both grounds; ALL strings in String Catalogs — D12/FR-20 AC-4); the VoiceOver state-in-words template; the per-screen table rows S1–S3 onboarding / S4 Home (AC-1a default-type no-scroll vs AC-1b accessibility-size scroll with zero function loss) / S5 Room / S6 Settings / S6.1 Rename / S6.2 Erase alert / W1 Watch glance (its own composite formula: "Momo feels {mood} and has {energy}. {Stage}. Today's wish: {wish}. Pat button."); the audit-scope sentence above.
- **04 §3.5 binding formula:** "{Name} feels {mood word} and {energy phrase}" + bond stage when relevant — energy phrases are verb phrases ("has plenty of energy"…); Wistful announced as "quiet".
- **Known owner-gated item — DO NOT "fix" copy (REVIEW-TASK-039 F-2):** the SHIPPED state-in-words template reads "{stage}. {descriptor}." without 03 §10's "You two are" carrier. The audit pins encode the SHIPPED strings (the recorded evidence is what VoiceOver actually reads). Audit against shipped strings; the template delta stays an OPEN owner copy decision — never edited in this task (§22/§24; `Apps/Shared/MomoCopy.xcstrings` is frozen anyway).
- **Existing coverage (name-precise starting pointers — VERIFY AT BODY LEVEL, never trust this contract's numbers blindly):** `MomoUITests/MomoAccessibilityAuditUITests.swift` — `testS1MeetSurfacesAuditClean` / `testS2Name…` / `testS3Enter…` / `testS4Home…` / `testS5Room…` / `testS6Settings…` / `testS62EraseAlertAuditsClean` (:129-210) + `testStatusRowComposesTheStateInWordsTemplate` (:242); `Tests/MomoUIColorContrastTests` (the 4 body-text pairs ≥ 4.5:1 both grounds, TASK-039); `Tests/MomoCharacterTests/MomoReduceMotionTwinTests` (character-level RM twin law — the ENGINE half; UI-level RM legs are separate); `Apps/MomoWatch/GlanceView.swift:72-82` the composite VoiceOver element (children ignored) + :145 the pat label; `MomoWatchUITests` fixture flows assert ≥ 44 pt targets (TASK-041); D12 catalog law tests.
- **Candidate REAL GAPS (R0 must verify each; hypotheses, NOT verdicts):**
  - (a) **Per-family interaction legs** — audit scope demands "one interaction per family" (touch/feed/play/care + the refusal-warm and stir paths) with reactions ANNOUNCING their spoken lines (`momo.line.react.*`, UX-8); the existing suite audits SURFACES, likely not the per-family VoiceOver leg.
  - (b) **Quest-completion leg** — in audit scope; likely unasserted as an accessibility flow.
  - (c) **W1 composite VERBATIM** — whether the Watch glance label is asserted against 03 §10's W1 formula (words for mood/energy/stage, wish spoken, "Pat button.") anywhere.
  - (d) **Dynamic Type** — AC-1a (default type, smallest device → no scroll) and AC-1b (accessibility sizes → standard scroll, ZERO function loss; canvas flexes with preserved minimum); S1–S3 reflow; S6 native list. Likely the largest real gap — no named DT test found at contract time.
  - (e) **UI-level Reduce Motion** — S1 greeting/meet → single gentle pose; S4 looping idle → subtle static poses, eye-follow → single brief glance; M1–M3 → crossfade + haptic. The twin law covers the engine half; an RM-toggle E2E leg may be missing.
  - (f) **VoiceOver ORDERING** — S1–S3 "canvas described, then line, then button"; S4 status row → action row → quest card semantics.
  - (g) **REVIEW-TASK-039 N-2 ride-along (contracted):** the 44-pt assert on quest rows — TASK-047 IS the audit-suite touch this item waited for; fold it in.
- **Manual-audit honesty:** §10 demands "manual + automated". On sims, manual legs mean what can honestly be done (Accessibility Inspector / xcresult screenshots inspected / spoken-line playback logs); anything genuinely requiring human judgment or a device (e.g., Dynamic Type on real hardware, wrist ergonomics) is recorded attempt-then-BLOCKED per §25 → owner device-pass backlog. Never sim-claim a manual leg.

## Requirements

- **R0 — re-derive the §10 checklist (mandatory first; independence discipline).** From `03-ux-architecture.md` §10 + `04-character-system.md` §3.5 ALONE (before reading the audit suite bodies), build the complete checklist: the 4 global commitments + one row per screen (S1–S3, S4 incl. AC-1a/AC-1b, S5, S6, S6.1, S6.2, W1) across the 5 columns (Dynamic Type / VoiceOver / Reduce Motion / Color-independence / Targets-contrast) + the audit-scope loop legs. The checklist lands in Implementation Notes. THEN body-verify existing coverage against it: every claim of "already covered" carries a name-precise `file:line` pointer whose BODY was read and confirmed. Verdicts: ALREADY-COVERED / GAP / MANUAL-LEG (with its §25 disposition).
- **R1 — close the real gaps the freeze allows.** New/extended automated tests in the correct suites (`MomoUITests/` app UI target; `Tests/MomoKitTests/` or `Tests/MomoCharacterTests/` for unit-level pins; `MomoWatchUITests` for the Watch leg). Each new test carries a one-line provenance comment citing its §10 row/column. Expected shapes (verify, then implement only what is real):
  - **R1a** per-family interaction + quest-completion + (if missing) W1-composite-verbatim legs — via accessibility labels/identifiers already present; NO production edits to frozen surfaces.
  - **R1b** the Dynamic Type legs — AC-1a no-scroll at default type on the smallest pinned iPhone sim; AC-1b function-preservation at accessibility sizes (UI test with `launchArguments` UIContentSizePreference or equivalent honest mechanism; record exactly what the mechanism does).
  - **R1c** the UI-level RM leg (toggle honored on the surfaces §10 lists).
  - **R1d** the N-2 ride-along: 44-pt assert on quest rows.
- **R2 — freeze discipline (epic constraint):** `Sources/MomoCore/`, `Sources/MomoCharacter/`, `Apps/Momo/**`, `Apps/Shared/MomoCopy.xcstrings`, `Momo.xcodeproj/` stay diff-EMPTY. An audit finding that would require touching them is a FINDING, escalated: record it in Implementation Notes as BLOCKED-pending-adjudication (with the §10 row, the evidence, and the proposed fix shape) and end the handoff — the orchestrator mints an adjudicated fix task; never fix opportunistically. `Apps/MomoWatch/**` and `Tests/` are NOT frozen (a Watch-side a11y defect may be fixed in-task with the §19 gates + review).
- **R3 — launch-blocking verdict (NFR-6):** the task's bottom line is an explicit audit VERDICT recorded in Implementation Notes: **ZERO OPEN BLOCKERS** required for DONE. A blocker is any §10 commitment that fails against shipped behavior on the pinned sims and cannot be closed within the freeze. Non-blocker notes (improvements, owner-gated copy deltas like F-2) are listed separately and do not gate.
- **R4 — non-vacuity + honesty (§25):** every new test non-vacuous per house style (bite or negative control, or a truthful rationale); every leg surface-labeled (sim + OS); no device claim; the manual-vs-automated split recorded truthfully per leg.
- **R5 — §19 gates at session end:** `swift test` green (exact counts); both builds BUILD SUCCEEDED; the app UI suite green (baseline 35 + TASK-046's additions + yours); `MomoWatchUITests` green (9/9 + additions) if touched. Repo hygiene: porcelain shows exactly the expected task-doc entries; stash 0.
- **R6 — disk discipline:** the host volume is at ~critical free space — `df -h /` before heavy legs; UI suites are the expensive legs — run them once, evidence from xcresult summaries; text-only evidence under `.claude/tasks/evidence/TASK-047/`; below ~200 MiB free, stop and record (do not wedge the host).

## Files / Areas Likely Affected

- `MomoUITests/MomoAccessibilityAuditUITests.swift` (+ possibly siblings in `MomoUITests/`), `MomoWatchUITests/`, `Tests/MomoKitTests/` or `Tests/MomoCharacterTests/` (unit-level pins), this task file, `.claude/tasks/evidence/TASK-047/`.
- Production surfaces expected UNTOUCHED (all frozen per R2). If R0 proves a Watch-side (`Apps/MomoWatch/**`) a11y defect, that surface MAY change in-task with full gates — minimum diff.

## Dependencies

- TASK-039 (the 8-test audit suite + contrast pins) DONE; TASK-044 (Watch a11y surfaces incl. the composite + RM scan work) DONE; TASK-046 (running now — its UI additions land before this task's dispatch; the contract's baselines refresh at dispatch).

## Constraints

- All agents Jupiter. The implementer does NOT commit (§9).
- Scope control (§22/§24): execute and close the audit; no new features; no copy changes (catalog frozen; F-2 and any wording deltas are owner items).
- Verify every claim at source; report actual state (§25).

## Acceptance Criteria

- AC-1: the R0 checklist exists, complete over 03 §10's global commitments + all seven screen rows × five columns + the audit-scope legs, every coverage claim body-verified.
- AC-2: every checklist item lands ALREADY-COVERED (pointer + fresh green run), GAP→closed (new test, non-vacuous), MANUAL-LEG (honest §25 disposition), or BLOCKED-pending-adjudication (frozen-surface finding, escalated).
- AC-3: the explicit verdict "ZERO OPEN BLOCKERS" (or the blocker list, if any — which gates DONE and triggers adjudication).
- AC-4: all §19 gates green at the final tree; exact counts recorded.
- AC-5: frozen surfaces diff-empty; zero copy changes; the F-2 delta and any new owner items recorded as OPEN, never "fixed".
- AC-6: the §28 handoff is complete and truthful.

## Required Tests

- New: whatever R0's real gaps demand (expected 3-10 tests across the audit/UI/Watch/unit suites — N-2's quest-row assert is contracted regardless).
- Standing: `swift test`; both builds; app UI suite; Watch UI suite if touched.

## Review Requirements

- Independent fresh §10/§33 reviewer (Jupiter, not primed): re-derives the §10 checklist from the docs BEFORE reading Implementation Notes or the audit suite; body-reads every coverage pointer; hunts misattributions and non-vacuity (own probes; sha256 restores); re-runs `swift test` + both builds + the touched UI suites. Findings in `.claude/tasks/reviews/REVIEW-TASK-047.md`; CHANGES_REQUIRED/BLOCKED gates the commit.

## Git Requirements

- Implementer: NO commit. Orchestrator: one atomic commit after review approval — `<type>(<scope>): TASK-047 <summary>` — carrying the task record, REVIEW-TASK-047, and the evidence set; push; status.md updated.

## Status

READY-pending-dispatch (contract authored 2026-09-12 while TASK-046 runs; dispatch follows TASK-046's closeout; baselines refresh at dispatch).

## Implementation Notes

(filled by the implementer)

## Reviewer Findings

(filled at review)

## Completion Evidence

(filled at closeout)

## Handoff protocol

End the final report with a freshly-typed marker line: the word HANDOFF-COMPLETE, one space, then TASK-047. Type it fresh in your own final message — exactly once, on its own line, at column 0, as the last line of the handoff.
