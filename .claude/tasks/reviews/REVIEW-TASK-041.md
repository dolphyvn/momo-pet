# REVIEW-TASK-041 — Watch W1 Glance, Snapshot Persistence & AOD (independent adversarial review)

Reviewer: fresh Jupiter agent (independent of task041-impl). Method per CLAUDE.md §10/§33: spec re-derived from normative sources BEFORE reading implementation; every implementation claim treated as a claim until verified at source. Working tree left byte-identical (sha256-verified restores).

## Part 1 — Spec derivation (written before reading any implementation file)

### D1 — Wire schema (R1; ADR-014; 05 §6.2, §4.11)
- `WatchSnapshot` gains exactly one additive-OPTIONAL field, `character: WatchCharacterDTO?` — nothing else changes shape.
- `WatchCharacterDTO` mirrors exactly the four fields `DisplayState` lacks: `moodBand`, `energyBand`, `activity`, `satietyHint`. No redundant copies of bondStage/wakefulness/greeting (ADR-014 rejects the full-mirror alternative).
- Codec discipline per ADR-014: hand-written Codable with `decodeIfPresent`/`encodeIfPresent`; **NO `schemaVersion` bump** (stays at the pre-task value); OBS-3 parity-fixture obligation NOT fired.
- Strict gates of both DTO decoders established by TASK-040 must remain untouched (the additive field must not loosen them).
- The iPhone push derives the DTO from the SHARED `makeCharacterDisplayState(state)` derivation (05 §4.11) — no re-derivation anywhere; threaded through `makeWatchSnapshot`.
- A pure MomoKit assembly function `DisplayState + WatchCharacterDTO? → CharacterDisplayState` with `momentRequest` projected from `display.greeting`; the nil-character path degrades to text-only (words + quest line render, canvas slot skipped, DEBUG-loud) — never a crash, never an error surface (UX §9).

### D2 — Watch-side store (R2; 05 §5.6)
- Persisted files: `watch-snapshot.json` plus exactly ONE `.prev` generation (two total — NOT the iPhone store's three).
- Writes happen on EVERY receive and EVERY background transition (TR9/NFR-9: raise-to-wake renders from the local file).
- Atomic writes (temp-then-rename); rotation demotes current→prev.
- Read chain: current → prev → nil.
- One-writer census expectation: exactly ONE production write path per file (snapshot current, snapshot prev, consumed-marker file), all on a single serialized writer; ordering total; main thread never blocks on I/O beyond launch's KB-scale initial read (05 §5.2's discipline carried to the Watch store).

### D3 — Receive path & queue discipline (R4; 05 §6.1, §6.3; OBS-1)
- WCSession delegate callbacks arrive off-main; the receive flow must hop off WCSession's queue correctly (decode → decide → render → persist).
- The main actor's ONLY synchronous I/O is the KB-scale launch read.
- Background-transition persist exists in production code (TR9).

### D4 — Reset-marker consumption (R5; 05 §6.6 erase row; TASK-040's DTO/builder/marker work)
- Consumption decision boundaries: first marker → wipe; repeat marker (≤ consumed) → NO re-wipe; newer marker → wipe; nil marker → no-op; count regression → no re-wipe.
- Wipe discards the received payload (wipe means wipe — the payload that carried the marker must not also be rendered).
- F-3's self-defense reasoning (TASK-040) must still hold at the site where snapshot writes could resurrect after a wipe.
- Post-wipe render state = the settling-in line (UX §9).
- The journal leg (05 §5.6 `intent-journal.ndjson`) is TASK-042 scope: the wipe must be wired FOR it (a wipe that cannot later extend to the journal is wrong), but no journal implementation may exist in this task.

### D5 — W1 glance view (R6; UX §6.1, §9, §10; FR-17)
- Layout (UX §6.1): Status ("Feeling happy"-class mood in words + bond stage compact secondary) / pet canvas (~40% height; 04 §2.1 watch stage 60–80 pt, full grid) / quest line (single wish; "All done — see you soon" only on completion) / full-width Pat pill ≥ 44 pt.
- One glanceable summary, never a dashboard: no numbers, no bars, no freshness indicator (UX-9), no sync UI anywhere.
- Every user-visible string resolves through catalog keys — no product-copy literals in view code; `CopyKey.isInApprovedNamespace` extended for the watch namespace; banned-vocabulary scan covers the new entries; shipped strings pinned verbatim in tests.
- VoiceOver composite per UX §10 W1 row over the SHIPPED strings: "{name} feels {mood} and has {energy}. {Stage}. Today's wish: {wish}. Pat button."
- Settling-in line pre-first-sync: "Momo is settling in — meet Momo on iPhone." (UX §9 row).
- Pat targets (pet canvas + pill) ≥ 44 pt and INERT this task — no pat capture, no haptics, no journal (TASK-042). Any leaked pat behavior is a scope violation (§22).

### D6 — AOD (R7; UX §6.5; FR-17 AC-5; D16; 04 §2.1/§6.4/§7.3)
- Foreground `.glance` (LOD glance rig) and luminance-reduced `.glyph` (static, silhouette-preserving, 24–32 pt class) derive from the SAME assembled read-model.
- The `.glyph` branch never binds a clock — no animation, no timeline, no time-dependent rendering in AOD.
- AOD: no reaction, no animation (04 §6.4). SE has no AOD — disclosure required, not hidden.
- O4 judgment: `stageSide` values recorded with evidence; reviewer re-judges the still independently.

### D7 — Structural guards (R9)
- Three NEW structural guards scoped to `Apps/MomoWatch`, comment-stripped scanning; each recorded bite must produce EXACTLY ONE red (a guard that bites in N places is miscalibrated; a guard that cannot bite is decoration).

### D8 — Tests (§19, §10)
- New suites must be genuine: fail when the pinned behavior breaks; no tautologies.
- Pre-task baseline 995/100 must not regress.
- MomoKit line coverage ≥ 80 % (llvm-cov; method per TASK-040 record).

### D9 — Project shape (ADR-013/D-R3; pbxproj convention)
- `Momo` and `MomoWatch` targets keep `dependencies = ()`; the only PBXTargetDependency entries remain the two UI-test bundles.
- New files registered per the project's explicit-file-reference convention.

### D10 — Scope & hygiene (§22, §24, §25, §26, §27)
- R1–R10 only: NO pat capture, NO `watchSessionEpoch` persistence, NO intent-journal implementation, NO Watch-side cascade, NO haptics (all TASK-042/043/044).
- No entitlements/capabilities/Info.plist permission keys/network additions; no secrets; no unexplained TODO/FIXME/HACK/TEMP; fixture seam DEBUG-only with no Release path; no fake completion (SE-no-AOD disclosed, device obligations never claimed from simulators).

### Normative-authority note (layout-share item, pre-registered judgment frame)
UX §6.1 says pet canvas "~40% height"; 04 §2.1 freezes the watch foreground stage at 60–80 pt (full grid). These bind different things: UX §6.1 governs W1's layout proportions; 04 §2.1 governs the character-space mapping (the stage the rig is drawn into). On the pinned 40 mm canvas (~162×197 pt) ~40 % height ≈ 79 pt — inside 04 §2.1's 60–80 pt band. A resolution is acceptable iff the implementation keeps the canvas in the §2.1 band (or documents an owner-authorized deviation); where the two docs disagree numerically on other devices, UX §6.1's W1 layout contract governs the surface and 04 §2.1 governs the rig mapping, and the task must not silently violate either.

---

## Part 2 — Contract as written (TASK-041 R1–R10)

The task file's R1–R10 were cross-checked against the Part 1 derivation after the derivation was committed to this record: **no divergence between the contract and the normative sources was found** on R1 (additive-optional character), R2 (two-generation store), R3 (transport twin), R4 (receive path + OBS-1), R5 (consumption boundaries), R6 (W1 layout/copy/a11y), R7 (AOD tiers), R8 (catalog law), R9 (guards), R10 (gates). The single normative tension in the whole task is the layout-share wording (UX §6.1 "~40 %" vs 04 §2.1's 60–80 pt band), which was pre-registered in Part 1 and is adjudicated as F-3 below. The contract's R1 wording says the nil path renders with "the canvas slot skipped"; the ADR and DTO comment say the same, while the view holds the slot with a blanket — adjudicated as F-2 (wording only; both satisfy UX §9's degrade-to-text-only rule).

## Part 3 — Per-requirement verification (file:line evidence)

All claims below were verified by reading the files at source, not from implementer notes.

**R1 — character DTO (additive-optional, no bump, shared derivation)**
- `Sources/MomoKit/SyncDTOs.swift`: `WatchSnapshot.character: WatchCharacterDTO?` — additive OPTIONAL; hand-written codec uses `decodeIfPresent` (line 210) and `encodeIfPresent` (line 249). `WatchCharacterDTO` carries exactly `moodBand`, `energyBand`, `activity`, `satietyHint` — the four fields `DisplayState` lacks; no mirrored bondStage/wakefulness/greeting.
- No `schemaVersion` bump: the decode gate remains `snapshot.schemaVersion == StoreRules.watchSnapshotSchemaVersion`, untouched; the version-gate constants and the TASK-040 strict-decoder structure (unknown-band refusal, exhaustive case-maps) are intact.
- Byte-compatibility is pinned by tests, including a hand-written PRE-CHARACTER JSON bytestring test (`Tests/MomoKitTests/WatchCharacterDTOTests.swift` "a PRE-CHARACTER payload decodes cleanly…", "a no-character snapshot's bytes OMIT the key…") — the bytes come from an independent source, not from the implementation's own encoder (non-tautological).
- iPhone push derives from the SHARED derivation: `Apps/Momo/MomoAppModel+Watch.swift` push arm passes `character: makeWatchCharacter(makeCharacterDisplayState(state))` — no re-derivation. `WatchSnapshotBuilder` threads `character: WatchCharacterDTO? = nil` verbatim (default nil preserves all pre-task call sites).
- Assembly: `Sources/MomoKit/WatchCharacterAssembly.swift` — `makeWatchCharacter` is a 4-field pass-through; `makeWatchCharacterDisplay(display:character:)` returns nil for nil character (degraded shape), and projects `momentRequest` from `display.greeting` via `CharacterMoment.greeting` — digit-for-digit the same projection MomoCore's `makeCharacterDisplayState` performs (`state.lastGreeting.map { .greeting($0.kind) }`). Pure: no I/O, no clock, no globals.

**R2 — WatchSnapshotStore (05 §5.6)**
- `Sources/MomoKit/WatchSnapshotStore.swift` (read fully): two generations only — current + one `.prev` (lines 100–101); save sequence = remove stale prev → rename current→prev → write temp → atomic rename temp→current (lines 108–122) — verified against the header's crash-window table; the temp file is inert (nobody reads it) and cleaned on failure (lines 126–131); load chain current → prev → nil via the nonisolated decode path (line 158+); wipe removes BOTH generations and the temp and deliberately touches nothing else — in particular never the consumed-marker file sharing the directory (lines 138–148). All persisted on the `MomoWatchSnapshotPersister` actor (single serialized writer, O1).

**R3 — transport twin**
- `Apps/MomoWatch/MomoWatchTransport.swift`: `MomoWatchTransporting` protocol + `LiveWatchTransport` (delegate installed at init, `activate()` called, `didReceiveApplicationContext` unwraps the `"payload"` Data and forwards). Receive-only: no send-side API exists to misuse.

**R4 — receive path, queue discipline, OBS-1**
- `Apps/MomoWatch/MomoWatchAppModel.swift` (read fully): sink binds BEFORE activation (lines 144–148, the WCSession.h:42-45 discipline); `receiveContext` = decode-or-skip → pure `decide` → consume branch (`consumeWipe` + snapshot=nil + return — the payload is NOT rendered) / render branch (snapshot=snapshot → `persist`); the WC queue's frames hop onto the main actor, which total-orders them, and each receive's persist submission preserves that order through the persister's FIFO mailbox.
- The main actor's ONLY synchronous I/O is the KB-scale launch read (lines 140–142: snapshot pair + consumed marker). Background persist exists in production: `scenePhaseChanged(to:)` persists on `.background` when a snapshot exists, wired for real in `MomoWatchApp.swift` via `.onChange(of: scenePhase)` (the TR9 leg is live, not just implemented).

**R5 — reset-marker consumption (05 §6.6)**
- `Sources/MomoKit/WatchResetConsumption.swift`: `decide` is pure — consume IFF `incoming > consumed` (guard at lines 55–59); nil → render; equal/regressed → render. `consumeWipe` fuses wipe+record into ONE mailbox step (no interleaving window). The F-3 self-defense reasoning is documented at the site (wipe BEFORE record, so a crash between them replays the wipe idempotently) and pinned by a dedicated replay test plus a rebirth test (`WatchResetConsumptionTests`).
- Wipe → settling-in: consume sets `snapshot = nil`, and the view renders the settling-in line for nil — end-to-end shape verified in the UI suite's first test.

**R6 — W1 glance view (UX §6.1/§9/§10, FR-17)**
- `Apps/MomoWatch/GlanceView.swift` (read fully): four slots in §6.1 order (status with mood word + bond-stage secondary / pet canvas / quest line / full-width Pat pill). Canvas stage side 68 pt + 8 pt spacing = 76 pt canvas height — inside 04 §2.1's frozen 60–80 pt band (see F-3 for the "~40 %" wording). `minimumTargetSide` = 44 pt for both pat targets.
- Pat targets are INERT: both are Text-only; grep over `Apps/MomoWatch` shows no gesture recognizers, no pat capture, no haptic triggers. `WatchSnapshot.hapticsEnabled` exists only as the pre-existing TASK-040 wire field (set in the DEBUG fixture, never consumed by any view).
- No numbers/bars/freshness/sync UI anywhere in the view (UX-9).
- VoiceOver: single composite element (`.accessibilityElement(children: .ignore)`) labeled via the 5-placeholder template over the SHIPPED strings — "%1$@ feels %2$@ and %3$@. %4$@. Today's wish: %5$@. Pat button." — matches UX §10's W1 row.
- Settling-in: nil snapshot renders the single "Momo is settling in — meet Momo on iPhone." line (UX §9 verbatim).
- Quest line resolves through the shared `HomeCopyKeys` (wish / all-done) — no watch-specific duplicate of product copy.

**R7 — AOD**
- `GlanceView.swift` tier property: `isLuminanceReduced || model.aodPreview` → `.glyph` (line 163), else `RigLOD.tier(for: .watchForeground)` — both tiers derive from the SAME assembled read-model; the `.aodPreview` flag is DEBUG-only (`aodPreviewEnabled()`).
- The `.glyph` branch never binds a clock: verified at rig level, `Sources/MomoCharacter/MomoRigView.swift:102-108` — the TimelineView exists only in the non-glyph branch; glyph renders the static silhouette. No AOD reaction/animation (04 §6.4).
- O4 judgment (mine, independent): the DEBUG still `.claude/tasks/reviews/aod-preview-still-TASK-041.png` was re-analyzed blind. The creature silhouette (rounded body, two upright ears) is recognizable at roughly 12–18 % of screen height with adequate contrast on black and no clipping — the implementer's recorded claim (glyph ink ≈36×52 pt at the 28 pt stage, ~1.9× sprite overflow, silhouette legible) is SUPPORTED. Honest caveat recorded: this is a simulator render; physical AOD hardware has lower effective brightness, and fine details (eyes) soften — but shape-level legibility holds. SE has no AOD; the task record discloses this (§25 compliant — glyph tier is a static render that simply won't be shown on SE hardware).

**R8 — catalog law (INV-11)**
- `Apps/Shared/MomoCopy.xcstrings`: exactly 3 new entries, verbatim per spec — `momo.line.watch.settlingIn` ("Momo is settling in — meet Momo on iPhone."), `momo.line.watch.pat` ("Pat"), `momo.line.watch.a11y.glance` (the 5-placeholder template). The ASCII apostrophe in "Today's" is spec-verbatim (the UX §10 row uses it).
- `Apps/MomoWatch/WatchCopyKeys.swift` + `MomoCopyText.swift`: the 3 fixed keys; render = `MomoCopy.resolve(key, bundle: .main)` — no product-copy literals in view code.
- Namespace law extended for `momo.line.watch.*`; copy-law scan widened 74 → 76 scanned sources; catalog-scaffolding pin 113 → 116 with the W1 verbatim pins (`Tests/MomoCharacterTests/CatalogCopyLawTests.swift`, `MomoCatalogScaffoldingTests.swift`).
- Banned-vocabulary real-tree coverage CONFIRMED non-vacuous: `TestRepo.stringCatalogs()` recursively globs the repo for `*.xcstrings` (`Tests/MomoCoreTests/Support/TestRepo.swift:43-46`), and the standing scan `realTreeCatalogsAreClean` (`Tests/MomoCoreTests/BannedVocabularyScanTests.swift:147+`) runs the 12-entry banned list over every catalog found — including the shipped `Apps/Shared/MomoCopy.xcstrings` with the 3 new entries. Green in the full run.

**R10 — project shape**
- `Momo.xcodeproj/project.pbxproj`: `Momo`/`MomoWatch` keep `dependencies = ()` (D-R3); PlaceholderGlanceView removed; the 5 new files registered across PBXBuildFile + PBXFileReference + group + Sources phase under the project's explicit-file-reference convention. Diff inspected line-by-line — no capability/entitlement/plist changes.

## Part 4 — One-writer census

Method: repo-wide grep for every user of the five new file-name constants, then grep for every WRITE-SITE caller (`.save(`, `persist(`, `consumeWipe(`) across `Sources/` and `Apps/`.

- File-name constants appear ONLY in `Sources/MomoKit/WatchSnapshotStore.swift` and `Sources/MomoKit/WatchResetConsumption.swift` (plus their defining `StoreRules.swift`). No app-target file constructs any of these paths.
- Snapshot generations (current/prev/temp): written ONLY by `WatchSnapshotStore.save`, called ONLY by `MomoWatchSnapshotPersister.persist` (`Apps/MomoWatch/MomoWatchAppModel.swift:32-33`), whose callers are exactly: the receive render path (line 207), the background-transition path (line 221), and the DEBUG fixture seed (line 283, `#if DEBUG`). The persister actor serializes all of them; the receive hop's FIFO order is preserved through the mailbox.
- Consumed marker: written ONLY by `WatchConsumedMarkerStore.save`, called ONLY by `consumeWipe` (`MomoWatchAppModel.swift:45-47`), whose only caller is the receive consume branch (line 198) — fused wipe+record.
- iPhone-side stores (`MomoAppModel+Watch.swift:25,195`, `MomoAppModel+Settings.swift:108`) write DIFFERENT files in DIFFERENT (iPhone) directories — not second writers of the Watch's files.

**Census result: exactly one production write path per file, all on one serialized writer. Rule HOLDS.**

## Part 5 — Blind-spot hunt (wiring legs no kit test can see)

1. **Launch-load directory derivation** (the TASK-040 Probe C class): `testStoreDirectory()` resolves ONE directory up front; the fixture seed, the launch read, receive persists, and background persists all use that same resolved value — no fixture-vs-real divergence exists at launch (lines 128–142). Relative store-directory values are sandboxed into the app temp dir, so cross-launch reads are consistent.
2. **Receive flow call chain**: `LiveWatchTransport` (delegate, WC's non-main queue) → `onContextData` → main-actor `receiveContext` → pure `decide` → consume/render → persister. Verified hop-by-hop at source; the sink binds before `activate()`, so no frame can arrive unhandled.
3. **Delivery-order nuance**: a context decoded during the launch read's synchronous window vs. one delivered after activation — benign, because `updateApplicationContext` is latest-wins (ADR-003): the newest frame always carries the full payload, so interleavings converge to the same state.
4. **UI-test restore leg**: the restore-within-budget test relaunches WITHOUT the fixture argument and reads from disk — a genuine persistence round-trip through the real app lifecycle, not a seeded read. Green in gate 5.

**No Probe-C-class wiring divergence found.**

## Part 6 — Guards R9 verification

`Tests/MomoKitTests/Support/WatchGlanceScan.swift` + `MomoWatchGlanceScanTests.swift` (read fully):
- Guard 1 (persist legs): the receive path and the background path each call the persister; the O1 census leg asserts EXACTLY TWO persist call sites — matching my independent Part 4 census.
- Guard 2 (no engine): no engine-mutation/`reduce` tokens in `Apps/MomoWatch` — the Watch twin stays a renderer.
- Guard 3 (AOD): the tier property must gate on the luminance condition, `return .glyph` in the branch, and reach the foreground tier otherwise.
- All scans are comment-stripped (`strippingComments`), with two-direction stub fixtures (violating stub → findings; compliant stub → clean) so the scanners are neither blind nor vacuously green; standing real-tree tests assert emptiness.

**Operational verification of the disclosed Bite C divergence claim:** the implementer disclosed that post-bite comment-only edits to `GlanceView.swift` changed its hash from Bite C's restore hash (`1ec58ffa…`) to `1cc7d04e…`. I re-ran Bite C's mutation class (`return .glyph` → `return .glance`) against the CURRENT file myself: mutated hash `00a715164a7afad2…`, full suite run → **exactly ONE red** (the Guard 3 test, "…renders the static glyph in AOD…"), restored `1cc7d04ecd832a50831cbc3a233ed1d90a225a9e4be4e9471b4decc0ba830cc9` — byte-identical to both the baseline and the implementer's disclosed current hash. The comment-only-edit claim is TRUE and the scanner's comment-stripping is what makes it true.

## Part 7 — Gate results

| # | Gate | Result |
|---|------|--------|
| 1 | `swift test` | **1056 tests / 104 suites, all passed** (pre-task baseline 995 — no regression; +61 tests). Re-run green AGAIN after all probe restores. |
| 2 | MomoKit coverage (llvm-cov, TASK-040 method) | **Lines 91.48 %** (1608 lines, 137 missed), regions 91.53 %, functions 89.84 % — floor 80 % **PASS**. Independently reproduced; matches the implementer's claim digit-for-digit. |
| 3 | `xcodebuild` Momo (iPhone sim 1F25E487-A78E-464C-95AF-0BD1A9B3E1BE) | **BUILD SUCCEEDED**. Warnings: only `ld: warning: search path '/opt/extra/lib' not found` ×3 (caused by the machine's `LIBRARY_PATH` shell env, NOT the repo) + one benign appintentsmetadataprocessor note. **Zero warnings from touched files.** |
| 4 | `xcodebuild` MomoWatch (Watch sim 8A854895-225C-411B-89C1-B03337BFE957) | **BUILD SUCCEEDED**. Same 3 machine-env `ld` warnings + benign note. **Zero warnings from touched files.** |
| 5 | `xcodebuild test` MomoWatchUITests (pinned Watch sim) | **3 tests, 0 failures, TEST SUCCEEDED** (26.45 s) — settling-in-only fresh launch; fixture-seeded W1 content (composite prefix/suffix, ≥44 pt canvas+pill); restore-within-budget relaunch WITHOUT fixture (genuine disk restore). |
| 6 | Mutation probes | Bite C re-run + 3 reviewer-designed probes (Part 8) — all sha256-restored byte-identical. |
| 7 | Frozen surfaces | `git diff Sources/MomoCore/` EMPTY; `git status Sources/MomoCharacter/` EMPTY; `Apps/Momo/MomoAppModel.swift` **800/800 lines, no diff**. Full 28-file sweep at review end: **ALL BYTE-IDENTICAL**. |

## Part 8 — Probe table (mutations + sha256 restores)

| Probe | File | Mutation | Mutated sha256 (16) | Reds | Restored sha256 | Byte-identical |
|-------|------|----------|--------------------:|------|-----------------|----------------|
| Bite C re-run (implementer's class, my execution) | Apps/MomoWatch/GlanceView.swift | `return .glyph` → `return .glance` | `00a715164a7afad2` | **1** (AOD guard test) | `1cc7d04ecd832a50831cbc3a233ed1d90a225a9e4be4e9471b4decc0ba830cc9` | YES |
| Reviewer Probe 1 | Sources/MomoKit/StoreRules.swift | current-name literal → `"watch-snapshot2.json"` | `c66378a37fbf78ca` | **1** (byte-for-byte pin, StoreRulesPinnedTests.swift:114) | `2227062729d6585dca9f3d0d6fca240c6693bb165d3dfd14322c2582e790ee53` | YES |
| Reviewer Probe 2 | Sources/MomoKit/WatchResetConsumption.swift | nil-guard steady shape flipped (nil incoming → `.consume`) | `50538a4f963fa8a4` | **2** (nil-shape test ×2 issues + rebirth lifecycle test) — boundary is double-covered; see note | `6b5bb7a60f1026276d6a9f495cce7cab79cd99563f849fb2e51fbdacd7315005` | YES |
| Reviewer Probe 3 | Sources/MomoKit/WatchSnapshotStore.swift | commit point `moveItem` → `copyItem` (temp left behind) | `a6451ffba44b1fbd` | **1** (no-temp invariant, WatchSnapshotStoreTests.swift:132) | `b75d002f70c5bfc691a462ed38101d5551e475606c69cdfe3e2f5b9c5c589446` | YES |

Probe 2 note: my first caller census for `decide(` was truncated by `head` and missed the rebirth test's nil call at WatchResetConsumptionTests.swift:157 — the probe therefore landed 2 reds, recorded honestly. Calibration conclusion is unchanged (the class is caught; nothing is blind), and Probes 1 and 3 satisfy the exactly-one-red bar. A post-probe full run was green (1056/104), and the final loop-free sweep verified all 28 baseline files byte-identical.

## Part 9 — Findings

**Severity counts: 0 Critical · 0 Major · 2 Minor · 2 Notes. No CHANGES_REQUIRED findings.**

- **F-1 (Minor) — ADR-014's DEBUG-loud nil-character log is not implemented.** ADR-014 specifies a DEBUG-loud log on the nil-character decode/assembly path; the implementation degrades silently (the path is tested and safe, and DEBUG `aodPreview`/fixture seams exist, but no loud log fires when a context decodes without a character in DEBUG). Impact: diagnostics-only; a silent nil-character in the field would be invisible in a DEBUG console. Recommendation: fold a one-line `Self.debugLoudFailure`-style log into the receive decode-or-skip and nil-assembly sites as part of TASK-042's receive-path work, or record an explicit ADR amendment accepting the silence. Not blocking: behavior (degrade-to-text-only) is correct and pinned by tests.
- **F-2 (Minor, doc-only) — "slot skipped" vs "slot held" wording divergence.** ADR-014 and the DTO comment describe the nil-character path as the canvas slot being skipped; the view actually holds the slot and renders a blanket so the layout does not jump. Both satisfy UX §9 (text-only degrade) and the render is arguably better than a skipped slot; but one of the two wordings should win. Recommendation: one-line comment reconciliation in the next touch of `GlanceView.swift` or the ADR; no code change required.
- **F-3 (Note, pre-registered adjudication) — layout-share resolution HONORS the authority chain.** UX §6.1's "~40 %" and 04 §2.1's 60–80 pt band bind different things (surface proportion vs character-space mapping). The implementation's 76 pt canvas (68 pt stage + 8 pt spacing) sits INSIDE the frozen §2.1 band on the 40 mm device, where §6.1's ~40 % ≈ 79 pt — the two docs agree on the pinned device, and the implementation never violates either. Verdict: ACCEPTABLE. Follow-up: route a doc-erratum note for UX §6.1's "~40 %" phrasing (percent-of-height wording on non-40 mm devices can numerically disagree with §2.1) to the doc-errata backlog — a documentation task, not a code task.
- **F-4 (Note, cosmetic) — Pat capsule ~2 pt edge nit.** Visual-only rounding asymmetry in the Pat pill's capsule edge; nothing in UX §6.1/§10 or the catalog law is violated, and the a11y target is correct. No action required; may be swept up in any future W-surface polish pass.

## Part 10 — Scope / security / debt

- **Scope (§22/§24):** no pat capture, no `watchSessionEpoch` persistence, no intent-journal implementation (the wipe is wired FOR it structurally — a fused wipe step that can later extend — without any journal code), no Watch-side cascade, no haptics. `hapticsEnabled` appears once (`MomoWatchAppModel.swift:313`) as the pre-existing TASK-040 wire field in the DEBUG fixture; no view consumes it. No MVP expansion.
- **Security/privacy (§27):** no entitlements, capabilities, Info.plist keys, or network additions in the diff; no secrets; the only I/O is the app-container JSON pair + marker (KB-scale, local). WCSession receive is decode-or-skip — malformed payloads are skipped, never surfaced. Clean.
- **Debt (§26):** zero TODO/FIXME/HACK/TEMP in all changed production and test files (sweep run; `temporary` filename identifiers excluded as code, not debt markers).
- **DEBUG seams (§25):** fixture seed (`-momo-watch-fixture w1`), store-directory override (`-momo-store-directory`), and AOD preview (`-momo-aod-preview`) are all inside `#if DEBUG` with no Release path. SE-no-AOD is disclosed in the task record; no device behavior is claimed from simulator evidence (O4 is explicitly labeled a simulator still).

## Part 11 — Verdict

**APPROVED_WITH_MINOR_NOTES.**

All seven gates pass on independent reproduction (1056/104 tests; coverage 91.48 %; both app targets BUILD SUCCEEDED with zero touched-file warnings; UI suite 3/3; frozen surfaces clean; tree byte-identical after 4 mutation runs). The implementation satisfies every contract requirement R1–R10 with file:line-verified evidence; the one-writer census and the blind-spot hunt found no wiring divergence; the guard family is live and correctly calibrated (Bite C re-verified exactly-one-red over the final tree); O4's evidence survives independent image judgment. The two Minor findings (F-1 DEBUG-loud log, F-2 wording reconciliation) are diagnostics/documentation items that do not affect correctness, acceptance criteria, or the product philosophy, and are recommended for TASK-042's receive-path work rather than a fix round on TASK-041.

*Tree state at verdict: the only files differing from the review-start baseline are this review record (now complete) and the one-line verdict note appended under `## Reviewer Findings` in the task file — both mandated reviewer outputs. All 26 implementation/test/build files verified byte-identical.*
