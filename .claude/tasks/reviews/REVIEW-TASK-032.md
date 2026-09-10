# REVIEW-TASK-032 — Onboarding S1→S2→S3

- **Reviewer:** independent adversarial review agent (fresh Jupiter dispatch; not the implementer, not the orchestrator)
- **Date:** 2026-09-10
- **Branch / HEAD at review:** `feature/EPIC-007-iphone-home` @ `c0ad5ec`
- **Tree state reviewed:** UNCOMMITTED working tree — 7 modified (`Apps/Momo/MomoApp.swift`, `Apps/Momo/MomoAppModel.swift`, `Sources/MomoKit/AppModelPlan.swift`, `Tests/MomoKitTests/Support/AppModelFixture.swift`, `MomoUITests/MomoUITests.swift`, `Momo.xcodeproj/project.pbxproj`, `.claude/tasks/active/TASK-032-onboarding.md`) + 7 new (`Apps/Momo/OnboardingFlow.swift`, `OnboardingCanvasView.swift`, `OnboardingMeetView.swift`, `OnboardingNameView.swift`, `OnboardingEnterView.swift`, `MomoUITests/MomoOnboardingUITests.swift`, `Tests/MomoKitTests/AppModelOnboardingPlanTests.swift`). Verified unchanged (nothing else dirty) at review start AND at review end.
- **Method:** per CLAUDE.md §10/§33 and the task's Review Requirements — (1) read the contract + status context; (2) re-derived the normative spec from `docs/design/03-ux-architecture.md` §3 and `docs/product/02-mvp-prd.md` FR-1/FR-13 BEFORE opening any implementation code; (3) read the full diff and every new file, comparing against MY derivation; (4) adversarial verification — five sha256-proven mutation bites, freeze checks, census/scans, pbxproj audit, character-for-character copy fidelity, test-quality audit; (5) reproduced `swift test`, `xcodebuild build`, the full UI battery, and performed two of my own `simctl install`+`launch` cycles with screenshots; (6) audited the implementation's disclosures (a)–(k) for honesty.

---

## 1. Spec re-derivation (written before implementation code was opened)

From UX §3 + FR-1/FR-13, my independent derivation:

- **Gate (FR-1 AC-2):** `settings.onboardingComplete` is the sole gate — `false` (fresh store or invisibly recovered store, indistinguishable) routes to the flow; `true` routes to Home/RootTabView. Nothing else may decide the branch.
- **S1 Meet:** creature canvas ~half screen; line "This little one just moved in."; button "Say hello" that is a FLOW button — it must NOT route a pet interaction (UX-6: the daily hello stays anchored to the first pet touch in the real app; completing Q1 here would be a grants-something violation). Copy character-agnostic. VO: canvas = one element labeled "A small creature looks up at you"; line read; button labeled.
- **S2 Name:** "What should your new friend be called?"; field pre-filled "Momo" with a clear affordance and label "Pet name"; "Continue" enabled only when trimmed input holds ≥ 1 non-whitespace char (INV-1's UI face); validation gentle/inline — disabled button IS the signal, no error copy, no shake; hint "A name with at least one letter is needed" explains the disabled state to VoiceOver; typed name in view state only (kill before Enter ⇒ restart from S1).
- **S3 Enter:** full-focus canvas; "Meet your new friend." / "This is {name}." (interpolated from S2's value); "Begin" is THE completion tap.
- **Completion (FR-1 AC-2 / FR-13 AC-1):** ONE atomic write flipping `onboardingComplete` to true and minting the final pet identity; grants NOTHING else (no bond, no counters, no day records, no greeting stamp, no stage ceiling, no intent-ledger change); no response, no moments. After the tap every launch goes straight to Home.
- **Non-negotiables:** zero dialogs/sheets/alerts, zero network, zero accounts, zero permission requests (FR-1 AC-1/AC-4); character modules frozen; onboarding copy does NOT enter `MomoCopy.xcstrings`; ≥ 44 pt targets; Reduce Motion substitutes transitions; no species words; banned vocabulary clean.

The implementation matches this derivation on every point I checked (below). No requirement was found implemented against a different reading of the spec.

## 2. Per-requirement findings

| Req | Finding | Evidence |
|---|---|---|
| R1 gate | **Pass.** Branch consults ONLY `requiresOnboarding` (= `!state.settings.onboardingComplete`, MomoAppModel.swift:124); `OnboardingFlow()` vs `RootTabView()`; `.environment(appModel)` + `scenePhase` onChange preserved on the surrounding `Group`. Fresh and recovered stores both hit the flow — nothing distinguishes them. | `Apps/Momo/MomoApp.swift` diff |
| R2 S1 | **Pass.** Canvas 240 pt via shared `OnboardingCanvasView`; line + "Say hello" verbatim; button advances the flow's `@State step` ONLY — `OnboardingMeetView`'s `onContinue` never touches `appModel.interact` (UX-6 held). VO canvas label verbatim, one element (`.accessibilityElement()`). | `OnboardingMeetView.swift`, `OnboardingCanvasView.swift`; UI test pins |
| R3 S2 | **Pass.** Question verbatim; field pre-filled "Momo" (flow `@State petName` default; placeholder also "Momo"); clear affordance 44×44 "xmark.circle.fill" labeled "Clear name", hidden when empty; label "Pet name"; `canContinue = !trimmed.isEmpty` with Continue `.disabled(!canContinue)`; hint present exactly while disabled; typed name in flow view state only. Gentle validation confirmed: no error copy, no shake anywhere in the flow. | `OnboardingNameView.swift:16-18,29-34,43-60` |
| R4 S3 | **Pass.** Canvas 280 pt (full-focus; within MomoCharacter's `fullStagePoints = 220...280`); "Meet your new friend." / "This is \(name)." verbatim; "Begin" → `appModel.completeOnboarding(name:)`. | `OnboardingEnterView.swift` |
| R5 completion plan | **Pass.** Sixth trigger `onboardingCompleted(petID:name:)` with doc comment; `plan` dispatches it BEFORE engine routing to a pure `onboardingPlan(state:petID:name:clock:calendar:)` — no `reduce`, zero EngineEvents. Executor (`completeOnboarding(name:)`) trims, DEBUG-loud-rejects whitespace, mints `UUID()` AT the tap (core stays pure; determinism testable with injected ids). Steps exactly `[.persist, .pushWatchSnapshot]`; `.persist` is the SnapshotStore atomic write (FR-13 AC-1). `engineEvent` gained the case in QuestTick house shape (unreachable arm: `assertionFailure` + clock-sourced fallback — no ambient read). Exhaustive switches compile (census, below). | `AppModelPlan.swift:113-125,189-197,232-242,287-330`; `MomoAppModel.swift` |
| R6 grants nothing | **Pass.** Transformation touches ONLY flag + pet identity; every other field carried verbatim (constructed field-by-field). Zero EngineEvents (no `reduce` call). S1 button routes no intent. Pinned by whole-state + field-by-field tests (below). | `AppModelPlan.swift:306-320`; `AppModelOnboardingPlanTests` |
| R7 kill/restart | **Pass.** UI-pinned both directions (Required Test 8): kill before Begin ⇒ S1 again, no tab bar; completed ⇒ straight Home, no onboarding text. My own two launches reproduce both sides (§5). | `MomoOnboardingUITests.swift:70-102`; my launches |
| R8 zero dialogs/network/accounts | **Pass.** No alerts/sheets/dialogs in any flow file; grep of the flow's call graph shows no `URLSession`/`NWPath`/network symbols; no account surface. | census grep over new files |
| R9 a11y | **Pass.** `OnboardingLayout.minimumTapTarget = 44`; primary button `minHeight: 44`; clear button 44×44; tokens give the contrast; three VO obligations implemented and UI-pinned at label level. (Full manual audit is TASK-039's, correctly not claimed here.) | `OnboardingFlow.swift`, UI test 9 |
| R10 Reduce Motion | **Pass.** `@Environment(\.accessibilityReduceMotion)` read in the FLOW view (app target — permitted); `.animation(reduceMotion ? nil : .easeInOut(0.25), value: step)` ⇒ instant swap under RM; presentation-level only, no character-fold branches. | `OnboardingFlow.swift` |
| R11 copy/vocabulary | **Pass.** All lines are authored view literals; `MomoCopy.xcstrings` untouched (git status); no species words anywhere in new copy; I checked every new string against all 12 banned terms — clean, no new exemptions. | git status; manual sweep |
| R12 canvas hosting | **Pass.** `OnboardingCanvasView` hosts `MomoRigView(displayState:tier:.full:clock:stageSide:)` fed by `MomoAppModel.characterDisplayState` (= `makeCharacterDisplayState(state)`, MomoCore) and a presentation-owned `canvasClock` (`CharacterClock(timeSource: clock)` — same injected source as the engine). No-op overlay default confirmed against `MomoRigView`'s init. No director/report/choreography machinery added. Freezes byte-untouched (§4). | `OnboardingCanvasView.swift`; `MomoAppModel.swift` |
| R13 enabler | **Pass.** `MomoApp.testStoreDirectory()` parses `-momo-store-directory <value>`; absolute honored, relative resolved against the APP's `temporaryDirectory` (the disclosed interpretation — sound: runner and app-under-test live in different sandboxes); production launches unaffected; disclosed in code. Proven live: every UI-test launch got its own fresh store; my own launches used both relative names successfully. | `MomoApp.swift`; UI battery; my launches |

## 3. Required Tests 1–9

- **1 completion transform** — pinned: flag true, re-minted id/name, `createdAt == mintInstant`, steps EXACTLY `[.persist, .pushWatchSnapshot]` (array equality ⇒ no response/moments by the enum's four-case shape), nextBoundary pinned (nightOnset 22:00). `AppModelOnboardingPlanTests.swift`
- **2 grants-nothing** — whole-state + field-by-field (bond, mood, energy, wakefulness, activity, satietyPhase, days, haptics, pendingHandshake nil, processedIntents empty, `.newFriends`, stage ceiling, lastGreeting nil, stamps). See Finding N-1 on one assertion's sensitivity.
- **3 purity/determinism** — identical inputs ⇒ identical plans; different injected id ⇒ different plan.
- **4 idempotence stance** — disclosed stance (unconditional trigger; executor sends at most once — the gate makes a second send unreachable) pinned by `alreadyCompleteStillReMints` over a completed fixture, carry verified. Premise verified: fixture default is `onboardingComplete: true`, so the test's premise holds.
- **5 census** — `triggerCensus`: six-case literal + default-free exhaustive switch + count pin. Missing case = build error, per house law.
- **6 existing tests unmodified** — `git diff` shows zero edits under `Tests/` except the NEW file + the additive `AppModelFixture.swift` extension (`freshCarrier(at:)` mirrors `freshDefaultState` field-for-field — verified). No exhaustive-switch companion edits needed outside `AppModelPlan.swift`. Baseline 851 + 6 new = 857 observed.
- **7 fresh flow (UI)** — full S1→S2→S3→Home walk incl. whitespace-reject pin (`Continue.isEnabled == false`), clear affordance, name carry into S3, tab bar after Begin.
- **8 restart semantics (UI)** — both directions, one store across terminate/relaunch.
- **9 a11y labels (UI)** — canvas label via element query, field label "Pet name", "Clear name", disabled-state pin. Hint non-observability handled honestly (§6c).

Test-quality audit: assertions are behavior-level, no tautological asserts found beyond the sensitivity note N-1; the whitespace guard is tested at BOTH layers (plan-level second guard + UI-level disabled button); no test was weakened to pass.

## 4. Freezes, census, scans, project file

- **Freezes:** `git diff --stat Sources/MomoCore Sources/MomoCharacter` — EMPTY. `Apps/Shared/MomoCopy.xcstrings` untouched. `Sources/MomoKit/NextBoundary.swift` / `AppModelLaunch.swift` untouched.
- **Census (D-R5):** only `Apps/Momo/MomoAppModel.swift` imports MomoCore among Apps/ files; views import MomoCharacter (necessary — design tokens live there); no view imports plan core/engine symbols.
- **Scans:** no TODO/FIXME/HACK/TEMP in new code; no network symbols; banned vocabulary clean over new copy; token purity held (no raw Color/font values in new views — all through MomoUIColors/MomoTypography/MomoSpacing/MomoRadius).
- **pbxproj:** all 6 new files registered at all 4 sites (PBXBuildFile, PBXFileReference, group children, Sources phase) — app files only in Momo's phase, the UI test only in MomoUITests' phase; verified in raw file, not just via build success.

## 5. Reproduction results (my own runs)

| Check | Command | Result |
|---|---|---|
| Headless suite | `swift test` | **857 tests / 86 suites, all PASSED** (baseline 851 + 6 new) |
| Package warnings | `swift build --build-tests` | **0 warnings** |
| App build | `xcodebuild build` (pinned sim `1F25E487-…`) | **BUILD SUCCEEDED**; zero Swift warnings; 2 pre-existing environment warnings (see N-3) |
| UI battery | `xcodebuild test` (MomoUITests + MomoOnboardingUITests) | **TEST SUCCEEDED — 5/5** |
| My launch 1 | `simctl install` + `launch -momo-store-directory momo-review-032-fresh-…` | S1: creature canvas, "This little one just moved in.", "Say hello", **no tab bar** — screenshot `/tmp/review-032-launch1-fresh.png` (visually verified) |
| My launch 2 | relaunch with a completed UI-test store | **Straight to Home**: Home/Room/Settings tab bar, zero onboarding text — screenshot `/tmp/review-032-launch2-home.png` (visually verified) |
| Atomic swap (FR-13 AC-1) | store inspection | Chain in one store: `state.prev2.json` `"onboardingComplete":false` → `state.prev.json` `true` → `state.json` `true`; name "Momo" carried unchanged — the completion write is the swap |

## 6. Disclosures (a)–(k) honesty audit

All disclosures checked were accurate. Key ones: **(b)** relative store-directory resolution against the app's tmp — verified correct and necessary (sandbox separation); **(c)** S2 hint not observable via XCUITest — I independently confirmed ZERO "hint" occurrences in this toolchain's `XCUIElement.h`; the code+state-level pinning and the TASK-039 flag are the honest handling; **(e)** the standing banned-vocabulary scanner covers `.xcstrings` only, so new view copy was manually checked — confirmed, and I performed my own manual sweep (clean); **(j)** warning claim — zero Swift warnings confirmed; the two warnings a FULL build emits are pre-existing environment noise (N-3), consistent with the incremental-final-run framing. The idempotence-stance disclosure matches the pinned test.

## 7. Mutation bites (five; all bit; all restored byte-identical)

| # | Bite | Expected red | Actual red | Restore proof |
|---|---|---|---|---|
| A | `AppModelPlan.swift` onboardingPlan: `hapticsEnabled: state.settings.hapticsEnabled` → `false` | grantsNothing carry assert fails | **FAILED** — `grantsNothing` at `AppModelOnboardingPlanTests.swift:89` | sha256 restored == `0cbd9fb4…148fa` (matches pre-bite) |
| B | same file: `days: state.days` → `days: []` | grantsNothing days assert | **FAILED** — but via `alreadyCompleteStillReMints` (:185, populated-fixture carry); `grantsNothing` did NOT see it (see N-1) | same digest match |
| C | steps `[.persist, .pushWatchSnapshot]` → reordered | steps-EXACTLY pins fail | **FAILED** — `completionTransform` :47 + `alreadyCompleteStillReMints` :179 | same digest match |
| D | `guard let pet = Pet(…)` → `Pet(…)!` (remove 2nd guard) | whitespace test fails | **FATAL** in `whitespaceNameIsTheSecondGuard` (crash = red) | same digest match |
| E | `OnboardingNameView.swift` `canContinue` → `!name.isEmpty` | UI whitespace pin fails | **FAILED** — `testFreshStoreFlowsThroughThreeStepsToHome` at `MomoOnboardingUITests.swift:39` | sha256 restored == `110dba8f…190f2d` (matches pre-bite) |

Every pin I bit bit. Bite B's catch came from a different test than predicted — recorded as N-1, not a gap (the suite as a whole is red under the mutation, which is the property that matters).

## 8. Findings

No MAJOR. No MINOR.

- **NITPICK-1 — `onboardingPlan` doc comment looseness.** The comment reads "The outcome is `changed` ⇒ the §4.1 emission rules yield steps EXACTLY `[.persist, .pushWatchSnapshot]`", but the code hardcodes the steps literal rather than computing them through the emission rules. Substance is fine (applying the rules with `changed == true` yields exactly that, and two tests pin the literal); a one-word rewording ("the fixed-order steps are") would remove the ambiguity. No action required to approve.
- **NOTE-2 — grantsNothing's `days` assert is insensitive to a `days: []` mutation** (bite B): the fresh carrier's days are already empty, so dropping the carry is invisible to that test. The same mutation IS caught suite-wide by `alreadyCompleteStillReMints` (populated fixture). Nil/empty-fixture tautology class. Optional hardening: one populated-days carry assert in grantsNothing.
- **NOTE-3 — full xcodebuild builds re-emit 2 pre-existing environment warnings** (`ld: warning: directory not found for option '-L/opt/extra/lib'`; AppIntents metadata extraction). Not this task's code; zero Swift/package warnings verified. Consider a follow-up environment fix at epic level.
- **NOTE-4 — orchestrator attention item resolved:** an earlier status note flagged 3 modified docs files as uncommitted; those landed in `c0ad5ec`. The current tree contains exactly the 14 task paths (verified before and after my review) — no mismatch remains.

## 9. Verdict

The implementation matches my independently derived spec on all 13 requirements and all 9 required tests; every mutation bite bit and was restored byte-identically (sha256-proven); freezes, census, and scans are clean; the suite (857/86), app build, UI battery (5/5), and both launch semantics reproduce; disclosures are honest; the working tree is exactly as found.

**VERDICT: APPROVED_WITH_MINOR_NOTES**

(0 MAJOR, 0 MINOR, 1 NITPICK, 3 NOTE — none blocking; NITPICK-1/NOTE-2 may be folded into any future touch of these files or ignored.)
