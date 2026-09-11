# TASK-038 — Settings + rename + erase-all-data (FR-19; UX §1.2 S6; size M)

## Parent Epic

EPIC-007 — iPhone Home Experience (`.claude/tasks/epics/EPIC-007-iphone-home.md`), task 8 of 9.

## Objective

The third and last placeholder falls: the Settings tab becomes the real FR-19 surface — rename (S6.1), haptics on/off, Erase all data with the S6.2 system-alert confirmation (FR-19 AC-2: store deleted → onboarding, fresh), and About (version + short privacy statement) — with EXACTLY that inventory and NOTHING else. Rename and haptics flow through the app-model plan core as new pre-engine triggers (the `onboardingCompleted` precedent); erase is the launch-path-symmetric store-lifecycle operation.

## Context

- Placeholder today: `Apps/Momo/PlaceholderSettingsView.swift` hosted at `Apps/Momo/RootTabView.swift:17` (the tab label is already catalogized — TASK-037's `momo.tab.settings`).
- **Spec sources (read them):** PRD FR-19 `docs/product/02-mvp-prd.md:367-370` (inventory + MUST-NOT list + AC-1/2/3); UX `docs/design/03-ux-architecture.md` — §2 :103 (flat IA: no push navigation; the erase alert is THE ONLY modal in the product), §9 :417 (the exact S6.2 alert copy — VERBATIM below), §10 :436-438 (a11y: native list rows, field labeled/value announced/Save labeled, destructive erase clearly traited, erase = system alert); 04-character-system §11 (haptics: the only audio-adjacent surface — there is NO sound system in Phase 1).
- **Sound toggle ADJUDICATED ABSENT:** FR-19 ships the sound row "present only if Phase 1 ships any audio — audio scope is decided by TASK-005; otherwise the toggle is omitted" (PRD :367; UX :480). TASK-005/04 §11 shipped no audio system ⇒ the toggle is omitted. This is the doc's own conditional resolving to absent — record it in the view header, do not invent a sound row.
- **Banked pre-read (verified by the orchestrator 2026-09-11):**
  - Plan-core dispatch: `Sources/MomoKit/AppModelPlan.swift:189` dispatches `.onboardingCompleted` BEFORE engine routing; `onboardingPlan` (:281-320) rebuilds `EngineState` preserving all other fields and guards `Pet(id:name:createdAt: foldInstant)` (nil ⇒ identity plan). Its doc (:281-286) states the division of labor: the executor trims + rejects at the tap (UI disables the button), the plan core RE-HONORS INV-1 (defense in depth).
  - INV-1 is TYPE-LEVEL: `Pet.init?(id:name:createdAt:)` (`Sources/MomoCore/Pet.swift:29-38`) trims and rejects whitespace-only names — an invalid name is unrepresentable.
  - `MomoAppModel` (`Apps/Momo/MomoAppModel.swift`): `requiresOnboarding` is DERIVED (`:128`, `!state.settings.onboardingComplete`) — erase needs NO new routing flag; the init resolves the store directory at `:316-320` into a LOCAL (only `SnapshotStore` retains it — erase needs the directory retained); `freshDefaultState(clock:)` is the private static fresh construction at `:866-884` (pet "Momo"/new UUID, `SettingsState(onboardingComplete: false, hapticsEnabled: true)`, empty days); a fresh install persists NOTHING until the onboarding completion write (the first write, atomic at the tap — TASK-032).
  - `SnapshotStore` (`Sources/MomoKit/SnapshotStore.swift`) has NO delete API — public surface is init/save/load. `SyncStateStore` is NOT app-wired (zero app-target references). Erase is therefore DIRECTORY-level.
  - Haptics gate (TASK-036): moment haptics deliver through the injected sink at the app model's `.deliverMoments` arm, gated on `state.settings.hapticsEnabled` at delivery time — the toggle takes effect on the next delivery by construction.

## Requirements

### R1 — Settings surface (native list, exact inventory)

NEW `Apps/Momo/SettingsView.swift` replaces the placeholder (DELETE `Apps/Momo/PlaceholderSettingsView.swift`; pbxproj both directions in the SAME list slots, deterministic-ID scheme — verify IDs free before landing; `RootTabView` hosts `SettingsView()`). Native `List`/`Form` (UX :436 — native rows give 44 pt + Dynamic Type + VoiceOver by construction) containing EXACTLY:

1. **Rename** (R2-R3) — inline labeled `TextField` pre-filled with the current name + a `Save` button.
2. **Haptics** (R4) — native `Toggle`.
3. **Erase all data** (R5) — a row styled destructive (`.role(.destructive)`) opening the system alert.
4. **About** (R6) — version + short privacy statement.

NO sound toggle (adjudicated absent, header-recorded). NO account/sign-in, notification, HealthKit, or monetization/purchase rows (FR-19's MUST-NOT list — enforced by the R8 guard). D12: every string via catalog keys through `MomoCopyText.render`; zero user-facing literals. The view header records the inventory adjudications (sound-absent rationale; the S6.1-inline rationale below).

### R2 — S6.1 rename renders INLINE (disclosed adjudication)

The UX IA tree (:46) calls S6.1 a "sub-screen", but §2's flat-IA law (:103) bans push navigation AND names the erase alert "the only modal in the product". Therefore S6.1 renders INLINE on the Settings list — no NavigationStack push, no sheet (either would violate :103). Standard keyboard flow (UX :437): field labeled ("Pet name" per S1's convention), current value announced, Save labeled. Save disabled when the trimmed field is empty (UI-level rejection per the :281-286 division of labor); on success the field shows the current name. No success/failure announcement exists (rename is silent — the name simply changes everywhere).

### R3 — Rename through the plan core (pre-engine trigger)

NEW trigger `.petRenamed(petID: UUID, name: String)` dispatched BEFORE engine routing (the `onboardingCompleted` precedent):
- Guard `petID == state.pet.id`, else identity plan (grants nothing — a rename aimed at a pet that isn't this one is a no-op).
- Rebuild the pet: `Pet(id: state.pet.id, name: name, createdAt: state.pet.createdAt)` — identity (id + createdAt) preserved; the INV-1 failable init trims + rejects — nil ⇒ identity plan (the plan core re-honors; the Save button is the first gate).
- New state preserves EVERYTHING else (whole-`EngineState` field-for-field). Persist-IFF-changed (a rename to the identical name ⇒ `changed == false` ⇒ no write); response nil; moments empty; push-IFF-changed per the fixed §4.1 order (the snapshot carries the new name; the push seam itself stays the documented EPIC-008 no-op — "Watch after sync" is FR-19 AC-1's sync half, owned by EPIC-008/TASK-044; HOME reflection is this task's scope and is automatic: every read-model reads `state.pet.name`).
- Expose the executor-side convenience (e.g. `renamePet(to:)`) on the app model; views never touch `AppModelPlan` directly (D-R5).

### R4 — Haptics toggle through the plan core (pre-engine trigger)

NEW trigger `.hapticsToggled(enabled: Bool)`: rebuild `SettingsState(onboardingComplete: state.settings.onboardingComplete, hapticsEnabled: enabled)` preserving everything else; persist-IFF-changed; no engine routing (settings-only). The `Toggle` binds through the app model (get: `state.settings.hapticsEnabled`, set: apply the trigger). Effect is immediate: the TASK-036 sink gate reads the flag at delivery time — verify that wiring still holds and say so in the task notes (extend, don't duplicate, TASK-036's sink-gating tests if a package pin is needed).

### R5 — Erase all data (FR-19 AC-2) — launch-path-symmetric, executor-level

`MomoAppModel.eraseAllData()` — an EXECUTOR-LEVEL store-lifecycle operation, NOT a plan-core trigger. Adjudication (record it in the method's doc comment): an `.allDataErased` plan that re-persists after deletion would (a) leave the pre-erase bytes in SnapshotStore's `prev`/`prev2` rotation, failing AC-2's "deletes every local store", and (b) resurrect a store where a fresh install has none — failing NFR-7's fresh-install indistinguishability. Therefore:

1. **Retain the directory:** the init's resolved `directory` (:316-320) becomes a retained `let` so erase deletes EXACTLY the directory the running store uses — the `-momo-store-directory` override honored (the UI-test enabler, `MomoApp.swift:226-245`), never a hardcoded path.
2. **Delete first:** remove the store directory tree (`FileManager`, idempotent if already absent). Crash-window: between delete and the state swap, a crash lands on the store's fresh fallback — the correct landing (FR-13's invisible recovery).
3. **Swap in memory:** cancel the boundary task, reset the reaction director (and ANY other transient app-model presentation state — enumerate them in the notes: moment FIFO / line-retention memory / etc.) to post-init values, then set state = `freshDefaultState(clock:)` — the SAME factory the init path uses (single-sourced; erase and fresh-install are indistinguishable).
4. **No persist.** The first write remains the onboarding completion write. `requiresOnboarding` (:128) routes to onboarding with zero new machinery.
5. **Watch:** the push seam stays a no-op; the snapshot resets at its next sync — the full E2E is TASK-044 (do not build transport).
6. **UI:** the Erase row opens the SYSTEM alert (`.alert` — the product's only modal, UX :103/:438) with the EXACT S6.2 copy: title "Erase everything?" is part of the UX message line — land the catalog strings so the assembled alert reads verbatim: "Erase everything? This deletes {name} and all memories on this iPhone; {name}'s Watch snapshot resets at its next sync. This can't be undone." with buttons **Erase** (destructive role) and **Keep {name}** (cancel). The name interpolates TWICE — use a positional `%1$@` template (both placeholders reference argument 1). Keep ⇒ nothing at all happens (store untouched). Confirm ⇒ `eraseAllData()` ⇒ S1.

### R6 — About

Version row: the app's `CFBundleShortVersionString` (a system VALUE read via `Bundle` — data, not copy; the D11/CopyRules carveout does not apply to non-copy values; the label string itself is catalogized) + the short privacy statement. In-contract draft (≤ 12 words — the copy law scans it as body copy; calm register): **"Everything stays on this iPhone. Nothing about Momo ever leaves."** — land this verbatim as a catalog key; do not alter without disclosing the delta. It restates D7/D19/FR-20 (Data Not Collected) without naming them.

### R7 — Catalog landing: `momo.settings.*` keyspace, FIXED lookups, NO epoch bump

NEW `Sources/MomoKit/SettingsCopyKeys.swift` (type-safe key builders, the `HomeCopyKeys`/`RoomCopyKeyTests` precedent) + the catalog entries (~12 keys — draft the exact set: row labels rename/haptics/erase/about; field label + Save; alert title/message/confirm/cancel with the message as the `%1$@` template; version label; privacy statement; any VoiceOver-only labels you add). ALL settings keys are FIXED lookups (the `momo.line.moment`/`momo.tab.*` precedent) — **NO `copyEpoch` bump** (no variational pool changes; the epoch-4 residue pins stay verbatim: slots `.07`, touch `.02`, pools `.01`, `CareInteractionTests` `.04`/`.01`). Catalog counts pinned in the scaffolding tests (current total 103 → 103 + your count; the `.00` placeholder index stays reserved; sort order preserved). The 12-word law scans the privacy statement (body copy); row labels are chrome (disclose which keys you place outside the law and why, tab-label precedent).

### R8 — Structural guard: the inventory red line (RigDiscipline family)

NEW guard in `Tests/MomoCharacterTests/RigDisciplineTests.swift` reading `Apps/Momo/SettingsView.swift`:
- **Absence (the FR-19 MUST-NOT enforcement):** after stripping `///`+`//` comment lines (a DISCLOSED family first — the guard's own header prose legitimately discusses the forbidden concepts, so raw-text scanning would self-trip; keep the strip simple and pin it), the remaining source must contain NONE of: `account`, `sign in`, `signIn`, `notification`, `healthKit`/`HealthKit`, `purchase`, `subscription`, `sound` (case-insensitive).
- **Presence:** the settings-key constants for all four inventory groups + `.role(.destructive)` (or equivalent destructive construction) + the alert modifier.
- Family practice: SOME-legs fixtures both directions (non-vacuity pinned), and a second guard (or the same test) reading `Apps/Momo/MomoAppModel.swift` pinning `eraseAllData`'s ORDER — the directory deletion (`removeItem` or the chosen removal call) appears BEFORE the `.allDataErased`-era swap — plus the `freshDefaultState` reuse. Mutation-bite your own guards before handoff and record the bites.

### R9 — Accessibility (FR-19 AC-3)

Native list carries VoiceOver + Dynamic Type by construction (UX :436-438): field labeled + value announced + Save labeled; Erase clearly destructive-traited; the erase alert is a system alert (correct traits automatic). No custom a11y work beyond labels/identifiers — but set stable accessibility identifiers for the UI tests (e.g. `settings.name.field`, `settings.name.save`, `settings.haptics.toggle`, `settings.erase.row`, `settings.about`) under the `settings.` namespace (the `room.` precedent).

## Files / Areas Likely Affected

- NEW `Apps/Momo/SettingsView.swift`; DELETE `Apps/Momo/PlaceholderSettingsView.swift`; `Apps/Momo/RootTabView.swift` (host); `Apps/Momo/MomoAppModel.swift` (retained directory; rename/haptics/erase executor methods — **check the ≤ 800-line budget first: `MomoAppModel.swift` is the largest app file; if the additions would push it near/over ~750, extract the settings executor surface to `MomoAppModel+Settings.swift` (same-target extension) and disclose**)
- `Sources/MomoKit/AppModelPlan.swift` (two new triggers + plans, dispatched before engine routing)
- NEW `Sources/MomoKit/SettingsCopyKeys.swift`; `Apps/Shared/MomoCopy.xcstrings` (+settings keyspace)
- `Momo.xcodeproj/project.pbxproj` (SettingsView in, placeholder out, `MomoSettingsUITests.swift` in — all four sections, deterministic IDs)
- `Tests/MomoKitTests/AppModelPlanTests.swift` (+trigger tests); NEW `Tests/MomoKitTests/SettingsCopyKeyTests.swift`
- `Tests/MomoCharacterTests/MomoCatalogScaffoldingTests.swift` (+settings grammar/counts/verbatim), `Tests/MomoCharacterTests/CatalogCopyLawTests.swift` (+privacy statement in the law scan), `Tests/MomoCharacterTests/RigDisciplineTests.swift` (+R8 guards)
- NEW `MomoUITests/MomoSettingsUITests.swift`

## Dependencies

TASK-031 (the facade/apply loop), TASK-032 (onboarding flow + the `-momo-store-directory` enabler), TASK-022 (the delete+fresh store path this task exercises at the app layer). EPIC-004 stays frozen (the plan core ADDS pre-engine triggers — the `onboardingCompleted` precedent; no `reduce` semantics change). `Sources/MomoCharacter/` is a no-touch wall. `Sources/MomoCore/` is expected diff-empty (no epoch, no CopyRules, no new domain types) — ANY touch is a disclosed carveout.

## Constraints

- No epoch bump; no engine semantics; no Watch code; no notifications/accounts/HealthKit (red lines, guard-enforced).
- §26: zero TODO/FIXME/HACK/TEMP debt. Zero warnings from touched files. Swift 6 strict concurrency clean.
- The S6.2 alert copy and the About privacy statement are VERBATIM in-contract strings — land them exactly (catalog conventions: U+2019 apostrophes, `%1$@` positional templates).
- Do not add persistence for the erase path; do not add a store-delete API to `SnapshotStore` (directory-level is the design; a store API would be dead code).
- Mid-cycle discipline: no git commits/pushes/branch ops; no .md edits beyond this task file; status.md/epic untouched (orchestrator's).

## Acceptance Criteria

1. Settings shows EXACTLY rename · haptics · Erase all data · About — the R8 guard proves the red line structurally, and the UI census proves it on glass.
2. Rename flows: Save → Home reflects the new name immediately (canvas label + status line), Room label re-interpolates, pet id + createdAt unchanged, whitespace-only Save disabled, plan-core rejection paths identity.
3. Haptics toggle persists through the plan core, preserves `onboardingComplete`, and gates the next moment delivery.
4. Erase: alert verbatim (both name interpolations), Keep = no-op, Erase ⇒ store directory GONE (runner-side filesystem assertion), app on S1 fresh; complete onboarding again ⇒ clean Home; kill-and-relaunch after erase stays onboarding (the persisted pre-erase store would resurrect the old pet — the discriminating glass evidence).
5. Package suite green with the new plan-core/copy/guard tests; NO epoch movement; frozen walls diff-absent.

## Required Tests

- **Package (MomoKitTests):** rename plan (happy: whole-state field-for-field + id/createdAt stability; petID mismatch ⇒ identity; whitespace-only ⇒ identity via the TYPE-LEVEL init; identical name ⇒ `changed == false`); haptics plan (flip + preservation + whole-state); the settings copy-key pins (the `RoomCopyKeyTests` shape: constants verbatim, the `%1$@` message formats with the current name, exhaustive key inventories against the SHIPPED catalog).
- **Package (MomoCharacterTests):** scaffolding counts + verbatim pins for every new key; the law scan over the privacy statement; the R8 guards with two-direction fixtures.
- **UI (new `MomoSettingsUITests`, fixture-store landing like TASK-037's room test):** (1) inventory census — the four groups present, zero forbidden rows (namespace-scoped census + tab-bar non-vacuity, the TASK-037 N-2 shape); (2) rename flows to Home + Room labels; (3) alert copy verbatim + Keep cancels; (4) the erase roundtrip incl. the runner-side `FileManager` existence check on the `-momo-store-directory` path (deleted, not merely overwritten) and the re-onboarding completion; (5) relaunch-after-erase lands on S1 (terminate + launch, the TASK-032 precedent).
- §19 gate (orchestrator): `swift test`; the FULL UI suite on the pinned iPhone SE `1F25E487-A78E-464C-95AF-0BD1A9B3E1BE`; `MomoWatch` build on the pinned Watch SE 3 (44mm) `8A854895-225C-411B-89C1-B03337BFE957`; zero warnings. Run the app-target BUILD before claiming UI results (the TASK-036 BUILD-before-claim lesson).

## Review Requirements

Fresh independent §10/§33 reviewer (not primed): re-derive FR-19 + UX S6 from the docs BEFORE comparing; verify the R3/R4 trigger plans against the `onboardingCompleted` precedent; bite the R8 guards (incl. one negative probe of the reviewer's own design — standing practice); verify the erase ordering + no-persist adjudication against the stale-prev/NFR-7 reasoning; catalog verbatim + interpolation + banned-vocabulary coverage; epoch-4 residue pins verbatim; pbxproj both directions; §25 disclosure audit.

## Git Requirements

Atomic commit (§12): `feat(settings): TASK-038 settings — rename, haptics, erase-all-data, about` — the implementation, the review record, and the task file ride ONE commit; push per §13; the orchestrator closeout follows.

## Status

READY (2026-09-11) — contract authored from the fully banked pre-read; fresh implementation agent dispatching.

## Implementation Notes

(implementation agent fills)

## Reviewer Findings

(reviewer fills)

## Completion Evidence

(orchestrator fills at closeout)

## Handoff

Use the §28 format; end with the marker `HANDOFF-COMPLETE TASK-038` on its own line at line start.
