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

READY (2026-09-10) — contract committed; fresh implementation agent dispatching next.

## Implementation Notes

(filled by the implementation agent at handoff — §28 Handoff format)

## Reviewer Findings

(filled after REVIEW-TASK-032)

## Completion Evidence

(filled at close: commit hash, push range, §19 results, test counts, launch evidence, review verdict)
