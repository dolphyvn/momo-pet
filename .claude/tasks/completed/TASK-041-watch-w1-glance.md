# TASK-041 — MomoWatch W1 glance + snapshot persistence + AOD

## Parent Epic

EPIC-008 — Watch App & Sync (`.claude/tasks/epics/EPIC-008-watch-sync.md`), task 2 of 5.

## Objective

MomoWatch leaves its placeholder shell and becomes **W1** — the one glanceable surface (UX §6.1) that renders the last-synced `WatchSnapshot` instantly from local storage: mood in words + bond stage word + the single quest line + the pat targets, the LOD-glance rig animating in the foreground and the STATIC glyph in AOD. The Watch side of the sync grows its receive half: a duplicated transport twin (ADR-013) receives the iPhone's context, the snapshot persists to `watch-snapshot.json` (+ one `.prev`) on every receive AND every background transition (05 §5.6), and the §6.6 reset-marker consumption wipes the Watch's snapshot store when the iPhone's erase marker arrives. Pre-first-sync (and post-wipe), W1 shows the calm settling-in line. The Watch runs NO engine (ADR-003, EPIC-008 AC-5): it renders what the iPhone issued through the shared pure derivations — it derives nothing itself.

## Context

- TASK-040 (complete, `0719129`) built the iPhone half: latest-wins context push through the reserved `.pushWatchSnapshot` seam via `WatchSnapshotBuilder.makeWatchSnapshot`, the intent receive path, the §6.6 reset-marker producer leg (erase writes the marker OUTSIDE the store tree via `StoreRules.watchResetMarkerDirectory()`; it rides every context while non-zero), and the WC VERIFY-AT-BUILD record. The context the Watch will receive is exactly what TASK-040 ships.
- The Watch target (`Apps/MomoWatch/`) is today a three-file placeholder shell (`MomoWatchApp.swift`, `PlaceholderGlanceView.swift`, `Info.plist`) with one UI smoke test (`MomoWatchUITests/MomoWatchUITests.swift`). It already links MomoCore + MomoCharacter + MomoKit (pbxproj Frameworks phase; never the `Momo` app target — D-R3).
- **The character-render gap is adjudicated — ADR-014 (this contract's authoring decision, binding):** the rig consumes `CharacterDisplayState`, whose moodBand/energyBand/activity/satietyHint fields ride nowhere in `DisplayState`. The snapshot gains an additive-OPTIONAL `character: WatchCharacterDTO?` field (exactly those four fields), built iPhone-side from the SHARED `makeCharacterDisplayState(state)`; a pure MomoKit assembly function (`DisplayState` + DTO → `CharacterDisplayState`) is W1's render input; `decodeIfPresent`/`encodeIfPresent`, NO `schemaVersion` bump, OBS-3 not fired; nil → text-only degraded render (words + quest), DEBUG-loud, never a crash or error surface. Do NOT re-litigate this in implementation; deviations surface in review.
- **Inherited review routings (binding):**
  - **O4 (REVIEW-TASK-025 OBS-4)** — the glyph's legibility must be re-judged at TRUE 24–32 pt on W1/AOD (RigLOD.glyphStagePoints), not the debug canvas's large scale. This task closes O4 by recording the judgment.
  - **OBS-1 (REVIEW-TASK-024, app-layer leg)** — the launch read is the ONE sanctioned synchronous main-thread read (KB-scale); the receive/background paths must not block the main actor with I/O beyond it.
  - **F-2 (REVIEW-TASK-039)** — the owner's pending "You two are {stage}." copy decision gates the state-in-words template's final WORDING only, never this task's start: pin the SHIPPED strings verbatim now (the TASK-039 pattern); when the owner decision lands, only the pinned wording changes.
  - **F-3 (REVIEW-TASK-040)** — the Watch-side journal self-defense note: the reset-marker consumption design must document how the Watch avoids being wedged by a marker/journal disagreement. The journal itself does not exist until TASK-042 — address the note in the consumption design's reasoning and code comments, and leave the journal-wipe leg explicitly wired-for (TASK-042 completes it).
- Normative sources: `docs/architecture/05-technical-architecture.md` §5.6 (Watch stores), §6.2 (payloads), §6.3 (freshness — render local instantly, no staleness UI ever), §6.6 (reset-marker consumption row); `docs/design/03-ux-architecture.md` §6.1 (W1 layout), §6.4 (offline), §6.5 (AOD + background-transition persistence), §9 (settling-in line, no-failure-surfaces), §10 (W1 accessibility row — the VoiceOver composite); FR-17 (02-mvp-prd), NFR-9/TR9; ADR-003, ADR-013; ADR-014 (above).

## Requirements

- **R1 — Character read-model on the wire (ADR-014):** additive-OPTIONAL `character: WatchCharacterDTO?` on `WatchSnapshot` (MomoKit, hand-written Codable per the existing DTO discipline: explicit CodingKeys, `decodeIfPresent`/`encodeIfPresent`, strict `schemaVersion ==` gates untouched, no bump). `makeWatchSnapshot` gains the threading parameter; the iPhone executor (`MomoAppModel+Watch.swift` — MomoAppModel.swift stands at exactly 800/800, NOTHING may be added to it) derives the DTO from `makeCharacterDisplayState(state)`. A pure, headless-testable MomoKit assembly function maps (DisplayState, WatchCharacterDTO?) → CharacterDisplayState? (nil DTO → nil; momentRequest projected from `display.greeting` as `makeCharacterDisplayState` does). Decode-compatibility test: a pre-character fixture payload still decodes with `character == nil`.
- **R2 — WatchSnapshotStore (MomoKit):** the Watch's snapshot persistence per 05 §5.6 — `watch-snapshot.json` + ONE `.prev` generation (additive StoreRules file-name constants; watchOS resolves `StoreRules.defaultDirectory()` inside the Watch app's own container). Atomic writes, current→prev rotation, read path current → prev → nil (corruption/unrecoverable degrades to the settling-in line — warm, self-healing, no error surface). ONE production write path (the O1 one-writer rule) on a single serialized writer; headless-testable like every MomoKit store.
- **R3 — Transport twin (ADR-013):** a Watch-side duplicate of the transport pattern in `Apps/MomoWatch/` — app-target code, duplicated per target, plain over DRY. TASK-041's twin is RECEIVE-only: activation-completion + `didReceiveApplicationContext` context delivery surfaced through a sink the app binds BEFORE activation (the TASK-040 sink-before-activate discipline), plus `activate()`. NO send surface yet — TASK-042 adds the intent path; no dead code this task.
- **R4 — Watch receive path:** decode-or-skip (`WatchSnapshot.decoded(from:)` — garbled/future-version frames are skipped, logged, never an error surface) → latest-wins render + persist on EVERY receive (05 §5.6 normative) → ALSO persist on every background transition (scenePhase; TR9). The WC delegate callback arrives on WCSession's non-main serial queue: hop to the main actor for state, keep the file I/O on the serialized writer off the main actor — the ONLY synchronous main-thread read is the sanctioned KB-scale launch load (OBS-1). The Watch imports no engine semantics: it decodes, stores, and renders (AC-5).
- **R5 — Reset-marker consumption (the Watch leg of §6.6; completes the consumption design TASK-040 routed here):** the Watch store persists its consumed-erase-count. On receive: incoming `resetMarkerEraseCount` > consumed count → wipe the snapshot store (current + prev), render the settling-in line, record consumed = incoming; incoming ≤ consumed → a normal render (no re-wipe — the marker rides every context while non-zero by design). Decision logic as a pure MomoKit function (testable boundaries: first marker, repeat marker, newer marker, nil marker, count regression). The just-received context's display payload is discarded on a wipe (it is pre-erase state); the fresh pet renders at the next sync (WC re-delivers the latest context at activation — the settling-in period is one sync gap, per §6.6's row). F-3's self-defense reasoning (why a marker/journal disagreement cannot wedge the Watch) documented at the consumption site; the journal-wipe half is TASK-042's and is left explicitly wired-for, not stubbed.
- **R6 — The W1 view (UX §6.1, exactly):** status slot (mood word — the glance — + the compact bond-stage secondary); pet canvas (~40 % height, the `.glance` rig from the assembled CharacterDisplayState); quest line (the snapshot's `display.questLine` resolved through the existing `HomeCopyKeys` wish/all-done keys — DISPLAY-ONLY this task; the Watch-side re-cascade after pats is TASK-043; Q7 pat-completability claims are TASK-043); the Pat pill and the tappable canvas as ≥ 44 pt labeled pat TARGETS (capture/reaction is TASK-042 — inert this task, disclosed in the task notes, the placeholder precedent). Everything resolves through String Catalog keys via `MomoCopy`/`MomoCopyText` (INV-11 — no composed prose, no product-copy literals in view code); the W1 VoiceOver composite follows UX §10's row ("{name} feels {mood} and has {energy}. {Stage}. Today's wish: {wish}. Pat button."). Pre-first-sync: the calm settling-in line (UX §9) and nothing else — no error, no retry affordance.
- **R7 — AOD leg + O4 closure:** foreground = `.glance` tier via `RigLOD.tier(for: .watchForeground)`; luminance-reduced = `.glyph` tier (static — that branch never binds a clock), SAME assembled CharacterDisplayState, no Watch-side derivation. **O4 judgment owed:** render the glyph at true 24–32 pt on the W1 layout (a DEBUG-only, launch-argument-gated AOD-preview mode is the sanctioned evidence vehicle) and RECORD the legibility judgment + the chosen `stageSide` value in the task file's Implementation Notes. If the glyph fails legibility at true size, STOP that leg and record the finding — do not silently redesign the glyph or exceed the band. **§25 honesty:** Apple Watch SE (the pinned simulator/hardware class) has no always-on display, so runtime AOD observation is structurally unavailable — the evidence this task ships is the kit-level tier-mapping pins (existing), the new view-branch structural guard, and the true-size stills; live AOD observation on capable hardware routes to TASK-044's device obligations.
- **R8 — Copy + catalog law:** new W1 copy (the settling-in line "Momo is settling in — meet Momo on iPhone.", the pat pill's rendered label, any W1-specific slot) lands as catalog keys in `Apps/Shared/MomoCopy.xcstrings` under a Watch-appropriate namespace with `CopyKey.isInApprovedNamespace` extended accordingly; the banned-vocabulary scan must cover the new entries (CatalogCopyLawTests) and the shipped strings get verbatim pins (the TASK-039 scaffolding pattern — pin what actually ships). Existing vocab keys (mood words, energy phrases, stage names, wish lines, all-done) resolve unchanged through the shared catalog — no new entries for those. Catalog scaffolding inventory/count updates disclosed.
- **R9 — Structural guards:** extend the wiring-scan family over `Apps/MomoWatch` (comment-stripped text, named findings, the WatchWiringScan mechanism): (a) the receive path persists on every receive (the persist call present in the receive flow); (b) the Watch runs no engine (no engine-mutation/`reduce` tokens in `Apps/MomoWatch`); (c) the AOD branch binds the glyph tier. Each guard gets a mutation bite proving EXACTLY ONE test goes red, every mutation sha256-restored to byte-identical.
- **R10 — Tests + gates:** kit tests for the store (rotation, corruption recovery, one-writer seam), the character DTO (decode compatibility, assembly purity incl. the nil path), the marker-consumption decision boundaries, and builder threading; `MomoWatchUITests`: fresh-sim launch shows the settling-in line, and the restore ≤ ~2 s assertion using a DEBUG-only, launch-argument-gated fixture-seeding seam (disclosed; NO Release path), with the measurement semantics honestly documented (XCUITest launch overhead included in the notes). Final gates: `swift test` green (baseline 995 tests / 100 suites), MomoKit line coverage ≥ 80 % (currently 92.47 % — new kit code stays covered), MomoWatch BUILD SUCCEEDED zero-warning on the pinned Watch SE 3 44 mm `8A854895`, Momo app build green on the pinned iPhone SE `1F25E487`, MomoWatchUITests executed green on the pinned Watch sim, `git diff Sources/MomoCore/` EMPTY, MomoCharacter untouched.

## Files / Areas Likely Affected

- `Sources/MomoKit/` — `SyncDTOs.swift` (WatchCharacterDTO + character field), `WatchSnapshotBuilder.swift` (threading), `StoreRules.swift` (Watch store file-name constants), NEW `WatchSnapshotStore.swift`, NEW marker-consumption + assembly pure logic (placement per existing file conventions), new test files under `Tests/MomoKitTests/`.
- `Apps/MomoWatch/` — `MomoWatchApp.swift` (entry wiring), NEW W1 view file(s) (small, focused files per house rules), NEW transport twin, NEW receive/store application layer; `Momo.xcodeproj/project.pbxproj` (new-file registrations per the project's explicit-file-reference convention — TASK-040's 8A4x/8A5x ID pattern; **D-R3 re-check mandatory**: both app targets keep `dependencies = ()`).
- `Apps/Momo/MomoAppModel+Watch.swift` — the push arm threads the character DTO (derives it from `makeCharacterDisplayState`). **`MomoAppModel.swift` is at exactly 800/800 lines (REVIEW-TASK-040 F-8) — zero headroom; NOTHING lands in that file.**
- `Apps/Shared/MomoCopy.xcstrings` — new W1 keys. `Tests/MomoCharacterTests/` — catalog-law/pin extensions. `MomoWatchUITests/` — W1 suite. Structural guard extensions in `Tests/MomoKitTests/Support/` + `MomoWatchWiringScanTests.swift` (or a sibling suite per the existing convention).
- Frozen: `Sources/MomoCore/` (the assembly function lives in MomoKit, NOT MomoCore), `Sources/MomoCharacter/` (the rig API is consumed as-is), `docs/` (no normative-doc edits).

## Dependencies

- TASK-040 complete on this branch (`0719129` + closeout, pushed). TASK-026 (LOD tiers + clock pause), TASK-025 (glyph/glance constants), TASK-019 (DisplayState + cascade), TASK-023 (sync DTOs/logic) — all merged.
- ADR-014 (this contract); ADR-013 (duplicated packaging); ADR-003 (transport); ADR-006/ADR-008 (watchOS 26.0, `TARGETED_DEVICE_FAMILY = 4`).
- Pinned simulators: iPhone SE 3rd gen `1F25E487-A78E-464C-95AF-0BD1A9B3E1BE`; Watch SE 3 (44 mm) `8A854895-225C-411B-89C1-B03337BFE957` (watchOS 26.5).

## Constraints

- **Scope control (§22/§24):** R1–R10 exactly. NOT this task: pat capture/reaction/journal/`transferUserInfo`/`watchSessionEpoch` (TASK-042); the Watch-side quest cascade + settings/haptics-surface law (TASK-043); the §10.4 matrix + E2E + paired-hardware obligations (TASK-044); widgets/complications; any Watch settings surface (UX-13); performance-budget measurement beyond the restore assertion (TASK-045/EPIC-009). Discoveries route to the orchestrator as follow-ups, never silently implemented.
- **§27:** no new entitlements, capabilities, Info.plist keys, permissions, or network touches. No secrets. The WC transport stays device-to-device.
- **§26:** no unexplained TODO/FIXME/HACK/TEMP. The TASK-042/043/044 hand-offs are documented routings, not TODO comments.
- **§25:** no fake completion — the AOD/SE limitation and the UI-test fixture seam are DISCLOSED evidence scopes, never glossed as runtime proof.
- Immutability discipline; small focused files (200–400 lines typical, 800 hard); no `console`-class debug residue; DEBUG-loud logging pattern (`debugLoud`) for failure paths, per house precedent.

## Acceptance Criteria

1. `WatchSnapshot` carries `character: WatchCharacterDTO?` additively (no schema bump); the iPhone push derives it from `makeCharacterDisplayState(state)`; a pre-character payload still decodes with `character == nil`.
2. The Watch receives the context through its own transport twin (ADR-013 duplicate), decodes-or-skips, and renders latest-wins instantly from the local store; the store is `watch-snapshot.json` + one `.prev`, written on every receive AND every background transition; the store has exactly one production write path.
3. W1 renders mood in words + stage word + the single quest line + the pat targets from the snapshot; no numbers, no bars, no freshness indicator, no error surface, ever (UX-9/§6.4); the settling-in line shows pre-first-sync and after a marker wipe.
4. The reset marker consumes exactly once on the Watch (wipe → settle → consumed count recorded); repeat contexts with the same count do not re-wipe; a newer count wipes again; the F-3 self-defense reasoning is documented at the site.
5. Foreground renders the `.glance` rig; luminance-reduced renders the static `.glyph` from the SAME assembled CharacterDisplayState; no Watch surface ever binds the full rig (existing `RigLOD` pins hold); the O4 true-size judgment + chosen `stageSide` are recorded (or the legibility failure is recorded as a stop-and-escalate finding).
6. The Watch runs no engine: zero engine-derivation logic in `Apps/MomoWatch` (guard (b) green); the quest line is the snapshot's cascade output, display-only this task.
7. All W1 strings are catalog keys with verbatim pins + banned-vocab coverage; the W1 VoiceOver composite matches UX §10's template over the SHIPPED strings (F-2: owner wording delta lands later, wording only).
8. Restore ≤ ~2 s asserted in MomoWatchUITests (fixture-seeded, seam disclosed); fresh-sim launch shows the settling-in line; AOD static rendering is evidenced at the structural + true-size-still level with the SE limitation recorded (§25).
9. All gates green per R10; frozen surfaces untouched; D-R3 verified on the pbxproj diff; MomoAppModel.swift byte-identical (800/800).

## Required Tests

1. **MomoKitTests (new suites):** WatchSnapshotStore — rotation (current→prev), atomic-write recovery, corruption → prev → nil chain, one-writer seam; WatchCharacterDTO — decode compatibility fixture, assembly purity (incl. nil-character path, momentRequest projection); marker-consumption decision — first/repeat/newer/nil/regression boundaries; builder — character threading to the encoded payload.
2. **Structural guards:** the three new Watch-side scans, each with a bite (exactly one red, sha256-restored).
3. **MomoWatchUITests:** settling-in on fresh sim; fixture-seeded restore ≤ ~2 s (semantics documented); W1 content present (status, stage, quest line, pat targets reachable).
4. **Standing discipline:** import whitelist, banned vocabulary (now covering the new catalog entries), token purity, catalog scaffolding — all green with no new exemptions; the pre-existing 995-test baseline stays green.
5. **Coverage:** MomoKit ≥ 80 % line floor re-measured; new kit code covered.

## Review Requirements

- Independent §10/§33 review agent (fresh Jupiter session), NOT primed with implementation claims; the reviewer re-derives the spec from 05 §5.6/§6.2/§6.3/§6.6, UX §6/§9/§10, FR-17, NFR-9, ADR-003/013/014 BEFORE opening implementation files, then verifies every claim at source.
- Reviewer runs ≥ 2 of its own mutation probes (sha256-restored, byte-identical) in addition to re-biting the implementer's recorded bites; blind-spot hunting is mandatory (the TASK-040 Probe C lesson: store-level green ≠ wiring-level green — the reviewer must check the LAUNCH-LOAD and RECEIVE wiring legs the kit tests cannot see).
- Record under `.claude/tasks/reviews/REVIEW-TASK-041.md` with verdict APPROVED / APPROVED_WITH_MINOR_NOTES / CHANGES_REQUIRED / BLOCKED. CHANGES_REQUIRED/BLOCKED block commit (§10).
- §11 loop on findings: fresh fix agent for material corrections, fresh delta reviewer to verify, tests re-run — never self-approved.

## Git Requirements

- Branch `feature/EPIC-008-watch-sync`. The implementation agent does NOT commit (§9) — work stays uncommitted in the tree for review; the orchestrator commits after approval (§12: `feat(watch): TASK-041 <summary>`), pushes (§13), and updates status.md.
- One atomic task commit; no unrelated files; the diff inspected against §34's checklist before commit.

## Status

DONE — implemented 2026-09-11 (fresh Jupiter agent), independently reviewed (REVIEW-TASK-041: **APPROVED_WITH_MINOR_NOTES**, 0 Critical / 0 Major / 2 Minor / 2 Notes; F-1 DEBUG-loud nil-character log + F-2 "skipped vs held" wording routed to TASK-042's receive-path work; F-3 UX §6.1 "~40 %" doc-erratum → backlog; F-4 cosmetic nit, no action). All gates green over the final tree (1056/104; coverage 91.48 %; both builds zero touched-file warnings; UI suite 3/3; 4 probes sha256-restored byte-identical). Commit + push per the placeholders below.

## Implementation Notes

**(implemented 2026-09-11, fresh Jupiter agent; branch `feature/EPIC-008-watch-sync`, uncommitted for review per §9)**

### Delivered shape (R1–R10 map)

- MomoKit (new): `WatchCharacterDTO` + additive-optional `WatchSnapshot.character` (ADR-014, `decodeIfPresent`/`encodeIfPresent`, no schema bump), `makeWatchCharacterDisplay` assembly, `WatchSnapshotBuilder` character threading, `WatchSnapshotStore` (current + one `.prev`, atomic writes, current→prev→nil read chain), `WatchResetConsumption.decide` (pure), `WatchConsumedMarkerStore`, `StoreRules` Watch file-name constants.
- Apps/Momo (one-file touch): `MomoAppModel+Watch.swift` derives the DTO from `makeCharacterDisplayState(state)` in the push arm. `MomoAppModel.swift` untouched (verified 800/800 byte-identical).
- Apps/MomoWatch (new, per ADR-013 duplication): `MomoWatchTransport.swift` (receive-only WC twin, sink-before-activate), `MomoWatchAppModel.swift` (`@Observable` executor: decode-or-skip → §6.6 consumption → latest-wins render → persist; background-transition persist; DEBUG seams), `GlanceView.swift` (W1 four slots + settling-in + AOD tier branch + VO composite), `WatchCopyKeys.swift` (Watch-slot catalog keys, app-target internal), `MomoCopyText.swift` (plain catalog lookup).
- Tests: new MomoKit suites (store rotation/corruption/one-writer, DTO decode-compat + assembly incl. nil path, consumption boundaries first/repeat/newer/nil/regression, builder threading), `MomoWatchGlanceScanTests` + `WatchGlanceScan` (three structural guards with two-direction stub fixtures), catalog pins + law coverage for the new W1 keys, and the rewritten `MomoWatchUITests` (3 tests: settling-in-only fresh launch; fixture-seeded W1 content + ≥44 pt targets; restore-within-budget).

### O4 judgment of record (R7) — PASS; chosen stageSide: glance 68, glyph 28

`GlanceLayout.glanceStageSide = 68` (mid-band of `RigLOD.glanceStagePoints` 60–80) and `GlanceLayout.glyphStageSide = 28` (mid-band of `RigLOD.glyphStagePoints` 24–32). Evidence vehicle: DEBUG `-momo-aod-preview` launch over the pinned Watch SE sim renders the glyph branch full-screen; the evidence still is copied to `.claude/tasks/reviews/aod-preview-still-TASK-041.png`. Pixel-measured (not eyeballed): the glyph's rendered ink at 28 pt stage is ≈ 36 pt wide × 52 pt tall — the rig's sprite overflows its stage square at a consistent ~1.9× (foreground ink ≈ 88 × 130 pt at the 68 pt stage), and the ink clears a low luminance threshold even in the dimmed AOD render. The silhouette reads as the creature (rounded body; ears carry the "bunny" read). Honest caveats: the glyph is compact (~10–12 % of screen height) and ear detail compresses at this size. No STOP condition fired — per R7, no redesign of the glyph or the band was made or needed.

### Layout-share deviation record (UX §6.1 "~40 %" vs frozen §2.1 glance band)

UX §6.1 specifies the pet canvas at "~40 % of the screen height"; the frozen §2.1 glance stage band (60–80 pt) caps any glance stage at 80/448 ≈ 17.9 % of the Watch SE 44 mm's 448 pt screen. The two specs are arithmetically irreconcilable. This implementation pins the frozen band (the task contract and the `RigLOD` pins govern): stage 68 in a fixed `canvasHeight = 76` slot (stage + `MomoSpacing.small`), which also preserves the ≥ 44 pt canvas pat target and lets the AOD glyph center in an UNCHANGED slot — no layout jump at the luminance transition. The inaccurate "~40 %" doc comments that initially appeared in `GlanceView.swift` were corrected to state band governance (comment-only final edits). **For reviewer/orchestrator attention:** honoring §6.1's share would be a `RigLOD`/UX-doc decision, not a W1-code change; routed here rather than silently implemented (§22).

### Quest-line render — measured, not transcribed

Vision-model reads of the evidence stills repeatedly reported the quest line truncating ("Gentle pats — Momo…"); direct pixel-extent measurement disproved this. The quest `Text` renders ONE left-aligned line spanning ≈ 295 pt with ≈ 41 pt of right slack inside the ≈ 336 pt text container — the full catalog string "Gentle pats — Momo wouldn't mind some pats" fits untruncated (a truncated SwiftUI line always runs to its container's edge). `.lineLimit(2)` stays as the safety net for longer owner-approved copy; the full wish is also in the VO composite (UI-test-asserted).

### Observed cosmetic nit — recorded, not fixed (§22)

On the fixture still, the stack's ink spans nearly the full 448 pt screen and the Pat capsule's bottom edge may kiss the screen edge by ~2 pt (the label is fully visible; the UI test asserts pill height ≥ 44). Any fix is a layout redesign outside this task's contract — flagged for reviewer judgment.

### Persister / threading design (O1, OBS-1, TR9, F-3)

`MomoWatchSnapshotPersister` is the snapshot files' ONE writer: an actor exposing async `persist(directory:snapshot:)` and `consumeWipe(directory:eraseCount:)`. Consumption fuses wipe-then-record into ONE mailbox step, so the F-3 order cannot interleave; a marker/journal disagreement cannot wedge the Watch because the decision is count-based (incoming ≤ consumed → plain render) and the wipe replays idempotently (reasoning at the `consumeWipe` site; the journal-wipe leg is TASK-042's and does not exist yet — nothing to wipe there). Exactly two `persister.persist(` production legs exist (receive; background-gated transition) — structural guard 1 enforces the census. The WC queue's frames hop to the main actor; the main actor's only synchronous I/O is the KB-scale launch read (OBS-1). The F-3 reasoning and the count-regression boundary tests are in the consumption suite.

### Fixture-seam disclosure (DEBUG-only; release never seeds)

`-momo-watch-fixture w1` seeds a deterministic snapshot through the REAL `WatchSnapshotStore.save` BEFORE the synchronous launch read, so the UI restore test exercises the genuine persistence + read path. The seed must precede the sync launch read (that is the seam's whole point), but `save` is actor-isolated and `init` is synchronous — the disclosed bridge is a detached task plus a `DispatchSemaphore` that blocks the launch thread for the one KB write (the store actor is independent of the main actor; no deadlock). `-momo-store-directory` honors absolute paths and resolves relative names inside the app's own temporary directory (runner/app sandbox separation; per-launch UUID isolation). Both seams are DEBUG-gated or argument-absent in production launches.

### Other implementation decisions

- `WatchCopyKeys` lives as an app-target file internal to `Apps/MomoWatch` (ADR-013 per-target duplication); shared vocab/stage/quest keys resolve through the existing shared `HomeCopyKeys`.
- W1 catalog entries use ASCII apostrophes, matching the existing catalog convention; the UI-test assertions pin those same bytes.
- Restore measurement semantics (honest by construction): the assertion is `restore − baseline ≤ 2.0 s` where baseline is a measured fresh-store launch in the same run — the large, sim-dependent XCUITest launch overhead cancels, and the bound is exactly NFR-9's budget; both durations are recorded in the failure message.
- MomoKit line coverage moved 92.47 % → 91.48 % (floor 80 %): the new store's hard-to-reach defensive legs (unrecoverable-store fallbacks, decode-skip logging) and the consumption guards account for the dip; rotation, restore chain, DTO compatibility, and all decision boundaries are suite-covered.

### Disclosed scope-adjacent touches

- The AOD evidence still was copied into `.claude/tasks/reviews/` as review evidence (non-code).
- Comment-only corrections to `GlanceView.swift` doc comments (the "~40 %" inaccuracy, above) were made after the guard bites were recorded — see Completion Evidence for the hash note.

## Reviewer Findings

Pending — not yet reviewed. The independent review agent records its findings in `.claude/tasks/reviews/REVIEW-TASK-041.md` and its verdict here (APPROVED / APPROVED_WITH_MINOR_NOTES / CHANGES_REQUIRED / BLOCKED).

**VERDICT (independent adversarial review, 2026-09-11): APPROVED_WITH_MINOR_NOTES** — full record in `.claude/tasks/reviews/REVIEW-TASK-041.md`; 0 Critical / 0 Major / 2 Minor (F-1 DEBUG-loud nil-character log absent, F-2 "slot skipped vs held" wording) + 2 Notes (F-3 layout-share resolution acceptable, route UX §6.1 "~40 %" wording to doc-errata; F-4 cosmetic Pat capsule nit); all 7 gates green independently reproduced (1056/104 tests, coverage 91.48%, both builds 0 touched-file warnings, UI tests 3/3, frozen surfaces clean); Bite C re-verified exactly-one-red + 3 reviewer probes (2 at exactly-one-red), all sha256-restored byte-identical.

## Completion Evidence

(gates re-run over the FINAL tree — the only post-bite deltas are the comment-only `GlanceView.swift` edits, documented above)

- **swift test:** 1056 tests in 104 suites PASSED, exit 0 (re-run after all edits; baseline 995/100 grew by this task's suites).
- **Coverage (MomoKit):** lines 91.48 % (137/1608 missed), regions 89.84 %, functions 91.53 % — floor 80 % cleared.
- **MomoWatch build:** BUILD SUCCEEDED, zero warnings (re-run after final edits; destination id `8A854895-225C-411B-89C1-B03337BFE957`, Watch SE 3 44 mm).
- **Momo app build:** green, zero warnings in touched files (iPhone SE `1F25E487`; `GlanceView.swift` is not in the Momo target — unaffected by the final comment edits).
- **MomoWatchUITests:** 3/3 green on the pinned Watch sim.
- **Structural guard bites (recorded at bite time, each exactly-one-red, sha256-restored):** Bite A (receive-persist removed) `a166c8b6dd7c1f0b61cc36b9d725507622f16bb342e13dde689d4f878ed835eb`; Bite B (background persist removed) same file, same restore hash; Bite C (AOD glyph branch reverted) `1ec58ffa2716b36872419933913da20e38c0edffa2d393def2167039f464a256`. Post-bite verification: `MomoWatchAppModel.swift` current sha256 == `a166c8b6…` (byte-identical restore confirmed). `GlanceView.swift` current sha256 is `1cc7d04ecd832a50831cbc3a233ed1d90a225a9e4be4e9471b4decc0ba830cc9` — differs from Bite C's restore hash solely because of the post-bite comment-only edits; the scanner is comment-stripping (the property Bite C itself proved), and the standing AOD scan is green over the final tree in the re-run suite.
- **Frozen surfaces (verified at closeout):** `git diff Sources/MomoCore/` empty; `git status Sources/MomoCharacter/` empty; `Apps/Momo/MomoAppModel.swift` 800/800 lines with no diff; pbxproj: `Momo` and `MomoWatch` app targets both `dependencies = ()` (D-R3 — the UI-test bundles keep only their test-host dependencies); no new entitlements/capabilities/Info.plist keys/permissions (§27).
- **AOD evidence:** `.claude/tasks/reviews/aod-preview-still-TASK-041.png` (DEBUG `-momo-aod-preview` true-size still; SE has no AOD hardware — §25 disclosure, live observation routed to TASK-044).
- **Commit:** (this commit) — `feat(watch): TASK-041 W1 glance + snapshot persistence + AOD`, created by the orchestrator after review approval.
- **Push:** (this push pending) — orchestrator pushes to `feature/EPIC-008-watch-sync` per §13.
