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

READY (contract authored 2026-09-11 from the orchestrator's completed pre-read; epoch-4/5 numbers validated against epochs 2/3).

## Implementation Notes

(To be filled by the implementation agent — include: files changed, the exact Done-pill delay authored, the R6 disclosure table (every frozen file touched + why), your independent epoch-4 derivation, tests added with counts, suite numbers, and the §28 handoff block.)

## Reviewer Findings

(To be filled by the review agent.)

## Completion Evidence

(To be filled at closeout: review chain, §19 gate numbers at the final tree, commit + push.)
