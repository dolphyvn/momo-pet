# TASK-032 — Onboarding S1→S2→S3

## Parent Epic

EPIC-007 — iPhone Home Experience (task 2 of 9). Epic file: `.claude/tasks/epics/EPIC-007-iphone-home.md`.

## Objective

Make the first-run flow REAL per UX doc §3 and PRD FR-1: exactly three calm, forward-only steps — Meet → Name → Enter — gated by TASK-031's `requiresOnboarding`, ending in an ATOMIC completion write at the Enter tap (FR-13 AC-1) that lands the user on Home. Zero system dialogs, zero network, zero accounts. After this task the vertical slice's front door exists: fresh install → onboarding → Home (placeholder content until TASK-033 composes it).

## Context

- **TASK-031 landed the facade** (commit `257a58f`): `Apps/Momo/MomoAppModel.swift` is the `@MainActor @Observable` executor (state, `launchOrigin`, `requiresOnboarding`, `interact`/`submit` trigger entries, `deliverResponse`/`deliverMoments` seams, boundary scheduling); `Sources/MomoKit/AppModelPlan.swift` is the pure plan core (`AppModelPlanCore.plan(state:trigger:clock:calendar:)`, fixed §4.1 step order, persist-IFF-changed); `Sources/MomoKit/NextBoundary.swift` derives the boundary. `MomoApp.swift` publishes the model into the environment and hosts `RootTabView()` (three placeholder tabs) unconditionally.
- **Normative sources (read these FIRST; they govern):** `docs/design/03-ux-architecture.md` §3 (S1/S2/S3 wireframes, copy, validation stance, VoiceOver notes, AC-2 semantics, "Post-onboarding" — including UX-6: the Say hello button is deliberately NOT a pet touch) and §0's principles; `docs/product/02-mvp-prd.md` FR-1 (AC-1…AC-4) + FR-13 AC-1; the epic's AC-2 row. Also read `CLAUDE.md`, `.claude/tasks/status.md` (Important Context — especially the contract-phrase-precision and wrapper-pin lessons), and the delivery-plan TASK-032 row.
- **Engine facts already verified (do not re-litigate, but the tests re-pin them):** every fold segment calls `TimeFold.rollover`, which appends the landing day's record (with its generated quest set) when absent — the FIRST day record is engine machinery on the launch fold, NOT onboarding's. `InteractionEffects.updatingDay` is a no-op on a missing entry (no retroactive records). The engine owns no initial-state factory — the fresh-default carrier (`MomoAppModel.freshDefaultState`, name "Momo", `onboardingComplete: false`, `days: []`) is what onboarding completes.
- **Copy infrastructure:** `Apps/Shared/MomoCopy.xcstrings` + `CopyKey`/`MomoCopy` are the ENGINE-owned namespaces (`momo.line.*` pool grammar, `isInApprovedNamespace`); onboarding lines are authored VIEW copy, not engine-emitted keys — they do NOT enter that catalog (see R11). Placeholder views already use plain literals (the TASK-009/011 precedent).

## Requirements

Each requirement cites its authority. Where this contract interprets, the interpretation is stated and the reviewer checks it against the docs.

- **R1 — The gate (UX §3 post-onboarding; FR-1 AC-2; 05 §5.2/§5.3).** `MomoApp` routes on the app model's `requiresOnboarding`: `true` → the onboarding flow; `false` → `RootTabView`. The ONLY state that decides is `settings.onboardingComplete` (already surfaced as `requiresOnboarding`). A fresh store AND an invisibly-recovered store both read `false` → onboarding — exactly §5.3's indistinguishable-recovery stance. No intermediate screens, no splash logic beyond what exists.
- **R2 — S1 Meet (UX §3 S1).** Pet canvas (center, ~50% height) hosting the live rig per R12; the line "This little one just moved in."; a "Say hello" button advancing to S2. Character-agnostic copy — no species words (E2 is open). The button is a FLOW button, never a pet touch: it must NOT route through `MomoAppModel.interact` and must not complete Q1 or award the hello (UX-6 — the daily hello stays anchored to the first pet touch in the real app). VoiceOver: the canvas is one accessibility element ("A small creature looks up at you"), the line is read, the button is labeled.
- **R3 — S2 Name (UX §3 S2; FR-1; INV-1).** The line "What should your new friend be called?"; a text field PRE-FILLED "Momo" with a clear affordance and accessibility label "Pet name"; a "Continue" button ENABLED only when the trimmed input contains at least one non-whitespace character (whitespace rejected — INV-1). Validation is gentle and inline: the disabled button IS the signal — no error copy, no shake (calm). An accessibility hint on the disabled button tells VoiceOver users why ("A name with at least one letter is needed"). The typed name lives in view state only until Enter (kill before Enter ⇒ restart from S1 — R7).
- **R4 — S3 Enter, the payoff beat (UX §3 S3).** Pet canvas at full focus; the lines "Meet your new friend." / "This is {name}." (the {name} comes from the in-flow S2 value, interpolated); a "Begin" button. The tap is THE completion event (R5). VoiceOver: canvas described, both lines read, button labeled.
- **R5 — The completion plan (FR-1 AC-2; FR-13 AC-1; 05 §4.1 fixed order; D-R5).** Extend the app layer's plan vocabulary with a sixth trigger, `AppModelTrigger.onboardingCompleted(petID: UUID, name: String)` — the EXECUTOR mints the final pet identity (fresh `UUID()`) at the tap and passes it in, so the plan core stays PURE (no ambient randomness; determinism testable with injected UUIDs). `AppModelPlanCore.plan` handles it as a state transformation over the freshest applied state: `settings.onboardingComplete = true`; the pet re-minted as `Pet(id: trigger.petID, name: trigger.name, createdAt: fold instant)`. The outcome is `changed` ⇒ the plan emits `.persist` (the SnapshotStore's atomic write — that IS the atomic completion write of FR-13 AC-1) and, per the existing emission rules, `.pushWatchSnapshot` (the reserved EPIC-008 no-op — correct as-is); it emits NO response and NO moments. The executor gains ONE new public entry (`completeOnboarding(name:)` or equivalent) that mints the UUID and applies the trigger — views call the app model, never the core (D-R5). The new trigger case must be handled in every exhaustive switch (a missing case is a BUILD ERROR — the house census law).
- **R6 — Grants nothing, starts no clocks (UX §3 "Post-onboarding"; epic scope).** The completion transformation touches ONLY the settings flag and the pet identity. Pins required (see Tests): bond and ledger counters unchanged; `days` unchanged (no day fabrication — the engine's `rollover` owns records); `lastGreeting` NOT stamped; `highestCelebratedStage` unchanged; `processedIntents`/`pendingHandshake` unchanged; zero `EngineEvent`s emitted by the completion outcome. The S1 button likewise routes no intent (R2).
- **R7 — Kill/restart semantics (FR-1 AC-2).** Killing the app before the Enter tap ⇒ next launch reads `onboardingComplete == false` ⇒ onboarding restarts cleanly from S1. After the tap, every launch goes straight to Home (RootTabView). Engine folds DURING onboarding (the launch foreground catch-up may append today's day record and persist it) are expected and harmless — the flag is the sole gate. Note the FR-13 AC-1 bound honestly: a kill between the state application and the in-flight save completing is the documented ≤ 1 s in-flight-event loss window, not a violation.
- **R8 — Zero dialogs, zero network, zero accounts (FR-1 AC-1/AC-4).** No permission requests, no alerts, no sheets beyond the flow's own views, no `URLSession`/network symbols anywhere in the flow's call graph (grep-verifiable), no account surface.
- **R9 — Accessibility (UX §3 notes; FR-20 groundwork — the full audit is TASK-039).** The three VoiceOver obligations in R2/R3/R4 are requirements, not polish: canvas = one element with the UX-given label, lines readable, every button labeled, the S2 hint on the disabled state. ≥ 44 pt touch targets; contrast per the design tokens.
- **R10 — Reduce Motion (TASK-029 RM law; 04 §7.3).** Any authored entrance/step transition in the flow is presentation-level and must substitute under Reduce Motion (no motion under RM — stillness or instant swap). The app target MAY read `@Environment(\.accessibilityReduceMotion)` (no ambient ban in the app target — the discipline scans govern the packages). Do NOT add RM branches inside any character-layer fold.
- **R11 — Copy placement + vocabulary (D12/INV-11 scoping; TASK-010 banned-vocabulary scan; E2).** Onboarding lines are authored view copy as localizable string literals in the flow's views (the placeholder-shell precedent). They do NOT enter `MomoCopy.xcstrings` (the catalog's grammar is engine-emitted pools only; `isInApprovedNamespace` must keep passing; the catalog's key set is UNCHANGED by this task). All new copy is character-agnostic — no species words; the banned-vocabulary scan stays green with NO new exemptions.
- **R12 — The canvas hosting (EPIC-006 view API; character freeze).** Host `MomoRigView` (the EPIC-006 public view) fed by the app model's `makeCharacterDisplayState(state, …)` read-model, full tier, a presentation-owned `CharacterClock`, the no-op overlay default (the alive-at-rest pose — blink/breath ARE the "small greeting animation"), `stageSide` per the layout. Build NO new character machinery: no director wiring, no report plumbing, no choreography — the greeting-moment/director wiring is TASK-033's. Frozen modules stay byte-untouched (`Sources/MomoCore/` engine files, `Sources/MomoCharacter/`).
- **R13 — Deterministic UI-test enabler (disclosed; needed for the Required Tests).** `MomoApp` (or the model's default init path) accepts a test-only launch argument (e.g. `-momo-store-directory <path>`) that overrides the store directory for that launch — so MomoUITests can run against a throwaway store and pin fresh-install + restart semantics deterministically. Disclose it in the code where it lands; production launches without the argument are unaffected.

## Files / Areas Likely Affected

- `Apps/Momo/MomoApp.swift` — the gate (R1) + the launch-argument enabler (R13).
- `Apps/Momo/OnboardingFlow.swift` (NEW) + per-step views (NEW — file organization rule: many small files) — S1/S2/S3, copy, a11y, RM (R2–R4, R9–R11).
- `Sources/MomoKit/AppModelPlan.swift` — the sixth trigger + its plan-core handling (R5, R6).
- `Apps/Momo/MomoAppModel.swift` — the one new public entry (R5).
- `Momo.xcodeproj/project.pbxproj` — register every NEW file under `Apps/Momo/` at all required sites (build file + group children + sources phase — the hand-authored pbxproj; the TASK-031 precedent shows the four-site shape; a file that builds under `swift build`'s targets but is missing from the pbxproj will still fail the xcodebuild verification).
- `Tests/MomoKitTests/AppModelPlanTests.swift` (+ fixture if needed) — the new-trigger suites.
- `Apps/MomoUITests/` (NEW file(s)) — the flow's UI tests (see Required Tests).
- UNTOUCHED: `Sources/MomoCore/` (engine freeze), `Sources/MomoCharacter/` (character freeze), `Apps/Shared/MomoCopy.xcstrings` (R11), `Sources/MomoKit/NextBoundary.swift`/`AppModelLaunch.swift` (no behavioral change expected).

## Dependencies

- TASK-031 (DONE, `257a58f`) — the facade, the gate input, the plan core, the persist path.
- EPIC-006 view API (`MomoRigView`, merged) — the canvas.
- EPIC-002/003/004/005 infrastructure — tokens, copy lookup discipline (unaffected), engine, store.

## Constraints

- **D-R5:** views never invoke the engine or the plan core directly — only `MomoAppModel` (the only app file importing `MomoCore` remains `MomoAppModel.swift`; keep the import census exactly as TASK-031 left it unless the contract genuinely requires otherwise — it does not).
- **Engine + character freezes:** consume, never edit (`Sources/MomoCore/`, `Sources/MomoCharacter/` diffs must be ZERO — verify with `git diff --stat` at handoff).
- **Scope control (§22/§24):** no customization, no skip-flow, no progress dots (UX-7), no sound, no permissions, no analytics, no tooltips beyond the a11y hints, no Watch code (EPIC-008). The S2 clear affordance is the UX-specified one; nothing more.
- **File budgets:** views stay focused and small (many small files; each ≤ ~300 lines); no `console.log`-equivalent debug residue; the `MomoCopy` DEBUG-loud discipline governs any new logging (literal, non-interpolated text).
- **Swift 6 strict concurrency** per the repo baseline; `@MainActor` views; the executor's existing concurrency shape is not restructured.
- All numbers/copy pinned to the UX §3 text verbatim where §3 gives exact strings (the six copy lines + the VO label + the hint); deviations require disclosure in the task file, not silent editing.

## Acceptance Criteria

1. **AC-1 (FR-1):** a fresh store shows exactly S1→S2→S3 in order, forward-only, with zero system dialogs; no network/account surface exists in the flow.
2. **AC-2 (FR-1; epic AC-2):** kill before Enter ⇒ onboarding restarts from S1; after Enter, relaunch goes straight to Home. The completion write is the plan's `.persist` step (atomic, FR-13 AC-1).
3. **AC-3 (FR-1):** the name is carried into state at the Enter tap (the UI rename surface itself is TASK-038).
4. **AC-4 (FR-1):** completion happens with no account, sign-in, or network activity.
5. **INV-1/UX §3:** whitespace-only names are rejected (button disabled); "Momo" prefill; the S2 a11y hint explains the disabled state.
6. **Grants-nothing (R6):** the completion outcome carries zero events/moments/response and leaves bond, counters, days, `lastGreeting`, stage ceiling, intents, handshake untouched; the S1 button routes no intent.
7. **D-R5 census:** `MomoAppModel.swift` remains the only app-target file importing `MomoCore`; no view imports the plan core.
8. **Freezes hold:** `git diff --stat Sources/MomoCore Sources/MomoCharacter` is EMPTY at handoff; the catalog's key set is unchanged.
9. **A11y groundwork (R9):** the three UX §3 VoiceOver obligations are implemented and UI-test-pinned at the label level (full audit = TASK-039).
10. **RM (R10):** the flow's transitions substitute under Reduce Motion.

## Required Tests

Headless (Swift Testing, `Tests/MomoKitTests/` — run `swift test`, must be green with ZERO new warnings; baseline **851/85 @ the TASK-032 contract commit**):

1. **Completion plan transform:** `onboardingCompleted` over a fresh-default carrier → flag true, pet re-minted with the injected id/name and `createdAt == fold instant`; `changed == true` → steps EXACTLY `[.persist, .pushWatchSnapshot]`; no response; no moments.
2. **Grants-nothing pins (R6/AC-6):** whole-state diff outside {settings flag, pet identity} is EMPTY — assert field-by-field (bond, days, counters via days, `lastGreeting`, `highestCelebratedStage`, `processedIntents`, `pendingHandshake`, `lastOpenedAt`/`lastEvaluatedAt` per the core's existing stamping rules).
3. **Purity/determinism:** identical (state, trigger, clock, calendar) ⇒ identical plan (the existing meta/plan discipline; injected UUID, no ambient randomness in the completion path).
4. **Gate input:** the flag false ⇒ plan unchanged... (i.e., the transformation is the flag's sole writer — the plan core mutates nothing else when the flag is already true: applying `onboardingCompleted` to an already-complete state still re-mints per the trigger (executor never sends it twice — document; test pins the idempotence stance you choose and DISCLOSES it).
5. **Census:** the trigger's exhaustive-switch handling — a new case compiles only with handling (existing plan tests' shape covers the emission rules; add a case-set pin if the house pattern expects one).
6. Existing 851 tests stay green UNMODIFIED except where the new trigger case requires an exhaustive-switch companion (disclose any such edit).

UI (`Apps/MomoUITests/` — run via `xcodebuild test` on the pinned iPhone SE (3rd generation) simulator):

7. **Fresh-install flow:** launch with the R13 argument pointing at a fresh directory → S1 visible ("This little one just moved in.", "Say hello") → advance → S2 prefilled "Momo", Continue disabled for whitespace-only input, enabled for valid → S3 shows the interpolated name → Begin → Home (tab bar visible).
8. **Restart semantics:** kill/terminate before Begin → relaunch (same store dir) → S1 again; complete the flow → relaunch → straight to Home (no onboarding step visible).
9. **A11y labels:** the S1 canvas label ("A small creature looks up at you"), button labels, the S2 field label + hint exist (accessibility inspection at the label level).

Build/launch verification (record in the task file): `xcodebuild build` (Momo scheme, pinned sim) BUILD SUCCEEDED; `simctl install` + `simctl launch` — the app launches to S1 on a fresh store and to Home on a completed store (two launches, both logged). `swift test` green ×2.

## Review Requirements

- §10/§33: a FRESH adversarial reviewer (never the implementer, never the orchestrator) writes `.claude/tasks/reviews/REVIEW-TASK-032.md`: re-derive UX §3 + FR-1 from the docs BEFORE reading code; verify every R-requirement; mutation-bite at least the grants-nothing pins and the whitespace validation; reproduce the suite + a launch; verdict APPROVED / APPROVED_WITH_MINOR_NOTES / CHANGES_REQUIRED / BLOCKED.
- Standing scans stay green: D-R1 import whitelist, banned vocabulary (now over the new view copy — verify the scan actually covers the app target's new files), token purity, MomoKit discipline scans — no new exemptions.
- Orchestrator verifies every finding's diagnosis personally before dispositioning (the standing rule); fix loop per §11 when material.

## Git Requirements

- The implementation agent does NOT commit — leaves the tree DIRTY at handoff.
- After review + disposition + §19, the ORCHESTRATOR makes ONE atomic commit containing exactly this task's files:
  `feat(app): TASK-032 onboarding S1→S2→S3 — three calm steps, atomic completion flag`
- Push immediately after the commit; record the hash + push range in the task file and status.md. No attribution lines (owner's global setting).

## Status

DONE pending commit+push (2026-09-10) — implemented (R1–R13) → reviewed APPROVED_WITH_MINOR_NOTES → findings dispositioned (NITPICK-1 fixed, NOTE-2 hardened, NOTE-3 recorded) → §19 green (857/86). Orchestrator committing next; hash + push range land in Completion Evidence, then this file moves to `.claude/tasks/completed/`.

## Implementation Notes

## Handoff

Implementation agent (fresh Jupiter dispatch), 2026-09-10. Tree left DIRTY per Git Requirements. All R1–R13 implemented; all Required Tests green; launch evidence visually verified.

### Completed

- **R1 (gate):** `Apps/Momo/MomoApp.swift` routes on `appModel.requiresOnboarding` — `true → OnboardingFlow()`, `false → RootTabView()`; the only state consulted is `settings.onboardingComplete` (already surfaced by TASK-031). SwiftUI re-evaluates the branch from the same observable the completion write flips. `.environment(appModel)` and the `scenePhase` `onChange` are preserved on the `Group` around both branches.
- **R2 (S1 Meet):** `Apps/Momo/OnboardingMeetView.swift` — canvas (240 pt, via the shared `OnboardingCanvasView`), the line "This little one just moved in." (verbatim), "Say hello" button. The button advances the flow's `@State` step ONLY — it never routes through `interact`, completes no quest, awards no hello (UX-6). VoiceOver: canvas is ONE element labeled "A small creature looks up at you" (verbatim); line and button read/labeled.
- **R3 (S2 Name):** `Apps/Momo/OnboardingNameView.swift` — "What should your new friend be called?" (verbatim); field pre-filled "Momo" via the flow's `@State petName` default, placeholder also "Momo"; clear affordance ("xmark.circle.fill", 44×44, labeled "Clear name", shown when non-empty); field `accessibilityLabel` "Pet name" (verbatim); "Continue" enabled iff trimmed input has ≥ 1 non-whitespace char (INV-1's UI face — disabled button IS the signal, no error copy, no shake); accessibility hint "A name with at least one letter is needed" (verbatim) present exactly while disabled (R3 says "hint on the disabled button"). Typed name lives in view state only (R7).
- **R4 (S3 Enter):** `Apps/Momo/OnboardingEnterView.swift` — canvas full focus (280 pt), "Meet your new friend." / "This is {name}." (verbatim, interpolated from S2's value), "Begin" button = the completion tap (→ `appModel.completeOnboarding(name:)`).
- **R5 (completion plan):** `Sources/MomoKit/AppModelPlan.swift` — sixth trigger `case onboardingCompleted(petID: UUID, name: String)` with full doc comment. `plan` dispatches it EARLY (before engine-event routing) to a private pure `onboardingPlan(state:petID:name:clock:calendar:)`: flag → true, pet re-minted `Pet(id:petID, name:name, createdAt: fold instant)` where fold instant = `clock.now()`, every other field carried verbatim; steps EXACTLY `[.persist, .pushWatchSnapshot]`; no response, no moments, zero EngineEvents. The `engineEvent` routing table gained the mandatory case in QuestTick house shape ("Unreachable:" comment + `assertionFailure` + clock-sourced fallback — no ambient read); `foldInstant` maps the case to `clock.now()`. `Apps/Momo/MomoAppModel.swift` gained the ONE new public entry `completeOnboarding(name:)` — trims, DEBUG-loud-rejects whitespace-only, mints `UUID()` AT the tap, applies the trigger. Every exhaustive switch compiles (census law).
- **R6 (grants nothing):** the transformation touches ONLY flag + pet identity; field-for-field carry pinned by whole-state equality test plus per-field asserts (bond, mood, energy, wakefulness, activity, satietyPhase, days == [], haptics, pendingHandshake nil, processedIntents empty, .newFriends, stamps, lastGreeting nil). S1's button routes no intent.
- **R7 (kill/restart):** UI-pinned both directions (Required Test 8).
- **R8:** no dialogs/sheets/alerts, no network symbols in the flow's files (grep-verified: no URLSession/NWPath), no account surface.
- **R9 (a11y):** all buttons ≥ 44 pt (`OnboardingLayout.minimumTapTarget = 44`, primary style `minHeight: 44`, clear button 44×44); the three UX §3 VO obligations implemented and UI-pinned at the label level.
- **R10 (RM):** step changes crossfade 0.25 s; under `accessibilityReduceMotion` the animation is `nil` (instant swap) — presentation-level only, no character-fold branches.
- **R11 (copy):** all copy is authored view literals; `MomoCopy.xcstrings` UNTOUCHED (verified in git status); no species words; new copy manually checked against all 12 banned terms — clean (see Decisions (e) on the standing scan's coverage).
- **R12 (canvas):** `OnboardingCanvasView` hosts `MomoRigView(displayState:tier:.full:clock:stageSide:)` fed by the new `MomoAppModel.characterDisplayState` read-model and the new presentation-owned `canvasClock` (ONE `CharacterClock`, same injected time source as the engine; TASK-033's director wiring reuses it). No new character machinery; freezes byte-untouched.
- **R13 (enabler):** `MomoApp.testStoreDirectory()` — private static, parses `-momo-store-directory <value>`; absolute honored as-is, relative resolved against the APP's `temporaryDirectory` (disclosed interpretation — see Decisions (b)); production launches unaffected. Disclosed in the code.

### Files Changed

Modified (6):
- `Sources/MomoKit/AppModelPlan.swift` — sixth trigger + pure `onboardingPlan` + unreachable-arm census handling (R5/R6).
- `Apps/Momo/MomoAppModel.swift` — `import MomoCharacter`; `canvasClock` (one session `CharacterClock`); `characterDisplayState` computed read-model; `completeOnboarding(name:)` entry (R5/R12). Still the ONLY app file importing MomoCore (D-R5 census re-verified).
- `Apps/Momo/MomoApp.swift` — the R1 gate + `testStoreDirectory()` (R13).
- `Momo.xcodeproj/project.pbxproj` — 6 new files × 4 sites each (build file, fileref, group children, sources phase; app sources phase for 5 views, UI-test target for MomoOnboardingUITests). Verified 4/4 per file.
- `MomoUITests/MomoUITests.swift` — smoke test walks the flow (REQUIRED: the R1 gate sends a fresh default store to onboarding); own throwaway store via R13.
- `Tests/MomoKitTests/Support/AppModelFixture.swift` — ADDITIVE: `onboardedPetID`/`onboardedPetIDOther` + `freshCarrier(at:)` (mirrors the executor's fresh-default shape).

New (7):
- `Apps/Momo/OnboardingFlow.swift` (97 ln) — step enum, layout constants, flow view, primary button style.
- `Apps/Momo/OnboardingCanvasView.swift` (31 ln) — shared `MomoRigView` host + VO label.
- `Apps/Momo/OnboardingMeetView.swift` (31 ln) — S1.
- `Apps/Momo/OnboardingNameView.swift` (73 ln) — S2 + INV-1 + hint.
- `Apps/Momo/OnboardingEnterView.swift` (38 ln) — S3 payoff.
- `MomoUITests/MomoOnboardingUITests.swift` (157 ln) — Required Tests 7–9 (4 tests).
- `Tests/MomoKitTests/AppModelOnboardingPlanTests.swift` (237 ln) — Required Tests 1–5 + census guard (6 tests).

Note: the contract's "Files Likely Affected" says `Apps/MomoUITests/` (NEW) — the UI-test TARGET directory already existed as `MomoUITests/` (TASK-010), so the new file landed there.

NOT touched: `Sources/MomoCore/`, `Sources/MomoCharacter/` (freezes — `git diff --stat` EMPTY, re-verified at handoff), `Apps/Shared/MomoCopy.xcstrings`, `Sources/MomoKit/NextBoundary.swift`, `Sources/MomoKit/AppModelLaunch.swift`, existing SPM tests (zero edits — Required Test 6 satisfied with NO exhaustive-switch companion edits needed outside `AppModelPlan.swift` itself).

### Tests Run

1. `swift test` — ×2 (before UI-test-only edits; SPM package unchanged since): **857 tests / 86 suites, PASSED both runs, zero warnings** (baseline 851/85 @ contract commit + 6 new tests in 1 new suite).
2. `xcodebuild build -project Momo.xcodeproj -scheme Momo -destination 'platform=iOS Simulator,id=1F25E487-A78E-464C-95AF-0BD1A9B3E1BE'` — **BUILD SUCCEEDED, zero warnings** (app target; unchanged by later UI-test-only edits).
3. `xcodebuild test` (same destination) — full UI battery; see Test Results for the run history; **FINAL RUN: TEST SUCCEEDED** (log `/tmp/momo-uitests-final3.log`).
4. `xcodebuild build-for-testing` — TEST BUILD SUCCEEDED, zero errors, zero Swift warnings (used to fast-check the final test-file shape).
5. `xcrun simctl install` + `launch` + `terminate` + `screenshot` + `log show` — two-launch evidence (below).
6. Static verifications at handoff: freezes `git diff --stat Sources/MomoCore Sources/MomoCharacter` EMPTY; catalog untouched (`git status` clean for `Apps/Shared/`); census — only `Apps/Momo/MomoAppModel.swift` imports MomoCore; zero TODO/FIXME/HACK/TEMP across all new/changed files; no URLSession/NWPath in onboarding views; banned-vocabulary check over new view copy clean.

### Test Results

- Headless: **857/86 PASSED ×2** — Required Tests 1–6 covered by `AppModelOnboardingPlanTests`: completionTransform (flag/pet/steps exactly `[.persist, .pushWatchSnapshot]`/no response/no moments/nextBoundary pinned); grantsNothing (whole-state + field-by-field); determinism (identical inputs ⇒ equal plans; different injected id ⇒ different); whitespaceNameIsTheSecondGuard (plan no-ops: unchanged state, empty steps, flag false); alreadyCompleteStillReMints (pins the disclosed idempotence stance); triggerCensus (6-case literal + default-free switch + count pin).
- UI battery FINAL: **TEST SUCCEEDED — 5 tests, 0 failures** (MomoOnboardingUITests 4/4 in ~47 s: fresh-flow, kill-before-Enter restart, completed-store straight-to-Home, a11y labels; MomoUITests 1/1 smoke-through-flow). Required Tests 7–9 green.
- Run history (honest): first battery 5 tests / 2 failures — both were my assertions on the S2 hint via `debugDescription`; XCUITest's `XCUIElementAttributes` exposes NO hint property (verified against this toolchain's headers + live element snapshot), so the pins were replaced with the observable disabled-state (`isEnabled == false`) + in-code disclosure; after the fix, all subsequent full batteries green. Two intermediate compile iterations while converging on the MainActor-correct test-file shape (a `@MainActor override` of nonisolated `setUpWithError` is a hard error — overrides cannot add isolation; and one missed helper parameter after removing stored properties) — both caught by the BUILD, no test run on a broken build, final shape compiles and runs clean.
- Final-run warning audit: ZERO warnings of any kind in `/tmp/momo-uitests-final3.log` (no Swift-source warnings from either UI-test file; not even the pre-existing `/opt/extra/lib` ld notice re-emitted on that build).
- **Launch evidence** (pinned iPhone SE 3rd gen, `com.momo.app`): launch 1 — fresh store `-momo-store-directory momo-simctl-fresh-evidence` (PID 39469, 14:15:23): log "app model live — fresh store, onboarding input surfaced"; screenshot `/tmp/momo-launch1-fresh.png` VISUALLY VERIFIED: S1 — creature canvas with mat + sparkles, "This little one just moved in.", "Say hello", NO tab bar. Launch 2 — completed store `momo-smoke-uitest-2799D704-345E-4A04-97AB-A977DA0FD576` (PID 40826, 14:15:31): log "app model live — loaded store, launch is the first open"; screenshot `/tmp/momo-launch2-home.png` VISUALLY VERIFIED: Home tab selected, 3-tab shell Home · Room · Settings, "Home — placeholder" content, NO onboarding text. (That store's `state.json` carries `"onboardingComplete":true` with `state.prev.json` false — the atomic-swap completion write, FR-13 AC-1, observed on disk.)

### Known Issues

None blocking. Disclosures (contract §25/§26 spirit — everything on the table):

(a) **`MomoUITests.swift` modified** — REQUIRED, not scope creep: the R1 gate routes a fresh DEFAULT store to onboarding, so the TASK-010 smoke (assert tab bar on plain launch) would fail unchanged. It now walks S1→S2→S3 with its own throwaway store; the flow's dedicated pins live in `MomoOnboardingUITests`.
(b) **Relative `-momo-store-directory` resolves against the APP's temporary directory** (R13 interpretation, disclosed in code): the UI-test runner and the app-under-test live in different sandboxes, so the runner cannot pre-create an absolute path for the app; a unique relative name per test gives the app a throwaway store (SnapshotStore creates the directory on first save; the launch probe reads absence as fresh). Absolute paths still honored as-is.
(c) **The S2 hint is NOT observable through XCUITest** — `XCUIElementAttributes` has no hint property (toolchain headers + live snapshot both checked). Required Test 9's "hint exists" is established by code (`.accessibilityHint(...)` on Continue, present exactly while disabled) and pinned in the UI by the state it explains (`Continue.isEnabled == false` for whitespace-only). Manual VoiceOver verification of the hint is flagged for TASK-039's full accessibility audit.
(d) **Authored labels disclosed**: "Clear name" (the UX specifies a clear affordance but no label string) and field label "Pet name" (UX-given). The TextField's placeholder is "Momo" — doubles as visual prefill guidance if the user clears the field.
(e) **Banned-vocabulary standing scan covers `.xcstrings` catalogs only**; the new copy is view literals (R11), so the scanner does not see it. Manually verified clean against all 12 terms. Extending the scanner to view literals is a follow-up candidate (§22 — not done here to avoid scope creep).
(f) **Idempotence stance (contract test 4's document-and-disclose)**: the trigger is UNCONDITIONAL — applied to an already-complete state it re-mints the pet and persists again; the executor sends it at most once (the gate makes a second send unreachable from the product flow). Pinned by `alreadyCompleteStillReMints`.
(g) **Authored presentation constants**: `meetStageSide 240` / `enterStageSide 280` (within `RigLOD.fullStagePoints` 220–280; UX's "~50% height" is approximate guidance), `stepCrossfadeDuration 0.25`, `minimumTapTarget 44`. Primary CTA style = `textPrimary` fill with `background` label (token-pure, high contrast), 0.3 opacity while disabled.
(h) **INV-1 second guard in the plan core**: a whitespace-only name cannot mint a `Pet` (failable init), so `onboardingPlan` returns the UNCHANGED state with NO steps (nothing persisted). Unreachable from the product flow (executor trims/rejects + button disabled) — defense in depth only.
(i) **MainActor isolation in the UI test target**: my new class is `@MainActor` (XCUIApplication's API is MainActor-isolated); test methods and helpers are therefore isolated; `setUpWithError`/`tearDownWithError` overrides CANNOT take `@MainActor` (overrides cannot add isolation — compiler-enforced), so the file uses a slim nonisolated `setUpWithError` (only `continueAfterFailure`, nonisolated-safe) and a per-test `freshApp()` helper (house style: per-test `XCUIApplication`, like the legacy file). No tearDown override (the runner relaunches per test; restart tests terminate explicitly mid-test).
(j) **Legacy `MomoUITests.swift` was never `@MainActor`-annotated** — when recompiled it emits the same MainActor-isolation warning class my file had before annotation (TASK-010 vintage). The FINAL full-target compile (`build-for-testing` + final battery) emits ZERO Swift warnings; incremental builds may re-surface legacy-file warnings on future recompiles. Annotating it is a one-line follow-up I did NOT take (§22 — my sanctioned change to that file was the flow walk only).
(k) **Conditional hint**: the S2 hint is present exactly while the button is disabled (empty when enabled) — matches R3's "hint on the disabled button"; a hint on an enabled Continue would be misleading.

### Decisions Made

- **Completion is NOT engine-routed**: `plan` dispatches `.onboardingCompleted` before `reduce` — a transformation that grants nothing has no `EngineEvent`; the mandatory `engineEvent` arm is QuestTick-shaped (`assertionFailure` + clock-sourced fallback, no ambient read).
- **`canvasClock` lives on the app model** (one session `CharacterClock`, engine-injected time source) — TASK-033 reuses it for Home; views hold no clocks.
- **`characterDisplayState` computed on the app model** so onboarding views never name a MomoCore type (D-R5 census by inference; views bind through `@Environment(MomoAppModel.self)`).
- **Gate as a `Group` branch in `MomoApp`** keeping `.environment` + `.onChange(of: scenePhase)` outside the branch — the completion flip re-evaluates the branch from the same observable.
- **UI tests per-test `freshApp()`** (see Known Issues (i)/(j) for the isolation constraints that shaped it).
- **Test-store evidence store**: the UI battery itself produced a completed on-disk store (atomic `state.json`/`state.prev.json` swap) reused as launch-evidence input.

### Reviewer Status

NOT YET REVIEWED — no review agent has inspected this work. Per §10/§33 a fresh adversarial reviewer must author `.claude/tasks/reviews/REVIEW-TASK-032.md` BEFORE any commit. Suggested reviewer focus: re-derive UX §3 + FR-1 from docs first; mutation-bite the grants-nothing pins (flip a carried field → test must fail) and the whitespace validation (enable Continue for whitespace → UI + plan guards); verify the pbxproj 4-site registrations; reproduce `swift test` + one launch.

### Commit

None — tree left DIRTY per Git Requirements. The orchestrator makes the single atomic commit after review + disposition + §19.

**ORCHESTRATOR ATTENTION — parallel-work collision risk**: `git status` at handoff also shows THREE modified docs files that are NOT this task's: `docs/architecture/05-technical-architecture.md`, `docs/design/04-character-system.md`, `docs/product/02-mvp-prd.md` (apparently the parallel doc-errata cycle, task #74). The TASK-032 commit must contain EXACTLY the 13 files listed under Files Changed — do not sweep the docs edits into it.

### Push

None — orchestrator pushes after the commit (Git Requirements).

### Recommended Next Step

Orchestrator: dispatch the fresh review agent (§10/§33) for REVIEW-TASK-032; after verdict ≥ APPROVED_WITH_MINOR_NOTES and findings addressed, run §19 checks, commit exactly the 13 task files with `feat(app): TASK-032 onboarding S1→S2→S3 — three calm steps, atomic completion flag`, push, record hash + range, move this file to `.claude/tasks/completed/`, update `status.md`. Then TASK-033 (Home composition) — it should reuse `MomoAppModel.canvasClock` + `characterDisplayState` and add the director/moment wiring this task deliberately left out.

## Reviewer Findings

**REVIEW-TASK-032 (2026-09-10, `.claude/tasks/reviews/REVIEW-TASK-032.md`) — VERDICT: APPROVED_WITH_MINOR_NOTES** (0 MAJOR, 0 MINOR, 1 NITPICK, 3 NOTE). The reviewer independently re-derived UX §3 + FR-1/FR-13 BEFORE opening code, confirmed all 13 R-requirements and all 9 required tests, bit five sha256-proven mutations (all red, all restored byte-identical), reproduced `swift test` 857/86 + `xcodebuild build` + the 5/5 UI battery, and performed two of its own screenshot-verified launches (fresh → S1, completed → Home). All disclosures (a)–(k) audited honest. Findings and dispositions:

- **NITPICK-1 (doc-comment looseness in `onboardingPlan`) — FIXED by orchestrator.** Diagnosis personally verified against my own diff read: the comment claimed the §4.1 emission rules "yield" the steps literal while the code hardcodes it (substance identical; two tests pin the literal). Applied the reviewer's one-word rewording: "the fixed-order steps are EXACTLY `[.persist, .pushWatchSnapshot]`" (`Sources/MomoKit/AppModelPlan.swift`).
- **NOTE-2 (grantsNothing's days assert insensitive to a `days: []` mutation; bite B was caught suite-wide by `alreadyCompleteStillReMints` over the populated fixture) — HARDENED by orchestrator.** Diagnosis verified: `freshCarrier` has `days: []`, so the empty-on-empty assert cannot distinguish carry from reset. Added the reviewer's suggested populated-days carry assert to `grantsNothing` (`AppModelOnboardingPlanTests.swift`) with a comment citing this review — the mutation now bites inside that test on its own.
- **NOTE-3 (2 pre-existing environment warnings on full builds: `-L/opt/extra/lib` ld notice + AppIntents metadata) — RECORDED, no code change.** Not this task's code; zero Swift/package warnings verified by both the reviewer and the implementation. Added to status.md's Known Issues as an epic-level environment-fix candidate.
- **NOTE-4 (earlier docs-files collision flag resolved by `c0ad5ec`) — no action; moot.**

Orchestrator additionally folded one held citation alignment into the same disposition touch: `OnboardingEnterView.swift`'s doc comment cited "FR-13 AC-2" (corruption recovery) where the atomicity claim's authority is FR-13 AC-1 (the ≤ 1 s force-quit bound + atomic write) — corrected to AC-1. Held deliberately from the reviewer (not primed; §33) — the reviewer did not flag it.

§19 after dispositions: `swift test` **857 tests / 86 suites PASSED** (the hardening adds assertions inside an existing test — no count change).

## Completion Evidence

(filled at close: commit hash, push range, §19 results, test counts, launch evidence, review verdict)
