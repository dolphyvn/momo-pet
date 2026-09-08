# REVIEW-TASK-008 — Verify Toolchain & Pin Deployment Targets (ADR-008)

- **Task**: TASK-008 (EPIC-002 gate) — `.claude/tasks/active/TASK-008-toolchain-pins.md`
- **Deliverable under review**: `.claude/tasks/decisions/ADR-008-bootstrap-pins.md` (ACCEPTED) + task-file Implementation Notes
- **Reviewer**: fresh independent adversarial reviewer (did not write the work; CLAUDE.md §10/§33)
- **Date**: 2026-09-08
- **Repo state at review**: branch `feature/EPIC-002-foundation` @ `80a859a` (no commits by implementation agent); working tree = task file modified + ADR-008 added (plus pre-existing untracked `.DS_Store`)

## Review Method (independently re-run — not taken from the task file)

The following were re-executed by this reviewer during the review:

1. `xcodebuild -version` → `Xcode 26.6` / `Build version 17F113` — **matches recorded evidence exactly**.
2. `swift --version` → `swift-driver version: 1.148.6 Apple Swift version 6.3.3 (swiftlang-6.3.3.1.3 clang-2100.1.1.101)` / `Target: arm64-apple-macosx26.0` — **exact match**.
3. `xcodebuild -showsdks` → **byte-identical** to evidence 2, including the anomalous **duplicated `macOS 26.5 -sdk macosx26.5` line** — which I initially suspected was a transcription/fabrication artifact; it is real and recorded faithfully. Strong verbatim-authenticity signal.
4. `xcrun simctl list runtimes` → identical (iOS 26.5 build 23F77, watchOS 26.5 build 23T570).
5. `xcrun simctl list devices available` → identical, **including all UDIDs**.
6. `xcodebuild -checkFirstLaunchStatus` → exit 0, no output — matches.
7. **Swift Testing probe reproduced from scratch** in a fresh `/tmp` package (outside the repo): `import Testing` + `#expect(true)` under `swift test --list-tests` → exit 0 with the **same output shape**: identical step line `[8/11] Compiling ProbeTests ProbeTests.swift`, the identical macro note `'#expect(_:_:)' will always pass here; use 'Bool(true)' to silence this warning (from macro 'expect')`, `Build complete! (…s)`, and the identical list line `ProbeTests.swiftTestingFrameworkIsAvailable()`. The framework claim is authenticated (a fabricated output could not match this precisely).
8. **Governing-screen dimensions re-measured**: booted iPhone 17e and Apple Watch SE 3 (40mm) by UDID, `simctl io screenshot` + `sips` → **1170×2532** and **324×394 px** — exact match to evidence 6d. Both shut down cleanly.
9. **Device-support probes beyond the implementation's evidence** (the crux of MAJOR-1):
   - `xcrun simctl create … "com.apple.CoreSimulator.SimDeviceType.iPhone-SE-3rd-generation" "com.apple.CoreSimulator.SimRuntime.iOS-26-5"` → **accepted and booted under Xcode 26.6**; screenshot = **750×1334 px (375×667 pt)**. Device deleted after the probe.
   - `xcrun simctl create … "com.apple.CoreSimulator.SimDeviceType.Apple-Watch-SE-40mm-2nd-generation" "com.apple.CoreSimulator.SimRuntime.watchOS-26-5"` → accepted and booted; screenshot = **324×394 px**. Device deleted after the probe.
10. `git log` / `git status --short` → HEAD `80a859a` (matches the task file's claimed execution-time branch state), no new commits, no unexpected repo files. `git diff` of the task file vs HEAD shows exactly **2 removed lines** (the Status value; the `### Verdict` heading renamed) — BLOCKED history otherwise preserved verbatim; successful run appended.
11. Ground truth cross-read: 05 §2.4, §10/§10.1/§10.6, §12, Appendix A/B; ADR-001, ADR-006; PRD FR-2 AC-1a (02:239–242); delivery plan §3 EPIC-009, §4.1, §7 R1/R4, §8.3, §9.

(Web verification of Apple's published device list was unavailable during the review — WebSearch/WebFetch backend errors — so the toolchain-pairing probes in item 9 stand in for it; they are Apple's own compatibility encoding and are independently reproducible.)

## Findings

### MAJOR-1 — iPhone-small pin is wrong: the "supersedes 4.7\" SE-class" claim is refuted by the toolchain; AC-1a's governing device is mis-pinned

**Evidence in the artifacts under review:**
- `ADR-008-bootstrap-pins.md:4` (Status): "specifically supersedes 05 §12's 'expected 4.7\" SE-class' smallest-iPhone expectation"
- `ADR-008-bootstrap-pins.md:14` (Decision 4): "iPhone small … `iPhone 17e` — smallest of the visible generation set"
- `ADR-008-bootstrap-pins.md:19`: "the smallest device run by the pinned iOS 26 generation in this toolchain is the iPhone 17e"
- `TASK-008-toolchain-pins.md:243` (pin table): "supersedes 05 §12's 'expected 4.7\" SE-class' placeholder"
- `TASK-008-toolchain-pins.md:257` (Appendix B item 3): "RESOLVED … smallest = iPhone 17e"

**Ground truth:** 05 §12 defines the small slot as "**the smallest device run by the pinned iOS generation (expected 4.7\" SE-class)**"; PRD FR-2 AC-1a (`02-mvp-prd.md:241`) governs no-scroll on "the smallest supported device"; §12 launch/energy budgets are measured "on the smallest devices"; §10.6 Dynamic Type sizing inherits the same referent.

**Refutation:** The Xcode 26.6 toolchain **accepts and boots an iPhone SE (3rd generation) on the pinned iOS 26.5 runtime at 750×1334 px (375×667 pt)** — see Review Method item 9 (one command, independently reproducible). The 4.7-inch class therefore demonstrably *runs the pinned generation in this very toolchain*, so 05 §12's expectation was **not** superseded, and the 17e is not "the smallest device run by the pinned iOS 26 generation". The inference conflated "smallest in the default auto-created simulator list" (`xcrun simctl list devices available`, which contains only current-gen devices) with "smallest device run by the pinned generation" — those are different sets. Note the SE-class viewport is 375×667 pt vs the 17e's 390×844 pt: the no-scroll budget differs by ~26 % of screen height, so this is not a cosmetic difference; every downstream consumer (TASK-009 simulator set, EPIC-007 UI tasks' AC-1a checks, TASK-045's launch/energy measurement devices) inherits the wrong referent.

**Root cause (evidence-class error, CLAUDE.md §25-adjacent):** The agent showed good §25 hygiene in *refusing* to assert physical diagonals from memory, but then asserted a device-support fact from an unverified inference (default simulator availability) without consulting Apple's supported-device documentation or probing the device-type/runtime pairing. A correct conclusion by luck would still have been an unsound decision record; here the conclusion itself is wrong.

**Suggested fix (either):**
1. Re-pin iPhone-small to **iPhone SE (3rd generation)** — measure it with the same screenshot probe (750×1334 px / 375×667 pt) and record it; update ADR-008 Decision 4 + the Status supersession sentence, the task-file pin table row, and Appendix B item 3; restate the Consequences referents (AC-1a, launch/energy) accordingly. or
2. If the owner intends the support matrix to cover **only current-generation hardware**, record that as an **explicit owner decision** (it is product-defining scope — CLAUDE.md §36), not as a supersession "from recorded evidence". The ADR as written dresses a product-scope choice up as a bootstrap measurement.

Watch side verified unaffected: the oldest supported 40 mm watch (SE 2nd generation) boots on watchOS 26.5 at 324×394 px — pixel-identical to SE 3 (40 mm) — so the ADR-001 ~32 pt glyph-governing geometry stands (though the same flawed inference pattern is present there; only its immateriality is coincidental).

### MINOR-1 — ADR-008 implements a policy whose own record still reads PROPOSED

`ADR-006-deployment-targets.md:4` Status line: "PROPOSED — under review (TASK-006). Becomes ACCEPTED upon REVIEW-TASK-006 approval." Delivery plan §9 records REVIEW-TASK-006 as APPROVED, so ADR-006's status line is stale (pre-existing, outside this task's diff). ADR-008 (ACCEPTED) cites ADR-006 as its governing policy without flagging this. **Fix owner: orchestrator** — reconcile ADR-006's Status line to ACCEPTED (with pointer to REVIEW-TASK-006) so a fresh agent reading ADR-008's lineage isn't sent to a "PROPOSED" source.

### MINOR-2 — Silent task-id correction: ADR-006/05 §2.4 say "(TASK-007)" for the N-1 re-evaluation; ADR-008 says TASK-050

ADR-006 (`ADR-006-deployment-targets.md:10`) and 05 §2.4 both write "re-evaluated once at release planning (TASK-007)". The repo's TASK-007 is the Intake Obligation task; the backlog of record assigns the N-1 re-evaluation (with pairing-matrix check) to **TASK-050** (delivery plan EPIC-009 row: "N-1 deployment widening re-evaluated once (ADR-006) with pairing-matrix check"; §7 R13). TASK-008/ADR-008 use TASK-050 — **correct** per the delivery plan — but they correct the stale reference **silently**. A fresh agent following ADR-006's literal text would go to the wrong task. **Suggested fix:** add one line to ADR-008's Context or Decision 6: "(ADR-006's text says 'TASK-007' — pre-delivery-plan numbering; the backlog of record, delivery plan TASK-050/§7 R13, owns the re-evaluation.)"

### NITPICK-1 — Pairing-rule wording: "same-generation pairs only" vs the operative ≥ formulation

`ADR-008-bootstrap-pins.md:12` defines a supported pair as "(iPhone ≥ 26.0) + (Watch ≥ 26.0)" yet labels it "same-generation pairs only"; the ≥ formulation admits future mixed pairs (e.g. 27/26). Immaterial in Phase 1 (the matrix is re-checked at TASK-050), but "both ≥ 26.0 — current-generation floor" would say what is meant.

### NITPICK-2 — "Six named devices" vs a five-device matrix

`ADR-008-bootstrap-pins.md:31`: "TASK-009 consumes … the six named devices for simulator runs." The matrix names **five** devices (3 iPhone + 2 Watch); the sixth (Ultra 3) is explicitly an optional upper bound, not a matrix member. Align the count or enumerate them.

### NITPICK-3 — Untracked `.DS_Store` at repo root

Not produced by this task's evidence (Finder artifact), but it sits in `git status` next to TASK-008's two legitimate changes — ensure it is not swept into the TASK-008 commit; consider adding it to `.gitignore`.

## Clean dimensions (checked, with the evidence)

- **Evidence authenticity — CLEAN and unusually strong.** Every re-runnable command reproduced byte-identically, including the suspicious duplicated macOS SDK line; probe UDIDs, build IDs (23F77/23T570), Swift build step numbering, and macro-note text all matched. The Swift Testing probe output could not have been paraphrased into existence. No sign of fabrication anywhere.
- **Deployment-target pin soundness — CLEAN.** Generation-floor 26.0/26.0 is the correct mechanical reading of ADR-006's "current stable shipping OS generation" (generation = 26; 26.5 is a point release) and of 05 §2.4's "expected iOS 26 / watchOS 26 or their then-current successors". Rejecting point-release pins (26.5) as an alternative is correct and recorded.
- **Pairing rule — CLEAN in substance.** Stated, consistent between task file and ADR-008 (Decision 3 vs table row), correctly deferred to TASK-050 for the formal matrix (wording nit: NITPICK-1).
- **N-1 deferral — CLEAN.** Explicit in both artifacts (Decision 6; table row), correctly targeted at TASK-050 per the delivery plan (see MINOR-2 for the stale reference in the *older* docs).
- **Watch-side device obligations — CLEAN.** SE 3 (40mm) is the smallest watch and carries the ADR-001 ~32 pt glyph role; verified 324×394 px, and shown stable against older supported watches (SE 2 40mm = same geometry). Series 11 (46mm) satisfies the flagship slot; §12's SE-class + flagship shape is met on the watch side.
- **Screen-measurement evidence — CLEAN.** Device-size probe (6d) recorded with method (boot → screenshot → `sips`), and the two governing values independently reproduced exactly. Refusing to assert physical diagonals was the right §25 call.
- **Framework pin — CLEAN.** Swift Testing authenticated by an exactly-reproducible probe; XCUITest correctly scoped to UI automation only (05 §10.1 shows unit targets run `swift test` on macOS; §10.6 is the XCUITest home); in-target wiring correctly left to TASK-009/010 per delivery plan §9.
- **Appendix B ownership — CLEAN at the boundary.** Exactly the owned items are marked resolved (OPEN-3; §2.4 pins/pairing; §12 composition; §10 framework *side*); the explicitly-not-resolved list matches delivery plan §9 ownership one-for-one (009/010, 014, 025, 040/044, 045, 048; Phase-2 items left as reservations). No over-claiming. (The §12 resolution's *substance* is defective per MAJOR-1; the ownership boundary itself is right.)
- **ADR template compliance (CLAUDE.md §21) — CLEAN.** Status/Context/Decision/Alternatives/Consequences/Date all present and substantive; alternatives are real (26.5 point pins, N-1 now, defer again, XCTest, Ultra-3-as-flagship); consequences honest (pins don't auto-update on toolchain change; docs/status.md updates left to the orchestrator).
- **BLOCKED history integrity — CLEAN.** Diff vs HEAD shows exactly 2 removed lines (Status value; heading rename); the BLOCKED record, verbatim failure outputs, unblock path, and risks sections are preserved unaltered; the successful run is appended below it. Status field correctly IN_REVIEW.
- **Scope/process — CLEAN.** No commits (HEAD still `80a859a`, as the task file states); working tree contains only the two expected changes; no package/project files (TASK-009 scope intact); scratch probes confined to `/tmp`; `status.md` and `docs/` untouched; no secrets recorded (paths are `/tmp`/`/Applications`; no credentials, no user-identifying machine details).

## Acceptance-criteria sweep

- **AC-1 (verbatim toolchain evidence recorded) — SATISFIED.** Independently authenticated (see Clean dimensions).
- **AC-2 (ADR-008 per §21 template with all six mandated statements) — SUBSTANTIALLY SATISFIED; defective on one:** the device-matrix name for iPhone-small is wrong (MAJOR-1). iOS pin, watchOS pin, pairing rule, framework pin, N-1 note are all present and correct.
- **AC-3 (every OPEN-3 sub-item decided; owned Appendix B items resolved) — SUBSTANTIALLY SATISFIED;** pins and framework decided correctly; the "device names" sub-item's iPhone answer and Appendix B item 3's "RESOLVED (smallest = iPhone 17e)" are the defective records (MAJOR-1).
- **AC-4 (TR10 retired) — SATISFIED.** Retired as **verified** with real, reproduced evidence; delivery-plan R1 mitigated; docs/status.md updates correctly left to the orchestrator.

## VERDICT

**CHANGES_REQUIRED**

TASK-008's core engineering is real and its evidence is among the most verifiably authentic I have re-run — every command I reproduced matched byte-for-byte, the Swift Testing probe reproduced exactly, and the BLOCKED history is intact. But the task exists to prevent precisely the defect I found: ADR-008's iPhone-small pin asserts, as a supersession "from recorded evidence", that the 4.7-inch SE-class no longer runs the pinned iOS 26 generation — and the pinned toolchain itself boots an iPhone SE (3rd generation) on iOS 26.5 at 375×667 pt, materially smaller than the 17e's 390×844 pt. AC-1a's no-scroll budget, §12's launch/energy measurement devices, and TASK-009's simulator set would all inherit a wrong referent from a decision record marked ACCEPTED. Per CLAUDE.md §10, a task may not be committed while a MAJOR finding requires changes: re-pin iPhone-small (or convert the current-generation-only scope into an explicit owner decision), fold in the two MINORS (ADR-006 status reconciliation is the orchestrator's; the TASK-007→TASK-050 note is a one-line ADR-008 edit), and re-review. The deployment pins, pairing rule, watch matrix, and framework pin are sound and need no rework.

---

## Disposition (orchestrator, 2026-09-08)

Verdict received: **CHANGES_REQUIRED** (1 MAJOR / 2 MINOR / 3 NITPICK). All six findings closed:

| ID | Ruling | Disposition | Fix |
|---|---|---|---|
| MAJOR-1 | Reviewer's option 1 adopted (orchestrator ruling): re-pin iPhone-small to **iPhone SE (3rd generation)** — the mechanical reading of ADR-006 (generation 26) + 05 §12 (smallest device run by the pinned generation) + toolchain evidence; it only tightens obligations (375×667 pt vs 390×844 pt) and is reversible. Option 2 (current-generation-hardware-only) is a product-scope decision reserved to the owner (CLAUDE.md §36) — recorded in ADR-008 Alternatives as a rejected alternative / available lever, not taken | FIXED | Fresh fixer agent re-pinned ADR-008 (Status, Decision 3/4/6, Consequences) + task-file pin table and Appendix B item 3, recording its **own** boot-probe evidence (§25): iPhone SE (3rd generation) on iOS 26.5 → 750×1334 px (375×667 pt); task file gains the "Fix pass" subsection; watch side gains the SE (2nd generation) 40mm same-geometry (324×394 px) stability note. |
| MINOR-1 | Orchestrator-owned per review | FIXED | ADR-006 Status line reconciled PROPOSED → ACCEPTED with REVIEW-TASK-006 pointer (orchestrator, applied before the fix pass). |
| MINOR-2 | As prescribed | FIXED | ADR-008 Decision 6 carries the note: ADR-006/05 §2.4 say "TASK-007" (pre-delivery-plan numbering); the backlog of record assigns the N-1 re-evaluation to TASK-050. |
| NITPICK-1 | As prescribed | FIXED | Pairing wording now "both floors ≥ 26.0 — the current-generation floor (26)" in ADR-008 Decision 3 and the mirrored task-file pin row. |
| NITPICK-2 | As prescribed | FIXED | "The five named matrix devices (3 iPhone + 2 Watch)"; Ultra 3 remains the optional upper bound. |
| NITPICK-3 | As prescribed | FIXED | `.gitignore` created (`.DS_Store` only; Swift/Xcode entries deferred to TASK-009's build baseline); stray `.DS_Store` deleted; not part of any commit. |

Post-fix verification: fresh verifier agent — record at `REVIEW-TASK-008-VERIFY.md` — verdict **FIXED — CLEARED FOR COMMIT**: independently reproduced both probes (third agreeing measurement pair: 750×1334 / 324×394), all six findings VERIFIED FIX with file:line evidence, scope clean (no agent commits; HEAD `80a859a`), no stale committed references downstream.

**Final: APPROVED — cleared for commit** `chore(bootstrap): TASK-008 verify toolchain and record deployment pins (ADR-008)`.
