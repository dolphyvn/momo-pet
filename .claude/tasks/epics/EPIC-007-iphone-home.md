# EPIC-007 — iPhone Home Experience

## Objective
Deliver the complete iPhone experience per FR-1…FR-8, FR-16, FR-19 and 03: the app-model facade (evaluate/apply loop, persistence wiring, boundary scheduling), onboarding S1–S3, Home composition with the living character, touch/petting with eye-follow, Feed/Play/Care flows, quest moments and celebrations, the Room tab, Settings with erase-all-data — and consolidate the iPhone accessibility audit. Completes the vertical slice up to (not including) the Watch leg.

## User / Product Value
The product a person actually holds: meet Momo in three taps, see her alive on Home, pet her and be answered, feed her and be politely refused when she is full, tuck her in, watch small quests complete without ever being nagged. Everything stays calm, permission-free, and offline.

## Scope
- Facade (05 §4.1–4.2, D-R5): fixed-order side effects (apply → persist if changed → deliver response/moments); fold-to-now triggers (foreground, interaction, report, boundaries 22:00/07:00/midnight/nap-end, time-change notifications); one scheduled next-boundary evaluation; views never touch the engine directly.
- Onboarding (FR-1, UX §3): exactly 3 steps, zero dialogs/network/accounts, Enter writes completion flag atomically.
- Home (FR-2, UX §5.1): status row (glyph + words, never numbers), pet canvas ≥ ~45 %, contextual line (UX-12), action pills, quest card (soft per-wish marks UX-4, window rendering UX-5); no-scroll at default type on the smallest pinned device (AC-1a), full function at accessibility sizes (AC-1b).
- Touch & petting (FR-5, UX §5.1, 04 §2.3–2.4/§6.1): 4 gestures × 2 zones (y=550), eye-follow per 04 §2.4 (RM → single glance, UX-14), sleeping → stir, canvas as one VoiceOver element with Pat/Cuddle custom actions (UX-8).
- Feed/Play/Care (FR-6/7/8, UX §5.2–5.4, 04 §6.2–6.3): refusal-warm and nibble paths; UX-3 play round ≤ 30 s with early-exit; Tuck-in chip only from 20:00 (clock-based); Nap chip when Drowsy/Exhausted.
- Quest moments + celebrations (FR-16, UX §5.5–5.6, 04 §4.3): M1 inline, M2 stage banner once (UX-10, deferred-while-closed), M3 all-done; Q1 vanishes silently at 12:00; Q6 from 20:00; midnight silent reset.
- Room (FR-3) and Settings + erase-all-data (FR-19, UX §1.2, S6.2 confirmation).
- UI-test consolidation + per-surface accessibility audit (FR-20 AC-2, NFR-6).

## Non-Goals
Watch app and transport (EPIC-008 — rename/haptics/erase reach the Watch there; TASK-038 ships the reset marker only), widgets/notifications/HealthKit (Phase 2), customization/collection UI (FR-2 AC-4), sound settings (no audio exists), punishment or streak mechanics (banned), analytics (D7).

## Dependencies
- EPIC-004 (engine), EPIC-005 (store), EPIC-006 (rig) — all complete.

## Tasks
Branch: `feature/EPIC-007-iphone-home` (from `main`).

| TASK | Title | Size | Depends on |
|---|---|---|---|
| TASK-031 | Implement the app model facade: evaluate/apply loop + persistence wiring + boundary scheduling (05 §4.1–4.2) | L | TASK-020, TASK-021 |
| TASK-032 | Implement onboarding S1→S2→S3 (FR-1, UX §3) | M | TASK-031 |
| TASK-033 | Implement Home composition (FR-2, UX §5.1/§5.5) | L | TASK-026, TASK-031 |
| TASK-034 | Implement touch & petting (FR-5, UX §5.1, 04 §2.3–2.4/§6.1) | L | TASK-033 |
| TASK-035 | Implement Feed / Play / Care flows (FR-6/7/8, UX §5.2–5.4, 04 §6.2–6.3) | L | TASK-034 |
| TASK-036 | Implement quest moments + celebrations (FR-16, UX §5.5–5.6, 04 §4.3) | M | TASK-033, TASK-018 |
| TASK-037 | Implement Room tab (FR-3, UX §1.2 S5) | S | TASK-025, TASK-031 |
| TASK-038 | Implement Settings + rename + erase-all-data (FR-19, UX §1.2 S6) | M | TASK-031, TASK-022 |
| TASK-039 | iPhone UI test consolidation + per-surface accessibility audit (FR-20 AC-2, NFR-6, 03 §10) | M | TASK-032…038 |

## Acceptance Criteria
1. Every FR-1…FR-8, FR-16, FR-19 acceptance criterion passes on the iPhone (traceability: delivery plan Appendix A).
2. Vertical slice minus Watch demonstrable: launch → onboarding → Momo visible → idle → touch → react → state change → **persist** (force-quit-safe, FR-13 AC-1).
3. No permission dialog, network call, account, or numeric-stat UI anywhere (FR-1 AC-1/AC-4, FR-2 AC-3).
4. Dynamic Type behavior per AC-1a/1b; VoiceOver announcements use engine-provided keys (INV-11 respected); Reduce Motion honored (UX-14).
5. Accessibility audit (TASK-039) fully green — launch-blocking per NFR-6.

## Test Requirements
- project.md §32 **UI matrix (iPhone half)** per 05 §10.1 `MomoUITests` (iOS simulator): onboarding flow incl. kill-before-Enter restart; primary interactions (pet, feed refusal/nibble, play round, tuck-in/nap); quest completion inline + expiry silence + stage-once; settings rename/erase roundtrip; no-scroll layout check on smallest pinned device.
- Facade tests with injected clock (boundary scheduling, fold-on-foreground, write-through on change).
- Standing static scans (import-whitelist, banned vocabulary) stay green.

## Definition of Done
All nine tasks DONE per CLAUDE.md §18; UI suites + audit green with evidence; reviews APPROVED; atomic TASK-ID commits on `feature/EPIC-007-iphone-home`, pushed; epic merged to `main`; orchestrator status update.

## Status
TODO
