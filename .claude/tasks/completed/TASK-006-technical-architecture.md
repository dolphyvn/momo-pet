# TASK-006 — Step 5: Technical Architecture

## Parent Epic
EPIC-001 — Product Definition & Delivery Plan

## Objective
Produce the technical architecture for Phase 1 and record all meaningful decisions as ADRs (project.md §40 Step 5, §30 items 17–21; CLAUDE.md §21).

## Context
Native Apple stack, local-first MVP (§21). iPhone is the authoritative pet state holder; Watch syncs carefully around offline/eventual consistency (§21). Pet behaviour is a real domain engine with deterministic core + injectable randomness (§23). Domains per §22; no business logic in views; Presentation/Domain/Data separation proportional to product. Phases 2+ concerns (HealthKit reads, widgets, notifications) are architecture-*reservations*, not implementations.

## Requirements
Read `CLAUDE.md`, `project.md`, `docs/product/01-product-review.md`, `docs/product/02-mvp-prd.md`, `docs/design/03-ux-architecture.md`, `docs/design/04-character-system.md`, then produce `docs/architecture/05-technical-architecture.md` containing:
1. System context diagram (textual) — app, Watch app, future widget/HealthKit extension points
2. Module architecture (targets: iOS app, Watch app, shared domain package; module boundaries + dependency rules)
3. Domain model (Pet, PetState, Mood/Energy/Bond, DailyProgress, Quest, Interaction, Room — normalized from §24 example, with types and invariants)
4. Pet State Engine design (inputs, outputs, pure core, injectable clock/randomness, tick model, transition rules; how the character system consumes it per 04-character-system §9)
5. Persistence architecture (SwiftData vs alternatives — decide with rationale; corruption/recovery stance; migration policy)
6. iPhone↔Watch synchronization strategy (transport, freshness/staleness rules, conflict handling, what happens with no iPhone/paired-but-away; per §32 sync test matrix)
7. HealthKit strategy (Phase 2 reservation: permission UX contract, data minimization, read-only step counts, denied-permission degradation)
8. Widget architecture (Phase 2 reservation: timeline budget, shared state read path)
9. Notification architecture (Phase 2 reservation: categories, frequency governor, quiet rules per §15)
10. Testing architecture (per-target test plan mapping §32's domain/persistence/sync/UI/edge matrices to concrete test targets)
11. Privacy architecture (data inventory, on-device stance, privacy manifest implications, deletion story; §25)
12. Performance budget (launch, animation frame target, Watch battery stance, §33)
Also create ADRs under `.claude/tasks/decisions/` (format per CLAUDE.md §21). **ADR-001 is already taken** (character direction, E2 owner decision) — continue the sequence, minimum:
- ADR-002-local-first-persistence.md
- ADR-003-watch-sync-strategy.md
- ADR-004-pet-state-engine.md
Plus any additional ADRs for decisions with real alternatives (e.g., module packaging, animation runtime).
Rules:
- Verify API/deployment claims against current official Apple documentation knowledge; where uncertain, mark VERIFY-AT-BUILD rather than asserting (project.md §21, §25 "no fake completion").
- Deployment target choice must be explicit and justified.
- No enterprise abstractions without demonstrated value (§22).

## Files / Areas Likely Affected
- Creates `docs/architecture/05-technical-architecture.md`
- Creates `.claude/tasks/decisions/ADR-001…00n.md`

## Dependencies
- TASK-004 ✅ DONE (`40c4b77`) and TASK-005 ✅ DONE (`ce84811`) — both satisfied. E2 owner gate RESOLVED: **Direction C — Round Rabbit** (ADR-001).

## Intake Obligations (accumulated from TASK-004/005 reviews — binding)
- DisplayState read-model (UX §7); FR-2 AC-1a device matrix (UX §5.1 budget).
- Hello idempotency + the hello/Q1 window split: hello (+8) once per local day on first touch from either device, never window-gated; Q1 ticks only before 12:00 (UX §11.3).
- Haptics sync to Watch (UX-13 reduces to haptics — no sound in Phase 1 per 04 §11).
- Watch snapshot restore ≤ ~2 s (protects FR-17 ≤ 5 s); invisible corruption-recovery cadence (FR-13 AC-2).
- From 04 §9: ResponsePlan per PRD §4 matrix (engine decides what/when, never warm/cold); satiety window value (open — TASK-006 decides); settle/wake/play handshakes with idempotent completion reports AND `handshakeCancelled(HandshakeKind)` cancellation reports; play effects applied at the single instant the round ceases (completion or preemption, §9.6 item 4); single CharacterClock pause authority; day-stable idle seed = hash(petID, localDay, choreographyEpoch); copy-class namespace (`momo.line.<slot>.<nn>`, `momo.line.react.<family>.<nn>`, `momo.line.moment.<nn>`) with M2 banner + M3 all-done surfaces.
- OBS-1: 04 §3.5's VoiceOver formula governs wording (03:428's literal template hard-codes "has {energy phrase}"); OBS-2: exempt the M2 banner from tone rule 2's 12-word max or scope rule 2 to visual lines — resolve in the copy/engine sections as appropriate.
- **PRD §5.5 cascade rule 1 gap — flag to owner:** rule 1's "local time ≥ 20:00" misses Q6's 00:00–07:00 tail when Q1 is already complete (e.g., 02:00 tuck-in). TASK-006 must surface this as a one-line PRD fix candidate, not silently re-interpret it.

## Constraints
- Jupiter model, fresh agent, no commit by agent.

## Acceptance Criteria
- All 12 sections present; domain model has types + invariants; engine design is testable-by-construction (pure core, injected clock/random); sync strategy covers the §32 sync edge matrix; ADRs exist with Status/Context/Decision/Alternatives/Consequences/Date; every open Apple-API question is marked VERIFY-AT-BUILD, none asserted blindly.
- Review verdict ≥ APPROVED_WITH_MINOR_NOTES.

## Required Tests
- Not applicable (document). Independent review agent required.

## Review Requirements
- Fresh reviewer (architecture mindset) verifies: dependency rules actually enforceable, engine determinism/injectability, sync conflict coverage, persistence choice rationale, no speculative Phase 2+ implementation, ADR completeness. Record in `.claude/tasks/reviews/REVIEW-TASK-006.md`.

## Git Requirements
- Commit (orchestrator, post-approval): `docs(architecture): TASK-006 technical architecture and ADRs`

## Status
DONE (REVIEW-TASK-006: CHANGES_REQUIRED → fresh fix agent applied all 13 findings → fresh verifier ALL_FIXES_VERIFIED → APPROVED; 3 non-blocking residuals closed mechanically by the orchestrator. Committed `docs(architecture): TASK-006 technical architecture and ADRs` — hash "(this commit)" in status.md until the next task's commit records it explicitly.)

## Implementation Notes
- (agent fills in)

### Implementation Notes — TASK-006 agent, 2026-09-08

Deliverables: `docs/architecture/05-technical-architecture.md` (12 sections + Appendices A–C: intake traceability, open/VERIFY-AT-BUILD register, §30 traceability) and ADRs 002–007 under `.claude/tasks/decisions/`. No code, no project files, nothing committed.

**Section-by-section key decisions:**

1. **System context (§1):** two-device fully offline system; single engine host (iPhone); Watch renders snapshots + queues pats only; hard boundaries restated (no cloud/analytics/third-party SDKs/location/permissions); Phase 2 extension points drawn as reservations.
2. **Module architecture (§2, ADR-005, ADR-006):** local SPM package with `MomoCore` (Foundation-only purity, macOS `swift test`), `MomoCharacter` (rig/clock/sequencer/LODs), `MomoKit` (store, sync DTOs, journal) + `Momo`/`MomoWatch` app targets; 6 enforceable dependency rules with enforcement mechanisms; idle sequencer placed in MomoCharacter (04 owns choreography; pure files still headless-testable). **Deployment targets: pinned at EPIC-002 bootstrap to the current shipping OS generation (expected iOS 26 / watchOS 26 or successors — VERIFY-AT-BUILD); N-1 explicit non-commitment, re-evaluated at release.**
3. **Domain model (§3):** value types only, Sendable; Pet/PetState/DayRecord(7-day ledger)/QuestProgress/SettingsState; bands and stages are pure derivations, never stored; Room deliberately has NO domain entity in Phase 1 (static scene, D13/K4) — recorded, not silently dropped; 11 numbered invariants each mapped to test targets.
4. **Engine (§4, ADR-004):** single pure `reduce(state, event, clock, rng)`; **event-driven catch-up fold, no timers/background work** (segment folding of waking/night/midnight/nap; triggers = foreground, interaction, report, scheduled in-session boundaries, OS time-change); time-fold starting values table (decline 1.5/h; night ramp to 85 with ≥75 clamp; attractor 60 τ=3h; coupling target 35 floor 25); **satiety DECISION: 90 min window** (0–30 `.full` refusal/zero effects; 30–90 `.recentlyFed` nibble ×0.25 — response class proposed as I-2/OPEN-5, pending owner confirmation; then `.hungry`; phasing label corrected in the fix pass below) with justification and rejected alternatives; counting rules implement PRD letter (feed counts always incl. refusals — flagged interpretation I-1; play counts on round completion only); bond ledger with clamp-at-award +20 cap (2-quest variety day = 8+8+4, PRD's own arithmetic made explicit); **handshakes token-matched idempotent + `handshakeCancelled` always available; play effects CONFIRMED at the single instant the round ceases; settling interactions CONFIRMED as decline-warm, never queue**; quest generation by construction (constraint-filter-before-draw; unknown priors force Q6; candidate space provably non-empty); **cascade implements PRD §5.5 letter with the rule-1 gap flagged as PRD FIX CANDIDATE (00:00–07:00 Q6 tail) — not silently re-interpreted**; copy = keys-only from the three namespaces, OBS-1 resolved to 04 §3.5 formula, OBS-2 resolved by scoping the 12-word max to visual body-copy classes (M2/M3 `moment` class exempt); seeds SHA-256(petID‖dayKey‖epoch‖salt); DisplayState read-model defined as the one derivation behind Home/W1/future widgets.
5. **Persistence (§5, ADR-002):** **plain Codable atomic file store over SwiftData** — envelope+checksum, write-through per event, 3 generations, invisible recovery (worst case = 1 event, FR-13 AC-2; fresh-pet regeneration documented as catastrophic-disk limit), additive-first migration policy with explicit chain for breaking changes, 7-day ledger pruning; Watch store = snapshot(+prev) + NDJSON intent journal.
6. **Sync (§6, ADR-003):** WatchConnectivity — `updateApplicationContext` (iPhone→Watch snapshot, latest-wins) + `transferUserInfo` (Watch→iPhone queued intents) with `sendMessage` as best-effort immediacy only; **dual idempotency guards** (iPhone UUID set + watchSeq/watermark journal pruning); conflict handling dissolved by construction (only commutative additive pat events cross the link); no-iPhone/paired-but-away/erase-marker/offline-midnight/termination cases tabulated; §32 sync matrix mapped to tests incl. device-only obligations.
7. **HealthKit (§7):** reservation only — `ActivitySource` port, additive `steps` field via §5.5 migration, read-only aggregates, decline-first-class UX, never-leaves-device policy, TR5 late/retroactive tolerance.
8. **Widgets (§8):** reservation only — DisplayState + cascade at timeline-entry build time, day-phase entries, app-group entitlement + file-protection change enumerated as Phase 2 scope.
9. **Notifications (§9):** reservation only — local scheduling, category controls, frequency governor shape (≤2/day starting value, min spacing, no absence-dependent content), night-window quiet rules, §15 tone checklist as standing gate.
10. **Testing (§10):** 5 test targets; headless-first strategy; coverage floors (Core ≥90%, Kit ≥80%); static banned-vocabulary build test; §32 domain/sync/edge matrices mapped row-by-row to named tests; device-only obligations (WC delivery, energy) explicitly not claimable from unit tests.
11. **Privacy (§11):** complete data inventory (all local; only paired-link egress); "Data Not Collected" label target; privacy manifest minimal (required-reason APIs avoided — VERIFY-AT-BUILD); deletion story with erase marker + honest offline-Watch retention limit; **Phase 1 entitlements = zero** (enumerated Phase 2 additions only).
12. **Performance (§12):** budgets table (launch ≤2.0 s; 60 fps / 8 ms frame; 150 MB iPhone / 80 MB Watch provisional; ≤60 MB download, art ≤1.5 MB; energy-gauge Low; snapshot restore ≤~2 s); device matrix defined as intake-bound (smallest pinned-OS device, SE-class expected — VERIFY-AT-BUILD names at bootstrap).

**OPEN items fenced (Appendix B):** OPEN-1 PRD §5.5 rule-1 gap (owner doc fix; letter implemented + flip-ready test); OPEN-2 interpretation I-1 (refused feeds count toward feedCount/quests — FR-6 AC-3 letter; required for Q3 ≤2-min completability); OPEN-3 bootstrap pins (OS versions, device names, test idioms); OPEN-4 sequencer placement rationale. VERIFY-AT-BUILD consolidated register included.

### Implementation Notes — fix pass for REVIEW-TASK-006 (CHANGES_REQUIRED), 2026-09-08

Finding → resolution, one line each; no commits, no review-record changes:

- **MAJOR-1** (recently-fed nibble vs FR-6): framing corrected in 05 §0 #7 / §4.4 / §4.5 and ADR-004 — the window VALUE is PRD-delegated, the response classes are PRD-owned; the nibble is registered as interpretation I-2 / OPEN-5 (PRD FIX CANDIDATE note on FR-6/§4 wording; flip-ready response-matrix test: conformance = delete the nibble row, 30–90 min → politely-full; disposition "proposed, pending owner confirmation"). No numbers or mechanics changed.
- **MAJOR-2** (sync guard reset semantics): per-install `watchSessionEpoch` added to `IntentEvent` (05 §6.2), persisted in the Watch store (§5.6); iPhone stores `lastAppliedIntentSeq` per epoch, unseen epoch initializes at 0 (§6.4); snapshot carries `lastAppliedEpoch` so a stale watermark never prunes a newer journal; expired-dayKey rule added (§6.4: current-state effects, day-ledger attribution dropped, days never resurrected); §6.6 rows added for Watch re-pair/reinstall/new Watch and iPhone reinstall with paired Watch (WC transfer retention across reinstall VERIFY-AT-BUILD, registered in Appendix B); §10.4 counter-reset test row added; §11.3 unpairing note connected to the epoch.
- **MINOR-1**: §4.8 window checks explicitly evaluate the interaction's own local timestamp — consistent with dayKey attribution — never the application instant.
- **MINOR-2**: §4.7 waking rule added — interactions during `.waking` decline warm (symmetric with settling), the decline referencing the post-wake state; engine contract total over `.waking`; ADR-004 updated to "settling and waking".
- **MINOR-3**: `makeCharacterDisplayState(_:)` added beside `makeDisplayState` (§4.11) covering 04 §9.2's character-facing fields; "the one derivation" softened to "one read-model per consumer family" (§4.11 heading/body, §6.2 comment, §2.1 MomoCore row, Appendix A).
- **MINOR-4**: D-R1 claim corrected in 05 §2.3 and ADR-005 — a macOS build catches platform-unavailable imports (UIKit, WatchKit, WatchConnectivity, HealthKit), not SwiftUI; residual closed by an import-whitelist scan in MomoCoreTests (§10.2) plus SwiftUI-residue on the standing review checklist. Rule kept.
- **NITPICK-1**: both dangling pause-authority refs (§4 intro, §4.7 diagram) repointed §4.8 → §4.1/§4.2, matching Appendix A.
- **NITPICK-2**: mood-ceiling wording tightened to "complete-quest-set and stage moments" (§4.4).
- **NITPICK-3**: §0 #7 "two-phase" aligned with §4.5's three phases; `fedTodayPhase` → `satietyPhase`; `{ didSet-free; ≥ 0 }` rendered as a comment; `DayRecord` ≡ project.md §24 `DailyProgress` naming equivalence stated (§3.1).
- **NITPICK-4**: déjà-vu claim softened to "day-stable within a day, seeded across days" (§4.9); no no-repeat mechanism added.
- **NITPICK-5**: garbled trigger cell fixed → "every open (iPhone only — the Watch has no engine)" (§4.2).
- **NITPICK-6**: §11.1 inventory aligned with the actual `WatchSnapshot` — petID and createdAt NOT mirrored (data minimization stated); `watchSessionEpoch` disclosed as a random per-install sync-guard id, not a device identifier.
- **NITPICK-7**: care-family repetition-curve exemption justified (§4.4): care is window/band-gated; the curve's grind-protection purpose does not apply.

Consistency sweep done post-edit: `watchSessionEpoch`, `satietyPhase`, `makeCharacterDisplayState`, and I-2/OPEN-5 are used consistently across 05, ADR-004, ADR-005, and this note; Appendix A/B updated; no dangling refs introduced by the pass.

## Reviewer Findings
- REVIEW-TASK-006 (fresh independent agent): **CHANGES_REQUIRED — 2 MAJOR + 4 MINOR + 7 NITPICK**, full record in `.claude/tasks/reviews/REVIEW-TASK-006.md`.
  - MAJOR-1: 30–90-min "recently-fed nibble" was a new response class contradicting FR-6's normative assignment, framed as PRD-delegated and unflagged.
  - MAJOR-2: sync guards (`watchSeq`/watermark) had no reset semantics — a re-paired/new Watch would silently starve all later pats; iPhone-reinstall and expired-dayKey edges absent.
  - 4 MINOR: Q1/Q6 window reference time for delayed intents; `.waking` interaction semantics undecided; `CharacterDisplayState` derivation unplaced; D-R1's macOS-purity enforcement claim overstated (SwiftUI compiles on macOS).
  - 7 NITPICK: dangling §4.8 refs; mood-ceiling wording; §0/§3.1 labels; déjà-vu overclaim; garbled trigger cell; privacy inventory vs actual DTO; care-curve exemption silent.
  - Reviewer also CONFIRMED: OPEN-2/I-1 (refused feeds count) correct; OPEN-1 (§5.5 rule-1 gap flagged as PRD fix candidate) correct with the drafted fix endorsed; engine purity structural; bond/quest/seed arithmetic exact vs PRD; all three mandated scenario walks hold; all five §32 test matrices mapped; VERIFY-AT-BUILD discipline real; Phase 2 reservations-only; ADR-001 not contradicted.
- Fix pass: fresh fix agent `task-006-fixer` applied all 13 under orchestrator rulings (MAJOR-1 → reviewer option (b): nibble kept, framed as proposed, registered I-2/OPEN-5 with flip-ready test; MAJOR-2 → per-install `watchSessionEpoch` + per-epoch watermarks + epoch-matched pruning + lifecycle rows; MINOR-2 → decline-warm over `.waking`).
- Verification: fresh verifier `task-006-verifier` — **ALL_FIXES_VERIFIED**; scenario re-walks defined; regression sweep clean. Disposition in REVIEW-TASK-006.md. Final: **APPROVED**.
- Residuals (non-blocking) closed mechanically by the orchestrator: task-file "two-phase" label; ADR-003 per-epoch qualification + `lastAppliedEpoch` in snapshot payload; 05 §6.2 watermark comment phrasing + Appendix A row-1 citation annotation.

## Completion Evidence
- Commit: `(this commit)` — `docs(architecture): TASK-006 technical architecture and ADRs` (hash recorded explicitly in the next task's status.md update, per established pattern).
- Push: main → origin (recorded explicitly at next status.md update).
- Deliverables: `docs/architecture/05-technical-architecture.md` (12 sections + Appendices A–C); ADR-002…ADR-007 under `.claude/tasks/decisions/`.
- Review record: `.claude/tasks/reviews/REVIEW-TASK-006.md` incl. orchestrator disposition + verification verdict.
- Tests: not applicable (document); independent review per contract §10 — completed with verification pass.

## Handoff

### Completed
All 12 required sections + Appendices A (16/16 intake traceability), B (OPEN-1..5 + I-1/I-2 + VERIFY-AT-BUILD register), C (§30 traceability); ADRs 002–007 (persistence, watch sync, engine, module packaging, deployment targets, animation runtime); full fix pass verified.

### Files Changed
- `docs/architecture/05-technical-architecture.md` (new)
- `.claude/tasks/decisions/ADR-002…007` (new; ADR-003 touched by orchestrator for epoch accuracy)
- `.claude/tasks/reviews/REVIEW-TASK-006.md` (new)
- `.claude/tasks/active/TASK-006-technical-architecture.md` → `completed/` (this commit)
- `.claude/tasks/status.md`, `.claude/tasks/epics/EPIC-001-product-definition.md`

### Tests Run
Not applicable (document task) — independent review + verification pass instead.

### Test Results
REVIEW-TASK-006: CHANGES_REQUIRED → ALL_FIXES_VERIFIED → APPROVED.

### Known Issues
- Two owner decisions pending (batched, non-blocking): **I-2/OPEN-5** nibble response class (30–90 min ×0.25 vs FR-6 letter's politely-full; flip-ready test pre-marked); **OPEN-1** PRD §5.5 cascade rule-1 gap (00:00–07:00 Q6 tail; one-line PRD fix drafted). TASK-007 must carry both as open inputs.
- OPEN-3: bootstrap pins (OS versions, device names, test idioms) resolve at EPIC-002 bootstrap (TR10). All VERIFY-AT-BUILD items consolidated in 05 Appendix B.

### Decisions Made
- Persistence: plain Codable atomic store over SwiftData (ADR-002); Sync: WatchConnectivity-only with dual epoch-scoped guards (ADR-003); Engine: pure event-driven `reduce` (ADR-004); satiety window 90 min; deployment pins at EPIC-002 bootstrap (ADR-006); sequencer in MomoCharacter (OPEN-4).

### Reviewer Status
APPROVED (after fix + independent verification).

### Commit
`(this commit)` — docs(architecture): TASK-006 technical architecture and ADRs

### Push
main → origin (recorded explicitly at next status.md update)

### Recommended Next Step
Batch the two owner decisions (nibble I-2/OPEN-5; §5.5 OPEN-1) via AskUserQuestion → record outcomes → spawn fresh TASK-007 agent (Step 6 Delivery Plan) with status.md's intake.
