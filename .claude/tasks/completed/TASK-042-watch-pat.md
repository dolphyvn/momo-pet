# TASK-042 — The Watch Pat: Offline-First Micro-Reaction + Journaled Intents + Drain

## Parent Epic

EPIC-008 — Watch App & Sync (`.claude/tasks/epics/EPIC-008-watch-sync.md`), AC-2 and AC-4; follows TASK-041 (DONE, `4407544`).

## Objective

Make W1's two pat targets (pet canvas, Pat pill — shipped INERT in TASK-041) live: an immediate LOCAL micro-reaction state-distinct per wakefulness + a subtle toggle-honoring haptic, fully offline (FR-17 AC-2); every pat journaled as an `IntentEvent` (`watchSessionEpoch` + monotonic `watchSeq`) in `intent-journal.ndjson`; drained to the iPhone over `transferUserInfo` (already received iPhone-side by TASK-040) with the epoch-matched journal prune; the journal-wipe leg of the §6.6 consumption; and the three routed review folds (REVIEW-TASK-041 F-1 + F-2; TASK-040 F-3). This completes the first vertical slice's interaction half: an offline Watch pat applies exactly once on the iPhone.

## Context (normative sources — read ALL before coding)

- **UX `docs/design/03-ux-architecture.md` §6.2–6.4 (lines ~325–345):** pat = tap the pet or the Pat pill → micro-animation distinct per state ("happy bounce when awake; **stir + tiny heart, stays asleep** at night") + subtle haptic, immediately, even offline (FR-17 AC-2). Pat counts identically to iPhone pats — same counters, same quest ticks (FR-18 AC-2); petting banks zero bond (G2); first touch of the local day is the hello +8, device-agnostic, idempotent. §6.3 haptics table verbatim: Pat = single soft tick; quest completed *by an on-wrist action* (e.g., 3rd pat completes Q7) = gentle celebratory double; ANYTHING ELSE = **nothing** — no scheduled/background/sync-triggered haptics in Phase 1; iPhone-side completions celebrate on the iPhone and reach the Watch silently. All honor the Settings toggle (UX-13). §6.4: idempotent intent events, replay exactly once (FR-18 AC-1), the user is never told (UX-9).
- **Character `docs/design/04-character-system.md` §6.4 (lines 416–432):** "One interaction: pat — tap anywhere on the Watch stage. Reaction is state-distinct…: awake → happy micro-bounce; asleep → stir + tiny heart, stays asleep (≤ 1 s) + subtle haptic (Watch-owned). Offline-first… AOD: static snapshot, no reaction, no animation (FR-17 AC-5, D16)."
- **Technical `docs/architecture/05-technical-architecture.md` §5.6 + §6.1–6.6 (lines ~476–550):** `intent-journal.ndjson` (append-only pending-intent queue, pruned by the epoch-matched watermark); `watchSessionEpoch` persisted (generated at Watch app first launch; regenerated on reinstall/re-pair/new Watch); §6.1 transport mapping — `transferUserInfo` = reliable queued FIFO, duplicates possible ⇒ idempotent; `sendMessage` reachable-only = pure optimization (NOT used by this task); §6.4 intent path 5 steps: (1) pat → local reaction + haptic immediately, intent appended, transferUserInfo send attempted; (2) iPhone folds to now, applies iff UUID unseen ∧ `watchSeq > lastAppliedIntentSeq` for the intent's own epoch (per-epoch watermark, 0-init on unseen); (3) expired-dayKey intents apply current-state effects with day attribution dropped; (4) the next snapshot carries the watermark pair; the Watch prunes ≤ watermark ONLY on epoch match; (5) bond/counters/quests move ONLY on the iPhone. §6.6 case table: fresh-install pat = "no-op beyond local reaction"; offline midnight — pats journal their OWN `dayKey` so a 23:30 pat attributes correctly; TR9 termination mid-queue.
- **FR-17/FR-18** (`docs/product/02-mvp-prd.md:349–364`): AC-1 raise-to-pat ≤ 5 s; AC-2 immediate feedback offline; FR-18 AC-1 exactly-once; AC-2 same counters/quests (Q7).
- **ADR-014** (`decisions/ADR-014-watch-character-read-model.md`) — the snapshot's shape; **ADR-015** (`decisions/ADR-015-watch-pat-presentation.md`) — THIS task's two presentation adjudications (reaction binding D1; completion-haptic estimation D2; haptic-type VERIFY-AT-BUILD D3). ADR-015 is binding.
- **EPIC-008 AC-2/AC-4** and the epic's inherited routings (O1 one-writer; O5 accessor rule; TASK-040 F-3 journal self-defense).

**Key existing surfaces (verified 2026-09-11):**

| Surface | Where | Notes |
|---|---|---|
| Watch executor | `Apps/MomoWatch/MomoWatchAppModel.swift` (333 ln) | persister actor :23–50 (`persist`, `consumeWipe` — journal leg owed); receive path :176–208 (consume early-return; steady shape render→persist; prune leg owed); `characterDisplay` :163–166 (F-1 site); `debugLoud` :328–332; fixture seam :271–291 |
| Watch transport | `Apps/MomoWatch/MomoWatchTransport.swift` | receive-only protocol :22–36 (send surface OWED); `LiveWatchTransport` :60–112 (watchOS: session always available; ONE required delegate method) |
| W1 view | `Apps/MomoWatch/GlanceView.swift` | `petCanvas` :96–114 + `patPill` :129–139 — labeled, ≥ 44 pt, INERT (capture owed); composite a11y element :64–73 pre-announces "Pat button."; glyph tier never binds a clock |
| Rig reaction seam | `Sources/MomoCharacter/MomoRigView.swift:49,86` | `reactionMotion: (Double, Bool) -> MomoReactionMotion` sampler, default `.identity` — ADDITIVE at W1's call site |
| Clips | `Sources/MomoCharacter/MomoReactionClips.swift` | `.tap` :19 (touch family), `.stir` :29 AUTHORED 1.0 s (bodyScale/tail/head; stays down; "the asleep" per :70); specs at :115–135, :189 |
| Journal | `Sources/MomoKit/IntentJournal.swift` | append :79–109 (newline-sealing, torn-line tolerance), events :117–131, epoch-matched prune :140–212 (`pruned` pure core + atomic rewrite; absent == empty). `wipe()` OWED |
| DTOs | `Sources/MomoKit/SyncDTOs.swift` | `IntentEvent` :427+ (schemaVersion gate, wrapped `InteractionIntent` id/source/localDayKey/timestamp/kind, epoch, watchSeq; exhaustive case maps); `WatchSnapshot` :42–126 (hapticsEnabled, lastAppliedIntentSeq, lastAppliedEpoch, questInputs, display.wakefulness) |
| Sync state | `Sources/MomoKit/SyncState.swift`, `WatchReceivePlan.swift` | per-epoch watermark table, 0-init accessor; iPhone-side decision core COMPLETE |
| Store rules | `Sources/MomoKit/StoreRules.swift` | `intentJournalFileName` :107, `temporaryIntentJournalFileName` :114, `zeroWatchSyncEpoch` :101, schema versions :86/:93; `watchSessionEpochFileName` OWED |
| iPhone receive (SHIPPED — do not touch) | `Apps/Momo/MomoWatchTransport.swift:143` + `Apps/Momo/MomoAppModel+Watch.swift:162–187` | `didReceiveUserInfo` → `receiveWatchEvent`: decode → `WatchReceivePlan.decide` → record-before-apply → facade apply → own persist |
| iPhone precedents | `Apps/Momo/MomoAppModel.swift:462–472` (intent construction: clock.now + DayKey.make + source), `:288–304` (momentHapticSink — presentation-owned, gated AT DELIVERY) | Watch mirrors the construction shape with `source: .watch` |

## Requirements

**R1 — Watch session epoch (MomoKit + Watch init).** Add `StoreRules.watchSessionEpochFileName` + a small persisted store over it in MomoKit (the `WatchResetMarkerStore` pattern: load-or-nil / save; headlessly testable). The Watch app model resolves its epoch at init: load; if missing, generate a fresh `UUID()`, persist, AND wipe any journal present (TASK-040 F-3 self-defense — stale-epoch entries can never apply and must never linger). Epoch stability across relaunches is pinned by test; reinstall/re-pair resets it naturally (container wipe — documented, not coded).

**R2 — Journal writer legs (O1).** ALL journal file mutations funnel through `MomoWatchSnapshotPersister`'s mailbox (the Watch's one-writer actor; the `IntentJournal` instance is reconstructed per call over the executor directory — the established pattern). Legs: (a) `append(patEvent)` on pat; (b) `prune(epoch:seq:)` on every steady-shape receive AFTER the snapshot persist, with the snapshot's `lastAppliedEpoch`/`lastAppliedIntentSeq` (IntentJournal's prune is already epoch-matched — a stale-epoch watermark prunes nothing, pinned); (c) `consumeWipe` gains the journal wipe: snapshot pair wipe → journal wipe → marker record (the F-3 order — all wipes BEFORE the record; a crash between them replays idempotently). Add `IntentJournal.wipe()` to MomoKit (remove file if present; absent is success) mirroring `WatchSnapshotStore.wipe()`.

**R3 — Pat capture + journaling (the §6.4 step-1 leg).** Both targets (canvas tap, pill) capture ONE pat. The Watch app model builds `InteractionIntent(id: UUID(), source: .watch, localDayKey: DayKey.make(from: now, calendar:), timestamp: now, kind: .pat(gesture: .tap, zone: nil))` — `now` and `calendar` INJECTED (tests pin both; a 23:30 pat's own dayKey rides the event per 05 §6.6). `watchSeq` is DERIVED, never stored: `next = max(maxJournalSeq, epochMatchedWatermark) + 1` where `epochMatchedWatermark = snapshot?.lastAppliedEpoch == currentEpoch ? snapshot!.lastAppliedIntentSeq : 0`. The max's watermark term is the full-prune case's monotonicity (journal empty + watermark N ⇒ next seq N+1, never 1) — pin with a named test. Append via R2, then attempt the `transferUserInfo` send (R4). Journaling and reaction/haptic NEVER fail together: the reaction + haptic fire first and unconditionally (per gates), the journal append is best-effort persistence (its I/O failures are the journal's DEBUG-loud, keep-as-is discipline — a lost journal line is a lost pat, disclosed degradation; never an error surface).

**R4 — Watch transport send surface.** `MomoWatchTransporting` gains a `transferUserInfo` send (canonical `IntentEvent.encoded()` bytes under a `"payload"` key, mirroring the receive twin's unwrap); `LiveWatchTransport` implements it as a THIN `session.transferUserInfo(_:)` call (fire-and-forget; delivery is WC's reliable-queue job; duplicates are the idempotent guards' job). The protocol keeps its queue-contract comment discipline; the fake records sends for tests. NO `sendMessage` (the reachable-only optimization stays unshipped). The iPhone side is COMPLETE (TASK-040) — zero iPhone edits (see Constraints).

**R5 — Micro-reaction (ADR-015 D1).** The Watch app model holds a transient reaction (kind ∈ {awake, asleep} from the CURRENT snapshot's `display.wakefulness` + start time from the injected clock); `GlanceView`'s canvas passes a `reactionMotion` sampler to `MomoRigView`: awake → `.tap` clip motion, asleep → `.stir` clip motion, sampled over elapsed time, `.identity` past the clip window (authored baselines ≤ 1 s hold the window). Glyph/AOD tier binds NO sampler (static — 04 §6.4 "AOD: no reaction"); the resolved Reduce Motion flag returns a static pose (MomoReduceMotion's render-only law — use the existing reduced machinery if the clip API exposes one, else `.identity`; record which in the notes). **Zero `Sources/MomoCharacter/` edits; zero new art** — the docs' "tiny heart" does not exist in the frozen vocabulary and is NOT shipped (ADR-015 D1; disclose in notes + backlog).

**R6 — Haptics (ADR-015 D2/D3).** Injectable haptic seam over `WKInterfaceDevice.play(_:)` (protocol + default live impl; fake records kinds for tests). Pat → single soft tick; if the completion ESTIMATOR fires (pure helper: held `questLine == .wish(.q7)` ∧ Q7 `questInputs` progress + pending journal pats + 1 == that quest's target) the celebratory double REPLACES the tick (one haptic carries the moment — pinned by a named test). BOTH gate on the CURRENT snapshot's `hapticsEnabled` AT PAT TIME (the TASK-036 delivery-time discipline). Resolve the two `WKHapticType` values against the real SDK headers (the TASK-040 VERIFY-AT-BUILD discipline) and record them in the notes; haptic FEEL is TASK-044's paired-hardware obligation or BLOCKED evidence (§25/§27 — no simulator feel claims).

**R7 — FOLD F-1 (REVIEW-TASK-041).** The nil-character DEBUG-loud log ADR-014 promised but TASK-041 didn't land: in the Watch app model's `characterDisplay`, when `snapshot != nil` ∧ `snapshot.character == nil`, log through `debugLoud` (the invariant-regression discipline — cross-version skew cannot ship in Phase 1, both targets update together).

**R8 — FOLD F-2 (REVIEW-TASK-041).** ADR-014's wording ("the pet canvas slot is skipped") contradicts the pinned behavior (GlanceView HOLDS the slot with the palette blanket — no layout jump). Doc-only edit to `decisions/ADR-014-watch-character-read-model.md`: reconcile to the held-slot phrasing. No code change.

**R9 — UI wiring + a11y + raise-to-pat.** The Pat pill becomes a real action (button trait + action; its label already exists and the composite pre-announces "Pat button." — VoiceOver users act through the pill); the canvas tap works by touch and stays INSIDE the composite a11y element (no duplicate a11y action — the composite's contract is UX §10's exact wording). The settling-in state structurally exposes NO pat targets (already true — keep it true). FR-17 AC-1 (raise-to-pat ≤ 5 s) is structural: W1 is the root surface with immediate targets; assert the flow in the UI suite, don't build machinery. No new user-facing copy exists in this task (pat label + settling line ship from TASK-041) — zero catalog changes.

**R10 — Structural guards + mutation bites.** ≥ 2 structural guards in the established style: (a) a census/discipline guard that no Watch-app code touches the journal except through the persister actor (grep-style guard over `Apps/MomoWatch/`); (b) a guard pinning that app code never resolves the apply gate raw (the standing O5 guard — extend/keep green). ≥ 2 mutation bites with sha256-verified restores (the TASK-040/041 pattern): e.g., flip the seq formula's watermark term → exactly the full-prune monotonicity test goes red; flip the completion estimator's `==` to `>=` → the estimator truth-table test goes red.

## Files / Areas Likely Affected

- `Sources/MomoKit/`: `StoreRules.swift` (epoch filename), NEW small epoch store file, `IntentJournal.swift` (+`wipe()`), tests.
- `Apps/MomoWatch/`: `MomoWatchAppModel.swift` (+epoch/pat/journal/prune/reaction/haptic seams; extend via a same-target extension file if the budget demands — the `+Watch` precedent), `MomoWatchTransport.swift` (+send), `GlanceView.swift` (pat capture + sampler), NEW files registered in the Xcode project (pbxproj file refs only), Watch unit tests + UI tests.
- `decisions/ADR-014-watch-character-read-model.md` (R8 doc-only), `decisions/ADR-015-watch-pat-presentation.md` (already authored).
- **NOT touched:** `Sources/MomoCore/**` (frozen), `Sources/MomoCharacter/**` (frozen — ADR-015 D1), `Apps/Momo/**` (receive path shipped; the iPhone needs nothing).

## Dependencies

- TASK-041 DONE (`4407544`): snapshot store + consumption + W1 + inert targets; ADR-014's `WatchCharacterDTO?`; `consumeWipe` awaiting its journal leg.
- TASK-040 DONE (`0719129`): the ENTIRE iPhone receive path (`didReceiveUserInfo` → `receiveWatchEvent` → `WatchReceivePlan`) — this task's drain lands on it unchanged.
- TASK-023 DONE: `IntentJournal`, `SyncState`, `WatchSyncGate`, DTOs (all headlessly proven).
- ADR-015 (this contract's binding presentation decisions).

## Constraints

- `MomoCore`, `MomoCharacter` frozen; **`Apps/Momo/**` must diff EMPTY** — if implementation discovers an iPhone change is unavoidable, STOP and record a blocker in the task notes + status.md; do not improvise.
- O1: one writer per journal/snapshot/marker file (all through the persister actor). O5: never raw `WatchSyncGate` in app code (the standing structural guard stays green).
- pbxproj: new-file registration only; the D-R3 (no app-to-app target dependency) check is MANDATORY on any pbxproj change.
- §27: zero entitlements/Info.plist changes (`transferUserInfo` needs none — TASK-040's session established the shape; if the build disagrees, VERIFY-AT-BUILD and record).
- UX-9: no freshness/error surface, ever; §25: no unverified claims — the haptic-type record cites headers, the feel verdict defers to TASK-044.
- File budgets per the coding rules (≤ 800 hard; prefer small focused files — the Watch app model may grow an extension file).
- No TODO/FIXME/HACK debt without a task attachment (§26).

## Acceptance Criteria

1. Pat (canvas or pill) gives an IMMEDIATE local micro-reaction, state-distinct per wakefulness (awake → `.tap` clip bounce; asleep → `.stir`, stays asleep), ≤ 1 s, fully offline (FR-17 AC-2); zero MomoCharacter diffs.
2. Haptics: pat → soft tick; the estimated completing pat → celebratory double REPLACING the tick; NOTHING else ever haptic on the Watch; both honor `hapticsEnabled` at pat time (UX §6.3 exact; ADR-015 D2/D3).
3. Every pat journals exactly one `IntentEvent` (source `.watch`, `.pat(gesture: .tap, zone: nil)`, own `localDayKey`/timestamp, epoch + monotonic seq per the pinned formula); the journal survives termination (file-backed NDJSON).
4. Drain: events ride `transferUserInfo`; the SHIPPED iPhone path applies exactly once (duplicates/replays are no-ops); the Watch prunes ≤ the snapshot watermark on epoch-matched receives; a stale-epoch watermark prunes nothing; the full-prune case never reuses a seq.
5. `consumeWipe` wipes the snapshot pair AND the journal before recording the count (F-3 order); post-wipe render is the settling-in line with no pat targets.
6. The epoch is generated at first launch, persisted, stable across relaunches, and its (re)generation wipes the journal.
7. F-1: the nil-character path is DEBUG-loud; R8: ADR-014's wording is reconciled (held slot).
8. AOD/glyph binds no reaction; Reduce Motion renders the reaction static; the settling-in state exposes no pat targets.
9. Gates: `swift test` green including all new suites; MomoKit line coverage ≥ 80 % floor held; both apps build zero-warning on the pinned simulators (SE 3rd gen `1F25E487-A78E-464C-95AF-0BD1A9B3E1BE`, Watch SE 3 44 mm `8A854895-225C-411B-89C1-B03337BFE957`); MomoWatchUITests green including the new pat-flow tests; standing discipline suites (import whitelist, banned vocabulary, token purity) green with no new exemptions.

## Required Tests

- **MomoKitTests:** epoch store (roundtrip; missing → nil; generation is caller-side), `IntentJournal.wipe` (present → gone; absent → ok, stays absent), prune epoch-match regressions stay green.
- **Watch unit tests (fake transport + throwaway directory):** pat appends EXACTLY one journal line with the pinned fields; seq formula: fresh (empty journal + no snapshot) → 1; full-prune (journal empty + epoch-matched watermark N) → N+1; epoch-mismatched watermark → journal-max + 1; mixed-epoch journal unaffected; estimator truth table (completing → double; otherwise tick; toggle off → none; questLine ≠ Q7 / missing inputs / overshoot → tick); `consumeWipe` removes journal + snapshot + records the count; receive steady-shape calls prune with the snapshot's watermark pair (epoch-matched — mismatched prunes nothing); reaction kind follows wakefulness and expires; transport send attempted once per pat with the journal event's bytes; F-1 nil path renders words-only (behavioral).
- **MomoWatchUITests:** pat-pill flow (launch → tap pill → glance still renders, no crash); canvas tap flow; the existing 3 tests stay green.

## Review Requirements

Fresh Jupiter reviewer per §10/§33: re-derive the spec from THIS file + the normative sources BEFORE reading code; adversarial. Explicit review targets: ADR-015 conformance (no new art; sampler binding; double-REPLACES-tick pinned by a named test; estimator is presentation-only), O1 single-writer over the journal, the seq monotonicity formula under prune, F-3 wipe order, the zero-iPhone-diff constraint, a11y contract (composite + pill), §25 honesty in all records. Record in `.claude/tasks/reviews/REVIEW-TASK-042.md` (APPROVED / APPROVED_WITH_MINOR_NOTES / CHANGES_REQUIRED / BLOCKED).

## Git Requirements

Branch `feature/EPIC-008-watch-sync` (continues from `2e65019`). The implementation agent does NOT commit (§9); the orchestrator makes ONE atomic commit after review: `feat(watch): TASK-042 watch pat — journaled intents, drain, micro-reaction + haptics`. Push immediately after (§13); record hash + push status.

## Status

IN_REVIEW — implementation complete 2026-09-11, all gates green (see Handoff). Awaiting the fresh independent reviewer (§10/§33).

## Implementation Notes

**(implementation agent, 2026-09-11).** All requirements R1–R10 implemented; AC 1–9 satisfied; every quality gate green. The details below are the reviewer's map.

### WKHapticType choices (R6; ADR-015 D3 — VERIFY-AT-BUILD, resolved)

Resolved against the watchOS 26.5 SDK header `WKInterfaceDevice.h:16–33` (cases enumerated verbatim in `LiveWatchHaptics`'s doc): the Swift overlay renames `playHaptic:` to `play(_:)` (watchOS 2.0+); a pat touches only the always-available cases. **tick → `.click`** (the single-pulse user-interaction tick — UX §6.3's "single soft tick" read literally). **celebration → `.retry`** — chosen for PULSE SHAPE (the set's double-pulse case); the NAME is mismatched (its iOS meaning is "retry"), disclosed here and in code. `.success` is single-pulse, `.notification` triple — neither is a "celebratory double". The on-wrist FEEL verdict is TASK-044's paired-hardware obligation (§25/§27 — no simulator feel claims were made anywhere).

### Reduce Motion mechanism (R5)

`reduceMotionOverlay(at:)` on the SAME `MomoDirectorState` — ADR-015's "existing reduced machinery", the render-only law of `MomoReduceMotion`. The sampler closure (`MomoWatchPat.reactionMotion()`) branches per-frame: `reduceMotion ? director.reduceMotionOverlay(at: time) : director.overlay(at: time)`. No Watch-side reduction logic exists.

### Reaction sampler wiring (R5; ADR-015 D1)

The rig's EXISTING `reactionMotion` sampler parameter is bound at the W1 call site (the one sanctioned MomoCharacter touch; zero MomoCharacter edits). Foreground branch binds `model.reactionMotion()`; the glyph/AOD branch binds NOTHING (the parameter's `.identity` default IS the stillness posture) — keeping TASK-041's exact glyph rig shape. `MomoDirectorState` is used as a NARROW CLIP RENDERER: no `.displayState`/touch/moment folds — the per-clip choreography is private/internal to MomoCharacter, so the type's public `overlay`/`reduceMotionOverlay` pair is the ONLY legal path to the authored `.tap`/`.stir` motion; ADR-015's rejected alternative was PORTING the director, which this does not do (rationale recorded on `reactionMotion()`). The director is seeded at init and re-seeded on every accepted steady receive — NOT folded per displayState (that would trigger wake/settle choreography, out of scope).

### Seq formula verification (R3)

`next = max(epochScopedJournalMax, epochMatchedWatermark) + 1` — pure in MomoKit (`WatchPatPlan.nextWatchSeq`), pinned by the named tests: fresh→1, journal-max floor, FULL-PRUNE MONOTONICITY (N+1, never 1), stale-epoch watermark inert, mixed-epoch journal never inflates, watermark-wins-when-larger. The derivation runs INSIDE the persister's mailbox with the journal read as its first statement; the watermark pair is read on the main actor immediately before submission (no suspension between) — together with the FIFO mailbox this makes every receive-interleaving safe (the ordering argument is recorded on `appendPat`). `appendPat` returns the journaled event or nil; the send happens ONLY on a landed append (a lost journal line is a lost pat, never a reused seq). `IntentJournal.append` gained `@discardableResult -> Bool` (the send's durability gate) — a MomoKit API delta, disclosed.

### Prune placement (R2b)

A SEPARATE mailbox job on every steady-shape receive, AFTER the snapshot persist (`pruneJournal`) — preserving TASK-041's `persister.persist(` census == 2 scanner leg. Epoch-matched only (a stale-epoch watermark prunes nothing, pinned in MomoKit).

### F-1 log mechanism (R7 fold)

The nil-character DEBUG-loud fires ONCE per `snapshotSeq` via an `@ObservationIgnored` memo — an unconditional trap would crash-loop DEBUG on every body render. The words-only render itself is unchanged TASK-041 behavior.

### No-Watch-unit-target posture (accepted since TASK-040 F-6/D-7)

Pure logic (event shape, seq formula, estimator, pending count, reaction map) lives in MomoKit and is headlessly tested (27 tests). Wiring is pinned structurally (WatchPatScan: 19 tests, fixture self-tests in both stub directions + real-tree standing tests). Flows (pill/canvas pat) run as MomoWatchUITests (5 total).

### Disclosed deltas (each deliberate)

1. **Heart backlog** — the pat reaction is motion-only; the heart burst is ADR-015's recorded backlog item, not silently dropped.
2. **Mid-flight reaction cut** — a re-seed (steady receive) replaces the director wholesale, so a playing reaction may be cut by the returning snapshot's echo. Accepted: snapshot arrival is rare and the cut is a calm still frame; the alternative (reaction continuation state) is out of scope.
3. **Tempo context is per-seed** — the director seeds from the snapshot's character alone; no tempo context rides the wire (04 §9.2's four-field mirror is binding).
4. **Estimate double-fire window** — two hair-trigger pats can both read the same pre-append pending count (mailbox reads serialize, but both may precede both appends): a doubled celebration in the sub-second window is ADR-015 D2's disclosed benign false-positive shape; presentation-only, nothing stateful.
5. **`IntentJournal.append` now returns Bool** (public MomoKit API change, `@discardableResult`) — the send's durability gate needs the append's outcome; existing callers unaffected.
6. **consumeWipe's journal leg routed through the persister extension** (`wipeJournal`) instead of constructing `IntentJournal` inline — keeps the O1 census (`IntentJournal(` in exactly ONE Apps/MomoWatch file) true and the log message neutral.
7. **Cross-file extension access levels** — `storeDirectory`/`transport`/`persister`/`wallClock`/`calendar`/`reactionDirector`/`debugLoud` are internal (annotated) so the pat seam's same-target extension can use them (Swift `private` is file-scoped; the `MomoAppModel+Canvas` precedent).
8. **`/opt/extra/lib` ld warning** — machine-level `LIBRARY_PATH` environment noise, present on every build of this repo on this machine; NOT project-configured, not introduced by this task, no project change could remove it. The Watch/iPhone targets themselves compile warning-clean.

### File inventory (lines)

- MomoKit: `WatchPatPlan.swift` 150 (new), `WatchSessionEpochStore.swift` 153 (new), `IntentJournal.swift` 281 (append Bool + prune/wipe), `StoreRules.swift` 229 (journal file name).
- Watch target: `MomoWatchPat.swift` 190 (new), `MomoWatchPersister+Journal.swift` 117 (new), `MomoWatchAppModel.swift` 465 (epoch/F-1/wipe/director/receive-prune), `GlanceView.swift` 258 (pat targets + sampler branch), `MomoWatchTransport.swift` 135 (sendUserInfo).
- Tests: `WatchPatPlanTests.swift` 271, `WatchSessionEpochStoreTests.swift` 92, `IntentJournalWipeTests.swift` 92, `MomoWatchPatScanTests.swift` 303, `Support/WatchPatScan.swift` 225 (new), `MomoWatchUITests.swift` 217 (+2 flows).
- pbxproj: 8 added lines (registration only, verified by diff; D-R3 re-verified post-edit — both app targets `dependencies = ()`).
- Frozen surfaces: `Apps/Momo/**` diff-EMPTY (git status: 0 files); `Sources/MomoCore/`, `Sources/MomoCharacter/` untouched; no entitlements/Info.plist/capability changes; no catalog changes (R9 copy law).

## Reviewer Findings

APPROVED_WITH_MINOR_NOTES — REVIEW-TASK-042: all gates green (swift test 1102/108, both xcodebuilds, UI 5/5); 3 reviewer probes bit precisely with sha256-verified restores; 1 Minor (F-R1 journaled-but-never-sent crash-window drain gap, contract-conformant, follow-up sweep recommended) + 4 Notes — full record in `.claude/tasks/reviews/REVIEW-TASK-042.md`.

## Completion Evidence

(Orchestrator, 2026-09-12. Every gate reproduced personally by the orchestrator AND independently re-run by the reviewer on the post-probe, sha256-restored tree.)

- **Tests:** `swift test` **1102 tests / 108 suites PASSED** (pre-task baseline 1056/104; +46 = 27 pure-logic + 19 scan). MomoWatchUITests **5/5 TEST SUCCEEDED** (2 new pat flows + 3 existing).
- **Coverage:** MomoKit **90.79 % lines** (1738 total / 160 missed) — floor ≥ 80 % held; new `WatchPatPlan` 100 % lines, `WatchSessionEpochStore` 77.6 %, `IntentJournal` 74.7 %.
- **Builds:** MomoWatch + Momo **BUILD SUCCEEDED**, zero touched-file warnings (only the pre-existing machine-level `/opt/extra/lib` ld noise — delta 8).
- **Mutations:** implementer 3 bites + reviewer 3 independent probes (P1 estimator Q7-guard removal → non-Q7-estimate red; P2 `journalMaxSeq` epoch-filter drop → mixed-epoch red, journalMax 99 vs 2; P3 `.waking`→`.stir` flip → reaction-kind red). Every bite red-then-green; **18-file sha256 sweep byte-identical after restore**.
- **Frozen surfaces:** `Apps/Momo/**` diff-EMPTY; `Sources/MomoCore/` + `Sources/MomoCharacter/` untouched; pbxproj +8 registration-only lines (D-R3 re-verified at source — both app targets `dependencies = ()`); no entitlements/Info.plist/capability/catalog changes.
- **Review:** APPROVED_WITH_MINOR_NOTES (§10) — commit permitted; findings routed as recorded under Reviewer Status.
- **Commit:** ONE atomic task commit by the orchestrator — `feat(watch): TASK-042 watch pat — journaled intents, drain, micro-reaction + haptics` (implementation + tests + review record + ADR-014 wording + this task file moved to `completed/`), branch `feature/EPIC-008-watch-sync`; hash recorded in status.md Recent Commits.
- **Push:** pushed to `origin` immediately after the commit (§13); result recorded in status.md Recent Pushes.

## Handoff

### Completed

R1 epoch store + generation journal-wipe; R2 journal legs via the persister actor (+ `IntentJournal.append -> Bool` durability gate, `wipe()` wired into `consumeWipe` in F-3 order, steady-receive prune after persist); R3 pat flow (immediate reaction fold → deferred durable leg: estimate → haptic → append → send-only-if-journaled) + pinned seq formula + estimator; R4 `sendUserInfo` over `transferUserInfo`; R5 state-distinct micro-reaction via the rig's sampler seam + `reduceMotionOverlay`; R6 haptic seam (`tick→.click`, `celebration→.retry`) gated at pat time; R7 F-1 once-per-snapshot memo; R8 ADR-014 wording reconciled; R9 pill Button + canvas tap capture (composite a11y untouched); R10 three structural guards + three sha256-restored mutation bites + full gates.

### Files Changed

Modified: `Sources/MomoKit/IntentJournal.swift`, `Sources/MomoKit/StoreRules.swift`, `Apps/MomoWatch/MomoWatchAppModel.swift`, `Apps/MomoWatch/GlanceView.swift`, `Apps/MomoWatch/MomoWatchTransport.swift`, `MomoWatchUITests/MomoWatchUITests.swift`, `Momo.xcodeproj/project.pbxproj` (+8 registration lines only), `.claude/tasks/decisions/ADR-014-watch-character-read-model.md` (wording), this task file. New: `Sources/MomoKit/WatchPatPlan.swift`, `Sources/MomoKit/WatchSessionEpochStore.swift`, `Apps/MomoWatch/MomoWatchPat.swift`, `Apps/MomoWatch/MomoWatchPersister+Journal.swift`, `Tests/MomoKitTests/{WatchPatPlanTests,WatchSessionEpochStoreTests,IntentJournalWipeTests,MomoWatchPatScanTests}.swift`, `Tests/MomoKitTests/Support/WatchPatScan.swift`. **`Apps/Momo/**` diff-EMPTY; `Sources/MomoCore/` + `Sources/MomoCharacter/` untouched; no entitlements/Info.plist/capability/catalog changes.**

### Tests Run

1. `swift test` (full package): **1102 tests / 108 suites, PASSED** (pre-task baseline 1056/104; +46 = 27 pure-logic + 19 scan).
2. MomoKit coverage (measured immediately after `swift test --enable-code-coverage`): **lines 90.79%** (1738 lines, 160 missed) — gate ≥ 80% MET. New files: `WatchPatPlan` 100%, `WatchSessionEpochStore` 77.6%, wipe tests 100% of their surfaces.
3. `xcodebuild -scheme MomoWatch -destination 'id=8A854895-225C-411B-89C1-B03337BFE957' build`: **BUILD SUCCEEDED**, zero target warnings (only pre-existing machine-level `LIBRARY_PATH` noise — see Implementation Notes delta 8).
4. `xcodebuild -scheme Momo -destination 'id=1F25E487-A78E-464C-95AF-0BD1A9B3E1BE' build`: **BUILD SUCCEEDED**.
5. `xcodebuild ... -only-testing:MomoWatchUITests test`: **TEST SUCCEEDED — 5/5** (2 new pat flows + 3 existing).
6. Mutation bites (each sha256-hashed before, restored, hash-verified identical after): (a) `nextWatchSeq` watermark term dropped → FULL-PRUNE MONOTONICITY red (next→1, expected 4) + watermark-wins red; (b) estimator `==`→`>=` → OVERSHOOT test red (2 assertions); (c) second `IntentJournal(` touch in `MomoWatchAppModel.swift` → real-tree journal-census guard red ("2 files"). All suites green after each restore.

### Test Results

All green. No skipped, no TODO debt, no disabled tests.

### Known Issues

- `/opt/extra/lib` ld warning: machine-level environment noise (disclosed delta 8) — pre-existing, not actionable in-repo.
- Haptic FEEL (`.click`/`.retry` pulse shapes) is header+behavior reasoning, not on-wrist verified — TASK-044's paired-hardware obligation (§25).

### Decisions Made

Director-as-narrow-clip-renderer (rationale on `reactionMotion()`); prune as separate mailbox job after persist (preserves TASK-041 census); `appendPat` returns the journaled event or nil (send gate); F-1 once-per-snapshotSeq memo; consumeWipe routes its journal leg through the extension (O1 census); cross-file extension internals (the `+Canvas` pattern); heart stays backlog. Full list with reasons: Implementation Notes above.

### Reviewer Status

**APPROVED_WITH_MINOR_NOTES** — REVIEW-TASK-042 (fresh Jupiter, §33-unprimed; record `.claude/tasks/reviews/REVIEW-TASK-042.md`): 0 Critical / 0 Major / 1 Minor / 4 Notes. F-R1 Minor (journaled-but-never-sent crash window — no launch sweep; contract-conformant under R2/R3's three-leg scope) → routed to TASK-044 as an explicit sweep requirement. F-R2 Note (stale launch-read comments in `MomoWatchAppModel.swift`) → folded into TASK-043's incidental touch of that file. F-R3–F-R5 Notes: recorded, no action. All adversarial targets held; reviewer gates re-run green on the post-probe sha256-restored tree.

### Commit

NONE — implementation agent does not commit (§9). Orchestrator commits after review: `feat(watch): TASK-042 watch pat — journaled intents, drain, micro-reaction + haptics`.

### Push

NONE (follows the commit).

### Recommended Next Step

Spawn the fresh REVIEW-TASK-042 agent (task #134): read this task file + Implementation Notes, re-derive from ADR-015/ADR-014/05 §6.4/§6.6, review the working tree on `feature/EPIC-008-watch-sync`, re-run the gates, and record findings in `.claude/tasks/reviews/REVIEW-TASK-042.md`. Then the fix loop → atomic commit + push (#135).

HANDOFF-COMPLETE TASK-042
