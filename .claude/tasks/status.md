# Momo Project Status

Last Updated: 2026-09-09 00:20 UTC
Updated By: main orchestration agent

## Current Phase
**Phase 1 — Step 7 Engineering** (project.md §40). **EPIC-004 — Pet State Engine IN PROGRESS (2/7)** on `feature/EPIC-004-engine`: TASK-014 (`696d8dd`) and TASK-015 (`7b5d735`) DONE. EPIC-003 is DONE and fully merged (`4291f02`).

## Current Epic
EPIC-004 — Pet State Engine — **2/7 DONE** on `feature/EPIC-004-engine` (branch cut from `main` @ `bf2dcb7`). TASK-016 is next; TASK-017–020 follow per delivery plan §3.

## Overall Progress
Phase 0 complete (TASK-001…007, all pushed). **EPIC-002 complete — all four tasks DONE and merged to `main`** (`eb82184`): TASK-008 (`172bc11`, ADR-008 pins) · TASK-009 (`b28ccb4`, package + app targets + shells) · TASK-010 (`a9b9993`, test harness + scanners) · TASK-011 (`a2a36b7`, design tokens + String Catalog scaffolding; REVIEW-TASK-011 APPROVED_WITH_MINOR_NOTES 0/1/2, disposition applied). **Merge rule (owner, 2026-09-08): reviewed code merges directly to `main` — no PR — then continue immediately to the next epic (recorded in CLAUDE.md §14, commit `f5c1c11`).** **EPIC-003 TASK-012 DONE** (`bc95cb9`; REVIEW-TASK-012 APPROVED_WITH_MINOR_NOTES 0/1/3, disposition applied; domain model + property-test-ready `Thresholds` landed; swift test 64/11 green). TASK-013 is the only remaining EPIC-003 task.

## Completed Work
- TASK-001 — Repository & orchestration bootstrap (`557c936`)
- TASK-002 — Step 1 Product Review, D1–D20 + E1–E4 (`f72b78b`)
- TASK-003 — Step 2 MVP PRD (`c766ffe`)
- TASK-004 — Step 3 UX Architecture (`40c4b77`)
- TASK-005 — Step 4 Character System (`ce84811`, record fix `39d6bab`)
- E2 — Character direction C "Round Rabbit" (ADR-001; `2cfba30`)
- TASK-006 — Step 5 Technical Architecture + ADR-002…007 (`8fb9653`)
- Owner decisions OPEN-1 (§5.5 cascade rule) + I-2/OPEN-5 (nibble) — PRD amended (`95e7649`)
- TASK-007 — Step 6 Delivery Plan (8 epics / 43 tasks) (`71a510b`)
- **TASK-008 — Toolchain verified + ADR-008 bootstrap pins (`172bc11`, first commit on `feature/EPIC-002-foundation`, pushed).** Review chain: REVIEW-TASK-008 CHANGES_REQUIRED (MAJOR-1: smallest-iPhone mis-pin) → fresh fixer re-pinned iPhone-small to **iPhone SE (3rd generation)** → REVIEW-TASK-008-VERIFY: FIXED — CLEARED FOR COMMIT (three independent probe pairs agree).
- **TASK-009 — Swift package + app targets with placeholder shells (`b28ccb4`, pushed).** MomoCore (Foundation-only) / MomoCharacter / MomoKit, zero external deps; Momo 3-tab shell + MomoWatch glance launch on pinned sims (750×1334 / 324×394 exact); `swift test` green (3 empty Swift Testing suites); swift-test-hostability VERIFY item RESOLVED. REVIEW-TASK-009 **APPROVED** (0/0/3; nitpicks dispositioned in the review record).
- **TASK-010 — Test-target scaffolding + import-whitelist + banned-vocabulary scans (`a9b9993`, pushed).** Five-target architecture per 05 §10.1 (3 package suites + MomoUITests + MomoWatchUITests); scheme TestActions added; both scanners shipped as pure fixture-tested functions (import whitelist = Foundation-only documented; banned list = 04-character-system §10.2 verbatim, byte-verified, vacuously green until TASK-011's catalogs); self-tests caught 2 real defects during implementation; coverage wired (llvm-cov; xccov can't read SwiftPM profdata). All verifications green: swift test 20/5 suites; both xcodebuild test runs TEST SUCCEEDED on pinned sims. REVIEW-TASK-010 **APPROVED** (0/0/2, both mechanical — disposition in review file).
- **TASK-011 — Design-system token pass + String Catalog scaffolding (`a2a36b7`, pushed).** Token module in `MomoCharacter` (8 §8.4 slots verbatim + §18 UI tokens; light/dark compile-enforced; hex confined to the 2 palette files, scan-tested); `Apps/Shared/MomoCopy.xcstrings` in both app targets; type-safe `CopyKey`/`MomoCopy` lookup (bundle-injected, NUL-sentinel missing-key, DEBUG-loud resolve); both shells token-fed and pixel-verified exact (incl. dark); contrast recorded, all 12 pairs reviewer-recomputed exact; banned-vocab scan green and proven non-vacuous both directions. One real defect found+fixed in verification (watch canvas 32 pt strip). swift test 35/9; both builds + both UI smoke tests green. REVIEW-TASK-011 **APPROVED_WITH_MINOR_NOTES** (0/1/2 — disposition in review + task file).
- **TASK-012 — MomoCore domain model (`bc95cb9`, pushed; first EPIC-003 task).** All 05 §3.1 value types + all five 04 §9.2 interface types in `Sources/MomoCore/` (11 files): `Sendable`, `let`-immutable (zero `var` in module), Swift 6 strict-concurrency clean. Pure derivations `makeMoodBand`/`makeEnergyBand`/`makeBondStage` with every PRD number single-sourced in `Thresholds.swift` (bands 20/45/75; bond stages 150/400/750 first-value form = PRD's 0–149/150–399/400–749/750–1000; quest windows 12/20/7). `DayKey.make(from:calendar:)` injected-calendar-only (D20, DST + non-Gregorian tested). INV-1…11 dispositioned (type/representation-enforced where possible; engine/store halves honestly deferred to EPIC-004/005). Placeholder pair removed (self-documented EPIC-003 condition). swift test **64 tests / 11 suites green**; D-R1 + banned-vocab scans green. REVIEW-TASK-012 **APPROVED_WITH_MINOR_NOTES** (0/1/3 — MINOR-1 wording + NITPICK-3 doc note fixed; NITPICK-1/2 declined; disposition in review file). Contract commit `f5c1c11` recorded the owner merge rule in CLAUDE.md §14.
- **TASK-013 — Exhaustive domain-model property tests (`5bbdd72`, pushed; EPIC-003 complete).** 1203 parameterized cases: full-range mood/energy sweeps (0…100 ×2) + bond-stage sweep (0…1000) with every boundary; `ThresholdsPinnedToPRDTests` (PRD-literal pins + tiling + edge mappings — anti-echo proven by mutation probe: silent constant 45→46 fails pins 4/4 while constant-fed sweeps stay green); `NoNumericLeakageTests` (4-layer check incl. compile-time case-set pins via default-free exhaustive switches). Review chain: REVIEW-TASK-013 **CHANGES_REQUIRED** (MAJOR-1: `case historic(Int)` evaded the leakage suite — case sets unpinned) → fresh fix agent (test-file-only) → same reviewer's verification: Probe D re-run fails the build (`switch must be exhaustive`) — **REVISED VERDICT APPROVED_WITH_MINOR_NOTES**, commit-ready. Final: `swift test` **80 tests / 14 suites green**; coverage informational: Bands.swift 100 %, TOTAL 92.06 % lines. NITPICK-1 citation fixes applied at contract source (task file + epic AC-5).
- **TASK-015 — Time-fold catch-up + wakefulness machine + handshakes (`7b5d735`, pushed).** Real time semantics replace TASK-014's bookkeeping honesty: segment-fold per §4.3 (waking decline −1.5/h; night ramp anchored to the containing night's FULL real duration — DST-correct, proven necessary by the reviewer: endpoint anchoring makes the PRD ≥ 75 wake clamp vacuous; wake clamp; attractor τ=3 h target 60; coupling 35/floor 25 at SEGMENT-START energy), dayKey-keyed once-only rollover (landing-day-only adjudicated CORRECT vs FR-11/FR-12), harmless absence (7-day equilibrium re-derived from scratch), §4.7 wakefulness machine under INV-8 (night onset lands `.asleep` handshake-free with zero rng draws; morning lands `.waking`, wake-stretch mint deferred to the next event, exactly 2 draws), idempotent kind-matched handshakes (04 §9.2's token-less reports; stale reject + un-strand; settle preemption → `.awake`), calendar injected as documented third parameter (determinism tuple: state, event, clock, calendar, seed). New: `FoldRules` (constants home with PRD-normative/engine-owned authority labels), `TimeFold`, `HandshakeMachine`; `Reduce` rewritten; `CharacterReport` +`wakeFinished` (disclosed, both normative sources cite it). Named tests: 22:00 onset, 07:00 wake + clamp (exact 74.625), midnight ×1, DST fall-back 36000 s / spring-forward 28800 s (OS-verified), timezone change ≤ 1 rollover, backward clock no-double, 7-day absence, attractor exact `60 − 30/e`, coupling/floor exact. swift test **163/23 green** at handoff. REVIEW-TASK-015 **APPROVED_WITH_MINOR_NOTES** (0 MAJOR; strongest signal: a probe where the reviewer's adversarial expectation was wrong and the code was right). Disposition applied pre-commit: MINOR-1 code restored to the documented segment-start coupling + the reviewer's probe adopted now as the discriminating pin `couplingBandReadsSegmentStart`; MINOR-2 implemented (§4.7 settle-preemption edge → `.awake`); NITPICK-1 commented for TASK-016, NITPICK-2/3 fixed, NITPICK-4 coverage on record (TOTAL 97.77 % lines). Post-fix **164/23 green**.
- **TASK-014 — Engine core: reduce, EngineClock, seeded RNG, day-stable seeds (`696d8dd`, pushed; first EPIC-004 task).** 7 new `MomoCore` sources: repo-owned FIPS 180-4 SHA-256 (zero imports — D-R1 bans CryptoKit; NIST vectors OS-verified), SplitMix64 `RandomNumberGenerator` (canonical vectors; seed-9 constant computed and corrected before landing), `DaySeed` (length-framed injective preimage petID‖dayKey‖epoch‖salt, SHA-256 truncated first-8-BE; golden-byte + round-trip pins), `EngineState`/`EngineEvent`/`EngineOutcome` per §4.1 (all-`let`, `Equatable`), `EngineClock` protocol + `SystemEngineClock` (the one sanctioned ambient `Date.now`, scanner-exempted) + value-semantic `ManualEngineClock`, and pure `reduce` with honest bookkeeping-only semantics (owner tasks documented; clock/rng proven unread by probes). VERIFY item resolved: stdlib `Clock` rejected (monotonic instants can't see §4.3 wall-clock changes; `Date(ContinuousClock.now)` compile-fails). Engine-purity scan over all of `Sources/MomoCore` proven non-vacuous both directions (seeded violation RED, restored). swift test **125/20 green**; coverage 7 new files 100 % lines, TOTAL 97.12 %. REVIEW-TASK-014 **APPROVED_WITH_MINOR_NOTES** (0 MAJOR — every crypto/arithmetic constant independently re-derived by the reviewer: shasum 8/8 + 12/12 unseen, SplitMix64 9/9 from-scratch, preimage hand-built byte-identical). Disposition applied: MINOR-1 narrowed (exact frozen hex counts 72/3; full allowlist declined as redundant with the NIST/canonical vector pins), MINOR-2 occurrence-pinned (exactly one `Date` in EngineClock.swift), NITPICK-1/2 fixed (capacity==64 pin; distinct fixture intent id). Post-fix **126/20 green**.

## Work In Progress
- None (between tasks). TASK-016 (interaction semantics + satiety + repetition) is READY to dispatch — orchestrator materializes the contract first.

## Next Tasks
1. **TASK-016 — Interaction semantics + satiety + repetition curve** (L; 05 §4.4–4.5, PRD §4 response matrix) — orchestrator materializes the contract at `.claude/tasks/active/TASK-016-interactions-satiety-repetition.md`, then dispatch fresh Jupiter impl → reviewer → disposition → commit `feat(engine): TASK-016 interaction semantics, satiety window, repetition curve` → push. Notes carried in: the now-implemented §4.7 settle-preemption edge (`.settling` reachable via tuck-in), the `interactionPassThrough` mint note (NITPICK-1), play effects land at the `.playRoundFinished` unified point.
2. **EPIC-004 remainder** per delivery plan §3: TASK-017 (bond ledger) → TASK-018 (quests + Watch cascade) → TASK-019 (read-models) → TASK-020 (§10.3 matrix + coverage floor ≥ 90 %) → epic `--no-ff` merge to `main` per §14.
3. Follow-up candidates (no urgency, recorded per REVIEW-TASK-011): extend `TokenPurityTests` to component initializers (`Color(red:)`-class) + SwiftUI named colors outside the token module; optionally pin the four body-text contrast pairs with a test luminance helper (full audit remains TASK-047). REVIEW-TASK-014's full exact-literal hex allowlist was **declined** (count pins + NIST/canonical vector pins already cover both failure modes) — no follow-up owed.

## Blocked Tasks
- None. Owner gates pending but non-blocking: E1 (monetization) and E3 (location) closed for Phase 1 (D8/D19); E4 (name/trademark clearance) scheduled as TASK-050 release gate.

## Recent Commits
- (pending) — TASK-015 housekeeping record commit on `feature/EPIC-004-engine`
- `7b5d735` — TASK-015 — feat(engine): TASK-015 time-fold catch-up, wakefulness machine, handshakes
- `5fdbda1` — housekeeping — record TASK-014 completion (EPIC-004 1/7), task file to completed
- `696d8dd` — TASK-014 — feat(engine): TASK-014 engine core — reduce, clock, seeded randomness, day-stable seeds
- `696d8dd` — TASK-014 — feat(engine): TASK-014 engine core — reduce, clock, seeded randomness, day-stable seeds
- `8cf46e2` — docs(orchestration) — EPIC-004 epic + TASK-014/015 task files READY
- `4291f02` — merge — EPIC-003 Pet Domain Model (TASK-012–013) into `main` — direct merge per owner rule 2026-09-08
- `a334cba` — housekeeping — record TASK-013 completion (EPIC-003 2/2 DONE), task file to completed
- `5bbdd72` — TASK-013 — test(domain): TASK-013 exhaustive domain-model property tests
- `6d08f08` — housekeeping — record TASK-012 completion (EPIC-003 1/2), task file to completed
- `bc95cb9` — TASK-012 — feat(domain): TASK-012 define MomoCore domain model (05 §3.1)
- `f5c1c11` — docs(orchestration) — record owner direct-merge rule in CLAUDE.md §14
- `feb2898` — owner PR #4 — merged `feature/EPIC-003-domain-model` docs-only prefix (through `8ae4970`) to `main`
- `2973eb8` — housekeeping — record TASK-011 commit; EPIC-002 DONE (4/4), task file to completed
- `a2a36b7` — TASK-011 — feat(design): TASK-011 design-system token pass and String Catalog scaffolding
- `a9b9993` — TASK-010 — test(bootstrap): scaffold test targets with import-whitelist and banned-vocabulary scans
- `b28ccb4` — TASK-009 — feat(bootstrap): create Swift package and app targets with placeholder shell
- `172bc11` — TASK-008 — chore(bootstrap): verify toolchain and record deployment pins (ADR-008) — **first commit on `feature/EPIC-002-foundation`**
- `71a510b` — TASK-007 — docs(product): TASK-007 delivery plan with Phase 1 epics and task breakdown
- `95e7649` — owner decisions — OPEN-1 §5.5 rule-1 + I-2/OPEN-5 nibble applied (PRD amended)
- `8fb9653` — TASK-006 — docs(architecture): TASK-006 technical architecture and ADRs
- `2cfba30` — E2 record — Direction C gate resolution + ADR-001 + TASK-006 task file READY
- `39d6bab` — housekeeping — TASK-005 record completion
- `ce84811` — TASK-005 — docs(design): TASK-005 character system specification
- `40c4b77` — TASK-004 — docs(design): TASK-004 UX architecture for Phase 1
- `c766ffe` — TASK-003 — docs(product): TASK-003 MVP product requirements document
- `f72b78b` — TASK-002 — docs(product): step 1 product review of project spec
- `557c936` — TASK-001 — chore(orchestration): bootstrap Momo agent team contracts and task structure

## Recent Pushes
- `feature/EPIC-004-engine` → origin — **success** (`5fdbda1..7b5d735`, TASK-015)
- `feature/EPIC-004-engine` → origin — **success** (`8cf46e2..696d8dd`, TASK-014; branch tracking set)
- `main` → origin — **success** (`feb2898..4291f02`, EPIC-003 integration merge; merged state verified green 80/14)
- `feature/EPIC-003-domain-model` → origin — success (`5bbdd72..a334cba`, TASK-013 housekeeping)
- `feature/EPIC-003-domain-model` → origin — success (`6d08f08..5bbdd72`, TASK-013)
- `feature/EPIC-002-foundation` → origin — success (`a2a36b7..2973eb8`, housekeeping)
- `feature/EPIC-002-foundation` → origin — success (`5389af1..a2a36b7`)
- `feature/EPIC-002-foundation` → origin — success (`983d94d..a9b9993`)
- `feature/EPIC-002-foundation` → origin — success (`81be80b..b28ccb4`)
- `feature/EPIC-002-foundation` → origin — success (new branch, `172bc11`, tracking set)
- main → origin — success (`95e7649..71a510b main -> main`)

## Architecture / Product Decisions
- Binding decision log: `docs/product/01-product-review.md` §6 (D1–D20).
- **ADR-001 (owner, E2):** Direction C "Round Rabbit" — ~11-part rig, ear-thickness rule, posture-led expression.
- **ADR-002–007 (TASK-006):** Codable atomic file store (envelope+checksum, 3-gen recovery, additive migrations); WatchConnectivity-only sync (context latest-wins ↓, FIFO journal ↑, dual idempotency guards scoped per `watchSessionEpoch`); pure event-driven engine `reduce(state, event, clock, rng)`, no timers; 90-min satiety window (0–30 refusal / 30–90 nibble ×0.25 owner-confirmed); SPM packaging MomoCore/MomoCharacter/MomoKit + app targets; SwiftUI-native rig (ADR-007); deployment-target policy (ADR-006, now **ACCEPTED** — status line reconciled during TASK-008's review loop).
- **ADR-008 (TASK-008, bootstrap pins — ACCEPTED):** min **iOS 26.0 / watchOS 26.0** (generation floor per ADR-006; build SDKs 26.5); pairing = both floors ≥ 26.0, current-generation floor; device matrix — iPhone small **iPhone SE (3rd generation)** 750×1334 px (375×667 pt, governs FR-2 AC-1a no-scroll), mid iPhone 17, large iPhone 17 Pro Max; Watch small Apple Watch SE 3 (40mm) 324×394 px (governs ADR-001 ~32 pt glyph; SE 2nd gen 40mm confirmed same geometry), flagship Series 11 (46mm), Ultra 3 optional upper bound; **Swift Testing** + XCUITest; N-1 widening deferred to TASK-050. Current-generation-hardware-only exclusion recorded as an owner lever (§36), **not taken**.
- **TASK-009 build-baseline decisions (recorded in the task file; REVIEW-TASK-009 NITPICK-2 follow-up):** hand-authored committed pbxproj (xcodegen absent; text-diffable, fresh-clone-friendly); **standalone watch target** honoring D-R3 with the companion relation via `WKCompanionAppBundleIdentifier` — **promote to an ADR by EPIC-008 start (ADR-009 candidate)**, before sync design hardens; tools-version 6.2 (adversarially verified minimum for the `.v26` pins); `.macOS(.v26)` is host-only for `swift test` (no macOS product/target); bundle IDs `com.momo.app` / `com.momo.app.watchkitapp` (E4 name clearance remains the TASK-050 gate).
- **TASK-011 design-system conventions (single canonical pass, 04 Appendix B item 3):** hex literals confined to `MomoCharacterPalette.swift` + `MomoUIColors.swift` (allowlist test-pinned); `MomoColorToken` carries non-optional light+dark variants (compile-enforced completeness); catalog = `Apps/Shared/MomoCopy.xcstrings` shared by both targets; `CopyKey` type-safe builders + `MomoCopy.lookup` (NUL-sentinel → nil) / `.resolve` (DEBUG assertionFailure, release falls back to key) with **injected Bundle** — package code never touches `Bundle.main`; placeholder convention = index `00` + `PLACEHOLDER` comment + `extractionState: manual`, seed pinned at exactly 3 keys (one per namespace); react lines VoiceOver-announced, never rendered (04 §10.1 rule 7). REVIEW-TASK-011 follow-ups recorded under Next Tasks.
- **Owner decisions 2026-09-08:** OPEN-1 — §5.5 cascade rule 1 = "(local time ≥ 20:00 or local time < 07:00)"; I-2/OPEN-5 — nibble class normative (PRD FR-6/§4 amended).
- **TASK-007 delivery plan (`docs/product/06-delivery-plan.md`, normative for execution):** Phase 1 = EPIC-002 foundation → 003 domain model → 004 engine → 005 persistence/sync logic → 006 character rendering → 007 iPhone home → 008 watch & sync → 009 polish/QA/release. Slice spine 008→009→012→014→016→017→019→021→031→033→034→040→041(+042) = project.md §40 Step 7; slice completes at end of EPIC-008. Parallel lanes: LANE A (EPIC-005 from 012/014), LANE B (EPIC-006 from 009+011). Coverage floors Core ≥ 90 % / Kit ≥ 80 %; 05 §12 budgets are release blockers (measured on iPhone SE (3rd gen) / Watch SE 3 40mm at TASK-045); NFR-6 accessibility audit launch-blocking. Feature branches per epic from EPIC-002 (`feature/EPIC-00X-slug`); ADR numbering continues at ADR-009+. §3 task tables are the backlog of record — task files created just-in-time per batch.
- PRD-normative numbers: Bond 0–1000 monotonic, stages 149/399/749, +8/+4/+6/+20 cap; Mood bands 20/45/75 (attractor 60, floor 25, ceiling 92); Energy bands 20/45/75; quests Q1–Q7, daily set = Q1 + 2 seeded, Q1 < 12:00, Q6 20:00–07:00.
- Orchestration: docs under `docs/{product,design,architecture}/`; ADRs under `.claude/tasks/decisions/` (ADR-001…008 present); **feature branches from EPIC-002 onward**; all agents Jupiter.

## Known Issues
- ~~TR10 "Xcode availability never verified"~~ **RETIRED AS VERIFIED** (`172bc11`; ADR-008 Consequences; risk R1 mitigated).
- 2026 fall OS churn: all API availability claims VERIFY-AT-BUILD; register in 05 Appendix B, every item has exactly one owning task (009/010, 014, 025, 040/044, 045, 048).
- R9: paired Watch hardware needed for WC delivery obligations (TASK-044) — simulators carry development; device session is the explicit deliverable.
- ~~`.gitignore` minimal~~ **RESOLVED (TASK-009):** Swift/Xcode entries added (`.build/`, `DerivedData/`, `xcuserdata/`, `*.xcuserstate`; the committed `Momo.xcodeproj` is deliberate).
- ~~Schemes carry no TestAction~~ **RESOLVED (TASK-010):** TestActions added to both shared schemes; `xcodebuild test` works on both.
- `xccov` cannot read SwiftPM's raw profdata ("unrecognized file format") — coverage is read via `xcrun llvm-cov report …` (command recorded in the completed TASK-010 file).
- **Standing note (REVIEW-TASK-013 MINOR-1):** the reflection-based no-numeric-leakage check inspects STORED fields only — computed members, subscripts, and extension members on `PetState`/`CharacterDisplayState` are invisible to it (documented in the `NoNumericLeakageTests.swift` header, "KNOWN BLIND SPOT"). Any engine-era numeric computed accessor on a read-model type therefore requires explicit review attention; band/stage CASE sets are compile-time-pinned (a new enum case fails the build).
- **Ledger pruning owner (REVIEW-TASK-015 Observation):** `EngineState.days` grows past 7 un-pruned in the engine — retention belongs to **EPIC-005** (§5.4 store owns persistence + retention); TASK-018's quest generation consumes the prior-two-sets tail from the store's read path. Engine stays append-only.

## Test Status
- Phase 0: review gates — all six REVIEW records final (002–007 APPROVED).
- TASK-008: verification-as-evidence complete; **three independent probe pairs agree** (reviewer / fixer / verifier: iPhone SE 3rd gen 750×1334 px, Watch SE 2 40mm 324×394 px); Swift Testing probe reproduced exactly.
- TASK-010/011: `swift test` = 35 tests / 9 suites green (superseded); both scheme UI smoke tests green on pinned sims; banned-vocab scan green over the real catalog and proven non-vacuous both directions (REVIEW-TASK-011).
- **Current: `swift test` = 164 tests / 23 suites green** (TASK-015 final, post-disposition: 163 at impl handoff + 1 orchestrator disposition pin `couplingBandReadsSegmentStart`; +38 tests/+3 suites over the TASK-014 baseline 126/20). Standing scans (D-R1 import whitelist, banned vocabulary, token purity, engine purity) green in-suite. Parameterized sweeps carry 1203 cases + SHA-256/SplitMix64/DaySeed vector pins. Coverage informational via llvm-cov (REVIEW-TASK-015 Method 14): TimeFold 95.45 %, HandshakeMachine/Reduce 100 %, TOTAL 97.77 % lines (floors enforced from TASK-020/024).

## Build Status
- **Build baseline established (TASK-009, `b28ccb4`):** both schemes build on pinned simulators — BUILD SUCCEEDED; both apps launch with placeholder shells.
- **Test harness live (TASK-010, `a9b9993`):** `swift test` + `xcodebuild test` green for all five test targets on pinned sims; coverage 90.81 % lines TOTAL (informational).
- **Design system landed (TASK-011, `a2a36b7`):** both builds green; both UI smoke tests green; rendering pixel-verified exact against token hex on both canvases (iPhone light+dark, watch). Reviewer reproduced all of it independently.

## Repository Status
- Branch: `feature/EPIC-004-engine` @ `7b5d735` + this housekeeping commit; `main` @ `bf2dcb7` (EPIC-004 branch cut from it).
- Clean/Dirty: clean after this commit.
- Uncommitted files: none.
- Remote sync: `main` in sync (EPIC-003 merged); `feature/EPIC-004-engine` in sync through TASK-015; EPIC-003 feature branch retained at `a334cba`.

## Important Context for Next Agent
- Read first: `CLAUDE.md`, `project.md`, `docs/product/06-delivery-plan.md` (§3 tables = backlog of record), then doc chain 01→02 (amended)→03→04→05 + ADR-001…008.
- Per-task cycle: fresh Jupiter agent → implement (no commit) → fresh adversarial reviewer (writes review file, replies confirmation-only) → fix loop (fresh fixer + fresh verifier when material) → atomic commit with TASK-ID → push → status update. Agents inherit Jupiter by omitting the model override (an explicit `fable` override fails in this environment — discovered 2026-09-08).
- **git mv gotcha:** `git mv` moves the index blob, NOT working-tree edits — always `git add` the moved file explicitly after any post-edit rename.
- **Merge rule (owner authorization, 2026-09-08, recorded in CLAUDE.md §14):** after a task/epic passes its independent review and findings are addressed, merge the feature/epic branch **directly into `main`** and push — **no PR** — then continue into the next epic without waiting for the owner. Never merge unreviewed code; never merge before required tests pass (§19). (Supersedes the owner's earlier PR-based integrations, PRs #1–#3.)
- "(this commit)" convention: task files record `(this commit)` in Completion Evidence; the real hash lands in status.md's Recent Commits via the housekeeping commit (see `39d6bab`/`1746a98` precedent).
- Branch model: each epic on `feature/EPIC-00X-slug` cut from `main`; one atomic commit per task, pushed after each task; epic merges to `main` at DoD (delivery plan §1.5, §6.1). EPIC-002's branch now exists with TASK-008 as its first commit.
- EPIC-002 is DONE — downstream tasks inherit: package (`Sources/<Module>` + `Tests/<Module>Tests`), pbxproj with TestAction-equipped schemes, live scanners (import whitelist + banned-vocabulary, now actively scanning `Apps/Shared/MomoCopy.xcstrings`), design tokens in `MomoCharacter` (hex ONLY in the 2 palette files — keep it that way; `TokenPurityTests` enforces), copy lookup via `CopyKey`/`MomoCopy` with injected bundle (new UI code must not touch `Bundle.main` for copy or hardcode hex). Engine/read-model tasks own real copy pools (index ≥ 01). Known watchOS lesson: `xcodebuild build` does NOT install to the simulator — `simctl install` before `simctl launch`/screenshots; flexible aspect-ratio shapes can collapse in tight watch VStacks (use deterministic frames). All five ADR-008 matrix simulators are provisioned and available.
- Coverage floors (Core 90 %, Kit 80 %) recorded per task, enforced by TASK-020/024.
- Philosophy guardrail: Cute × Calm × Minimal × Alive × Premium. No punishment. MVP scope protection (§22/§24); scope-creep proposals route to KEEP/LATER/REJECT with the orchestrator (plan R10).

## Exact Next Action
Materialize the **TASK-016** contract (interaction semantics + satiety window + repetition curve — 05 §4.4–4.5, PRD §4 response matrix; size L; depends on TASK-015; carry-in notes: `.settling` is reachable via tuck-in and the settle-preemption edge is now implemented; `interactionPassThrough` mints a wake handshake mid-loop — waking-interaction responses must account for it; play effects land at the `.playRoundFinished` unified point; satiety 90-min window 0–30 refusal / 30–90 nibble ×0.25 owner-confirmed I-2; same-family repetition 1.0/0.6/0.25/~0; mood ceiling 92) at `.claude/tasks/active/TASK-016-interactions-satiety-repetition.md`, then dispatch the fresh Jupiter impl agent on `feature/EPIC-004-engine`.
