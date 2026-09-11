# TASK-037 — Room tab (FR-3; UX §1.2 S5)

## Parent Epic

EPIC-007 — iPhone Home Experience, task 7/9 (`feature/EPIC-007-iphone-home`). Epic context: the Home tab is fully alive (TASK-031…036 DONE); the Room and Settings tabs are still placeholders; TASK-037 replaces the Room placeholder with the real static scene.

## Objective

Replace `PlaceholderRoomView` with the real Room tab: one charming static room scene rendered from TASK-025's generated constants — Momo has a *home*, not just a screen (D13/K4) — with zero interactivity, a single VoiceOver image element ("{name}'s cozy room"), a Dynamic-Type-scalable caption, and the D12 tab-label catalogization riding the same shell file. No state, no logic beyond name interpolation, no new engine/kit semantics.

## Context (verified pins — read these surfaces before writing code)

- **Current placeholder:** `Apps/Momo/PlaceholderRoomView.swift` (a `ContentUnavailableView`), hosted by `Apps/Momo/RootTabView.swift` as the second tab (`Label("Room", systemImage: "door.left.hand.open")`). `RootTabView`'s header already documents the three-tab flat IA (UX-1; no push navigation in Phase 1 — UX §2 ~line 103).
- **The scene constants (consumed READ-ONLY):** `Sources/MomoCharacter/MomoRoom.swift` — GENERATED file, do not edit — five static `Path` constants: `floor`, `rug`, `window`, `pomString`, `pomPuff` (TASK-025's "room 5"; the pom string + puff are the room's static companion decor per 04 §8.5). The `MomoRoom` enum shell lives in `Sources/MomoCharacter/MomoRig.swift:29-30`. `Sources/MomoCharacter/MomoProps.swift` (`food`, `blanket`, `sparkleA`, `sparkleB`) is NOT room decor — food/blanket are interaction props, sparkles are moment-scoped (TASK-025 record) — do NOT add props to the scene.
- **Shapes are COLOR-LESS (R4):** the generated paths carry geometry only; MomoCharacter tokens are applied at render time. `MomoRigView` does NOT render the room (verified: its source has no room composition) — the app-side view applies the tokens itself. Read `Sources/MomoCharacter/MomoRigView.swift` + `Sources/MomoCharacter/MomoReactionOverlay.swift` for the established token-application idiom (MomoColorToken / MomoCharacterPalette fill-stroke usage) and follow it exactly. Geometry coordinate space + scaling: follow the rig host's scaling idiom (the scene scales to its container, aspect-preserving — UX §10 row 435 "Scene scales").
- **Name access:** app views read `model.petName` (precedent `HomeStatusRowView.swift:40`, `HomeView.swift:97`). The Room view composes its caption and a11y label from the same source.
- **PRD FR-3:** one charming static room scene, reachable from Home (the tab); AC-1 renders offline, no permissions, no purchasable/interactive elements; AC-2 no customization UI. "Momo MAY be visible in the room."
- **UX §1.2 S5 + §10 audit row 435:** static charming scene; a11y = scene announced as ONE image element ("{name}'s cozy room") + caption; no actions to discover; static already (no Reduce Motion substitution owed); no state encoded.
- **D12 (FR-20):** every string externalized — the three tab labels in `RootTabView` ("Home", "Room", "Settings") are currently hardcoded English literals. This task fixes them while it edits the file (the one directly-necessary D12 debt; recorded in status.md's checkpoint as riding TASK-037).

## Requirements

- **R1 — Scene:** `Apps/Momo/RoomView.swift` renders the five `MomoRoom` paths as one static scene, token-colored at render per the MomoCharacter idiom, scaled aspect-preserving to the available space. Momo (the rig) is NOT rendered in the room — DISCLOSED ADJUDICATION: FR-3 says MAY; Home owns the live rig and duplicating it here would add composition + motion surfaces for zero product value; the pom string/puff decor is the room's companion presence. Record this adjudication in the view's header doc.
- **R2 — Zero interactivity:** no `Button`, no `onTapGesture`, no gesture recognizers, no `allowsHitTesting(true)` overrides, no actions of any kind. Enforce structurally (R5).
- **R3 — A11y:** the scene is ONE a11y element: `.accessibilityElement(children: .ignore)`, `.accessibilityAddTraits(.isImage)`, label = the catalog-composed "{name}'s cozy room" line; the caption renders beneath the scene as its own text element (Dynamic Type scales both). No hidden interactive remnants (the placeholder's `ContentUnavailableView` goes away entirely).
- **R4 — Copy landing (catalog):** new FIXED-lookup keys for (a) the scene label ("{name}'s cozy room", name-interpolated with locale-correct positional specifiers `%1$@`) and (b) the caption line (calm, warm, ≤ 12 words — the "quietly shares everyday life" register; never cutesy-exclamatory). Plus (c) the three tab-label strings. All FIXED lookups rendered via the established copy pipeline (`MomoCopyText.render` precedent); naming per existing catalog conventions (`momo.line.*` style; 00-index reserved-for-placeholders — start at 01; if the tab labels warrant their own namespace, follow the catalog's existing organization and say so in the task notes). **NO epoch bump** — new FIXED keys cannot move seeded draws (established law; each draw seeds fresh and mods its own pool's count). `CopyRules`/`LineSelection` untouched.
- **R5 — Structural guard (the standing family):** extend `Tests/MomoCharacterTests/RigDisciplineTests.swift` (the file-text-scan family, R9a-g precedent) with a guard pinning `RoomView.swift`'s non-interactivity construction: no interactive tokens (Button/onTapGesture/allowing hit-testing), the one-element construction present (`.accessibilityElement(children: .ignore)`), and the a11y image trait present. Violation fixture: valid-Swift-shaped text containing SOME legs but not all (the F-1 lesson — non-vacuous). Header updated per the family's "updated deliberately" contract.
- **R6 — Shell wiring:** `RootTabView` hosts `RoomView` in the Room tab; the three tab labels render from the catalog (R4(c)); `PlaceholderRoomView.swift` deleted; project registration updated (add `RoomView.swift`, remove the placeholder — the TASK-033 pbxproj-registration precedent).
- **R7 — Tests:** catalog law/scaffolding tests extended to cover the new keys' namespace shape (whatever R4 lands); banned-vocabulary scan covers the new strings (standing suite — verify it enumerates them); the R5 guard with its fixture; a UI test in `MomoHomeUITests.swift`: switch to the Room tab, assert the scene element exists with a label containing the pet name, assert the caption exists, and assert ZERO buttons on the room screen (`app.buttons.count == 0` on the room surface). Package tests beyond that only if R4's key access warrants it.

## Files / Areas Likely Affected

- NEW `Apps/Momo/RoomView.swift`; DELETE `Apps/Momo/PlaceholderRoomView.swift`.
- `Apps/Momo/RootTabView.swift` (host + D12 labels).
- `Apps/Shared/MomoCopy.xcstrings` (R4 keys).
- `Tests/MomoCharacterTests/RigDisciplineTests.swift` (R5 guard), catalog law/scaffolding tests (R7).
- `MomoUITests/MomoHomeUITests.swift` (R7 UI test).
- Project registration (pbxproj) for the add/remove.
- ALLOWED small disclosed additions: a key accessor on the established keys surface (HomeCopyKeys precedent) if R4 warrants one.
- **NOT touched:** everything under `Sources/MomoCharacter/` (generated constants + views consumed read-only), `Sources/MomoCore/`, `Sources/MomoKit/` engine/store/plan surfaces, `CopyRules`, `LineSelection`, anything under the Watch targets, existing Home views (beyond nothing — they don't change), `MomoReduceMotion`/`MomoMoments`.

## Dependencies

- TASK-025 (the generated room constants — merged), TASK-031/033 (app model + composed shell — DONE).

## Constraints

- Static means static: no animation, no clock, no director touch, no scenePhase behavior beyond SwiftUI defaults (a static scene has no loop to pause).
- Calm × Premium copy register; never the forbidden poles (§23).
- No customization, no acquisition, no interactive affordance (FR-3 AC-1/2, UX AC-4 red line).
- Budget note: consumption doesn't change source budgets (room+props ≤ 250 KB was measured at TASK-025; no art is added).
- §26: no unexplained TODO/FIXME markers.

## Acceptance Criteria

1. The Room tab renders the static scene from the five generated constants, token-colored, aspect-preserving, offline, zero permissions.
2. The scene surface has ZERO interactive elements (R5 guard green + the UI test's zero-buttons assertion prove it independently).
3. VoiceOver sees ONE image element labeled "{name}'s cozy room" (name-interpolated, localized) plus the caption text element; both scale with Dynamic Type.
4. The three tab labels come from the catalog (D12); the new copy keys are FIXED lookups; NO epoch bump; epoch-4 residue pins (slots `.07`, touch `.02`, pools `.01`, CareInteractionTests fixtures `.04`/`.01`) stay verbatim green.
5. `PlaceholderRoomView` is gone; `RootTabView` hosts `RoomView`; registration updated; the app builds (§25: BUILD, don't assume — the TASK-036 F-import lesson).
6. Full gates green: `swift test`, the UI suite on the pinned SE (`1F25E487-A78E-464C-95AF-0BD1A9B3E1BE`), the `MomoWatch` build (Watch SE 3 44mm `8A854895`), zero warnings from touched files.

## Required Tests

Per R5/R7 above. The reviewer will bite the R5 guard (distinct plausible mutations, exactly-own-test failures, sha256-proven restorations) — write the guard so it bites.

## Review Requirements

Fresh independent §10/§33 reviewer per CLAUDE.md; record at `.claude/tasks/reviews/REVIEW-TASK-037.md`. Reviewer duties: requirements R1-R7, the no-touch walls (MomoCharacter/Core/Kit/Watch/CopyRules/LineSelection diff-absent), epoch pins verbatim, the guard bites, catalog correctness (interpolation specifiers, banned vocabulary), a11y construction (one element, image trait, scaling), and §25 disclosure audit.

## Git Requirements

Orchestrator commits after review approval: `feat(home): TASK-037 room tab — static scene, single a11y element, D12 tab labels` — atomic, TASK-ID included, pushed per §13.

## Status

READY (2026-09-11, orchestrator-authored on the pre-read evidence above; all pins verified in-source this session).

## Implementation Notes

(implementation agent fills)

## Reviewer Findings

(reviewer fills)

## Completion Evidence

(orchestrator fills at closeout)

## Handoff

§28 format; end with the marker `HANDOFF-COMPLETE TASK-037`.
