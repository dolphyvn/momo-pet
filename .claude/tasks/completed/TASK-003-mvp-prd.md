# TASK-003 — Step 2: MVP Product Specification (PRD)

## Parent Epic
EPIC-001 — Product Definition & Delivery Plan

## Objective
Produce a concise, implementation-ready MVP PRD that consolidates the spec + the resolved decisions from TASK-002 into the single product source of truth for Phases 1 (project.md §40 Step 2, §30 items 1–8).

## Context
Momo: iPhone + Apple Watch companion pet. Mood ❤️ / Energy ⚡ / Bond ✨ are the only three user-facing dimensions (§5). Phase 1 MVP = iPhone (one pet, home, idle animation, interactions, feed, simple play, basic room, persistence) + Watch (pet, mood/state, today's quest, one interaction, haptics, sync) (§27). No punishment (§4). Notifications must feel like a companion (§15).

## Requirements
Read `CLAUDE.md`, `project.md`, `docs/product/01-product-review.md`, then produce `docs/product/02-mvp-prd.md` containing:
1. Target users & personas (2–3, with jobs-to-be-done)
2. Core loop (daily loop per §6, explicitly excluding feed-grind loops)
3. Functional requirements (numbered FR-x, each testable, MVP-scoped)
4. Non-functional requirements (performance, battery, privacy, accessibility, reliability)
5. MVP scope (Phase 1, per §27) and explicit non-goals (§28)
6. Acceptance criteria per FR
7. Success metrics (aligned with §34 analytics events; no surveillance framing)
8. Three-dimension model definition (Mood/Energy/Bond semantics, ranges, what moves them — relational, not XP grinding)
9. Quest design rules for Phase 1 (small, achievable, non-manipulative)
Rules:
- Must incorporate every decision logged in `01-product-review.md`; if the PRD needs a decision that was escalated (not resolved), mark it OPEN-DECISION and do not invent it.
- Phase discipline: nothing from Phases 2–4 may appear as a requirement (§24, §27).
- Concise and decision-oriented; every requirement must be verifiable.

## Files / Areas Likely Affected
- Creates `docs/product/02-mvp-prd.md`

## Dependencies
- TASK-002 (DONE required).

## Constraints
- Jupiter model, fresh agent, no commit by agent.

## Acceptance Criteria
- All 9 sections present; FRs are numbered, testable, and MVP-only; acceptance criteria concrete; non-goals restated verbatim-equivalent to §28; every TASK-002 default decision either adopted (with trace) or challenged with rationale.
- Review verdict ≥ APPROVED_WITH_MINOR_NOTES.

## Required Tests
- Not applicable (document). Independent review agent required.

## Review Requirements
- Fresh reviewer independently verifies: MVP-only scope, no manipulative mechanics, FR testability, consistency with 01-product-review decisions, philosophy compliance. Record in `.claude/tasks/reviews/REVIEW-TASK-003.md`.

## Git Requirements
- Commit (orchestrator, post-approval): `docs(product): TASK-003 MVP product requirements document`

## Status
DONE

## Implementation Notes
- Executed 2026-09-08. Created `docs/product/02-mvp-prd.md` (~Appendix A/B included). All 9 required sections present; acceptance criteria inline per FR.
- **FR count: 20** (FR-1 Onboarding, FR-2 Home 3-second rule, FR-3 static Room, FR-4 idle aliveness, FR-5 touch/petting, FR-6 feeding, FR-7 playing, FR-8 care tuck-in/nap, FR-9 mood/energy model, FR-10 bond model, FR-11 time model, FR-12 absence/inactivity + tone guardrails, FR-13 persistence/determinism, FR-14 quest catalog, FR-15 daily set generation, FR-16 completion/expiry, FR-17 Watch experience, FR-18 device-to-device sync, FR-19 settings + data deletion, FR-20 privacy/accessibility/free guarantees). Plus NFR-1–9.
- **PRD-owned numbers (normative):**
  - **Bond:** cumulative 0–1000; stages New Friends 0–149 / Getting Close 150–399 / Best Friends 400–749 / Soul Companions 750–1000. Earning: daily hello +8, +4/quest (max 3/day), +6 variety bonus (all three families), **hard daily cap +20**. Touches never move bond. Absence = special warm greeting only, same +8.
  - **Mood bands:** Joyful 75–100 / Content 45–74 (attractor 60) / Wistful 20–44 / Low 0–19 (reserved; unreachable in Phase 1). Phase 1 floor 25, normal-play ceiling 92. Only downward pressure = daytime low-energy coupling (self-healing, floor 25, no guilt, no bond effect).
  - **Energy bands:** Energetic 75–100 / Relaxed 45–74 / Drowsy 20–44 / Exhausted 0–19. Directions normative, rates as starting values (post-sleep 85; play −10; feed +6; nap +20; ~1–2/h waking decline; night full restore by 07:00).
  - **Quest catalog (7, interaction-only per D1):** Q1 Morning hello (first touch/day, anchor always present) · Q2 feed ×1 · Q3 feed ×2 · Q4 play ×2 · Q5 play ×3 · Q6 Tuck-in (20:00–07:00) · Q7 pats ×3. Daily set = Q1 + 2 seeded from {Q2–Q7}; constraints: no dup, Q6 ≥ 1 per rolling 3 days, no identical pair on consecutive days. Auto-complete, silent midnight expiry, no carryover.
  - **Interaction semantics (D18):** always-available buttons, no cooldowns/locks; full-Momo feed = polite refusal, zero penalty; same-family repetition decays smoothly; D18 response matrix normative (§4), exact curves → TASK-006.
- **Anti-grind guarantees (core-loop section):** G1 bond daily cap, G2 touches bank nothing, G3 no currencies/sinks exist.
- **Decisions:** all D1–D20 adopted, none challenged — full traceability table in Appendix A. K-calls inherited as scope constraints (§8.1). §28 non-goals restated verbatim-equivalent (§8.2) plus phase-discipline non-goals (§8.3).
- **OPEN-DECISION items marked:** E1 (monetization — free at launch), E2 (character direction — §10 flags it as an EARLY gate; TASK-004 must stay character-agnostic: PRD fixes only head/belly zones + eye-follow + FR-4 state set as anatomy contract), E3 (location — excluded), E4 (name — TASK-007 gate). No escalated decision was invented.
- **Metrics:** ASC aggregate D1/D7/D30 + crash-free as the only Phase 1 measurement surface (D7); provisional targets D1 ≥ 30%, D7 ≥ 15%, crash-free ≥ 99.5%; paper-only event taxonomy (8 events, no PII); anti-metrics policy recorded.
- **Potentially review-sensitive calls (self-flagged):** (1) Low mood band deliberately unreachable in Phase 1 — argued as honest headroom; (2) daytime low-energy→mood coupling as the sole Wistful source; (3) touch-banks-no-bond rule; (4) Q1 as always-present anchor. All are PRD-owned product semantics, each with testable ACs.
- Nothing committed (per instructions); ready for independent review (REVIEW-TASK-003).
- Fix pass 2026-09-08: M1 + minors 1–7 + N1–N4 applied; details in REVIEW-TASK-003.md.

## Reviewer Findings
- Independent review (`task-003-reviewer`): CHANGES_REQUIRED — M1 (FR-2 AC-1 untestable) + 7 minors + 4 nitpicks; D1–D20 all verified compliant; arithmetic verified; no scope leakage. See .claude/tasks/reviews/REVIEW-TASK-003.md.
- Fix pass (`task-003-fixer`): all findings applied + 3 coherence edits.
- Fresh verification (`task-003-verifier`): ALL_FIXES_VERIFIED — every fix confirmed with line-level evidence; no regressions; two mechanical follow-ups applied by orchestrator (Q6 set guard; K3 14→15 in review doc).
- FINAL: APPROVED

## Completion Evidence
- Deliverable: docs/product/02-mvp-prd.md (20 FRs + 9 NFRs, PRD-owned numbers, Appendix A/B traceability)
- Review loop: CHANGES_REQUIRED → fix → ALL_FIXES_VERIFIED → APPROVED (.claude/tasks/reviews/REVIEW-TASK-003.md)
- Commit/push: hash recorded in .claude/tasks/status.md Recent Commits
