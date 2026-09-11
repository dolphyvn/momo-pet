# TASK-035 — Feed / Play / Care flows (FR-6/7/8; UX §5.2–5.4; 04 §6.2–6.3)

## Parent Epic

EPIC-007 — iPhone Home Experience (task 5 of 9). Branch: `feature/EPIC-007-iphone-home`. Record when DONE: `.claude/tasks/completed/TASK-035-feed-play-care.md`.

## Objective

Complete the care-interaction loop on the composed, touch-live Home: the three action-row families produce their engine-distinct flows end-to-end — feed (meal / politely-full refusal / nibble variants), play (the UX-3 fingertip-follow round with the early-exit "Done" pill and the completion count), care (tuck-in within its evening window, nap when Drowsy/Exhausted) — with their copy pools landed (accessibility-only `react.feed/.play/.care` + the VISUAL `care-moment` fixed lines), the copy epoch bumped 3→4, the VoiceOver announcement gate widened beyond touch, and the `.fingertip` play follow wired. Engine semantics are FROZEN — this task CONSUMES `InteractionSemantics`/`HandshakeMachine`/the frozen director; it edits `Sources/MomoCore/` only inside the sanctioned `CopyRules` carveout and `Sources/MomoCharacter/` only through the ONE disclosed minimal seam this contract authorizes (R6).

## Context (current state at `2264f35`)

- Home is composed (TASK-033 `f1668b7`) and touch-live (TASK-034 `2264f35`): `HomeView` hosts the rig (`MomoRigView(…, reactionMotion: appModel.reactionMotion())`), the gesture overlay (`HomeCanvasTouchLayer`), `HomeActionRowView` with all five pills (Pat/Feed/Play/Tuck in/Nap) already routed via `appModel.interact(action.intent)` → `MomoAppModel.interact(_:)` (`Apps/Momo/MomoAppModel.swift:301-311`) which assembles the `InteractionIntent` and applies trigger `.interaction`.
- `MomoAppModel` owns the director (`director: MomoDirectorState`, :163), folds it per scene phase (:279-295), and exposes the report seam `submit(_ report: CharacterReport)` (:316-318, trigger `.characterReport`) — **but nothing drains `director.reports` into it yet** (`MomoReactionDirector.reports`, `Sources/MomoCharacter/MomoReactionDirector.swift:62`, header: "drain `reports` for the engine"). The play count is the FIRST report-consumed effect, so this drain is load-bearing (R2).
- Engine (frozen, `Sources/MomoCore/InteractionSemantics.swift` + `HandshakeMachine.swift`):
  - **Feed** — full (0–30 min) → `politelyFull` refusal (:225, zero penalty, **count still applies**); eating vs nibble by `satietyPhase == .recentlyFed` × `InteractionRules.nibbleEffectMultiplier` (0.25, `InteractionRules.swift:53`, :227); asleep/settling → `gentleDecline`; Drowsy/Exhausted → sleepy nibbles. Every feed counts (I-1).
  - **Play** — authorization sets `activity .playing` + `pendingHandshake(.play)` + mints the token + plan `react.playReady` (:296-297), **NO count/effects at auth**; the unified cease (`HandshakeMachine.swift:103-117`) fires on **`playRoundFinished` OR `handshakeCancelled(.play)`** — a started-and-cancelled round counts exactly once; a never-started round (declined auth) is countless. Mid-round play → `react.cheer`; Exhausted/sleeping/settling → stir; waking → warm decline.
  - **Tuck-in** — the 20:00 gate is engine-side (`InteractionRules.isTuckInWindow`, `InteractionRules.swift:123`): asleep → `blanketAdjust` **counts** (:354); settling → warm reaffirm, **no count**, settle still completes (:357); waking/round-in-flight → decline.
  - **Nap** — Drowsy/Exhausted in `.awake`/`.waking` → `.napping` + careCount +1 + quest `.care` tick; asleep/settling → gentle decline; playing/Energetic/Relaxed → decline.
- Choreography (frozen, `MomoHandshakeChoreography.swift`): invite 2.4 s (:86), followBaseline 12.0 (:92), drowsyFollow 8.0 (:93), restGrace 2.0 (:99), restSoloFloor 10.0 (:100), restSoloTail 3.0 (:101), followDeadline 16.0 (:105), payoff 4.0 (:109); worst case 22.4 s (:117) inside UX-3's ≤ 30 s. The director ALREADY runs the full round from a `.plan(react.playReady)` event, solo (rest-rule path) — `.fingertip(offset:moving:at:)` exists in the frozen enum (`MomoReactionState.swift:28`, offset in grid units; `followMotion` normalizes by /300) but has NO app-side sender.
- `MomoCharacterEvent` has exactly 7 events (`MomoReactionState.swift:11-33`): `plan`, `displayState`, `touchBegan`, `touchEnded`, `fingertip`, `appHidden`, `appShown` — **no play-stop event**; hence R6's seam.
- Copy state: catalog has ONLY `momo.line.react.touch.00–04` (5 lines, epoch 3); `reactLineCount` returns 1 for feed/play/care (`CopyRules.swift:133-138`); `LineSelection.reactLineKey` already mints `lineKey` on every plan (0-based, `%02d`), so feed/play/care keys currently resolve nil. The `care-moment` CONTEXT slot "waits for TASK-035" (`CopyRules.swift:32`, :144). `HomeCopyKeys` has `ambientLineKey` + `greetingLineKey` (fixed 01–03 lookup); the contextual-line resolver (`HomeReadModel`, `HomeCopyKeys.swift:12-17` doc) is greeting ?? ambient and documents UX-12's extension as owed to TASK-034/035.
- Pills: visible labels "Feed"/"Play"/"Tuck in"/"Nap" are DISCLOSED view chrome (`HomeActionRowView.swift:63-87`); UX §10.4 (:434) pins the VoiceOver labels verbatim — **not yet applied** (R8).
- `LineSelection.pick` = ONE SplitMix64 draw over `DaySeed.make(petID:localDayKey:epoch: CopyRules.copyEpoch, salt: .copy)`, `% poolCount` (`LineSelection.swift:37-53`).

## Requirements

**R1 — Report drain (the play count's missing leg).** `foldDirector` (or the director-fold call sites) drains `director.reports` and routes each through `appModel.submit(_:)` so `.characterReport` triggers reach the engine; drain must be exactly-once per report (clear after submit — the director appends, never re-fires) and ordered by report instant. After this, a completed play round lands its count and effects through the unified cease; verify a `playRoundFinished` with nothing pending is a harmless engine no-op (it is — `HandshakeMachine` guards on `pendingHandshake?.kind`). This is a "default silently serves" wiring leg — R9's structural guard applies.

**R2 — Play round UX (UX §5.3).** Tap [ Play ] → authorization (invite beat renders through the existing `.plan` path; nothing else changes at auth). While a round is in flight, canvas drags stream director `.fingertip(offset:moving:at:)` events (convert the canvas-local point to the grid-unit offset the frozen choreography expects; sampling cadence is the drag stream, `moving` = whether the finger moved since the previous sample) INSTEAD of pat intents; after the round ceases, touch routing reverts to TASK-034's pat classification. The quiet "Done" pill (view chrome, "Done") appears on Home ~5 s after round start (≥ 4.5 s, ≤ 6 s band — authored, disclose the exact value), disappears when the round ends by any path. Tap [ Done ] → R6's stop event → the round ceases → the count lands (started-and-cancelled counts).

**R3 — Feed UX (UX §5.2).** Tap [ Feed ] routes `.feed` (already wired) — the meal animation/prop is the frozen director's business; do NOT add meal UI. The politely-full refusal renders its VISUAL line per R5 and UX-12; the tray/meal fade is frozen choreography. No cooldown/portion/currency UI (D18 red line).

**R4 — Care UX (UX §5.4).** Tuck-in/nap pills already gate via the read-model `actionPills` (tuck-in evening window, nap waking+Drowsy/Exhausted, daytime = Feed+Play only, no disabled ghosts) — verify the gating reads exactly the engine rules (chip visible ⟺ engine would accept or warmly reaffirm; a chip must never route into a guarantee-declined state) and pin it. Daytime absence is already UI-tested; add the 20:30 fixed-clock tuck-in presence + flow.

**R5 — Copy landing + epoch 3→4 (the §4.10 obligation).**
- **Spoken pools (accessibility-only, 04 §10.1 rule 7 / §10.4; UX-8):** author `momo.line.react.feed.00–05`, `momo.line.react.play.00–05`, `momo.line.react.care.00–05` — SIX lines each, ≤ 12 words, warm/calm, no numbers, no banned vocabulary (the scan covers new catalog strings automatically), third-person-present register matching the touch pool. Contract-authored verbatim (use the typographic apostrophe U+2019 everywhere, including the O1 normalization of `touch.03`):
  - feed: "Momo's ears perk up at the meal." / "Momo circles the tray, delighted." / "Momo takes a tiny, polite bite." / "Momo munches with quiet little sounds." / "Momo settles back, warmly full." / "Momo looks up as if to say thanks."
  - play: "Momo perks up, ready to play." / "Momo bounces once on the spot." / "Momo's tail wiggles with excitement." / "Momo spins in a small happy circle." / "Momo crouches low, ready to pounce." / "Momo glances at you, eyes bright."
  - care: "Momo snuggles under the blanket." / "Momo's breathing slows, soft and even." / "Momo curls into a round little ball." / "Momo yawns a tiny yawn." / "Momo tucks its paws in close." / "Momo drifts off, warm and safe."
  - Each key's xcstrings `comment` cites its authority (FR-6/7/8; UX-8 accessibility-only, never rendered as body copy). The drawn day-stable line accompanies whichever reaction in the family plays (same genericity as the touch pool — disclosed).
- **Visual care-moment lines (04 §10.1 rule 7's "few care moments"; UX-12's "interaction reaction" element):** ADJUDICATION (contract ruling, OBS-D precedent — a fixed lookup is not a "selection", no seed/epoch machinery): `momo.line.care-moment.<nn>` is a FIXED lookup by moment kind, never drawn — a refusal line must say refusal; a day-stable draw cannot serve both tuck-in and refusal. Fixed indices: `01` tuck-in "Momo snuggles down under the blanket." · `02` refusal "Momo is full and thanks you with a nod." · `03` blanket-adjust "Momo shifts sleepily under the blanket." `slotLineCount(.careMoment)` STAYS 1 with its comment updated (mirrors `greeting`'s "never through this count" reading). `HomeCopyKeys` gains `careMomentLineKey(for:)` mirroring `greetingLineKey`'s shape; nap/settling-reaffirm have NO visual line (animation only — rule 7's restraint).
- **Contextual-line priority (UX-12 verbatim: interaction reaction > greeting > ambient):** extend the resolver so the latest care-moment line (tuck-in settle, refusal, blanket-adjust — the only VISUAL reaction class) outranks greeting and ambient; feed-enjoys/play spoken lines stay accessibility-only and do NOT enter the visual slot (rule 7). Presentation state: the app model tracks the latest care-moment key in memory (never persisted — mirrors the greeting stamp's presentation-owned fading); it holds until superseded by a newer care moment or app relaunch — disclose this retention plainly; it rides the SAME owner item as greeting domination (REVIEW-TASK-033 OBSERVATION-A, ambient-visibility retune).
- **`reactLineCount`:** touch stays 5; feed/play/care become 6. **`copyEpoch` 3→4** with the header/comment updates (CopyRules :32, :46-59, :127-138, :144 — replace every "waits for TASK-035"/"EPIC-006/007" future tense with the landed state).
- **Epoch-4 pins (fixture pet `7C47A9C4-2E5F-4B8A-9C1D-3E6F8A2B4C0D`, day `2026-09-08`, salt `.copy`):** seed `0xda4187ce48ff0bb7`, draw `0xfdb4bc3ce6f541d3`. NOT same-residue: **ten-line slot pins MOVE `.02`→`.07`** (all four time slots — update `CopySelectionPinnedTests`; green suites go RED first — do not misread the re-pins as a defect); **touch `.02` SURVIVES** (draw mod 5 = 2); **feed/play/care (6 each) pin `.01`** (draw mod 6 = 1). Derivation replica validated against epochs 2/3's known-correct values before trusting these numbers — re-derive independently (do not copy) and record your derivation in the task file.

**R6 — The ONE disclosed minimal `MomoCharacter` seam (epic-pre-authorized).** Add a new `MomoCharacterEvent` case for the play early-exit — `case playStopped(at: Double)` — and its director handling: cancel the in-flight play layer via the SAME displacement-cancel machinery `applyHidden` uses for handshakes, emit `handshakeCancelled(.play)` exactly-once when (and only when) a round was actually in flight (no-op otherwise — no round, no report), then return to the underlying state. NOT `.appHidden`-as-lie (it must not hide other layers or pause the clock), NOT UI-only dismissal (the engine must see the cancellation so the count lands). Touch ONLY the files the exhaustive switches force (expect: `MomoReactionState.swift` the enum + timestamp, `MomoReactionDirector.swift` the apply case + handler; `MomoReduceMotion.swift` ONLY if its switches are over events — verify; RM is render-only, the cancelled round's RM still may fall out naturally). Every touched frozen file is disclosed in the task file with its diff rationale; the diff stays minimal (no reformatting, no drive-by edits). Exhaustive no-`default` switches make any missed site a build failure — that census is the design.

**R7 — Announcement gate widening (TASK-034's in-code promissory note).** `SpokenReaction.announcementKey` (in `Apps/Momo/CanvasTouch.swift`) currently admits ONLY `react.touch.*`; widen to admit `react.touch.*`, `react.feed.*`, `react.play.*`, `react.care.*` (all four families; keep excluding slots/greetings/vocab). Spoken lines remain VoiceOver-announced, never rendered (UX-8).

**R8 — §10.4 verbatim a11y labels.** The action row's ACCESSIBILITY labels become the UX §10.4 (:434) verbatim strings: "Feed Momo", "Play with Momo", "Tuck Momo in", "Nap time" (Pat keeps its existing accessible form). Visible labels stay the short disclosed chrome ("Feed", "Play", "Tuck in", "Nap"). Update `HomeActionRowView`'s "spoken label never abbreviates" comment to match.

**R9 — Structural guards for every new wiring leg (TASK-034 F-1 rule).** Each leg whose failure mode is "the default silently serves" gets a source-read structural guard in the `RigDisciplineTests` shape (read the file, pin the exact construction, non-vacuity pinned, mutation-bitten): (a) the report drain reaches `submit`, (b) the in-flight-play drag branch sends `.fingertip`, (c) the Done pill's action sends R6's `playStopped` event (not `.appHidden`, not a local-only dismissal). Extend the existing helper pattern; do not weaken the F-1 guard.

**R10 — Scope pins.** No new engine semantics (`Sources/MomoCore/` diff = `CopyRules.swift` ONLY); no new character motion beyond R6's seam; no quest-moment work (TASK-036); no Room/Settings work (037/038); no Watch transport; no rendered react text anywhere; no new pills; the meal/tray visuals stay frozen choreography.

## Files / Areas Likely Affected

- `Sources/MomoCore/CopyRules.swift` (epoch, counts, comments — the sanctioned carveout)
- `Sources/MomoCharacter/MomoReactionState.swift`, `MomoReactionDirector.swift` (+ `MomoReduceMotion.swift` only if switches force it) — R6, disclosed
- `Apps/Momo/MomoAppModel.swift` (report drain, fingertip send, playStopped send, care-moment presentation state)
- `Apps/Momo/HomeView.swift` / `HomeActionRowView.swift` (Done pill, a11y labels, contextual-line care-moment consumption)
- `Apps/Momo/CanvasTouch.swift` (announcement gate) and/or `HomeCanvasTouchLayer.swift` (in-flight drag branch)
- `Sources/MomoKit/HomeCopyKeys.swift` (+ maybe `HomeReadModel.swift`) — careMomentLineKey + resolver extension
- `Apps/Shared/MomoCopy.xcstrings` (18 react keys + 3 care-moment keys + touch.03 normalization)
- Tests: `Tests/MomoCoreTests/CopySelectionPinnedTests.swift` (+1 epoch pin), `Tests/MomoKitTests/` read-model/contextual tests, `Tests/MomoCharacterTests/` (playStopped behavior + RM mirror + structural guards), `Apps/Momo/MomoUITests` (MomoHomeUITests additions)
- pbxproj only if new files are added (prefer extending existing files)

## Dependencies

TASK-034 (DONE, `2264f35`). Uses: frozen engine (EPIC-004), frozen director/choreography (EPIC-006), the TASK-031 facade + TASK-033 read-models/pills.

## Constraints

- All agents Jupiter; fresh implementer, fresh adversarial reviewer (§9/§10/§33).
- Frozen surfaces: `Sources/MomoCore/` except the `CopyRules` carveout; `Sources/MomoCharacter/` except R6's disclosed seam. `docs/` untouched.
- D-R5: views never invoke the engine; everything routes through `MomoAppModel`.
- React lines are accessibility-only (never rendered); the 12-word rule on all new lines; banned-vocabulary scan stays green (new strings covered).
- Test before commit (§19): full `swift test` green; app UI suite green on pinned sim `1F25E487-A78E-464C-95AF-0BD1A9B3E1BE`; **Watch scheme build green** (MomoCharacter is shared — R6 touches it); zero source warnings.
- No commit by the implementer; the orchestrator runs the review chain and commits.

## Acceptance Criteria

1. Feed: hungry meal, recently-fed nibble (×0.25 visible), politely-full warm refusal (zero penalty, count still applies), asleep decline — each renders its engine-distinct clip on Home; the refusal shows the care-moment refusal line in the contextual line (E2E: second feed within 30 min).
2. Play: auth renders the invite; a full round auto-ends ≤ 30 s and lands exactly one count; Done after ≥ 5 s ceases the round and STILL lands the count; a declined auth (Exhausted/fixed-clock tricks aside — package-level) counts nothing; fingertip drags during a round stream `.fingertip` and don't fire pats.
3. Tuck-in: chip present from 20:00 (absent by day), settles to sleep and counts; already-asleep blanket-adjust counts; nap chip appears only waking+Drowsy/Exhausted and folds to `.napping`.
4. All 21 new catalog keys resolve; `reactLineCount` 5/6/6/6; `copyEpoch == 4`; the ten-line slot pins read `.07`, touch `.02`, feed/play/care `.01` — all with the golden seed/draw literals pinned.
5. VoiceOver: react announcements cover all four families; action row exposes the §10.4 verbatim labels; the canvas stays ONE element (TASK-034 pins hold).
6. Every R9 structural guard bites (exactly its own leg fails under a targeted mutation, restored byte-identically).
7. Full suites green per Constraints; frozen-surface diffs exactly the sanctioned carveout + disclosed seam.

## Required Tests

Package: CopyRules constants + epoch pins (renamed for 4); CopySelectionPinnedTests re-pins (all seven families/slots) with the golden seed/draw literals; announcement-gate widened-family pins; careMomentLineKey fixed-lookup pins; contextualLineKey priority (careMoment > greeting > ambient) + retention; director `playStopped` behavior (cancels in-flight round, exactly-once report, no-op without a round) + RM mirror + event-census; AppModelPlanCore `.characterReport` play-count path (auth ≠ count; report = count exactly once; cancelled-round counts). UI (MomoHomeUITests): feed-then-feed refusal line in the contextual line; play round Done-pill flow (appears in band, tap ceases); tuck-in at 20:30 fixed clock (chip present → tap → tuck-in line renders); action-row a11y labels verbatim; nap chip absent at daytime. Structural guards per R9.

## Review Requirements

Fresh unprimed reviewer per §10/§33 (requirements + diff + architecture + tests; NO "the implementation is correct" priming; independently re-derive the epoch-4 numbers and try to disprove the wiring legs). Record: `.claude/tasks/reviews/REVIEW-TASK-035.md` (verdict APPROVED / APPROVED_WITH_MINOR_NOTES / CHANGES_REQUIRED / BLOCKED). Fix loop per §11 if required.

## Git Requirements

One atomic commit: `feat(home): TASK-035 wire feed/play/care — pools, play round, report drain` — task ID in the message; include the task file (moved to completed/ at closeout per the TASK-033/034 pattern), the review record(s), and the status/epic refresh; push to `feature/EPIC-007-iphone-home` immediately after (§12/§13).

## Status

IN_REVIEW (implementation + verification complete 2026-09-11: package 906/92 green, UI suite 17/17 green on the pinned simulator at the final merged tree, MomoWatch build green, zero warnings from touched files; awaiting the independent review agent).

## Implementation Notes

**R1 — the report drain.** New `MomoDirectorState.drainReports()` (`Sources/MomoCharacter/MomoReactionDirector.swift`): returns the accumulated reports and clears the log. The mutator lives ON the director because `reports` is `public private(set)` — the app model can read it but can never clear it, so the exactly-once bridge needed a director-side API (disclosed; it is the R6 file's second, contract-anticipated addition alongside the seam — the contract's own header line "drain `reports` for the engine" is its authority). `MomoAppModel.foldDirector` applies the event to a successor, drains the successor, stores it, then submits each entry through `submit(_:)` in emission order — a report can never be delivered twice and causal order holds. Structural guard: `RigDiscipline.mentionsReportDrain` (R9a).

**R2 — the play round UX.**
- `HomeCanvasTouchLayer`: `onChanged` gates on `appModel.isPlayRoundInFlight` and routes drags to `appModel.sendFingertip(offset:moving:at:)` INSTEAD of the touch vocabulary; `onEnded` mirrors the gate (lift bookend sends `moving: false`; a round starting mid-drag falls through the normal lift path without firing a pat). Offset conversion: the canvas-local point relative to the stage center, scaled by stage side into `CanvasTouchLaws.stageGridSide` grid units (y-down, center-origin — the frozen choreography's space). Gesture bookends via `playTouchIsDown`: the FIRST sample of a contact sends `moving: false` with no travel delta (a fresh contact cannot compute a bogus movement), subsequent samples compare against the previous sample (`fingertipMovingPoints = 1 pt` threshold).
- Done pill: `MomoAppModel.donePillDelaySeconds = 5.0` — the exact authored delay (inside UX-3's 4.5–6 s band). The window opens once per round via a Task-based REAL-TIME delay (works under the frozen clock, which freezes only the canvas clock), is cancelled on round end, and visibility is DERIVED (`isPlayRoundInFlight && isDonePillWindowOpen`) so the pill closes on ANY round end — Done tap, natural finish, hide. `HomeView` hosts the pill as an overlay OUTSIDE the canvas's flattened accessibility element so VoiceOver keeps a separate tappable button; identifier `home.playDonePill`, label "Done". Tap routes `appModel.stopPlayRound()` → R6's `.playStopped` (structural guard R9c) — never a UI-only dismissal.

**R6 — the ONE disclosed MomoCharacter seam.** Every frozen file touched, with why:
- `Sources/MomoCharacter/MomoReactionState.swift` (+11 lines): the `case playStopped(at: Double)` enum member + its doc comment, and one line in the exhaustive `eventTime` switch. Nothing else.
- `Sources/MomoCharacter/MomoReactionDirector.swift` (+31 lines): the `apply` case routing to `applyPlayStopped(at:)`, which cancels an in-flight play through the SAME displacement-cancel machinery `applyHidden` uses (state layer → nil, fading remnant → nil, overlay returns to `.identity`), emits `handshakeCancelled(.play)` exactly-once ONLY when a round was in flight, and is a tolerated no-op otherwise; plus `drainReports()` (R1's API).
- `Sources/MomoCharacter/MomoReduceMotion.swift`: UNTOUCHED — its switches are over presentation state, not events, so the cancelled round's Reduce-Motion behavior falls out naturally; the twin suite pins it instead (+1 corpus test, 2 corpora).
- Adversarial-storm corpus in `MomoReactionDirectorTests` gained a `.playStopped` with no round owning the slot (no-op pin).
Engine side (frozen, untouched): the unified cease treats `.handshakeCancelled(.play)` with a matching pending token exactly like `.playRoundFinished` → `completePlayRound` — the started-and-cancelled round counts exactly once; stale/duplicate cancels are no-ops.

**R7 — announcement gate.** `SpokenReaction.announcementKey` lives in `Sources/MomoKit/CanvasTouch.swift`, NOT the contract's stated `Apps/Momo/CanvasTouch.swift` path — the type was assembled into the Kit package in TASK-031 (same type, same gate; path discrepancy disclosed). Widened to all four react families (prefix `momo.line.react.` + family in {touch, feed, play, care}); slots/greetings/vocab/moment classes and lookalike namespaces (`momo.line.reactx.*`) stay excluded. Pinned in `CanvasTouchTests` (`announcementGate` + `lawsPinned`'s prefix/family constants).

**R4 — pill parity.** The read-model `actionPills` gating was restated to read EXACTLY the engine rules: tuck-in chip ⟺ `InteractionRules.isTuckInWindow` && wakefulness ≠ `.waking` && activity ≠ `.playing`; nap chip ⟺ (drowsy ∨ exhausted) && ¬(asleep ∨ napping) && ≠ `.settling` && activity ≠ `.playing`. Designed consequences on existing pins (not defects): the tuck-in chip now appears in the 06:00–07:00 night shoulder (the engine accepts through 07:00) — `HomeReadModelTests.actionPillsGates`' 06:30 pin moved 2→3 pills; napping/exhausted/settling states gained the tuck-in chip where the engine would accept or warmly reaffirm. 20:30 presence was already pinned; the new UI flow test exercises it end-to-end.

**R5 — copy landing + epoch.**
- 21 catalog keys landed (18 react verbatim per contract, U+2019 throughout, each key's xcstrings `comment` citing its authority; 3 care-moment fixed lines). `touch.03` normalized to the U+2019 apostrophe per the contract's O1 note (the TASK-034 verbatim pin updated in place — designed).
- `reactLineCount`: touch 5, feed/play/care 6. `slotLineCount(.careMoment)` stays 1 with its comment updated (fixed lookup, never through the count — mirrors `greeting`). `copyEpoch` 3→4 with all "waits for TASK-035" future-tense comments replaced by the landed state.
- `HomeCopyKeys.careMomentLineKey(for:)` mirrors `greetingLineKey`'s shape; the contextual resolver reads careMoment > greeting > ambient (UX-12 verbatim). Nap/settling-reaffirm mint NO visual line (animation only).
- Retention: the latest care-moment kind is held in `MomoAppModel` MEMORY only — never persisted, survives until superseded by a newer care moment or app relaunch. Disclosed; rides REVIEW-TASK-033 OBSERVATION-A (ambient-visibility retune) as its owner item.
- **Independent epoch-4 derivation** (validated against epochs 2/3's known values before trusting): seed = SplitMix64 over (fixture pet `7C47A9C4-2E5F-4B8A-9C1D-3E6F8A2B4C0D`, day `2026-09-08`, epoch 4, salt `.copy`) = `0xda4187ce48ff0bb7`; draw = `0xfdb4bc3ce6f541d3`. Hex digit sum 142 → % 5 = 2: **touch `.02` SURVIVES** (the residue happens to be stable across the bump). Draw odd and ≡ 2 (mod 5) → % 10 = 7: **ten-line slots move `.02`→`.07`**. Mod 3 = 1 and odd → % 6 = 1: **feed/play/care pin `.01`**. Day-stability: the draw is over (pet, DAY, epoch) — `CareInteractionTests`' fixture uses `2026-09-09` for its night-shoulder tests, whose epoch-4 draw is index **4** (not 1); that file's three night-day lineKey pins read `care.04` with in-place comments, while its `2026-09-08` pins read `care.01`.
- Epoch parity re-pins (designed, R5's "green suites go RED first"): `EngineReduceTests`/`InteractionResponseTests`/`CareInteractionTests`/`PlayRoundTests` pinned the epoch-3 feed/play/care draw (`.00`); all moved to the epoch-4 draw for their fixture days (`.01` / `.04`). Touch pins (`.02`) untouched. The `CanvasTouchTests` `.00` reference is a gate-identity check (family membership), not a draw pin — untouched. Catalog verbatim tables pin CONTENT at keys 00–05 — untouched.

**R8 — a11y labels.** `HomeActionRowView.accessibilityLabel(for:)`: feed "Feed Momo", play "Play with Momo", tuckIn "Tuck Momo in", nap "Nap time"; visible chrome unchanged ("Feed"/"Play"/"Tuck in"/"Nap"); the header comment updated to the §10.4 rule. The switch is exhaustive (no default), so each kind MUST name its spoken label to compile. UI glass pins cover the three gates reachable at the glass under a frozen clock (feed/play at 09:00, tuckIn at 20:30); the nap gate (a drowsy/exhausted pet that is not asleep) is not deterministically reachable without unverified multi-day decay math — disclosed here rather than faked (§25).

**R9 — structural guards.** Three new `RigDiscipline` predicates + tests, each with a violation fixture proving it bites: (a) `mentionsReportDrain` — the app model must drain AND submit per entry; (b) `mentionsPlayFingertipSurface` — the gesture layer must gate on `isPlayRoundInFlight` AND stream `sendFingertip`; (c) `mentionsDonePillStopWire` — the pill identifier AND `appModel.stopPlayRound()` must both be present (a local-dismissal pill shape fails). The TASK-034 F-1 guard is untouched.

**R10 — scope check (at the verification tree).** `git status`: `Sources/MomoCore/` diff = `CopyRules.swift` ONLY (60 lines: epoch, counts, comments). `Sources/MomoCharacter/` diff = the two disclosed R6 files ONLY. `MomoReduceMotion.swift` untouched. No new pills, no meal UI, no quest/Room/Settings/Watch work, no rendered react text. Added file: `Tests/MomoKitTests/CareMomentTests.swift` (the new package suite). The UI tests extended `MomoUITests/MomoHomeUITests.swift` in place per the contract's "prefer extending existing files" pin — an interim standalone `MomoCareLoopUITests.swift` (which had required a 4-entry pbxproj registration) was consolidated into `MomoHomeUITests` and deleted, and the pbxproj reverted to byte-identical with HEAD, BEFORE the final §19 UI run (the standalone file's own earlier run — 4/4 passing, 17 total — validated the test logic; the merged file's run is the record). `git diff` contains no `print(`/TODO/FIXME/HACK/TEMP additions and no secrets (swept).

**Tests added (package, 19 tests + 1 suite; 906 total / 92 suites, 0 failures).**
- `CareMomentTests` (NEW suite, 7): fixed-lookup pin (01/02/03 verbatim keys); refusal classifies on the reaction alone; tuckIn via settle-token handshake; nap-settling → nil (no token); blanketAdjust on asleep + napping; reaffirm → nil on settling/awake; 7-reaction nil sweep across 3 states.
- `MomoHandshakeTests` (+4): stop cancels in-flight play exactly-once with identity overlay; stop without a round is a no-op (and never touches a running clip); late stop after resolution reports nothing new; stop never cancels a settle.
- `AppModelPlanTests` (+2): the count lands at the REPORT not the auth (auth → 0; cease → 1; duplicate cease → still 1); `.handshakeCancelled(.play)` counts once.
- `MomoReduceMotionTwinTests` (+1 test, 2 corpora): the Done-stop stream folds identically and renders RM-visibly (with and without an in-flight round).
- `RigDisciplineTests` (+3): the R9 guards.
- `MomoCatalogScaffoldingTests` (+1): the 21-key verbatim table; per-class counts now 97 keys.
- `HomeReadModelTests` (+1): contextual priority careMoment > greeting > ambient (+ rewritten `actionPillsGates` parity pins, + `careMoment` state-builder parameter).
- `CopySelectionPinnedTests`/`CanvasTouchTests`/`CatalogCopyLawTests`: epoch-4 pins (`.07` slots, `.02` touch, `.01` feed/play/care, golden literals); gate widened-family pins; copy-law scope 44→70 scanned lines (react + care-moment classes join the 12-word law).

## Reviewer Findings

**REVIEW-TASK-035 (round 1, fresh unprimed agent — APPROVED_WITH_MINOR_NOTES, 2026-09-11).** §33 adversarial: independently re-derived the epoch-4 numbers with a SplitMix64 replica VALIDATED against epochs 2/3's known-correct goldens BEFORE reading the epoch-4 values (agreeing: seed `0xda4187ce48ff0bb7`, draw `0xfdb4bc3ce6f541d3` → ten-line `%10=7`, touch `%5=2` survives, six-line pools `%6=1`); per-requirement PASS verdicts with file:line evidence for R1–R10; three mutation bites on the R9 guards (drain `let emitted = []`; both `sendFingertip` sites → `streamFingertip(`; `HomeView.swift:116` → `appModel.localDismissPill()`) each failing EXACTLY its own test, restored sha256-identically; UI suite re-run 17/17 and Watch build green independently. Findings: **F-1 (MEDIUM — FIXED in-task, see Fix Cycle below)** the play stillness ticker (`playTickerSeconds = 1.0`, `runPlayTicker`'s `moving: false` fold, the reconcile start wire — `MomoAppModel.swift:180/:586-592/:603-618`) is the passive round's ONLY fold source (edge-gated display-state folds are gesture-path-only), load-bearing for AC-2's solo auto-end, yet unguarded by R9 (zero Tests/ references); **F-2 (NOTE)** the Done-pill/reconcile double-start guard is instance-state (`playTickerTask == nil`), safe under `@MainActor` FIFO — first place to look if `apply` ever becomes reentrant/off-main; **F-3 (NOTE, pre-existing)** 19 actor-isolation warnings in `MomoUITests/MomoUITests.swift` (diff-empty file; whole-module recompile re-emits latent debt; lacks `@MainActor`) → routed to TASK-039; N-1 the R9 MARK "four" reading (now true via the fix); adjudications ACCEPTED: nap-label compile-only disclosure honest (§25), care-moment line memory-only retention contract-conformant (rides OBSERVATION-A), R7's `Sources/MomoKit/CanvasTouch.swift` path = contract erratum. Reviewer scope statement: pbxproj/docs/`MomoUITests.swift`/`MomoReduceMotion.swift` untouched.

**REVIEW-TASK-035-FIX (delta review, fresh unprimed agent — APPROVED_WITH_MINOR_NOTES, 2026-09-11).** Delta vs the round-1 reviewed tree provably **+43 insertions / 0 deletions** = `RigDisciplineTests.swift` +38 (zero deletions — no reviewed line modified; `readRigFile` moved :183-186→:202-205 while guard (a) held :158-161) + the task file +5; `MomoAppModel.swift` (the bite target) **sha256-identical** to the reviewed tree (`aa00873b…9fe79` = the round-1 restoration hash; numstat 170/17 as recorded); mtime forensics — exactly two files postdate the round-1 record, both accounted. The R9d predicate audited leg-by-leg (each leg unique in the real file; the comma-discriminated `moving: false,` claim re-derived — doc comments :174/:604 cannot satisfy leg 3; the gesture fold :428 is `moving: moving,`); the violation fixture proven genuinely non-vacuous (contains leg 2 exactly — the guard demands the whole wire, not any one leg). THREE bites on the real file (the required two plus payload perversion `moving: false,`→`true,`): cadence literalized, start wire removed, payload perverted — each failing EXACTLY `playStillnessTickerDrivesTheSoloRound` at :437:9, each restored sha256-identically. Full package rerun **907/92**; UI (17/17) + Watch gates carried over validly per the delta's §5 statement. Notes N-1 (fix-cycle prose erratum re "now", cosmetic), N-2 (leg 1's one independent bite = the authored `static let` shape), N-3 (substring guards cannot catch comment-entombment — the accepted trade of the textual-guard family; optional per-leg "exactly one uncommented occurrence" hardening recorded as a future candidate, never mid-review).

## Completion Evidence

- **Review chain:** REVIEW-TASK-035 APPROVED_WITH_MINOR_NOTES → F-1 fixed in-task by a fresh fixer agent (`fix-task-035-f1`) → REVIEW-TASK-035-FIX (delta) APPROVED_WITH_MINOR_NOTES. Both records in `.claude/tasks/reviews/`. No CHANGES_REQUIRED outstanding.
- **§19 gate at the FINAL tree (post-fix):** `swift test` = **907 tests / 92 suites, 0 failures** (baseline 887/91 → +19 tests/+1 suite implementation, +1 R9d fix; green by implementer, round-1 reviewer, delta reviewer). App UI suite: **17/17 TEST SUCCEEDED** (315.3 s; 13 baseline + 4 new care-loop tests) on the pinned iPhone SE 3rd gen `1F25E487-A78E-464C-95AF-0BD1A9B3E1BE` — carried over to the final tree validly per the delta review's byte-identity proof (delta test-file-only). MomoWatch: **BUILD SUCCEEDED** (scheme `MomoWatch`, Apple Watch SE 3 40mm, watchOS 26.5) — same carry-over basis. Zero compiler warnings from any touched file (the 19-actor-isolation pre-existing `MomoUITests.swift` debt disclosed as F-3 → TASK-039).
- **Scope evidence (R10):** `Sources/MomoCore/` diff = `CopyRules.swift` ONLY; `Sources/MomoCharacter/` diff = the two disclosed R6 files ONLY; `MomoReduceMotion.swift` untouched; pbxproj byte-identical with HEAD.
- **Commit:** `b8d181a` — `feat(home): TASK-035 wire feed/play/care — pools, play round, report drain` on `feature/EPIC-007-iphone-home`, with this task file (moved to completed/), both review records, and the status/epic refresh (§12).
- **Push:** `3a1698b..b8d181a` → origin — success (recorded in `.claude/tasks/status.md` Recent Pushes).

## Handoff

### Completed

R1 report drain (director-side `drainReports()` + app-model submit, exactly-once, causal order) · R2 play round UX (in-flight drag → `.fingertip` stream with bookends; Done pill, authored 5.0 s, derived visibility, R6 stop route) · R3 feed UX (refusal line at the glass; no meal/cooldown UI) · R4 care UX (pill gating restated to exactly the engine rules; 20:30 flow UI test) · R5 copy landing (21 verbatim keys, U+2019; `slotLineCount(.careMoment)` stays 1; `careMomentLineKey(for:)`; contextual priority careMoment > greeting > ambient; epoch 3→4 with all pins moved; independent derivation recorded) · R6 the ONE disclosed `MomoCharacter` seam (`playStopped(at:)` + displacement-cancel handling; no-op without a round) · R7 gate widened to the four react families · R8 §10.4 spoken labels · R9 three structural guards (each bites on its violation fixture; F-1 untouched) · R10 scope verified (MomoCore = CopyRules only; MomoCharacter = the two disclosed files only; pbxproj byte-identical with HEAD).

### Files Changed

- `Sources/MomoCore/CopyRules.swift` — epoch 4, reactLineCount 5/6/6/6, care-moment comment (the sanctioned carveout)
- `Sources/MomoCharacter/MomoReactionState.swift` — R6 enum case + `eventTime` line (+11)
- `Sources/MomoCharacter/MomoReactionDirector.swift` — R6 apply case + `applyPlayStopped(at:)` + `drainReports()` (+31)
- `Sources/MomoKit/CanvasTouch.swift` — R7 announcement-gate widening
- `Sources/MomoKit/HomeCopyKeys.swift` — `careMomentLineKey(for:)` + contextual resolver priority
- `Sources/MomoKit/HomeReadModel.swift` — care-moment contextual wiring + R4 pill parity
- `Apps/Momo/MomoAppModel.swift` — drain, `sendFingertip`, `stopPlayRound`, Done-pill window (`donePillDelaySeconds = 5.0`), care-moment memory, care-moment announcements
- `Apps/Momo/HomeView.swift` — Done-pill overlay (outside the canvas a11y element)
- `Apps/Momo/HomeCanvasTouchLayer.swift` — in-flight drag branch + down/lift bookends
- `Apps/Momo/HomeActionRowView.swift` — R8 labels + comment
- `Apps/Shared/MomoCopy.xcstrings` — 21 new keys (authority comments) + `touch.03` U+2019 normalization
- `MomoUITests/MomoHomeUITests.swift` — +4 care-loop tests, `assertLineBecomes`, header note
- `Tests/MomoKitTests/CareMomentTests.swift` — NEW suite (7 tests)
- Tests modified: `CopySelectionPinnedTests`, `CanvasTouchTests`, `HomeReadModelTests`, `AppModelPlanTests`, `MomoHandshakeTests`, `MomoReactionDirectorTests`, `MomoReduceMotionTwinTests`, `RigDisciplineTests`, `MomoCatalogScaffoldingTests`, `CatalogCopyLawTests`, `EngineReduceTests`, `InteractionResponseTests`, `CareInteractionTests`, `PlayRoundTests` (epoch-parity re-pins in the last four — designed movements, commented in place)

### Tests Run

1. `swift test` (full package, final tree)
2. `xcodebuild test -scheme Momo -destination 'platform=iOS Simulator,id=1F25E487-A78E-464C-95AF-0BD1A9B3E1BE' -only-testing:MomoUITests` (final merged tree)
3. `xcodebuild -project Momo.xcodeproj -scheme MomoWatch -destination 'platform=watchOS Simulator,name=Apple Watch SE 3 (40mm),OS=26.5' build`
4. Warnings sweep across the package build, the UI-run build, and the Watch build.

### Test Results

1. **PASS — 907 tests in 92 suites, 0 failures, 0 issues** (baseline 887/91 → +19 implementation tests, +1 suite; +1 more from the F-1 fix cycle's R9d guard: CareMomentTests 7, handshake 4, plan-core 2, rig 4, RM twins 1, verbatim 1, contextual priority 1).
2. **PASS — TEST SUCCEEDED, Executed 17 tests, 0 failures, 315.3 s** (13 TASK-033/034 baseline + 4 new). An earlier pre-consolidation run (tests in a standalone file) also passed 17/17 — the logic was validated twice; the merged run is the record.
3. **PASS — `** BUILD SUCCEEDED **`, exit 0** (MomoCharacter is shared; R6's seam compiles into the watch app).
4. **Zero compiler warnings from any file this task touches** (`swift build`: 0). Pre-existing environmental noise, unchanged: `ld: warning: search path '/opt/extra/lib' not found` (the HOST's `LIBRARY_PATH` env, not project config — appears in every build on this machine) and `appintentsmetadataprocessor` SDK notes. DISCLOSED: the final UI run re-emitted 19 actor-isolation warnings in `MomoUITests/MomoUITests.swift` (the TASK-031 launch test) — a file this task does NOT modify (git diff on it is empty); the same-target test merge triggered a whole-module recompile, which re-emits that file's latent diagnostics (the pre-merge run showed none only because it was a cache hit). Pre-existing debt, not new code; routed to the reviewer to disposition (the file lacks the `@MainActor` annotation the newer suites carry).

### Known Issues

- None blocking. Disclosed for review: the nap pill's "Nap time" label is compile-mandatory (exhaustive switch) but not glass-pinned (its gate is not deterministically reachable under a frozen clock — see R8 notes); the care-moment line lives in app-model memory only (retention disclosed, rides OBSERVATION-A); the contract's R7 path (`Apps/Momo/CanvasTouch.swift`) is actually `Sources/MomoKit/CanvasTouch.swift`.

### Decisions Made

- `drainReports()` lives on the director (`reports` is `public private(set)`; the app model can never clear it).
- The Done pill is an overlay OUTSIDE the canvas's flattened accessibility element so VoiceOver keeps a separate tappable button.
- Done-pill delay authored at exactly 5.0 s (inside UX-3's 4.5–6 s band), Task-based REAL-TIME so it works under the frozen clock.
- The UI tests were consolidated into `MomoHomeUITests` (contract's "prefer extending existing files") BEFORE the final §19 run; the interim standalone file and its 4-entry pbxproj registration were removed — the pbxproj is byte-identical with HEAD.
- Day-fixture draw pins: `CareInteractionTests`' `2026-09-09` day draws react-care index 4 at epoch 4 (day-stable draws), pinned `.04` with comments; its `2026-09-08` pins read `.01`.

### Reviewer Status

REVIEW-TASK-035 **APPROVED_WITH_MINOR_NOTES** (F-1 MEDIUM → fixed in-task via R9d; F-2/F-3 notes recorded) → delta review REVIEW-TASK-035-FIX **APPROVED_WITH_MINOR_NOTES** (delta provably +43/0; three bites; 907/92). Both records in `.claude/tasks/reviews/`.

### Commit

none — the implementer is barred from git writes; the orchestrator commits after review (§12: `feat(home): TASK-035 wire feed/play/care — pools, play round, report drain`).

### Push

none — follows the orchestrator's commit (§13, `feature/EPIC-007-iphone-home`).

### Recommended Next Step

Spawn the fresh independent review agent against the dirty tree (requirements R1–R10 + this file's Implementation Notes + the diff); record `.claude/tasks/reviews/REVIEW-TASK-035.md`; run the §11 fix loop if CHANGES_REQUIRED; then commit and push per §12/§13.

### Fix Cycle (F-1)

REVIEW-TASK-035 F-1 (MEDIUM, "before commit" disposition): the play stillness ticker — the passive round's only fold source, load-bearing for AC-2's solo auto-end — was unguarded by R9. Added the fourth structural guard, `RigDiscipline.mentionsPlayStillnessTicker` (R9d): a source-read conjunction over `Apps/Momo/MomoAppModel.swift` (same `readRigFile` accessor) pinning the authored cadence constant (`static let playTickerSeconds`), the fold's sleep on that constant (`Task.sleep(for: .seconds(Self.playTickerSeconds))`), the stillness payload folded into the director (`moving: false,` — the call-site shape; the file's doc-comment mentions of the bare phrase carry no comma and cannot satisfy the leg), and the reconcile's in-flight start wire (`playTickerTask = Task { await runPlayTicker() }`). Each named breakage shape bites: ticker deleted (declaration + start legs), fold disconnected from the director event path (payload leg), cadence decoupled to a literal (sleep leg), gating broken (start leg). Non-vacuity fixture is the F-1 shape itself — a loop still sleeping on the authored cadence but never folding stillness and never started — proven to fail the predicate. The R9 MARK comments now read "four structural wires". Delta vs the reviewed tree: `Tests/MomoCharacterTests/RigDisciplineTests.swift` only (+38 lines) plus this file. Package re-run: **907 tests in 92 suites, 0 failures** (906/92 → +1; RigDisciplineTests 19 → 20).

HANDOFF-COMPLETE TASK-035
FIX-CYCLE-COMPLETE TASK-035
