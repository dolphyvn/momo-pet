# REVIEW-TASK-003 — Independent Review of TASK-003 (MVP PRD)

| | |
|---|---|
| Date | 2026-09-08 |
| Reviewer | Fresh independent review agent (`task-003-reviewer`), Jupiter, no shared context with the implementation agent |
| Artifact | `docs/product/02-mvp-prd.md` |
| Verdict | **CHANGES_REQUIRED** → fix pass applied → fresh verification: **ALL_FIXES_VERIFIED** → **APPROVED** (with post-verify mechanical follow-ups, see Disposition) |

## Verified Compliant (reviewer's positive evidence)
- All 20 binding decisions D1–D20: **COMPLIANT** (incl. the D4 question — energy→mood coupling is activity-gated, self-healing, never guilt).
- All pacing/energy/mood arithmetic verified; all 16 §28 non-goals restated; no Phase 2–4 leakage; no manipulative mechanics; no telemetry/monetization paths.

## Findings

### MAJOR (blocking)
- **M1 — FR-2 AC-1 untestable**: "smallest supported Dynamic Type-compatible layout … visible without scrolling" is ambiguous (device size vs type size) and collides with FR-20's "Dynamic Type without loss of function" at accessibility sizes. The AC is a binding acceptance source for TASK-004/005/006 and must be rewritten to a measurable form.

### MINOR
1. §5.5 rule 5: literally can surface Q7 when it is not in today's set → must read "Q7, **if in today's set**"; rule 6 relabeled as the no-currently-selectable fallback.
2. §4 response matrix lacks an **Exhausted** column (behavior only implied by §3.2); FR-8 "Nap only when Drowsy" vs Exhausted semantics need one coherent rule.
3. Q1 expires at 12:00 but §5.1 rule 6 / FR-16 AC-2 say expiry is at local midnight — per-quest window expiry must be stated as an explicit exception; **Q6 cross-midnight day-ownership** (00:00–07:00 tuck-ins) undefined.
4. FR-10 AC-2 "No action … ever decreases bond" collides with FR-19 erase-all-data → add "gameplay" qualifier.
5. FR-13 AC-1 "uncommitted second" is undefined → state a concrete ≤1 s persistence-loss bound.
6. FR-4 AC-4 says "14-state inventory (§4)" — project.md §4 lists **15** states (error inherited from review K3).
7. §32's "upgrade" edge case only covered by blanket NFR-7 reference → explicit TASK-006 obligation needed.

### NITPICK
- N1: Variety bonus +6 is cap-absorbed on 3-quest days (8+12=20); clarify it is what lets a 2-quest varied day reach the cap.
- N2: Settings sound toggle has no Phase 1 audio FR behind it (audio scope undefined).
- N3: FR-17 prose "2-second pat" vs AC-1 "≤5 s" measure different things — align.
- N4: FR-15 AC-2's 30-day sample under-verifies a universal invariant → add "generator guarantees constraints by construction" as a TASK-006 obligation.

## Disposition — COMPLETE
1. ✅ Fresh fix agent (`task-003-fixer`) applied M1 + minors 1–7 + N1–N4 in a single editing pass, plus 3 self-justified coherence edits (§3.2 Exhausted nap mention; FR-16 intro "silent expiry (per-quest windows)"; Appendix A D20 pointer).
2. ✅ Fresh verification agent (`task-003-verifier`) — verdict **ALL_FIXES_VERIFIED**: every fix confirmed with line-level evidence; quest cascade simulated (13:00 afternoon case and 21:30 evening case terminate validly); §3.2/§4/FR-8 mutually consistent; 15-state count independently recounted against project.md §4; no D-decision violated; no Phase 2+ content.
3. Post-verify follow-ups applied by orchestrator before commit (mechanical one-liners):
   - PRD §5.5 rule 1: added the Q6 set-membership guard ("if Q6 is in today's set and …") — same defect class the reviewer flagged for Q7; pre-existing, found by the verifier.
   - `docs/product/01-product-review.md` K3 heading: "14 states" → "15 states" (stale count inherited from K3; the PRD's correction made the review doc inconsistent).
   - Verifier's cosmetic observation (rule-6 "All done" wording in the 12:00–20:00 dead zone) — no action: explicitly covered by the rule's nothing-selectable label; copy has no guilt/pressure content.

**Final status: APPROVED. Task cleared for commit and push.**
