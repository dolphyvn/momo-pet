# REVIEW-TASK-008-VERIFY — Independent verification of the TASK-008 fix pass

- **Verifies**: fix pass against REVIEW-TASK-008 (CHANGES_REQUIRED — 1 MAJOR / 2 MINOR / 3 NITPICK)
- **Verifier**: fresh independent verifier (CLAUDE.md §11; did not implement, review, or fix; adversarial stance — attempted to disprove)
- **Date**: 2026-09-08
- **Repo state at verification**: branch `feature/EPIC-002-foundation`, HEAD `80a859a` (unchanged — no new commits)

## Review Method (independently re-run — reviewer's and fixer's probes NOT trusted)

1. **Load-bearing fact re-proven from scratch (own devices, own UDIDs).** Per §25/§33 the crux was re-established by this verifier, not inherited from the reviewer's or fixer's records:
   - **Probe 1 — iPhone SE (3rd generation)**: `xcrun simctl create "MomoVerifyProbe-SE3" "com.apple.CoreSimulator.SimDeviceType.iPhone-SE-3rd-generation" "com.apple.CoreSimulator.SimRuntime.iOS-26-5"` → accepted; UDID `3B2D15F0-10E2-4102-A514-97F0C11AC1C2`; booted (`bootstatus -b` terminal line `Status=4294967295, isTerminal=YES … Finished`); screenshot via `simctl io`; then shutdown + delete. Verbatim `sips` output:
     ```
     /private/tmp/momo-verifyprobe-se3.png
       pixelWidth: 750
       pixelHeight: 1334
     ```
     → **750×1334 px = 375×667 pt @2x** — matches the fix's recorded value exactly and is smaller than iPhone 17e's 390×844 pt. The re-pin's load-bearing fact is TRUE.
   - **Probe 2 — Apple Watch SE (2nd generation) 40mm**: `xcrun simctl create "MomoVerifyProbe-WatchSE2" "com.apple.CoreSimulator.SimDeviceType.Apple-Watch-SE-40mm-2nd-generation" "com.apple.CoreSimulator.SimRuntime.watchOS-26-5"` → accepted; UDID `41073284-A392-4FA5-B0BA-E728EA934796`; booted (terminal `Finished`); screenshot; shutdown + delete. Verbatim `sips` output:
     ```
     /private/tmp/momo-verifyprobe-watchse2.png
       pixelWidth: 324
       pixelHeight: 394
     ```
     → **324×394 px** — pixel-identical to Watch SE 3 (40mm); the ADR-001 glyph geometry stability claim is TRUE.
   - **Cleanup**: `xcrun simctl list devices | grep -cE "MomoVerifyProbe|MomoFixProbe"` → **0** (both this verifier's and the fixer's probe devices absent).
2. **Diff forensics vs HEAD (`80a859a`)**: ADR-006 diff = exactly 1 line (Status). Task-file diff = 3 removed lines only: line 59 (Status value), line 63 (`### Verdict` heading rename — pre-approved by the original reviewer), line 118 (`- (orchestrator records)` placeholder in Completion Evidence → `- (commit hash + push, by orchestrator)`; benign, outside all protected regions). Hunks `@@ -59 +59 @@`, `@@ -63 +63 @@`, `@@ -116,0 +117,244 @@`, `@@ -118 +362,15 @@` — **no deletion or in-place modification lands inside the BLOCKED history body (task file lines 64–115)**. Note: the successful-run evidence block is entirely post-HEAD (uncommitted) content, so diff cannot prove the fixer left it untouched; immutability is attested by (a) the fixer's edit list claiming no edits there and (b) its key values (1170×2532 / 324×394 / UDIDs / build IDs 23F77 / 23T570) matching REVIEW-TASK-008's byte-for-byte quotes.
3. **Greps**: ADR-008 and task file swept for `17e`, `supersedes`, `six named`, `same-generation pairs only`; docs/ swept for `iPhone 17e` and `4.7`; delivery plan read for TASK-009/TASK-045/TASK-050/R13/NFR-8 rows.
4. Ground-truth reads: ADR-006 (full), 05 §12 (line 679 region), delivery plan rows cited by ADR-008.

## Finding-by-finding table

| Finding | Verdict | Evidence |
|---|---|---|
| **MAJOR-1** — iPhone-small re-pin | **VERIFIED FIX** | ADR-008:4 Status now says the "expected 4.7\" SE-class" expectation "the recorded evidence **confirms**: the smallest supported device is the iPhone SE (3rd generation)" — the supersession claim is gone, replaced by confirmation; ADR-008:14 iPhone small = `iPhone SE (3rd generation)`, 750×1334 px = 375×667 pt, with 17e (1170×2532 = 390×844 pt) as next-smallest contrast; ADR-008:19 confirmation + root-cause note (default `list devices available` ≠ supported set); task file :243 (pin table row) and :257 (Appendix B item 3) re-pinned with "expectation confirmed". **Independently re-proven**: my own probe boots the same device-type/runtime pair at 750×1334 px. |
| **MINOR-1** — ADR-006 Status | **VERIFIED FIX** | ADR-006:4 = "ACCEPTED — approved by REVIEW-TASK-006 (verdict APPROVED; recorded in `.claude/tasks/reviews/REVIEW-TASK-006.md` and delivery plan §9; status reconciled during TASK-008's review fix pass)". Diff shows exactly this one line changed; no other ADR-006 content touched. |
| **MINOR-2** — TASK-007→TASK-050 note | **VERIFIED FIX** | ADR-008:21 (Decision 6): "(ADR-006's and 05 §2.4's text says \"TASK-007\" — pre-delivery-plan numbering; the backlog of record, delivery plan §3 EPIC-009 / §7 R13, owns the re-evaluation as TASK-050.)" Cross-checked: delivery plan :145 TASK-050 row ("N-1 deployment widening re-evaluated once (ADR-006) with pairing-matrix check"), :249, :283, :336 (NFR-8: "050 (N-1 decision)") — attribution accurate. |
| **NITPICK-1** — pairing wording | **VERIFIED FIX** | ADR-008:12 Decision 3: "both floors ≥ 26.0, the current-generation floor (generation 26); within Phase 1 that makes every supported pair same-generation"; TASK-050 formal-matrix gate sentence kept. Mirrored task-file pin row :242 uses the same operative wording. Phrase "same-generation pairs only" absent from both files. |
| **NITPICK-2** — device count | **VERIFIED FIX** | ADR-008:32 Consequences: "the **five named matrix devices** (3 iPhone + 2 Watch)"; Ultra 3 (:18, :32) explicitly the optional upper bound, not a matrix member. "six named" absent; consistent with Decision 4's 3+2 matrix and the task-file pin table. |
| **NITPICK-3** — `.DS_Store` | **VERIFIED FIX** | `.gitignore` exists with `.DS_Store` entry (line 2, under a `# macOS` header, with a note deferring Swift/Xcode entries to TASK-009); `ls` shows no `.DS_Store` at repo root; `git status --ignored` lists no `.DS_Store` anywhere. |

## Stale-residue sweep (live sections)

- **ADR-008**: zero hits for `supersedes`, `six named`, `same-generation pairs only`. **One hit for `17e`** at ADR-008:14 — a *comparative measurement* ("the next-smallest measured device, iPhone 17e, is 1170×2532 px = 390×844 pt") that is part of the corrected evidence justifying the SE (3rd generation) pin — precisely the contrast the reviewer's MAJOR-1 fix option 1 prescribed recording. It asserts no property of the old (wrong) claim; judged **not residue**. Flagged here for the orchestrator's visibility as the single interpretive call in this sweep.
- **Task file**: hits at :176 and :221 (inside the preserved verbatim evidence — device list and probe output; must remain untouched, confirmed unmodified); :284, :318, :352 (Fix pass subsection — historical narrative of what the old claim was and what was edited); :363, :369, :373 (Reviewer Findings disposition table — quotes the findings verbatim, as §11 requires). **No hit in any live operative section** (pin table :237–249, Appendix B :253–260, AC-state :262–267, Handoff decisions :276). The Fix-pass/disposition mentions exist to record the finding and its fix — the §11 audit trail — and are correct as written.

## Internal consistency of corrected ADR-008 — CONSISTENT

Decision 4 matrix (iPhone: SE (3rd generation) small / 17 mid / 17 Pro Max large; Watch: SE 3 (40mm) small / Series 11 (46mm) flagship; Ultra 3 optional upper bound) ↔ Consequences (:32 five named, 3+2; :33 AC-1a vs SE (3rd generation), glyph floor vs SE 3 (40mm); :34 all §12 budgets measured on the SE-class devices at TASK-045) ↔ rejected alternative (:29 "Support current-generation hardware only" preserved as an explicit owner lever, §36, with the correct reasoning that it would *loosen* AC-1a/§12 obligations) ↔ task-file pin table rows — all mutually consistent. Watch-side stability sentence (:17, SE 2 40mm = 324×394 px) matches my Probe 2. Min iOS pin 26.0 is unchanged and independent of the device-matrix fix.

## Scope and process — CLEAN

- `git status --short`: exactly 5 paths — modified: `.claude/tasks/active/TASK-008-toolchain-pins.md`, `.claude/tasks/decisions/ADR-006-deployment-targets.md`; new: `.claude/tasks/decisions/ADR-008-bootstrap-pins.md`, `.claude/tasks/reviews/REVIEW-TASK-008.md`, `.gitignore`. Nothing else.
- No new commits: HEAD = `80a859a` (unchanged); branch `feature/EPIC-002-foundation`.
- No edits under `docs/`; no `status.md` edits.
- Probe hygiene: this verifier's 2 devices + fixer's devices all deleted (`grep -cE "MomoVerifyProbe|MomoFixProbe"` over `simctl list devices` → 0).
- One deviation from the pre-fix diff signature, benign and disclosed: a third removed line vs HEAD (`- (orchestrator records)` → `- (commit hash + push, by orchestrator)` in Completion Evidence) — outside all protected regions.

## Downstream coherence — NO CONTRADICTION FOUND

- `grep docs/` for "iPhone 17e": zero hits. No committed doc names the 17e.
- `05-technical-architecture.md:679` (§12 device matrix, committed): "expected 4.7\" SE-class" smallest-iPhone placeholder, VERIFY-AT-BUILD — the corrected ADR-008 now **confirms** rather than supersedes this expectation, so the committed doc and the decision record point the same way. Remaining "4.7" grep hits in docs/ are §4.7 section references (wakefulness machine), unrelated. (05 §12 remains an "expected … VERIFY-AT-BUILD" placeholder by design; its docs-side resolution belongs to the orchestrator, per ADR-008:37 — noted, not a defect.)
- Delivery plan TASK-009 row (:55, "deployment pins applied") and TASK-045 row (:140, "Measured on the pinned device matrix") are referent-generic and fully coherent with "smallest supported = iPhone SE (3rd generation)"; TASK-050's ownership of the N-1 re-evaluation (:145, :336) matches ADR-008 Decision 6.

## VERDICT

**FIXED — CLEARED FOR COMMIT**

The load-bearing fact was re-proven independently by this verifier's own probes (SE (3rd generation) on iOS 26.5 → 750×1334 px; Watch SE (2nd gen) 40mm on watchOS 26.5 → 324×394 px; both devices deleted). All six findings from REVIEW-TASK-008 are implemented as prescribed; no stale residue survives in any live section; ADR-008 is internally consistent; the working tree contains exactly the five expected changes with no new commits; no committed doc contradicts the corrected pins. Per CLAUDE.md §10/§12, the orchestrator may commit TASK-008 on `feature/EPIC-002-foundation`, push, record the hash, and update status.md.
