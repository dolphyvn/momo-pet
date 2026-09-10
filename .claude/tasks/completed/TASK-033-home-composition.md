# TASK-033 — Home composition (FR-2; UX §5.1, §5.5)

## Parent Epic

EPIC-007 — iPhone Home Experience (`.claude/tasks/epics/EPIC-007-iphone-home.md`), task 3 of 9.
Delivery row: `docs/product/06-delivery-plan.md:114` — "Home composition (FR-2; UX §5.1, §5.5): status row · canvas ≥ ~45 % · contextual line (single rotating slot, UX-12) · action row pills · quest card (per-wish soft marks, no aggregate bar; UX-5 windows); AC-1a no-scroll at default type on the smallest pinned device; AC-1b scroll-with-full-function at accessibility sizes; no Collection/customization (AC-4)."

## Objective

Replace `PlaceholderHomeView` with the composed Home screen: the status row (glyph + WORD bands — never numbers), the live pet canvas (≥ ~45 % of the screen, hosting the EPIC-006 rig at the full tier), the contextual line (single rotating slot per UX-12), the action row pills (presence-gated, tapping routes through the app model), and the quest card ("Today's little wishes", per-wish soft marks, UX-5 window rendering). Landing the composed surface requires the catalog's real copy pools (04 §10.3's verbatim lines + the recorded vocabulary obligations + the status/quest word keyspaces) and therefore the ONE documented `CopyRules` carveout (§4.10's epoch bump + time-slot pool counts). Everything else in MomoCore stays byte-frozen.

Explicitly OUT (routed by the epic): touch gestures + eye-follow + canvas VoiceOver custom actions (TASK-034); feed/play/care presentation flows + the care-moment visual class producer (TASK-035); M1/M2/M3 moment wiring, haptics, celebrations (TASK-036); Room (TASK-037); Settings (TASK-038); the full a11y audit (TASK-039).

## Context (verified engine + app surfaces — all facts below were read from the tree at `31b2953`)

**Frozen MomoCore consumption surface (read these files; consume, never edit — the single exception is Requirement R6's carveout):**

- `Sources/MomoCore/LineSelection.swift` — `LineSelection.copySeed(petID:dayKey:) -> UInt64`; `LineSelection.slotLineKey(petID:dayKey:slot:)` mints the day-stable ambient key `momo.line.<slot>.<nn>` (0-based two-digit index); `VocabularyKeys.moodWordKey(for:)` / `.energyPhraseKey(for:)` / `.bondDescriptorKey(for:)` mint the fixed `momo.line.vocab.<field>.<band>` keys (mood: joyful/content/wistful/low; energy: energetic/relaxed/drowsy/exhausted; stage: newFriends/gettingClose/bestFriends/soulCompanions).
- `Sources/MomoCore/CopyRules.swift` — `copyEpoch = 1`; `LineSlot` = morning/day/evening/night + context slots greeting/careMoment("care-moment"); `timeSlot(forLocalHour:)` (night [22,07) via `FoldRules`, morning [07,12), day [12,18), evening [18,22)); `slotLineCount(for:) = 1` for ALL slots (placeholder era); `reactLineCount(for:) = 1`. The header documents §4.10's bump obligation: **a catalog change ⇒ bump the copy epoch**. `formatted()`'s doc comment records "index 00 is reserved for placeholders, real pools start at 01" — see R6: the frozen picker is 0-based, so this convention sentence must be truthed, not the picker.
- `Sources/MomoCore/DisplayState.swift` — `DisplayState` fields: `petName`, `moodWordKey`, `energyPhraseKey`, `bondStage`, `bondDescriptorKey`, `questLine` (the **Watch's** one-wish cascade — NOT Home's card), `wakefulness`, `greeting: GreetingKind?`. `makeDisplayState(state, at:calendar:)` is the app read-model. `Greeting.select(previousOpen:now:calendar:)` rules → `.missedYou` (≥36 h) / `.nightGlance` (night window) / `.freshMorning` (first open of the local day) / `.welcomeBack` / nil (below the re-greet floor). 04 §3.5's VoiceOver formula: "{Name} feels {mood word} and {energy phrase}".
- `Sources/MomoCore/Quest.swift` — `QuestID` q1…q7 (rawValues "Q1"…"Q7"); `QuestCatalog.all` (Q1 greet×1 morningOnly / Q2 feed×1 / Q3 feed×2 / Q4 play×2 / Q5 play×3 / Q6 care×1 eveningAndEarlyMorning / Q7 pet×3, allDay); `QuestWindow.contains(hour:)` (morningOnly = `hour < Thresholds.Quest.q1WindowClosesAtHour`; eveningAndEarlyMorning = `hour >= Thresholds.Quest.q6WindowStartHour || hour < Thresholds.Quest.q6WindowEndHour`; allDay = true); `QuestProgress` {questID, progress, completed} (INV-6 failable init).
- `Sources/MomoCore/DayRecord.swift` — `questSet: [QuestProgress]` (exactly 3, no duplicates), `dayKey`, counters. **`Sources/MomoCore/TimeFold.swift` `rollover`** appends the landing day's record whenever it is absent — so any post-launch evaluation guarantees today's record exists; `priorTwoSets` filter the anchor and **"fresh-install day 1 forces Q6"**, i.e. a fresh store's first set is {Q1, Q6, +1 seeded}. VERIFY this derivation in `QuestGeneration.swift` + its tests before trusting it in UI assertions.
- `Sources/MomoCore/InteractionIntent.swift` — `Kind` = pat/feed/play/tuckIn/nap (exhaustive; `CopyRules.ReactFamily.init(_:)` maps them).

**App surfaces (editable):**

- `Apps/Momo/MomoAppModel.swift` — exposes `displayState` (computed via `makeDisplayState(state, at: clock.now(), calendar:)`), `characterDisplayState`, `canvasClock: CharacterClock`, `interact(_ kind:)` (mints the intent: UUID, `.iPhone`, dayKey, now — the ONLY sanctioned path from a view to the engine, D-R5), `requiresOnboarding`. Init injects `clock: any EngineClock = SystemEngineClock()` and `calendar: Calendar = .current`.
- `Apps/Momo/MomoApp.swift` — constructs `MomoAppModel(storeDirectory: MomoApp.testStoreDirectory())`; the TASK-032 `-momo-store-directory` UI-test enabler lives here (R13 precedent — follow its disclosure pattern for R9's clock enabler).
- `Apps/Momo/RootTabView.swift` — TabView over `PlaceholderHomeView` / `PlaceholderRoomView` / `PlaceholderSettingsView` (labels Home · Room · Settings). This task replaces ONLY the Home placeholder.
- `Apps/Shared/MomoCopy.xcstrings` — currently EXACTLY 3 placeholder keys (`momo.line.day.00`, `momo.line.moment.00`, `momo.line.react.touch.00`) with non-product text, `extractionState: "manual"`, "PLACEHOLDER…" comments.
- `Sources/MomoCharacter/MomoRigView.swift` — `init(displayState:tier:clock:model:stageSide:reactionMotion:reduceMotion:staticPoseTransition:)`; defaults are the no-op overlay and environment-resolved Reduce Motion. `RigLODTier.full` is the 21-constant tier; `RigSurface.iphoneHome` already exists. READ `RigLOD`'s stage-side bands before picking `stageSide` — the canvas must genuinely host the `.full` tier.

**Normative docs (copy sources — transcribe VERBATIM, never from memory):**

- `docs/design/04-character-system.md` §10.3 (≈ lines 665–718) — the 40 slot lines (10 per morning/day/evening/night, all guilt-free) and the return-greeting paragraph: regular "Momo looked up right away."; ≥36 h "Momo missed you."; the NIGHT slot header itself says "night-window lines; shown on night glance". §10.1: voice rules (≤ 8 words typical, ≤ 12 hard max; no emoji; third-person name-led; soft endings); rule 7: visual body copy appears ONLY in the contextual line, the greeting, and a few care moments — micro-reactions are a11y-only. §10.4: line classes; `momo.line.<slot>.<nn>`; day-stable seeded selection.
- `docs/product/02-mvp-prd.md` §3.2 — energy band names (Energetic/Relaxed/Drowsy/Exhausted); §3.3 — stage names (New Friends/Getting Close/Best Friends/Soul Companions) + descriptor lines; §5.2 — the seven quest wish texts (Q1 "Morning hello — say hello to Momo" … Q7 "Gentle pats — Momo wouldn't mind some pats"). Copy the exact strings from the doc.
- `docs/design/03-ux-architecture.md` §5.1 — the S4 Home sketch (status row `{mood glyph} {mood word} · {energy glyph} {energy word} · ✨ {bond stage}`; canvas ~45 %; contextual line; action row `[ Feed ] [ Play ] ( [ Tuck in ] 20:00+ ) ( [ Nap ] Drowsy/Exhausted )` with 44 pt pills; quest card header **"Today's little wishes"**, wish rows `glyph · wish text · soft state mark (○ pending / ● done)`); the AC-1a budget note (each wish line renders on a single line at default type at 375 pt width; truncation is NOT permitted); UX-4 (per-wish soft marks, no aggregate bar), UX-5 (wish lines render inside their windows; "2 visible lines on a Q6-day morning"), UX-12 (single rotating slot; priority interaction reaction > greeting > ambient; ambient pool may include the bond descriptor), §11.2.4 (conditional chips are ABSENT, never disabled ghosts).

**Frozen tests that constrain the catalog work (Tests/ is editable — updating them is part of this task):**

- `Tests/MomoCharacterTests/MomoCatalogScaffoldingTests.swift` — `everyKeyIsInApprovedNamespace` asserts EVERY key passes the frozen `CopyKey.isInApprovedNamespace` two-segment grammar (`^momo\.line\.(?:(?:morning|day|evening|night|greeting|care-moment)|react\.(?:touch|feed|play|care)|moment)\.\d{2}$` — `Sources/MomoCharacter/MomoCopy.swift:52`; the `momo.line.vocab.*` / `momo.line.status.*` / `momo.line.quest.*` keys would FAIL it); `placeholdersAreMarked` pins `strings.count == 3` ("unlisted keys need their own task" — this IS that task).
- `Tests/MomoCoreTests/VocabularyKeyTests.swift` — `catalogObligations` records the 8 verbatim (key, text) pairs for the energy phrases + stage descriptors as "the EPIC-007 catalog-entry contract (REVIEW-TASK-019 MINOR-1)"; the Wistful→"quiet" remap is pinned by name as a catalog obligation.
- `Tests/MomoCoreTests/CopySelectionPinnedTests.swift` — pins the selection recipe with raw literals (epoch 1, pool counts 1). Updating these pins to the new constants is required and disclosed (Tests are not frozen).
- `Tests/MomoCoreTests/BannedVocabularyScanTests.swift` — already scans the catalog file non-vacuously; new strings are auto-covered.

## Requirements

### R1 — MomoKit home read-models (pure, headless)

New `Sources/MomoKit/HomeCopyKeys.swift` + `Sources/MomoKit/HomeReadModel.swift` (two focused files; immutable value types):

- `HomeCopyKeys` (the NEW fixed-lookup keyspaces, minted in MomoKit — NOT in `VocabularyKeys`, so MomoCore is untouched):
  - energy word: `momo.line.status.energy.energetic|relaxed|drowsy|exhausted` (display text = PRD §3.2 verbatim);
  - stage name: `momo.line.status.stage.newFriends|gettingClose|bestFriends|soulCompanions` (display text = PRD §3.3 verbatim);
  - quest wish: `momo.line.quest.q1…q7` (display text = PRD §5.2 verbatim);
  - greeting: `momo.line.greeting.01` = "Momo looked up right away.", `.02` = "Momo missed you.", `.03` = **the ONE authored line of this task** — freshMorning has no verbatim doc line; author it under §10.1 (proposed, verify against the rules and keep or improve with disclosure): "Momo is up and starting the day."
  - Exhaustive switches over `EnergyBand` / `BondStage` / `QuestID` / `GreetingKind` — default-free; a new case breaks the build (the census discipline).
- `HomeGreetingCopy.lineKey(for: GreetingKind) -> String`: welcomeBack/missedYou/freshMorning → their greeting keys; **nightGlance has no separate greeting line** — 04 §10.3's night-slot header ("shown on night glance") means the night AMBIENT line is the night-glance class, so nightGlance falls through to the ambient pick (R2's resolver).
- `HomeReadModel` + `makeHomeReadModel(_ state: EngineState, at now: Instant, calendar: Calendar) -> HomeReadModel` — pure, same discipline as `makeDisplayState` (no ambient reads; D20):
  - `petName`; `moodWordKey` (from `VocabularyKeys.moodWordKey(makeMoodBand(…))`); `energyWordKey`; `stageNameKey`; plus the raw `moodBand`/`energyBand`/`bondStage`/`wakefulness` enums so the view can map glyphs;
  - `contextualLineKey: String` — the UX-12 slot resolved: greeting (3 kinds) > ambient `LineSelection.slotLineKey(petID:dayKey:slot: CopyRules.timeSlot(forLocalHour:))`. The interaction-reaction tier is the SPOKEN channel owned by TASK-034/035 (§10.1 rule 7: reactions carry no visual text) — do not implement it; the care-moment visual tier is TASK-035's producer. Disclose both deferrals.
  - `questCard`: rows built from TODAY's `DayRecord.questSet` (record found by `DayKey.make(from:now:calendar:)`; ABSENT record ⇒ empty rows — unreachable post-launch because `rollover` mints the landing day, disclosed as the recorded stance), each row = {questID, titleKey, completed, windowVisible = `QuestCatalog.entry(for:).window.contains(hour:)`}. Preserve the record's row order. Window filtering is the VIEW's/row's `windowVisible` flag — UX-5 says out-of-window rows do not render; the read-model carries the flag, the view filters.
  - `actionPills: [InteractionIntent.Kind]` — presence logic, pure over (wakefulness, localHour): feed + play ALWAYS; tuckIn iff `localHour >= Thresholds.Quest.q6WindowStartHour` (the SAME 20:00 constant as Q6's window — reference the constant, never restate 20); nap iff wakefulness is the Drowsy or Exhausted case. Exhaustive over `Wakefulness`.
  - No user-facing prose anywhere — keys and enums only (INV-11 carries into the app layer).
- Unit pins in `Tests/MomoKitTests/HomeReadModelTests.swift`: keyspace exhaustiveness + determinism; the resolver's tier behavior (3 greeting kinds → greeting keys; nightGlance and nil → the ambient slot pick; slot-class changes across 07/12/18/22); quest-card windows (hour 9: Q1 visible, Q6 hidden; hour 21: Q6 visible; hour 2: per the engine's window math — VERIFY and pin the truth); pills (every wakefulness × representative hours; nap absent on an awake pet; tuckIn absent at 19, present at 20); absent-record ⇒ empty rows.

### R2 — App-model exposure

`MomoAppModel` gains a computed `homeReadModel` mirroring the existing `displayState` pattern (`makeHomeReadModel(state, at: clock.now(), calendar: calendar)`). No new triggers, no engine edits, no plan-core changes.

### R3 — Catalog landing (Apps/Shared/MomoCopy.xcstrings)

Add en entries, `extractionState: "manual"` throughout (hand-authored):

1. **40 slot lines** — `momo.line.morning|day|evening|night.00…09`, text = 04 §10.3's ten lines per slot VERBATIM (transcribe from the doc, in order: doc line n → index n−1, because the frozen picker is 0-based). `momo.line.day.00` REPLACES the existing placeholder entry (real text takes the slot).
2. **3 greeting lines** — `momo.line.greeting.01…03` per R1.
3. **12 vocabulary entries** — `momo.line.vocab.mood.*` (4: joyful/content/**quiet for wistful**/low per 04 §3.5), `momo.line.vocab.energy.*` (4: the verbatim phrases recorded in `VocabularyKeyTests.catalogObligations`), `momo.line.vocab.stage.*` (4: the PRD §3.3 descriptor lines verbatim).
4. **8 status-word entries** (`momo.line.status.*`) + **7 quest wishes** (`momo.line.quest.q1…q7`) — PRD §3.2/§3.3/§5.2 verbatim. Casing: carry the docs' own casing (mood words lowercase per 04 §3.5; energy/stage names capitalized per PRD §3.2/§3.3); disclose that the mixed casing is doc-faithful and that TASK-039's formula audit may revisit.
5. `momo.line.moment.00` and `momo.line.react.touch.00` REMAIN untouched placeholders.

Total: 70 new/changed entries. UI-chrome strings (card header "Today's little wishes", pill labels Feed/Play/Tuck in/Nap, a11y trait words) are VIEW literals per the TASK-032 onboarding precedent — they do NOT enter the catalog; disclose this reading.

### R4 — The CopyRules carveout (the task's ONLY frozen-module edit — disclosed and bounded)

`Sources/MomoCore/CopyRules.swift`, exactly three changes, nothing else in MomoCore:

1. `copyEpoch` 1 → 2 (§4.10: a catalog change ⇒ bump — resalts every day-stable pick);
2. `slotLineCount(for:)`: 10 for morning/day/evening/night; 1 for the context slots (greeting/careMoment — greeting is a fixed map with no variational pool; the care-moment producer is TASK-035; react/moment counts stay 1 for TASK-034/035/036, each of which will bump the epoch again with its own landing);
3. Header + `formatted()` doc-comment truthing: the time-slot pools landed at TASK-033 occupying 0-based `.00…09`; the "real pools start at 01" sentence is superseded BY THE FROZEN PICKER'S 0-BASED MATH (do NOT touch `LineSelection` — the picker is frozen; the convention sentence was written before the picker existed).

Update `Tests/MomoCoreTests/CopySelectionPinnedTests.swift`'s raw-literal pins to the new constants and note the update in the task record. Every OTHER MomoCore/MomoCharacter source file must diff clean — the reviewer verifies byte-freeze.

### R5 — Catalog law tests (MomoCharacterTests)

- Split `everyKeyIsInApprovedNamespace`: keys passing the frozen validator stay asserted by it (all slot + greeting keys pass); every key OUTSIDE it must match one of the enumerated fixed-lookup grammars — `^momo\.line\.vocab\.(mood|energy|stage)\.<cases>$`, `^momo\.line\.status\.(energy|stage)\.<cases>$`, `^momo\.line\.quest\.q[1-7]$` — with the case lists spelled out. A key matching NEITHER grammar fails.
- `placeholdersAreMarked` shrinks to the 2 surviving placeholders (`moment.00`, `react.touch.00`); the `strings.count == 3` pin is replaced by per-class count pins: 10×4 slots, 3 greetings, 12 vocab, 4 status.energy + 4 status.stage, 7 quest wishes.
- New catalog law test file: the OBS-2 12-word rule scanner over `momo.line.(morning|day|evening|night|moment).<nn>` values (≤ 12 words each — this is "the TASK-010 scanner enforces when real pools land" landing NOW); run the same cap over the greeting entries too (stricter than required — disclose).

### R6 — HomeView composition (Apps/Momo)

New files: `HomeView.swift`, `HomeStatusRowView.swift`, `HomeContextualLineView.swift`, `HomeActionRowView.swift`, `HomeQuestCardView.swift` (small focused files; register EVERY new app/UITest file in the pbxproj — all four sites: PBXBuildFile, PBXFileReference, PBXGroup, PBXSourcesBuildPhase). RootTabView swaps `PlaceholderHomeView` → `HomeView` and the placeholder file is deleted (no dead code).

Layout per 03 §5.1's S4 sketch, top to bottom: status row · pet canvas · contextual line · action row · quest card. Tokens only (`MomoSpacing`/`MomoUIColors`/`MomoTypography`). Accessibility identifiers on the major containers: `home.statusRow`, `home.canvas`, `home.contextualLine`, `home.actionRow`, `home.questCard`, and per-pill identifiers.

- **Status row**: one line; per band a glyph + WORD (mood word from `moodWordKey`, energy word from `energyWordKey`), then the ✨ stage glyph + stage name (SF Symbol `sparkles` or equivalent; disclose glyph choices). Glyphs are decorative (`accessibilityHidden`) — the WORD carries the state (never color-only, never number). Mood+energy resolve through ONE catalog rendering helper (`String(localized:)` over the app catalog — a tiny Apps/Momo helper, e.g. `MomoCopyText.render(_:)`; MomoKit stays key-only). VoiceOver: mood+energy as one element labeled by 04 §3.5's formula ("{name} feels {mood word} and {energy phrase}"); stage as one element labeled "{stage name}. {descriptor}". TASK-039 audits formulas — disclose these as the first-cut formulas.
- **Pet canvas**: `MomoRigView(displayState: appModel.characterDisplayState, tier: .full, clock: appModel.canvasClock)` with the default no-op overlay and default Reduce Motion resolution (TASK-034 owns gestures/custom actions; RM eye-follow substitution is already the rig's). `stageSide` sized so the rig genuinely renders the `.full` band (verify `RigLOD`'s bands). The canvas region is ≥ 45 % of the Home screen height at default type on the smallest pinned device — enforce structurally (weight/flexible frame), prove via the UI test. One VoiceOver element (label "{name}" for now; custom actions are TASK-034).
- **Contextual line**: single `Text` rendering `contextualLineKey` — the ONE rotating slot (UX-12).
- **Action row**: `Button` per `actionPills` entry — labels Feed / Play / Tuck in / Nap; taps call `appModel.interact(.feed/.play/.tuckIn/.nap)` — the REAL intent path, no local state changes, NO flow presentation (TASK-035). Out-of-window chips are ABSENT (no disabled ghosts — §11.2.4). Pills ≥ 44 pt tall (03 §5.1).
- **Quest card**: header "Today's little wishes"; rows = in-window wishes only (`windowVisible`), each: family glyph (decorative) · wish text (`titleKey` rendered) · soft mark — ○ pending / ● done (SF Symbol `circle` / `circle.fill`, decorative; the row's a11y label appends the word "done" / "pending" — words, never symbols or numbers). NO aggregate bar, NO "x of y" counts (AC-3). Rows must render single-line at default type on the smallest pinned device with NO truncation (03 §5.1's budget note) — pick the token scale that achieves it and disclose.
- **AC-1b scroll law**: at default type the composed Home does not scroll (everything visible on the pinned SE); at accessibility sizes the content below the canvas scrolls with full function — conditional `ScrollView` on `\.dynamicTypeSize.isAccessibilitySize` (or `ViewThatFits`), disclosed.

### R7 — DEBUG fixed-clock UI-test enabler (the R13 precedent's sibling)

`MomoApp` gains a `-momo-fixed-clock <ISO-8601-UTC>` launch-argument override: under `#if DEBUG`, a parseable value constructs a fixed `EngineClock` (reuse MomoCore's manual clock type) injected into `MomoAppModel`; unparseable values `assertionFailure` (DEBUG-loud). Release builds ignore the argument entirely. Production defaults stay `SystemEngineClock()`. Disclose in the task record next to the R13 store-directory enabler.

### R8 — UI tests (MomoUITests; pinned simulator `1F25E487-A78E-464C-95AF-0BD1A9B3E1BE`, iPhone SE 3rd generation)

Use `-momo-store-directory <unique>` for every launch. Derive expected quest content from the ENGINE's semantics, never a hardcoded set: fresh-install day 1 forces {Q1, Q6, +1 seeded} (VERIFY in QuestGeneration first), so Q1/Q6 window assertions and row counts are deterministic under the fixed clock.

1. Composition (default type): fresh store → onboarding → Home; status row, canvas, contextual line, quest card header, Feed+Play pills all exist; the canvas frame is ≥ 45 % of the window height; the quest card is fully visible WITHOUT scrolling (AC-1a).
2. No-numeric state audit (AC-3): the status-row band labels are members of the sanctioned word sets (mood ∈ the four mood words; energy ∈ {Energetic, Relaxed, Drowsy, Exhausted}; stage ∈ {New Friends, Getting Close, Best Friends, Soul Companions}) — set membership IS the no-numbers proof; quest rows carry no numeric text.
3. Quest windows under the fixed clock: hour 09:00 → Q6 row absent, Q1 row present, exactly 2 visible rows; hour 20:30 → 3 visible rows incl. Q6; NO error/decoration where a hidden row would be (silent absence). **[CONTRACT DEFECT, annotated at closeout — verified independently by the implementer, the orchestrator, and REVIEW-TASK-033 §8: "3 rows at 20:30" is unreachable. Day 1's set is exactly [Q1, X, Q6]; Q1's window closes at 12:00 and never overlaps 20:30, so 20:30 shows 2 rows (X + Q6). The windows DO overlap on [0,7), so a day-2+ early morning can show 3 — the implemented tests pin the true 2+2 law and the engine's 06:30 all-open truth. See the 03 §5.5 engine-truth errata note.]**
4. Pills under the fixed clock: 09:00 → Feed+Play only; 20:30 → Feed+Play+Tuck in; Nap never present on the fresh awake pet (verify the fresh state's energy band first — assert accordingly and disclose the derivation).
5. Accessibility size: launch with `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityXXL` — every control remains reachable (scroll-to-hittable), full function (AC-1b).

## Files / Areas Likely Affected

- NEW: `Sources/MomoKit/HomeCopyKeys.swift`, `Sources/MomoKit/HomeReadModel.swift`, `Apps/Momo/HomeView.swift`, `Apps/Momo/HomeStatusRowView.swift`, `Apps/Momo/HomeContextualLineView.swift`, `Apps/Momo/HomeActionRowView.swift`, `Apps/Momo/HomeQuestCardView.swift`, `Apps/Momo/MomoCopyText.swift` (catalog rendering helper), `Tests/MomoKitTests/HomeReadModelTests.swift`, `Tests/MomoCharacterTests/CatalogCopyLawTests.swift`, new `Tests/MomoUITests/…Home…swift` suite file(s).
- EDIT: `Apps/Shared/MomoCopy.xcstrings`, `Sources/MomoCore/CopyRules.swift` (carveout only), `Apps/Momo/MomoAppModel.swift`, `Apps/Momo/MomoApp.swift`, `Apps/Momo/RootTabView.swift`, `Tests/MomoCharacterTests/MomoCatalogScaffoldingTests.swift`, `Tests/MomoCoreTests/VocabularyKeyTests.swift`, `Tests/MomoCoreTests/CopySelectionPinnedTests.swift`, the app + test pbxproj registrations, `.claude/tasks/active/TASK-033-home-composition.md` (implementation notes).
- DELETE: `Apps/Momo/PlaceholderHomeView.swift` (+ its pbxproj references).
- FROZEN, must diff clean: every other file under `Sources/MomoCore/` and `Sources/MomoCharacter/`.

## Dependencies

- TASK-026 (rig + view API — DONE, merged) and TASK-031 (facade — DONE `257a58f`); TASK-032 (onboarding gate — DONE `53e433f`) provides the route to Home and the store-directory enabler.
- Baseline: **857 unit + 86 UI tests green at `53e433f`** (HEAD `31b2953` is docs-only housekeeping on top).

## Constraints

- CLAUDE.md governs: §9 (this contract is your whole scope — no scope creep; discoveries → notes, not implementations), §19 (test before handoff), §22/§24 (MVP protection), §25 (report the actual state), §26 (no undocumented TODO debt), §27 (no secrets; nothing here touches entitlements/network).
- MomoCore/MomoCharacter are frozen except R4's bounded `CopyRules` edit and the catalog JSON. `LineSelection`, `DisplayState`, `VocabularyKeys`, the validator `CopyKey.isInApprovedNamespace` — untouched.
- Immutability: all new model types are `let`-only value types; no mutation.
- No `print`/`console` debugging left behind; DEBUG-loud discipline for the enabler.
- Every user-visible string is either a catalog entry or the disclosed view-literal set (header + pill labels + trait words). No other literals.
- The 12-word rule and the banned-vocabulary scan cover ALL new strings; no exclamation-mark spam (§10.1 rule 4).

## Acceptance Criteria

1. AC-1a: composed Home shows status row + canvas (≥ 45 % height) + contextual line + action row + quest card with NO scroll at default type on the smallest pinned device (UI-proven).
2. AC-1b: at accessibility sizes the Home scrolls with full function (UI-proven).
3. AC-3: Home renders WORDS, never numbers — band labels ∈ the sanctioned word sets; quest marks are symbols + a11y words; no aggregate bar (UI + unit proven).
4. FR-2 surfaces: the five S4 regions render per 03 §5.1; the contextual line is the single UX-12 slot (greeting > ambient; reaction/care tiers deferred and disclosed); quest rows honor UX-5 windows with silent absence; pills honor the 20:00/Drowsy-Exhausted presence law with no disabled ghosts.
5. The catalog carries the real copy pools (04 §10.3 verbatim ×40, greetings ×3, vocabulary ×12, status words ×8, wishes ×7) and every catalog key passes the split grammar law; the 12-word scanner is live; the banned-vocabulary scan stays green over the new strings.
6. MomoCore's diff is EXACTLY the R4 carveout; `copyEpoch == 2`; time-slot pool counts are 10; the pin tests reflect the new constants; every other frozen file diffs clean.
7. Tapping a pill routes a real intent through `appModel.interact` (D-R5 respected) and presents nothing (TASK-035's).
8. Full package suite (`swift test`) and the MomoUITests suite green on the pinned simulator, with the new tests added per R1/R5/R8.

## Required Tests

- `swift test` (package) — all suites green including the new `HomeReadModelTests`, `CatalogCopyLawTests`, the split scaffolding tests, the extended `VocabularyKeyTests` (8 obligations verbatim in the catalog + wistful=="quiet" + mood entries present), and the updated `CopySelectionPinnedTests`.
- `xcodebuild test` (MomoUITests) on the pinned simulator — the existing suites stay green; the five new R8 tests pass.
- Launch verification on the pinned simulator: onboarding → Home renders composed (screenshot/launch log evidence in the task record).
- Record exact commands + results in Completion Evidence (§19/§25 — never claim unrun tests).

## Review Requirements

Independent fresh reviewer per CLAUDE.md §10/§33 — do NOT prime with this contract's reasoning; the reviewer re-derives from CLAUDE.md, status.md, the epic, the docs, and the diff, and tries to DISPROVE correctness. Specific review obligations for this task:

- String-by-string fidelity diff of the catalog against 04 §10.3 and PRD §3.2/§3.3/§5.2 (the verbatim claims), including the wistful→"quiet" obligation and the 8 recorded (key, text) pairs.
- Byte-freeze verification: MomoCore's diff == the R4 carveout only; MomoCharacter's diff == catalog JSON only.
- The frozen-picker/0-based-indices reading (R4.3) — independently confirm from `LineSelection.slotLineKey` that real pools MUST occupy `.00…` and that no missing-key render path exists.
- The scanner-split soundness (a malformed key cannot sneak through either grammar).
- AC-3's no-numbers proof and the a11y structure (decorative glyphs hidden, single-element canvas, formulas as disclosed).
- Scope: no TASK-034/035/036/037/038 work leaked in.
- Review record: `.claude/tasks/reviews/REVIEW-TASK-033.md`, status APPROVED / APPROVED_WITH_MINOR_NOTES / CHANGES_REQUIRED / BLOCKED.

## Git Requirements

- Branch: `feature/EPIC-007-iphone-home` (work where the epic leaves off; do NOT create a new branch).
- One atomic commit after review approval + tests green: `feat(home): TASK-033 compose Home — status row, live rig canvas, contextual line, quest card, action pills` (TASK-ID mandatory; no Co-Authored-By — attribution is disabled globally).
- Push immediately after commit; record hash + push range.

## Status

DONE (this commit) — review APPROVED_WITH_MINOR_NOTES; the four code findings dispositioned (NITPICK-1 fixed, NITPICK-2/3 + NOTE-2 comments); §19 gate re-run green at the final tree (868/88 + 10/10); committed and pushed by the orchestrator per §12/§13.

## Implementation Notes

(Executing agent `task033-impl`.)

Verify-before-trust outcomes:
1. Fresh-install quest set: VERIFIED in `QuestGeneration.candidatePool` — day 1 has no priors ⇒ `q6Credit == false` ⇒ the pool is the 5 Q6-pairs ⇒ the drawn pair is always {X, Q6}, X ∈ {Q2…Q5, Q7}, and the set is exactly `[Q1, X, Q6]`. Consequence pinned in the UI tests: at 20:30 only **2** rows can ever be visible (Q1 closed + only 3 members) — the contract's illustrative "3 rows at 20:30" is unreachable by construction; the tests pin the actual law (2 at 09:00 with q6 absent; 2 at 20:30 with q1 absent, order-agnostic because X's draw varies with the random pet id).
2. `Wakefulness` cases: `awake/settling/asleep/waking` — the nap gate is `(energyBand, wakefulness)` with nap only for `(.drowsy|.exhausted, .awake)` (contract defect resolved; Wakefulness has no drowsy case).
3. `GreetingKind`: `welcomeBack/missedYou/freshMorning/nightGlance` in MomoCore; `HomeCopyKeys.greetingLineKey` returns `String?` (nightGlance → nil → the ambient slot), so `contextualLineKey`'s greeting tier is a flatMap.
4. `RigLOD.fullStagePoints` = 220–280 — Home's composed stage is 260, the scrolling branch's fixed canvas is 260.
5. `CopySelectionPinnedTests` pin shape: raw literals over a fixture pet/day; re-pinned to epoch 2 (`copyEpochIsTwo`, `poolCountsPinned`, `rawKeysPinned` — epoch-2 draws are `.02` in all four 10-line slots for the pinned pet/day, `.00` for all pool-of-1 classes; verified via a temporary probe test, created → run → deleted).
6. Window constants: q1 closes 12; q6 starts 20, ends 7 — the read-model and the R7 enabler rest on `Thresholds.Quest`/`CopyRules`, never restated hours.
7. Catalog strings transcribed from the docs (04 §10.3's 40 slot lines in doc order → indices 00–09; PRD §5.2 wishes verbatim with the "Name — wish" em-dash framing; the 04 §5.x vocabulary obligations; wistful→"quiet" per the recorded remap). JSON-validated: exactly 72 keys; the two placeholders byte-untouched.

Decisions & disclosures (reviewer attention):
- **AC-1a floor keyed off the SCREEN, not the content region** (`HomeLayout.canvasMinimumHeight = 305`): 45% of the SE's 667-pt screen is ~300 pt, but 45% of its safe-area content height is only ~269 pt — a fraction-only floor could sit BELOW the criterion. 305 pt = the floor alone satisfies AC-1a on the smallest device; `canvasMinimumFraction = 0.46` scales it up.
- **The canvas a11y element is the REGION, not the rig** (`HomeView.canvas`): `MomoRigView` is rigidly `stageSide × stageSide` (260), and an `accessibilityElement(children: .ignore)` element's frame is its content's union — an element built over the rig reported 260 pt while the flexed region was ~405 pt. The element now backs onto a `Color.clear` region rect with the rig overlaid in, so VoiceOver AND the UI test measure the region FR-2 AC-1 budgets (verified: 343×405.5 at 09:00 on the SE ≈ 60.8% of screen). The rigid rig cannot exceed 280 pt (42% of 667), which confirms AC-1a reads on the REGION.
- **`HomeActionPillKind` typealias** (`Sources/MomoKit/HomeReadModel.swift`): views stay MomoKit-only (the documented D-R5 boundary — `MomoAppModel` was the sole app-target `MomoCore` importer), while `HomeQuestCardView`'s glyph switch keys off `row.questID` by inference (no `QuestID` naming). The engine vocabulary still flows: pills call `appModel.interact` per R6.
- **`MomoApp` now imports MomoCore** for the R7 enabler (the contract places the enabler there and directs reusing `ManualEngineClock`) — the D-R5 doc comment in `MomoAppModel.swift` was amended to name the TWO sanctioned importers (executor + entry-point enabler). The enabler also UTC-pins the injected calendar when the flag is present: the Home windows are LOCAL-hour governed, so the instant alone would leave them hostage to the host timezone (contract defect resolved).
- **SCOPE EXPANSION — the launch-open kick in `MomoApp.body` (`.task { appModel.scenePhaseChanged(to: scenePhase) }`), disclosed for orchestrator review.** TASK-033's UI tests exposed a pre-existing TASK-031 trigger-wiring gap: by the time the shell's `onChange(of: scenePhase)` is installed, the scene is already `.active`, so a cold launch NEVER evaluates — no first day record, no greeting flow; a fresh install's Home quest card rendered EMPTY ("Today's little wishes" with no rows) until the next phase change. The kick reads the current phase at first appearance; a genuine later change still rides `onChange`; double-fires fold nothing (folds are forward-only; a second is zero-elapsed). MomoApp/MomoAppModel are both sanctioned edit surfaces (R7/R2); the full onboarding suite re-ran green after the change (4/4).
- **UI tests use the R13 restart pattern with two pinned instants** (onboard @ `2026-09-10T08:59:00Z`, assert @ the target hour): a fresh carrier pre-stamps `lastEvaluatedAt`, and a zero-elapsed fold short-circuits BEFORE the rollover (`TimeFold.apply`'s `from < to` guard) — under a never-advancing clock, a single frozen launch can never mint day 1's record. The one-minute relaunch gap gives the launch-open evaluate its fold; the record is born seeded by the real pet.
- Disclosed deferrals (per contract R1): the UX-12 interaction-reaction tier is TASK-034/035's spoken channel; the care-moment visual tier is TASK-035's producer; `contextualLineKey` carries greeting > ambient only.
- Catalog header comment: `momo.line.moment.00`'s value intentionally contains "placeholder" (it IS the placeholder); the `CatalogCopyLawTests` real-copy scan exempts `momo.line.moment.*` for exactly that reason.

## Reviewer Findings

**REVIEW-TASK-033 — APPROVED_WITH_MINOR_NOTES** (independent fresh reviewer; docs-first re-derivation preserved at `/tmp/review-task-033/derived-requirements.md`). Catalog: all 69 doc-sourced strings byte-identical (Python `==` comparison, not eyeballing); frozen-module discipline PASS (MomoCore diff = exactly the R4 carveout; MomoCharacter empty); 0-based picker reading PASS; scanner split SOUND; AC-3 + a11y formula PASS. All four disclosures adjudicated: launch-open kick JUSTIFIED (§4.2 row-1 normative; double-fire idempotent); R7 enabler SOUND; two-instant restart SOUND and the contract's R8.3 defect independently confirmed; D-R5 two-importer amendment COMPLIANT. Anti-tautology: the epoch-2 draw independently re-derived from the framing alone (index 2; epoch 1 lands index 9 — the pins genuinely bind epoch 2). Mutations: 4 bites as predicted + 1 documented survivor (MINOR-1's evidence). Verification: swift test 868/88 reproduced; the full app suite green TWICE (10/10, exit 0 — primary + confirmation re-run). Findings: MINOR-1 (no verbatim value pins beyond vocab — routed to TASK-039), NITPICK-1/2/3 + NOTE-2 (all fixed/documented by the orchestrator pre-commit), NOTE-1 (no action), OBSERVATION-A (greeting domination → owner product item), OBSERVATION-B (03 §5.5 Q6 doc tension → errata, recorded). Full record + orchestrator dispositions: `.claude/tasks/reviews/REVIEW-TASK-033.md`.

## Completion Evidence

- Package: `swift test` → **✔ Test run with 868 tests in 88 suites passed** (baseline 857 + 11 new: 7 `HomeReadModelTests`, 2 `CatalogCopyLawTests`, 1 `VocabularyKeyTests.catalogCarriesTheVocabularyVerbatim`, 1 net from the re-pinned `CopySelectionPinnedTests`).
- App suite: `xcodebuild test -project Momo.xcodeproj -scheme Momo -destination 'platform=iOS Simulator,id=1F25E487-A78E-464C-95AF-0BD1A9B3E1BE'` → **Executed 10 tests, with 0 failures** — MomoHomeUITests 5/5 (composition+AC-1a+no-scroll; words-never-digits audit; quest windows 2+2 silent; pill windows + interact routing; XXL scroll with full function), MomoOnboardingUITests 4/4, MomoUITests 1/1.
- Review verification (independent agent): swift test 868/88 reproduced; the app suite green TWICE (10/10 exit 0); five sanctioned mutation bites with sha256-proven restoration; catalog byte-compared against the docs.
- Closeout §19 gate (orchestrator, final tree WITH the dispositions): `swift test` → **868/88 passed**; app suite → **Executed 10 tests, with 0 failures — `** TEST SUCCEEDED **`** (2026-09-10 ~22:36 local).
- Byte-freeze: `git diff HEAD -- Sources/MomoCore/` = **exactly** `CopyRules.swift` (the R4 carveout: epoch 2, slot counts, doc truthing); `git diff HEAD -- Sources/MomoCharacter/` = **empty**. No Room/Settings/onboarding source touched.
- Tree state at handoff: DIRTY by design (dispatch rule — the orchestrator commits after review); branch `feature/EPIC-007-iphone-home`, HEAD `8bf6ff4`.

## Handoff

### Completed
R1–R8 all implemented and verified (see Implementation Notes for the decisions/deviations ledger and Completion Evidence for the real command outputs).

### Files Changed
- NEW: `Sources/MomoKit/HomeCopyKeys.swift`, `Sources/MomoKit/HomeReadModel.swift`, `Apps/Momo/HomeView.swift`, `Apps/Momo/HomeStatusRowView.swift`, `Apps/Momo/HomeContextualLineView.swift`, `Apps/Momo/HomeActionRowView.swift`, `Apps/Momo/HomeQuestCardView.swift`, `Apps/Momo/MomoCopyText.swift`, `Tests/MomoKitTests/HomeReadModelTests.swift`, `Tests/MomoCharacterTests/CatalogCopyLawTests.swift`, `MomoUITests/MomoHomeUITests.swift`.
- EDIT: `Apps/Shared/MomoCopy.xcstrings` (72 keys), `Sources/MomoCore/CopyRules.swift` (R4 carveout only), `Apps/Momo/MomoAppModel.swift` (`homeReadModel` + D-R5 doc amendment), `Apps/Momo/MomoApp.swift` (R7 enabler + launch-open kick — SCOPE, disclosed), `Apps/Momo/RootTabView.swift` (HomeView swap), `Tests/MomoCharacterTests/MomoCatalogScaffoldingTests.swift`, `Tests/MomoCoreTests/CopySelectionPinnedTests.swift`, `Tests/MomoCoreTests/VocabularyKeyTests.swift`, `Momo.xcodeproj/project.pbxproj` (six app files + MomoHomeUITests at all four sites each; PlaceholderHomeView references removed).
- DELETED: `Apps/Momo/PlaceholderHomeView.swift`.

### Tests Run
`swift test`; `xcodebuild test` (full scheme) on pinned sim `1F25E487-A78E-464C-95AF-0BD1A9B3E1BE`.

### Test Results
868/88 package green; 10/10 app-suite green (0 failures). No skipped tests.

### Known Issues
- The contract's "3 rows at 20:30" illustration is unreachable by construction (§4.8's exactly-3 day-1 set is `[Q1, X, Q6]`); the tests pin the true 2+2 law — orchestrator may want the contract line annotated at merge time.
- `CopyRules.formatted()`'s superseded "real pools start at 01" sentence was replaced by the indexing-truth paragraph inside the SAME sanctioned file (R4's doc-truthing clause).

### Decisions Made
See Implementation Notes (AC-1a screen-keyed floor; region-backed canvas element; `HomeActionPillKind` boundary typealias; MomoApp MomoCore import + D-R5 doc amendment; the disclosed launch-open kick; the two-instant restart pattern for quest UI tests).

### Reviewer Status
APPROVED_WITH_MINOR_NOTES — `.claude/tasks/reviews/REVIEW-TASK-033.md`; findings dispositioned (see Reviewer Findings above).

### Commit
`(this commit)` — `feat(home): TASK-033 compose Home — status row, live rig canvas, contextual line, quest card, action pills` (real hash recorded in status.md's Recent Commits).

### Push
Executed immediately after the commit per §13 (push range + status recorded in status.md's Recent Pushes).

### Recommended Next Step
Orchestrator dispatches TASK-034 (touch & petting) — contract authored from the pre-read: 04 §2.3–2.4/§6.1–6.2, 03 §5.1/UX-8, the frozen `PatGesture`/`TouchZone`/`InteractionSemantics.touchReaction` surface, the `MomoDirectorState`/`MomoCharacterEvent` seam, FIX1-NOTE-1's cancel seam, and the react.touch pool landing with the epoch 2→3 bump (same-residue trap documented).
