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

IN_PROGRESS — contract authored 2026-09-11 (this file + ADR-014 ride the contract commit); awaiting fresh Jupiter implementation dispatch.

## Implementation Notes

(to be completed by the implementing agent — design decisions, the O4 judgment record with the chosen `stageSide`, the restore-measurement semantics, the fixture-seam disclosure, any disclosed scope-adjacent touches)

## Reviewer Findings

(to be completed by the review agent — see `.claude/tasks/reviews/REVIEW-TASK-041.md`)

## Completion Evidence

(to be completed at closeout — gates run and their real outputs, commit hash, push status; the closeout convention applies: placeholders written as "(this commit)"/"(this push pending)" resolve in the NEXT status.md edit)
