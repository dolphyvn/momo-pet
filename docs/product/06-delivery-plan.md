# Momo — Delivery Plan (Step 6)

| | |
|---|---|
| Task | TASK-007 — Step 6: Delivery Plan (project.md §40 Step 6, §30 item 23) |
| Date | 2026-09-08 |
| Inputs | `project.md`; `docs/product/01-product-review.md` (D1–D20 binding); `docs/product/02-mvp-prd.md` (**normative, as amended 2026-09-08**: §5.5 rule 1 "(≥ 20:00 ∨ < 07:00)"; FR-6/§4 carry the 30–90-min nibble ×0.25, owner-confirmed); `docs/design/03-ux-architecture.md` (UX-1–UX-14); `docs/design/04-character-system.md` (Direction C per ADR-001; §10 tone guide governs all strings); `docs/architecture/05-technical-architecture.md` (module/test/persistence/sync/engine contracts binding); ADR-001…007 |
| Status | REVIEWED — APPROVED_WITH_MINOR_NOTES; minor findings fixed pre-commit (see `.claude/tasks/reviews/REVIEW-TASK-007.md`) |
| Scope | Phase 1 only (project.md §27; PRD §8.1). No Phase 2–4 implementation tasks exist here; §8 records reservations and an outlook only. |
| Authority | The PRD is the normative product source; 03/04/05 + ADRs are the binding engineering contracts. Where this plan sequences work, it never re-decides content — a conflict resolves toward the PRD and the ADRs, and the plan (not the requirement) yields. |

---

## 1. Planning Method

1. **Vertical slices, not layers (project.md §40 Step 7).** The first vertical slice — *Launch → Momo visible → idle animation → touch → react → state change → persist → Watch receives state* — is the ordering spine (§4). Each epic ends on a demonstrable increment of that slice (§2), so the product is always resumable and demoable at epic boundaries (CLAUDE.md §16).
2. **Granularity (CLAUDE.md §32).** Every task is independently understandable, implementable, testable, reviewable, and committable. The contract's own example split — *define model / implement engine / add tests / connect to view / persist* — is honored: domain model, engine, and comprehensive test suites are separate tasks; UI tasks fold their focused UI tests in-task, with dedicated hardening tasks where a suite is substantial.
3. **Domain before UI.** EPIC-003/004/005 (pure domain, engine, persistence logic) precede EPIC-006/007/008 (character, iPhone, Watch). Headless `swift test` coverage (05 §10) exists before any view consumes the logic.
4. **Phase discipline.** Anything Phase 2+ appears only as a reservation reference (05 §7–§9, 03 §7), never as a task. Non-goals restated in §8.3 of the PRD bind every task file.
5. **Branch model (orchestration decision: feature branches from EPIC-002).** Each epic executes on one feature branch (`feature/EPIC-00X-slug`) cut from `main` at epic start. Task commits land sequentially on the epic branch — one atomic commit per task, TASK-ID in the message (CLAUDE.md §12), pushed after each task (§13). The epic branch merges to `main` only when the epic's DoD is met. No two agents share a branch without orchestrator coordination (§14).
6. **Size legend.** S ≈ ≤ 0.5 agent-day · M ≈ 0.5–1.5 agent-days · L ≈ > 1.5 agent-days (rough, for sequencing only — never a commitment).
7. **Owner-confirmed amendments consumed everywhere:** cascade rule 1 window, satiety nibble class (0–30 full refusal / 30–90 nibble ×0.25 / >90 full), satiety window value 90 min (ADR-004).
8. **ADR numbering continues at ADR-008+**; the first build-time decision record (deployment pins, device matrix — OPEN-3/ADR-006) is ADR-008, produced by TASK-008.
9. **No punishment mechanics anywhere.** Any task touching copy is bound by FR-12 + the 04 §10 tone guide and the banned-vocabulary static test (05 §10.2). Bond never decreases; absence never penalizes; nothing gates affection (D3/D4/D18, G1–G3).
10. **VERIFY-AT-BUILD ownership.** Every item in 05 Appendix B's register has exactly one owning task (see §7 risk register + task files). Nothing is asserted from memory at build time (project.md §21, §25).

---

## 2. Epic Overview

| Epic | Name | Objective | Ends with (slice increment) | Tasks | Size |
|---|---|---|---|---|---|
| EPIC-002 | Foundation & Build Baseline | Toolchain verified, SPM + app targets exist, test harness + tokens in place | App launches on iPhone/Watch simulators showing a placeholder Home shell; `swift test` green | TASK-008…011 (4) | M |
| EPIC-003 | Pet Domain Model | MomoCore value types + invariant-enforcing derivations per 05 §3 | Band/invariant property tests green headlessly | TASK-012…013 (2) | S |
| EPIC-004 | Pet State Engine | Deterministic pure `reduce` implementing PRD §3–§5 + 05 §4 | Full §10.3 domain matrix green; engine simulatable for all §32 edge cases | TASK-014…020 (7) | L |
| EPIC-005 | Persistence & Sync Logic (MomoKit) | ADR-002 store + ADR-003 pure sync logic (DTOs, journal, watermarks) | Store/journal roundtrip, corruption-recovery, migration, idempotency tests green | TASK-021…024 (4) | M |
| EPIC-006 | Character Rendering (MomoCharacter) | Direction-C rig, clock, sequencer, reactions, Reduce Motion, LOD tiers | Momo renders alive (idle + reactions) on a debug canvas | TASK-025…030 (6) | L |
| EPIC-007 | iPhone Home Experience | Onboarding, Home, Room, Settings; full interaction loop wired to engine + store | **Vertical slice minus Watch:** launch → onboarding → Momo visible → idle → touch → react → state change → persist | TASK-031…039 (9) | L |
| EPIC-008 | Watch App & Sync | W1 glance, pat journaling, WatchConnectivity both directions, idempotency | **First vertical slice complete:** iPhone state reaches the Watch; offline pat applies exactly once | TASK-040…044 (5) | L |
| EPIC-009 | Polish, QA & Release Readiness | Performance budgets, §32 edge matrix, accessibility, privacy, tone, release gates | Phase 1 passes every §35 DoD condition and the §44 final product test | TASK-045…050 (6) | M |

**Total: 8 epics, 43 tasks (TASK-008…050).** Task files are created just-in-time by the orchestrator per batch (CLAUDE.md §8/§9); §3's tables are the backlog of record.

---

## 3. Task Breakdown (backlog of record)

Sizes and dependencies are per-task; "Depends on" may span epics. Every task's file, when created, will carry full §8 self-sufficiency (PRD FR/NFR + architecture citations, ACs, tests, branch).

### EPIC-002 — Foundation & Build Baseline (branch `feature/EPIC-002-foundation`)

| TASK | Title / Objective | Key acceptance criteria | Required tests | Depends on | Size |
|---|---|---|---|---|---|
| TASK-008 | Verify toolchain & pin deployment targets (TR10, OPEN-3, ADR-006) | Xcode verified present (or BLOCKED recorded per CLAUDE.md §3); current shipping iOS/watchOS generation confirmed; minimum deployment targets pinned; iOS↔watchOS pairing rule recorded; device matrix device names fixed (05 §12); all recorded in ADR-008 | Verification-command evidence recorded in task file (no code) | — | S |
| TASK-009 | Create the local Swift Package + app targets with placeholder shell (ADR-005) | `Package.swift` defines `MomoCore` (Foundation-only), `MomoCharacter` (Core+SwiftUI), `MomoKit` (Core) with zero external dependencies; `Momo` (iOS) + `MomoWatch` (watchOS) app targets consume them; both launch in simulators showing a placeholder Home/W1 shell; deployment pins applied; `swift test` hostability VERIFY item resolved | Build succeeds for both simulators; `swift test` runs (empty suites pass); launch evidence recorded | TASK-008 | M |
| TASK-010 | Test-target scaffolding + import-whitelist + banned-vocabulary harness (05 §10.1–10.2, D-R1) | `MomoCoreTests`, `MomoKitTests`, `MomoCharacterTests` run via `swift test` on macOS; `MomoUITests` / `MomoWatchUITests` exist and run on simulators; import-whitelist scan fails on any non-Foundation `import` in MomoCore; banned-vocabulary static test scans String Catalogs against 04 §10.2 and fails on a hit (vacuously green on empty catalogs); test framework pinned (VERIFY-AT-BUILD resolved) | Harness self-tests (a deliberate violation fails the scan, in a scratch commit reverted before review) | TASK-009 | M |
| TASK-011 | Design-system token pass + String Catalog scaffolding (project.md §18; 04 §8.4, Appendix B item 3) | One palette pass assigns project.md §18 UI tokens + all 8 character slots (`momo.fur.base` … `momo.sparkle`) in light/dark; typography/spacing/radius tokens per §18; tokens live as Swift constants (no hex anywhere downstream, R4); String Catalogs exist with `momo.line.<slot>`, `momo.line.react.<family>`, `momo.line.moment` namespaces (pools empty until engine tasks fill them) | Build green; token file imports clean in both app targets; catalog keys resolvable | TASK-009 | M |

**Epic slice:** launch → placeholder shell visible on both devices. TR10 and all OPEN-3 pins die here or become recorded blockers.

### EPIC-003 — Pet Domain Model (branch `feature/EPIC-003-domain-model`)

| TASK | Title / Objective | Key acceptance criteria | Required tests | Depends on | Size |
|---|---|---|---|---|---|
| TASK-012 | Define MomoCore domain model (05 §3.1) | All §3.1 value types (`Pet`, `PetState`, bands, `BondStage`, `DayRecord`, `QuestProgress`, `InteractionIntent`, `SettingsState`) + interface types from 04 §9.2 (`CharacterDisplayState`, `CharacterMoment`, `ResponsePlan`, `CharacterReport`, `HandshakeKind`) as `Sendable` value types; pure derivations `makeMoodBand/makeEnergyBand/makeBondStage` (PRD §3 tables as single source); `dayKey` derivation via injected calendar (D20); invariants INV-1…11 enforced at type boundaries | Focused unit tests in-task (name invariant, dayKey derivation) | TASK-009 | S |
| TASK-013 | Add domain-model property tests (FR-9 AC-1) | Band property tests sweep 0…100 exhaustively against the PRD §3.1–3.2 cut-offs (20/45/75; attractor values out of scope here — engine); stage thresholds 149/399/749; no numeric leakage types exist | Property tests over the full range (MomoCoreTests) | TASK-012 | S |

**Epic slice:** the domain is executable and provably matches the PRD tables — before any dynamics exist.

### EPIC-004 — Pet State Engine (branch `feature/EPIC-004-engine`)

| TASK | Title / Objective | Key acceptance criteria | Required tests | Depends on | Size |
|---|---|---|---|---|---|
| TASK-014 | Implement engine core: `reduce`, EngineClock, seeded RNG, day-stable seeds (05 §4.1, §4.10; ADR-004) | Single pure entry point `reduce(state, event, clock, rng)`; `EngineState`/`EngineEvent`/`EngineOutcome` per 05 §4.1; repo-owned SplitMix64-class generator; SHA-256-seeded day-stable seeds (choreography/copy/quest salts); no I/O, no `Date()`, no system randomness anywhere in the core | Determinism spot tests (identical inputs ⇒ identical outcome); Swift `Clock` idiom VERIFY item resolved | TASK-012 | M |
| TASK-015 | Implement time-fold catch-up + wakefulness machine + handshakes (05 §4.2–4.3, §4.7) | Segment folding over waking/night/midnight/nap (§4.3 table: decline −1.5/h, restore to 85/≥75, attractor τ=3 h, coupling target 35 floor 25); dayKey-keyed once-only rollover; absence folds harmlessly (FR-12); wakefulness machine per §4.7 diagram (INV-8); settle/wake/play handshakes with idempotent reports + `handshakeCancelled` path; interactions during settling/waking decline warm, never queue (ADR-004) | Fold tests: night onset, morning wake, midnight rollover ×1, DST/TZ cases; handshake late/duplicate/cancelled tolerance | TASK-014 | L |
| TASK-016 | Implement interaction semantics + satiety + repetition curve (05 §4.4–4.5) | Full PRD §4 response matrix (table test shape) across bands × wakefulness × satiety; counting rules (feed always — incl. refusal/nibble; play on round completion only; pats always; care when performed); satiety window 90 min, three phases: 0–30 `.full` refusal (zero effects), 30–90 `.recentlyFed` nibble ×0.25 (owner-confirmed I-2), >90 `.hungry`; same-family repetition curve 1.0/0.6/0.25/~0; effect table with mood ceiling 92 | Response-matrix table tests incl. the nibble as normative and the refusal-warm cells; satiety phase boundaries | TASK-015 | L |
| TASK-017 | Implement bond ledger (05 §4.6; FR-10) | Enumerated award events (hello +8 first-touch-either-device-never-window-gated; quest +4; variety +6; cap clamp-at-award +20); monotonic everywhere (INV-3); `highestCelebratedStage` once-guard for stage moments | Cap-by-construction property over randomized sequences; 1000-pats-zero-bond; hello idempotency incl. post-12:00 first touch | TASK-016 | M |
| TASK-018 | Implement quest generator + Watch cascade (05 §4.8; FR-14–16) | `generate(dayKey, seed, priorTwoSets, questGenEpoch)` with by-construction constraints (consecutive-pair ban; Q6-in-3-day-window, unknown priors force Q6; provably non-empty candidates); static Q1–Q7 catalog; window checks at the interaction's own local timestamp (Q1 < 12:00; Q6 ∈ 20:00–07:00; D20 day-ownership); §5.5 cascade implementing the amended rule 1 ("≥ 20:00 ∨ < 07:00") | Generator determinism; candidate-space non-emptiness; window checks; **named cascade test: 02:00 tuck-in with Q1 done selects Q6** (05 §4.8 box) | TASK-014 | M |
| TASK-019 | Implement DisplayState + CharacterDisplayState read-models + copy-key selection (05 §4.9, §4.11) | `makeDisplayState(_, at:, calendar:)` and `makeCharacterDisplayState(_)` pure derivations; VoiceOver word/phrase **keys** per 04 §3.5 (OBS-1); `momo.line.*` key selection day-stable by slot (OBS-2: M2 banner exempt from 12-word rule); engine composes no sentences (INV-11) | Derivation golden tests; slot-window selection tests; day-stability of picks | TASK-015, TASK-017, TASK-018 | M |
| TASK-020 | Add engine test suites — the §10.3 domain matrix + property tests + coverage floor | Every §10.3 row exists as a named test (mood/energy transitions, bond progression, daily reset, quest progression, engine rules incl. handshakes + play single-instant application, deterministic randomness); meta-determinism property over seeded random interaction sequences; **MomoCore ≥ 90 % line coverage recorded** (05 §10.2) | Full MomoCoreTests suite green via `swift test` on macOS | TASK-014…019 | L |

**Epic slice:** the whole product's dynamics are executable and headlessly provable — the iPhone has nothing to render yet, which is the point (domain before UI).

### EPIC-005 — Persistence & Sync Logic, MomoKit (branch `feature/EPIC-005-persistence`)

| TASK | Title / Objective | Key acceptance criteria | Required tests | Depends on | Size |
|---|---|---|---|---|---|
| TASK-021 | Implement SnapshotStore — envelope, atomic writes, generational recovery (05 §5.1–5.3; ADR-002) | `{schemaVersion, savedAt, checksum, payload}` envelope; write-temp-then-atomic-rename, serialized per event (write-through); 3 generations (`state.json`/`.prev`/`.prev2`); read path current→prev→prev2→fresh default with **no error surface**; intent ledger travels inside the payload | Roundtrip, checksum-failure recovery, torn-write simulation, write-through loss ≤ 1 event | TASK-012, TASK-014 (EngineState shape) | M |
| TASK-022 | Implement migration chain + retention/pruning (05 §5.4–5.5) | Additive evolution via decode defaults; explicit `migrate(v→v+1)` chain for breaking changes, pure and total; 7-day DayRecord retention + ≤ 64 processedIntents cap, deterministic pruning | Migration chain tests; **fresh-install vs upgrade parity** (NFR-7, §32 upgrade edge); pruning determinism | TASK-021 | S |
| TASK-023 | Implement sync DTOs + intent journal + watermark arithmetic (05 §6.2, §6.4 pure logic; ADR-003) | `WatchSnapshot` + `IntentEvent` Codable versioned DTOs; append-only NDJSON journal; per-`watchSessionEpoch` watermark semantics incl. 0-initialization on unseen epoch and epoch-matched pruning only; expired-dayKey intent rule (current-state effects, day attribution dropped) | Journal/watermark unit tests: duplicate delivery no-op, replay no-op, epoch-reset flows, stale-epoch never prunes (INV-10) | TASK-012 | M |
| TASK-024 | Add MomoKit test suites — persistence + sync pure-logic coverage floor | §32 Persistence row fully covered (save/load, migration, corruption/recovery); sync-matrix pure halves (idempotency properties, watermark arithmetic, codec versioning); **MomoKit ≥ 80 % line coverage recorded** (05 §10.2) | Full MomoKitTests green via `swift test` | TASK-021…023 | M |

**Epic slice:** state survives force-quit, corruption, and upgrade — provably, headlessly.

### EPIC-006 — Character Rendering, MomoCharacter (branch `feature/EPIC-006-character`)

| TASK | Title / Objective | Key acceptance criteria | Required tests | Depends on | Size |
|---|---|---|---|---|---|
| TASK-025 | Build the asset export pipeline + generated Path constants (04 §8.2, §8.5; ADR-007) | Repo-local build-time script (tooling choice VERIFY-AT-BUILD) exporting Direction-C geometry to committed, reviewable Swift `Path` constants: full rig (~17 parts), LOD-glance variant, glyph variant (ear-thickness rule; below ~32 pt ears merge into head outline per ADR-001), room scene + props (food, blanket, 2 sparkles, static pom decor); art budget ≤ 1.5 MB source contribution (04 §8.3) | Pipeline runs reproducibly; committed output compiles; size budget measured | TASK-009, TASK-011 | M |
| TASK-026 | Implement MomoRig layer tree + CharacterClock + LOD tiers (04 §2, §7.4, §9.5) | Transform-only motion on pre-built layers (R1/R2); rig rules R1–R4 (token colors only); single CharacterClock gates L0–L4 and is zeroed on scenePhase ≠ active / AOD (one-call pause); LOD tiers full / LOD-glance / glyph selected per surface | CharacterTests: clock pause/resume; every channel independently pausable | TASK-025, TASK-012 (interface types) | L |
| TASK-027 | Implement idle sequencer + expression system (04 §3, §5) | Pure sequencer files: scheduler parameters (§5.2), variant catalog, deterministic given (idleSeed, timeline); mood-band expressions (§3.2) + energy modulation (§3.3) + bond behavior dials (§3.4) — posture-led, no suffering visuals (INV-6); motion timings/curves per §7.1–7.2 | Sequencer determinism properties (same seed+timeline ⇒ same event log); aliveness-floor fallback; no-distraction motionlessness check | TASK-026 | L |
| TASK-028 | Implement reaction vocabulary + state choreography + CharacterReport emission (04 §4, §6, §9.2) | L0–L4 priority classes with the §4.1 coherence rules (blink preemptible; L2 crossfade; rapid-pat coalescing per 500 ms window; sleeping accepts only stir; eating/play rules; app-hide pauses everything); §6.1 gesture×zone reactions (7 distinct + stir + refusals); play-round character-side pacing inside UX-3's ≤ 30 s shell; emits idempotent `CharacterReport` incl. `handshakeCancelled(kind)`; engine owns what/when, character never applies effects (§9.3) | State-choreography tests (headless-able pure parts); reaction duration bounds per §7.1 | TASK-027 | L |
| TASK-029 | Implement Reduce Motion mapping + token-driven theming (04 §7.3, §8.4) | Full §7.3 mapping table (static poses, crossfades, milestone poses for play); RM never removes information (static pose + glyph/label/text channels); grayscale legibility verified per expression state (§3.5); rig reads only token slots (R4 — zero hex) | RM mapping table tests; grayscale preview checks recorded | TASK-028 | M |
| TASK-030 | Add character test suites (05 §10.1 MomoCharacterTests) | Sequencer determinism properties, pause discipline, RM pose mapping fully covered; pure files 100 % determinism-property covered per 05 §10.2 | Full MomoCharacterTests green via `swift test` | TASK-026…029 | S |

**Epic slice:** Momo visibly alive (breathing, blinking, looking around, reacting) on a debug canvas, pausing correctly — before the real Home exists.

### EPIC-007 — iPhone Home Experience (branch `feature/EPIC-007-iphone-home`)

| TASK | Title / Objective | Key acceptance criteria | Required tests | Depends on | Size |
|---|---|---|---|---|---|
| TASK-031 | Implement the app model facade: evaluate/apply loop + persistence wiring + boundary scheduling (05 §4.1–4.2; D-R5) | Fixed-order side-effect wrapper: apply `newState` → persist if `changed` (write-through) → deliver response/moments → (Watch push lands in EPIC-008); fold-to-now triggers per §4.2 table (foreground, interaction, report, in-session boundaries 22:00/07:00/midnight/nap-end, time-change notifications); one scheduled next-boundary evaluation; views never invoke the engine directly (D-R5) | Facade tests with injected clock (boundary scheduling, fold-on-foreground); launch-path store read inside budget | TASK-020, TASK-021 | L |
| TASK-032 | Implement onboarding S1→S2→S3 (FR-1; UX §3) | Exactly 3 steps, zero system dialogs, zero network, zero accounts (AC-1/AC-4); Enter writes the completion flag atomically at the tap (AC-2 restart semantics); name pre-filled "Momo", whitespace rejected (INV-1); name changeable later (AC-3) | MomoUITests: 3-step flow, kill-before-Enter restart, post-Enter straight to Home | TASK-031 | M |
| TASK-033 | Implement Home composition (FR-2; UX §5.1, §5.5) | Status row (glyph+word bands — never numbers, AC-3), 3-tap delight path (AC-2, joint with TASK-032), pet canvas ≥ ~45 % with the MomoCharacter rig, contextual line (single rotating slot, UX-12 priority), action row pills, quest card (per-wish soft marks, no aggregate bar, UX-4; window rendering UX-5); no-scroll at default type on smallest pinned device (AC-1a), scroll-with-full-function at accessibility sizes (AC-1b); no Collection/customization entries (AC-4) | MomoUITests: composition, no-numeric-state view audit, device-matrix layout check | TASK-026 (rig), TASK-031 | L |
| TASK-034 | Implement touch & petting (FR-5; UX §5.1 gesture map; 04 §2.3–2.4, §6.1) | 4 gesture classes × 2 zones (y=550 partition) render the engine's distinct ResponsePlans; eye-follow per 04 §2.4 (pupil clamp, head trail, release ease; RM → single glance UX-14); sleeping → stir, stays asleep; rapid-pat coalescing visual; canvas is ONE VoiceOver element with Pat/Cuddle custom actions + spoken reaction lines (UX-8); petting banks zero bond (G2 — engine-side, verified here E2E) | MomoUITests: gesture distinction, stir-while-asleep, a11y custom actions + announcements | TASK-033 | L |
| TASK-035 | Implement Feed / Play / Care flows (FR-6/7/8; UX §5.2–5.4; 04 §6.2–6.3) | Feed: eating state → content flourish; politely-full refusal (0–30 min, zero penalty); 30–90-min nibble (shortened animation — owner-confirmed); asleep → gentle decline; counts always. Play: UX-3 three-phase fingertip-follow round ≤ 30 s with early-exit pill; Drowsy low-key variant; counts on completion. Care: Tuck-in chip present only from 20:00 (absent by day — no disabled ghosts); blanket-adjust while asleep; Nap chip when Drowsy/Exhausted; careCount semantics | MomoUITests per family incl. refusal-warm and nibble paths; play round completion increments (FR-7 AC-1/2) | TASK-034 | L |
| TASK-036 | Implement quest moments + celebrations (FR-16; UX §5.5–5.6; 04 §4.3 L4) | M1 inline completion (auto, no claim, no modal; tiny flourish + optional light haptic per UX §5.4); M2 one-time stage banner (stage + PRD descriptor, shown once incl. deferred-while-closed, UX-10; VoiceOver announcement); M3 all-done line; Q1 silently gone at 12:00; Q6 line renders from 20:00; midnight silent reset | MomoUITests: completion inline, expiry silence, stage-once semantics | TASK-033, TASK-018 (cascade/moments) | M |
| TASK-037 | Implement Room tab (FR-3; UX §1.2 S5) | Static charming scene renders offline; zero interactive elements; caption + a11y (one image element, "{name}'s cozy room"); no customization UI | MomoUITests: renders, no actions | TASK-025 (room art), TASK-031 | S |
| TASK-038 | Implement Settings + rename + erase-all-data (FR-19; UX §1.2 S6) | Rename reflected on Home (Watch propagation verified in EPIC-008); haptics toggle (syncs in snapshot — no sound toggle exists, 04 §11); Erase all data with explicit confirmation (S6.2 copy class) → deletes store directory → onboarding, fresh; reset marker flows to Watch at next sync (full E2E in TASK-044); About (version + short privacy statement); no account/notification/Health/monetization rows (AC red lines) | MomoUITests: rename, erase roundtrip incl. fresh-onboarding state | TASK-031, TASK-022 (delete+fresh path) | M |
| TASK-039 | iPhone UI test consolidation + per-surface accessibility audit (FR-20 AC-2; NFR-6; 03 §10) | The FR-20 core-loop audit passes on iPhone surfaces (onboard, Home, one interaction per family, quest completion, settings): Dynamic Type behavior per AC-1a/1b, VoiceOver formulas, Reduce Motion substitution, ≥ 44 pt targets, ≥ 4.5:1 contrast, never color-only | Full MomoUITests suite green; audit evidence recorded (launch-blocking per NFR-6) | TASK-032…038 | M |

**Epic slice (complete on iPhone):** launch → onboarding → Momo visible → idle → touch → react → state change → **persist** (force-quit-safe). The Watch leg of the slice is EPIC-008.

### EPIC-008 — Watch App & Sync (branch `feature/EPIC-008-watch-sync`)

| TASK | Title / Objective | Key acceptance criteria | Required tests | Depends on | Size |
|---|---|---|---|---|---|
| TASK-040 | Implement iPhone-side WatchConnectivity session (05 §6.1–6.4; ADR-003) | Context push on every state change (`WatchSnapshot`: latest-wins, includes DisplayState + quest inputs + haptics flag + epoch-scoped watermark); intent receive path: fold-to-now → apply iff UUID unseen ∧ seq > watermark (epoch-scoped, 0-init) → next snapshot carries watermark; `sendMessage` as optimization only; VERIFY-AT-BUILD transport behaviors resolved and recorded | Kit-level integration tests with the wrapper (apply-exactly-once over duplicate/redelivery streams) | TASK-031, TASK-023 | L |
| TASK-041 | Implement MomoWatch W1 glance + snapshot persistence + AOD (FR-17; UX §6.1, §6.5; NFR-9) | W1 renders last-synced snapshot instantly from local store (persisted on every receive + background transition); mood in words + stage word + quest line + pat targets; LOD-glance rig foreground, static glyph in AOD (FR-17 AC-5); no numbers, no bars, no freshness indicator (UX-9); settling-in line pre-first-sync | MomoWatchUITests: restore timing ≤ ~2 s assertion; AOD static rendering | TASK-040, TASK-026 (LOD), TASK-019 | L |
| TASK-042 | Implement the Watch pat (FR-17 AC-1/2; UX §6.2–6.4; 04 §6.4) | Pat via pet canvas or Pat pill (UX-11): immediate local micro-reaction (state-distinct: bounce awake; stir + heart asleep) + subtle haptic honoring the synced toggle — fully offline; intent journaled with `watchSessionEpoch` + monotonic seq; `transferUserInfo` drain, journal-prune on epoch-matched watermark; raise-to-pat ≤ 5 s | MomoWatchUITests: offline pat flow, journal persistence across termination | TASK-041 | M |
| TASK-043 | Implement Watch cascade + settings/haptics propagation (05 §4.8 consumer; UX-13) | Quest line = `makeDisplayState` cascade output (single shared derivation — no Watch-side logic); "All done — see you soon" state; haptics toggle arrives via snapshot; no Watch settings surface (UX-13) | Cascade-render tests over stale quest inputs (renders sanely, no error) | TASK-041 | S |
| TASK-044 | Add sync test coverage — §10.4 matrix + device obligations | §10.4 rows as named tests: iPhone→Watch context re-render; offline pat exactly-once (FR-18 AC-1); same counters/quests as iPhone pats (AC-2); foreground-reconnect freshness (AC-3); replay/duplicate no-op + bond non-regression (AC-4/INV-3); epoch-reset flows; termination/relaunch; erase reset-marker E2E (completes TASK-038's AC); **device obligations: WC frame delivery under suspension verified on paired hardware** (05 §10.4; CLAUDE.md §25 — never claimed from simulators alone) | Full sync suites green + device-session evidence recorded | TASK-040…043 | L |

**Epic slice:** the first vertical slice is **complete** — iPhone state reaches the Watch; an offline Watch pat applies exactly once on the iPhone.

### EPIC-009 — Polish, QA & Release Readiness (branch `feature/EPIC-009-release-readiness`)

| TASK | Title / Objective | Key acceptance criteria | Required tests | Depends on | Size |
|---|---|---|---|---|---|
| TASK-045 | Performance budget verification (05 §12; NFR-1/2/3/4/9) | Measured on the pinned device matrix, evidence recorded: cold launch ≤ 2.0 s; 60 fps sustained; iPhone ≤ 150 MB idle soak; Watch ≤ 80 MB (VERIFY-AT-BUILD norms); download ≤ 60 MB; energy gauge Low over 10-min idle (both devices); Watch restore ≤ ~2 s; sync cadence log-verified (on-change only). **A budget miss is a task-level blocker, not a note** | XCTest launch metrics; Instruments traces; energy gauge sessions | TASK-039, TASK-044 | L |
| TASK-046 | §32 edge-case matrix execution (05 §10.5; FR-11 AC-3; NFR-7) | Every §10.5 row executed with evidence: timezone change, DST, date rollover, Watch unavailable, offline device, fresh install, upgrade, long inactivity (7-day fold), notification/Health rows recorded n/a-Phase-1 | Full edge suites green; results recorded per row | TASK-020, TASK-024 (suites exist) | M |
| TASK-047 | Full accessibility audit — launch-blocking (FR-20 AC-2; NFR-6; 03 §10) | Core-loop audit across **both** devices (onboard, Home, one interaction per family, quest completion, settings, Watch pat): every 03 §10 row passes; state never color-only; VoiceOver state formula verbatim; Reduce Motion honored everywhere | Manual + automated audit evidence; zero open blockers | TASK-039, TASK-044 | M |
| TASK-048 | Privacy & security review (FR-20; NFR-5; CLAUDE.md §27 checklist; 05 §11) | Network-traffic audit of a full session shows only the paired link (AC-1); repo/build contains no StoreKit/analytics/location/HealthKit (AC-3); all strings from catalogs (AC-4); privacy manifest accurate ("Data Not Collected" posture; required-reason APIs — VERIFY-AT-BUILD resolved); entitlements = zero (beyond WC transport if any — VERIFY-AT-BUILD resolved); secrets scan clean | Audit scripts + recorded evidence | TASK-039, TASK-044 | M |
| TASK-049 | Philosophy & tone QA — the §44 final product test (project.md §44; FR-12; 04 §10; PR1) | Every §44 question answered with evidence on the release build (idle aliveness, touch delight, Watch independent value, HealthKit-denied = n/a-but-equivalent offline posture, no guilt/manipulation, offline survival, iPhone/Watch consistency, a11y, battery); banned-vocabulary scan green; §15 bad-copy list swept; "would removing any feature simplify without losing emotional value?" answered and acted on | §44 checklist executed and recorded; static tone test green | TASK-045…048 | S |
| TASK-050 | Release readiness: gates, name clearance, App Store posture (project.md §35; E4; ADR-006 N-1) | §35 DoD checklist signed item-by-item; E4 name/trademark clearance executed (escalate to owner with search results if any risk); N-1 deployment widening re-evaluated once (ADR-006) with pairing-matrix check; App Store metadata + privacy label **"Data Not Collected"**; screenshots/previews; TestFlight build; release checklist recorded | Release checklist evidence; TestFlight build number recorded | TASK-049 | M |

---

## 4. Implementation Order & Dependency Graph

### 4.1 Graph (arrows = "must finish before")

```
EPIC-002 foundation ──────────────────────────────────────────────────────
  008 ──► 009 ──► 010
            │
            └──► 011 (tokens)
                   │
     ┌─────────────┼──────────────────────────────┐
     ▼ (009)      ▼ (009 + 011)                     │
EPIC-003 domain   EPIC-006 character (LANE B)      │
  012 ──► 013      025 ──► 026 ──► 027 ──► 028 ──► 029 ──► 030
     │
     ├────────────┬───────────────┐
     ▼ (012)      ▼ (012+014)     ▼ (012)
EPIC-004 engine  EPIC-005 kit    │      (LANE A — may start once 012/014 land;
  014 ──► 015 ──► 016 ──► 017 ──► 018 ──► 019 ──► 020     runs parallel to EPIC-004 tail)
                                    021 ──► 022 ──► 023 ──► 024
     └──────────────┬───────────────┘
                    ▼  (needs 004 + 005 + 006)
EPIC-007 iphone home
  031 ──► 032 ──► 033 ──► 034 ──► 035 ──┤
   │              └─(+018)──► 036 ──────┤
   ├─(+025)────► 037 ───────────────────┤
   └─(+022)──► 038 ─────────────────────┤
                                        ▼
                                        039  (iPhone audit; needs TASK-032…038)
                    │
                    ▼  (040 needs 031 + 023; 041 adds 026 + 019)
EPIC-008 watch & sync
  040 ──► 041 ──┬─► 042 ──┐
                └─► 043 ──┴──► 044   (044 needs 040…043)
                     │
                     ▼  (045/047/048 also need 039; 046 needs 020 + 024)
EPIC-009 release readiness
  (039 + 044) ──► 045 ──┐
  (039 + 044) ──► 047 ──┤
  (039 + 044) ──► 048 ──┼──► 049 ──► 050
  (020 + 024) ──► 046 ──┘
```

The graph is acyclic by construction (cross-epic edges only point from earlier to later epics; the two intra-Phase-1 "lanes" — EPIC-004/005 domain work and EPIC-006 character work — never converge before EPIC-007).

### 4.2 The first vertical slice as the earliest path (spine)

| Slice step (project.md §40 Step 7) | Delivered by |
|---|---|
| Launch | 008 → 009 (targets) → 031 (facade) → 032 (onboarding) |
| Momo visible | 025 → 026 (rig) + 033 (Home composition) |
| Idle animation | 027 (sequencer) + 031 (scenePhase scheduling) |
| User touches Momo | 034 (gestures/zones/eye-follow) |
| Momo reacts | 014 → 016 (engine ResponsePlan) + 019 (read-models) + 028 (reaction rendering) |
| State changes | 016/017 (effects + bond) + 015 (time folds) |
| State persists | 021 (store) + 031 (write-through) |
| Watch receives state | 023 → 040 (iPhone push) + 041 (W1 render) |

**Spine order:** 008 → 009 → 012 → 014 → 016 → 017 → 019 → 021 → 031 → 033 → 034 → 040 → 041 (+042 for the pat leg). Parallel lanes (EPIC-005 from 012/014; EPIC-006 from 009+011; TASK-015/018/020, 022–024, 027–030, 032/035–039, 043–044) fill breadth around the spine without delaying the first full slice.

### 4.3 Sequencing rationale

- **Domain before UI (intake rule):** EPIC-003/004/005 produce a headlessly tested core before any view exists; UI epics consume only proven derivations (D-R5 keeps views thin by construction).
- **Character parallel-early:** EPIC-006 depends only on EPIC-002 + the 04 §9.2 interface types (defined in TASK-012), so the longest art/rig track runs beside the engine track — the schedule's main compression.
- **Sync last among features (but only just):** EPIC-008 follows the iPhone slice because the Watch renders and queues — it needs the engine host and store to exist; its *pure logic* (TASK-023) is pulled early into LANE A precisely so the transport task (040) is thin.
- **Polish is not optional garnish:** EPIC-009's gates (performance, a11y, privacy, §44) are release-blocking per §35/NFR-6/§44 — they are epic scope, not residue.

---

## 5. Test Requirements per Epic (mapped to project.md §32 matrices and 05 §10)

| Epic | §32 matrix coverage | Concrete host (05 §10.1) | Coverage floor |
|---|---|---|---|
| EPIC-002 | — (harness itself) | All five targets exist; `swift test` green on macOS; simulators run | Harness self-tested |
| EPIC-003 | Domain: band/stage derivations | MomoCoreTests | Property over full 0…100 range |
| EPIC-004 | **Domain (complete):** mood/energy transitions, bond progression, daily reset, quest progression, engine rules, deterministic randomness | MomoCoreTests | **Core ≥ 90 %** + determinism properties |
| EPIC-005 | **Persistence (complete):** save/load, migration, corruption/recovery. Sync pure halves: idempotency, watermarks, codecs | MomoKitTests | **Kit ≥ 80 %** |
| EPIC-006 | Domain: deterministic randomness (sequencer); UI-support: pause/RM behaviors (pure parts) | MomoCharacterTests | Sequencer logic fully covered by determinism properties |
| EPIC-007 | **UI (iPhone half):** onboarding, primary interactions, quest completion, settings, accessibility | MomoUITests (iOS simulator) | Smoke over FR-1/2/5–8/19 critical paths |
| EPIC-008 | **Synchronization (complete):** iPhone→Watch, Watch→iPhone, disconnection, stale data, conflict, termination/relaunch — incl. device obligations | MomoWatchUITests + Kit/Core properties + paired-device session | Sync matrix row-by-row (05 §10.4) |
| EPIC-009 | **Edge cases (complete):** §10.5 matrix; plus release audits (privacy, a11y, performance, tone) | All targets + Instruments/energy sessions | Every row executed with evidence |

Standing static tests from day one (TASK-010): import-whitelist scan (D-R1), banned-vocabulary scan (FR-12 structural guard). Determinism property tests are the §10.2 meta-requirement and live in TASK-020/024/030.

---

## 6. Release Gates

### 6.1 Per-epic gates (CLAUDE.md §18 applied per epic)

An epic is DONE only when: all its tasks are DONE (implemented, reviewed by a fresh agent, findings addressed, committed with TASK-IDs, pushed); the epic's slice increment is demonstrable (§2); its §5 test rows are green with coverage floors recorded; no known critical regression; epic branch merged to `main`.

### 6.2 Final release gates (all blocking)

1. **Requirements:** every PRD FR's ACs verified (FR-1…FR-20) — traceability Appendix A; every NFR verified (Appendix B).
2. **Test matrices:** project.md §32 domain/persistence/sync/UI/edge matrices fully executed (§5 above), including the upgrade edge (NFR-7) and the paired-device WC obligations.
3. **Performance budgets (05 §12):** launch ≤ 2.0 s · 60 fps · ≤ 150 MB iPhone / ≤ 80 MB Watch · ≤ 60 MB download · energy Low · Watch restore ≤ ~2 s — measured on the pinned device matrix, never assumed.
4. **Accessibility (NFR-6, launch-blocking):** TASK-047 audit fully green.
5. **Privacy (FR-20/NFR-5):** network audit = paired link only; "Data Not Collected" label justified by implementation; zero third-party SDKs; privacy manifest accurate; secrets scan clean.
6. **Tone & philosophy:** §44 final product test executed and answered; banned-vocabulary scan green; no punishment/guilt mechanics anywhere (D3/D4/G1–G3; INV-6).
7. **Owner gates:** E4 name/trademark clearance (TASK-050); N-1 deployment widening decision recorded (ADR-006 revisit). E1 (monetization) and E3 (location) remain closed for Phase 1 by D8/D19 — no gate, no code.
8. **Process (CLAUDE.md §34):** commit checklist, push verified, `status.md` truthful, every REVIEW record APPROVED or APPROVED_WITH_MINOR_NOTES with fixes applied.

---

## 7. Risk Register

| ID | Risk | Impact | L×I | Mitigation (owning task) |
|---|---|---|---|---|
| R1 | TR10 — Xcode unavailable on the build machine | Blocks all EPIC-002+ build work | Med×High | TASK-008 verifies **first** and is the epic gate; absence ⇒ recorded BLOCKER + owner escalation (CLAUDE.md §3), nothing else proceeds |
| R2 | TR1 — WatchConnectivity delivery behaviors differ from assumptions (background latency, coalescing, launch delivery) | Sync ACs (FR-18) mis-estimated; rework in EPIC-008 | Med×High | Correctness never depends on immediacy (ADR-003 journal path); TASK-040 resolves VERIFY items; TASK-044 proves delivery on paired devices, not simulators alone |
| R3 | TR3 — Idle-animation battery cost | NFR-2 miss; App Review/quality risk | Med×High | Transform-only rig + single-clock pause (04 §7.4) built-in at TASK-026; battery note per animation; TASK-045 measures on device — a miss is a blocker |
| R4 | TR6 — 2026 fall OS churn (API deprecations, watchOS norms) | Bootstrap pins wrong; late breakage | Med×Med | TASK-008 pins at build start per ADR-006; every version-sensitive claim VERIFY-AT-BUILD with a named owning task (008, 010, 014, 025, 040, 045, 048) |
| R5 | TR7/TR9 — time/DST fold defects; Watch lifecycle staleness | Wrong-day quests, duplicate resets, stale glances | Low×High | DayKey-keyed once-only resets by construction (TASK-015); snapshot persisted per background transition (TASK-041); TASK-046 executes the §10.5 matrix |
| R6 | TR8 — Vector export tooling friction (organic curves) | EPIC-006 delay | Med×Med | TASK-025 keeps the pipeline repo-local + committed output (reviewable, re-runnable); SwiftUI Previews loop; budget ≤ 1.5 MB enforced |
| R7 | PR1/PR5 — tone or childishness drift in animation/copy | Breaks Cute × Calm × Premium | Med×High | Tone guide + banned-vocab static test from TASK-010 onward; every UI task's review checklist includes FR-12 + 04 §10; TASK-049 sweeps §15's bad list |
| R8 | PR6 — Watch feels like a phone mirror | §44 independence question fails | Low×Med | W1 designed independent (03 §6); pat offline-first with local delight (TASK-042); §44 asked explicitly in TASK-049 |
| R9 | Watch hardware availability for device obligations | WC delivery evidence delayed | Med×Med | Simulators carry development; paired-device session scheduled as TASK-044's explicit deliverable; if unavailable, record BLOCKED evidence and gate release on it (§25 no fake completion) |
| R10 | Scope creep during build (widgets/HealthKit/chatbot temptations) | MVP dilution, schedule slip | Med×High | §8.3 non-goals restated in every task file; CLAUDE.md §22/§24; any proposal routed to KEEP/LATER/REJECT with the orchestrator — never implemented opportunistically |
| R11 | Engine fold complexity underestimated (handshakes, satiety × repetition interactions) | EPIC-004 slip cascades into EPIC-007/008 | Med×Med | 05 §4 is a complete spec; TASK-015/016/017 are separate reviewable units; §10.3 matrix (TASK-020) is the exit criterion, not "it compiles" |
| R12 | Coverage floors slip under schedule pressure | Silent regressions later | Low×Med | Floors (Core 90 %, Kit 80 %) recorded per task (05 §10.2); TASK-020/024/030 own them explicitly; reviewers check the numbers |
| R13 | Long-lead owner decisions (E1/E3/E4) collide with release | Late-stage surprise | Low×Med | E4 is scheduled as TASK-050's first checklist item (search lead-time); E1/E3 are Phase-2+ and cannot block Phase 1 by decision |

---

## 8. Phase 2+ Outlook (reservations only — no tasks created)

Phase 1 deliberately leaves the following seams (all recorded in the architecture/UX docs; none may leak into any EPIC-002…009 task):

- **Widgets & complications (Phase 2):** `DisplayState` + the §5.5 cascade already render W1; a widget timeline entry is the same derivation at entry-build time (03 §7, 05 §8). New entitlement: app group.
- **HealthKit activity quests (Phase 2):** `ActivitySource` port + additive `DailyProgress.steps` field (05 §7); D17 inclusivity rules carry over.
- **Notifications (Phase 2):** governor + quiet rules shape pre-normative in 05 §9; §15 tone checklist becomes the review gate.
- **iCloud/CloudKit:** only with a written justification (D6 gate); store sits behind one narrow protocol for that revisit (ADR-002).
- **Monetization (E1), location/weather (E3), additional pets/outfits (Phase 3):** owner-gated; zero code paths exist.
- **N-1 deployment widening:** preserved as a cheap post-release option (ADR-006).
- **Paper analytics taxonomy** (PRD §9) remains uninstrumented; Phase 2 instrumentation decision starts from it (D7).

---

## 9. Open Items Carried Into Build

| Item | Disposition | Owner task |
|---|---|---|
| OPEN-3 — deployment pins, device names, test framework | Resolved at bootstrap | TASK-008 (record: ADR-008) |
| OPEN-2 — interpretation I-1 (refused feeds count; required for Q3 ≤ 2-min completability) | Treated as confirmed by REVIEW-TASK-006's APPROVED verdict; engine implements the PRD-letter counting rules | TASK-016 (tests assert it) |
| VERIFY-AT-BUILD register (05 Appendix B) | Each item has exactly one owning task: pins/pairing → 008; swift-test hostability + framework → 009/010; Swift Clock idioms → 014; export tooling → 025; WC behaviors + background capability → 040/044; watchOS memory norms → 045; required-reason APIs → 048 | Distributed (see §7 R4) |
| E4 — "Momo" name/trademark clearance | Release gate, non-blocking for development | TASK-050 |
| E1 / E3 | Closed for Phase 1 (D8/D19); no gate, no code | — (Phase 2+) |

---

## Appendix A — Functional Requirement → Task Traceability

| FR | Task(s) |
|---|---|
| FR-1 Onboarding | 032 |
| FR-2 Home composition | 033 (031 layout scaffolding) |
| FR-3 Room | 037 (025 art) |
| FR-4 Idle aliveness | 026, 027, 031 (+034 reactions) |
| FR-5 Touch & petting | 034 (016, 028 engine/character halves) |
| FR-6 Feeding | 016 (semantics), 035 (flow) |
| FR-7 Playing | 016, 028 (round), 035 (flow) |
| FR-8 Care | 016, 035 |
| FR-9 Mood & energy model | 012, 013 (types/bands), 015 (dynamics), 020 (tests) |
| FR-10 Bond model | 017, 020, 036 (celebration) |
| FR-11 Time model | 015, 020, 046 |
| FR-12 Absence & tone | 015, 019 (keys), 010 (banned-vocab), 049 |
| FR-13 Persistence & determinism | 014 (determinism), 021, 022, 024 |
| FR-14 Quest catalog | 018 |
| FR-15 Daily set generation | 018, 020 |
| FR-16 Completion & expiry | 018, 036 |
| FR-17 Watch experience | 041, 042, 043 |
| FR-18 Device-to-device sync | 023, 040, 044 |
| FR-19 Settings & erase | 038 (022 fresh path; 040/044 Watch reset E2E) |
| FR-20 Privacy/a11y/localization/free | 010 (scans), 011 (catalogs), 039, 047, 048 (042 haptics toggle) |

## Appendix B — Non-Functional Requirement → Task Traceability

| NFR | Task(s) |
|---|---|
| NFR-1 Performance (launch, smoothness) | 045 (026/027 structural guarantees) |
| NFR-2 Battery | 026 (pause authority), 045 (measurement) |
| NFR-3 Memory | 045 |
| NFR-4 App size | 025 (art budget), 045 (archive report) |
| NFR-5 Privacy | 048 |
| NFR-6 Accessibility (launch-blocking) | 039, 047 (+ per-UI-task audits in 032–038, 041–043) |
| NFR-7 Reliability | 021, 022, 024, 046 |
| NFR-8 Compatibility | 008 (pins), 050 (N-1 decision) |
| NFR-9 Watch efficiency | 041, 044 |

---

*End of document.*
