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

IN_REVIEW (2026-09-11, implementation complete; all six gates green — see Handoff; awaiting the independent §10/§33 review).

## Implementation Notes

- **R1 adjudication recorded in the view header** (`Apps/Momo/RoomView.swift`): Momo (the rig) is NOT rendered — Home owns the live rig; duplicating it would add composition + motion surfaces for zero product value; the pom string/puff decor is the room's companion presence. The header also records "static means static" (no Reduce Motion substitution owed — a static scene has no loop to pause) and the no-state/no-customization law.
- **R4 key names + namespace disclosure:** the scene label + caption landed as `momo.line.room.01`/`.02` FIXED lookups (the `moment.01` numbered-fixed-lookup precedent; 00-index stays reserved for placeholders). The three tab labels warranted their OWN chrome namespace, `momo.tab.home|room|settings` (R4's sanctioned option) — one-word chrome labels, distinct in class from body copy; the copy law's 12-word scanner deliberately does NOT scan them (they are not body copy). `room.01` is a `%1$@` positional TEMPLATE (one placeholder, name-interpolated — locale-correct reordering). HomeCopyKeys gained `roomSceneLabelTemplateKey`, `roomCaptionKey`, a `Tab` enum (CaseIterable), and `tabLabelKey(for:)` (exhaustive switch, no default — a new tab must name its key to compile), plus the header bullet documenting the keyspace. NO epoch bump; `CopyRules`/`LineSelection` untouched; epoch-4 residue pins untouched and green.
- **Token mapping** (no new hex — hex stays confined to the palette files): floor → `MomoUIColors.surface`, rug → `MomoCharacterPalette.blanket`, window frame → `MomoUIColors.accent`, pom string → `furShade`, pom puff → `furBase`. Rendered via the `Canvas` + `context.fill(path, with: .color(token.resolve(colorScheme)))` idiom (MomoRigView precedent), aspect-preserving `min(w,h)/gridSide` scale in the 1000×1000 design space (the `RigCanvas.gridSide` convention). The window's counter-wound opening stays a hole under the nonzero fill rule.
- **R3 construction:** the scene Canvas region is flattened `.accessibilityElement(children: .ignore)` + `.accessibilityAddTraits(.isImage)` + the composed label + identifier `room.scene`; the caption is its own `Text` element (`room.caption`); the whole tab surface is one `.accessibilityElement(children: .contain)` container (`room`) — the HomeView region pattern, queryable in XCUITest. SwiftUI type scaling handles the caption's Dynamic Type; the scene scales with its region.
- **R5 guard:** `RigDiscipline.roomInteractiveTokens` (8 tokens: Button(, .onTapGesture, .gesture(, .highPriorityGesture(, .simultaneousGesture(, allowsHitTesting(, LongPressGesture, DragGesture) + `roomInteractiveViolations(in:)`, and `mentionsRoomSceneAccessibility(in:)` (requires all three legs: `.ignore` + `.isImage` + `.accessibilityLabel(`). One @Test reads `Apps/Momo/RoomView.swift` via the family's `readRigFile` and pins BOTH directions with SOME-legs fixtures: one-element construction wrapping a Button (a11y right, interactivity not — the interaction scan fires), and an interaction-free canvas flattened only as a container (no ignore/trait/label — the presence check fails).
- **DISCLOSED small addition (R7's "if R4's key access warrants it"):** new `Tests/MomoKitTests/RoomCopyKeyTests.swift` (4 tests) — the KIT-side half of the copy gluing: the accessor constants pinned verbatim, the `Tab` domain pinned exhaustive, and the composition pin resolving `roomSceneLabelTemplateKey` against the SHIPPED catalog file (via the target's existing `KitRepo.repoRoot` anchor — the headless target cannot reach the app bundle's compiled copy) and proving `String(format: template, "Momo") == "Momo’s cozy room"`. SwiftPM test targets are path-based — no pbxproj registration needed.
- **UI-test zero adaptation (disclosed):** the contract's `app.buttons.count == 0` cannot hold screen-wide — the tab bar always carries 3 buttons. The zero is scoped to the room namespace (`app.buttons.matching(identifier BEGINSWITH "room.").count == 0`) with non-vacuity proven alongside (`app.tabBars.buttons.count == 3` on the same screen). Also asserted: one `room.scene` element, label exactly "Momo’s cozy room" (U+2019), caption verbatim, no alerts. Uses the `stage-crossing` fixture store only for its fast onboarding-complete landing — a static scene reads no care-loop state.
- **One compile fix during Gate 2 (§20 root-caused, not blind-patched):** `RoomSceneLayout.Layer` was declared `private struct`, narrower than the `layers(colorScheme:)` function returning `[Layer]` ("method must be declared private because its result uses a private type"). Fix: drop the redundant `private` — the enclosing enum's `private` caps both to file scope. Comment added in place.
- **Banned vocabulary + 12-word law:** the standing scans auto-cover the new values (they walk all stringUnit values); the caption "Somewhere soft to come home to." passes both. Copy-law scanned count pinned 71 → 73 (the two room lines are visual-class lines; the tab labels are chrome, not scanned); catalog total pinned 98 → 103 with the room/tab classes enumerated in the fixed-lookup grammar list and the five entries pinned VERBATIM (new `catalogCarriesTheRoomLinesVerbatim`).
- **pbxproj:** deterministic-ID scheme maintained — RoomView.swift registered as `8A4000000000000000000054`/`8A5000000000000000000054` (IDs verified free) in all four sections; the four `…0004` PlaceholderRoomView lines removed in place (same list slots).

## Reviewer Findings

(reviewer fills)

## Completion Evidence

(orchestrator fills at closeout)

## Handoff

### Completed

All seven requirements R1–R7 implemented; all six acceptance criteria satisfied and gate-proven. Room tab is the real static scene; placeholder deleted; D12 tab labels catalogized; copy law + scaffolding + discipline + kit + UI pins extended.

### Files Changed

- NEW `Apps/Momo/RoomView.swift` (static scene, one a11y image element, R1 adjudication header)
- DELETED `Apps/Momo/PlaceholderRoomView.swift`
- `Apps/Momo/RootTabView.swift` (hosts RoomView; three tab labels via `HomeCopyKeys.tabLabelKey`; header updated)
- `Apps/Shared/MomoCopy.xcstrings` (+5 entries: room.01/.02, tab.home/room/settings; sorted; Xcode JSON format preserved)
- `Sources/MomoKit/HomeCopyKeys.swift` (room/tab keyspace: 2 fixed keys, `Tab` enum, `tabLabelKey(for:)`, header bullet)
- `Momo.xcodeproj/project.pbxproj` (register RoomView `…0054`, remove PlaceholderRoomView `…0004`, 4 sections)
- `Tests/MomoCharacterTests/RigDisciplineTests.swift` (R5 room guard + two-direction fixtures)
- `Tests/MomoCharacterTests/CatalogCopyLawTests.swift` (room class in scan; 71 → 73)
- `Tests/MomoCharacterTests/MomoCatalogScaffoldingTests.swift` (room/tab grammars; counts 2/3/total 103; 5-entry verbatim pin)
- NEW `Tests/MomoKitTests/RoomCopyKeyTests.swift` (4 kit-side key/composition pins)
- `MomoUITests/MomoHomeUITests.swift` (TASK-037 room test)

### Tests Run

1. `swift test` (full package)
2. `xcodebuild test -project Momo.xcodeproj -scheme Momo -destination 'platform=iOS Simulator,id=1F25E487-A78E-464C-95AF-0BD1A9B3E1BE'`
3. `xcodebuild build -project Momo.xcodeproj -scheme MomoWatch -destination 'platform=watchOS Simulator,id=8A854895-225C-411B-89C1-B03337BFE957'`
4. Warning scan over the app build + SwiftPM build, scoped to touched files
5. `git status --porcelain` + diffstat; TODO/FIXME/HACK/TEMP marker scan over touched files

### Test Results

1. **PASS — 931 tests in 95 suites** (baseline 925/94: +6 tests = 4 RoomCopyKeyTests + 1 R5 room guard + 1 scaffolding room-verbatim; +1 suite). One intermediate RED during development, root-caused and fixed before gates (the composition pin initially formatted the raw KEY; fixed to resolve the TEMPLATE from the shipped catalog — see Implementation Notes).
2. **TEST SUCCEEDED — 22/22** (16 prior Home + new `testRoomTabShowsTheStaticSceneWithZeroInteractivity` + 4 onboarding + 1 launch; the room test passed in 10.6 s).
3. **BUILD SUCCEEDED** (MomoWatch; only the pre-existing environment warnings).
4. **Zero warnings from touched files** (only pre-existing environment noise: `ld: search path '/opt/extra/lib' not found`, appintents metadata note — present on every build).
5. **Working tree = exactly the task surface** (9 tracked modifications/deletions + 2 new files above; nothing stray). Marker scan clean ("TEMPLATE" prose matches only).

### Known Issues

None. No TODO/FIXME/HACK/TEMP debt added. No state, no animation, no clock, no director touch in the room.

### Decisions Made

- `momo.tab.*` chrome namespace for the tab labels (R4's sanctioned own-namespace option; disclosed above).
- Scene label = `momo.line.room.01` positional `%1$@` TEMPLATE; caption = `momo.line.room.02` (U+2019 apostrophe per catalog convention).
- Token mapping disclosed above (surface/blanket/accent/furShade/furBase — no new hex).
- Zero-buttons assertion scoped to the room namespace with tab-bar non-vacuity (disclosed above).
- Momo not rendered in the room (the contract's own disclosed adjudication, recorded in the view header).

### Reviewer Status

PENDING — fresh independent §10/§33 review owed; record at `.claude/tasks/reviews/REVIEW-TASK-037.md`. Reviewer note: the R5 guard bites (two-direction SOME-legs fixtures); epoch-4 residue pins untouched (no CopyRules/LineSelection edits in the diff); the wall files (MomoCharacter/MomoCore/MomoKit-engine/Watch) are diff-absent.

### Commit

NONE — orchestrator commits after review (per dispatch order). Suggested message in Git Requirements holds.

### Push

NONE — nothing committed; nothing to push.

### Recommended Next Step

Spawn the fresh review agent for TASK-037 (requirements R1–R7, no-touch walls, epoch pins verbatim, guard-bites check, catalog interpolation/banned-vocab audit, a11y construction, §25 disclosure audit); on APPROVED, commit `feat(home): TASK-037 room tab — static scene, single a11y element, D12 tab labels` and push per §13.

HANDOFF-COMPLETE TASK-037
