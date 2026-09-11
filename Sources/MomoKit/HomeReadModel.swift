import Foundation
import MomoCore

// MARK: - HomeReadModel — the Home screen's read-model (TASK-033 Requirements
// 1–2; 05-technical-architecture §4.11; 03-ux-architecture §5.1, §5.4, §5.5)

/// The engine interaction vocabulary an action pill routes (`R6`: pills call
/// `appModel.interact`), surfaced under a MomoKit name so the app's VIEW files
/// keep importing MomoKit only — the D-R5 boundary keeps `MomoCore` imports
/// confined to the executor (and the entry point's disclosed R7 enabler).
public typealias HomeActionPillKind = InteractionIntent.Kind

/// One quest-card row (UX §5.5's `glyph · wish · soft mark` row): the quest's
/// wish key, its per-wish soft completion state, and whether the quest's
/// local-time window is OPEN right now. The VIEW silently drops rows whose
/// window has closed (UX §5.1/§5.5's silent absence — never a disabled ghost,
/// §11.2.4); the model carries the visibility flag so the derivation stays
/// pure and both halves stay independently testable.
public struct HomeQuestRow: Identifiable, Sendable {

    /// The quest the row renders (the row's identity — one row per quest,
    /// never two).
    public let questID: QuestID

    /// The wish-line key (`HomeCopyKeys.questWishKey`) — resolved by the view.
    public let wishKey: String

    /// The per-wish soft mark state (UX §5.5: ○ pending / ● done — per-wish
    /// marks only, never an aggregate progress bar).
    public let isCompleted: Bool

    /// Whether the quest's local-time window (PRD §5.2, `QuestCatalog`)
    /// contains the current local hour.
    public let isWindowVisible: Bool

    public init(questID: QuestID, wishKey: String, isCompleted: Bool, isWindowVisible: Bool) {
        self.questID = questID
        self.wishKey = wishKey
        self.isCompleted = isCompleted
        self.isWindowVisible = isWindowVisible
    }

    public var id: QuestID { questID }
}

/// The Home screen's read-model (UX §5.1's composition, one value): the
/// status row's bands and their catalog keys, the contextual line's key, the
/// quest card's rows, and the action row's pills. INV-11 by field inventory —
/// the only Strings are catalog KEYS; everything else is an enum or a count.
/// Not `Equatable`: the pill list embeds `InteractionIntent.Kind`, which is
/// `Sendable`-only by design (messages, not compared values).
public struct HomeReadModel: Sendable {

    /// The pet's name (the a11y formula's subject; the canvas label).
    public let petName: String

    // MARK: Status row (UX §5.1: mood word · energy word · stage)

    /// The mood band (the VoiceOver word's band; the mood glyph's band).
    public let moodBand: MoodBand

    /// The energy band (also the Nap pill's gate — UX §5.4).
    public let energyBand: EnergyBand

    /// The bond stage (also the stage-celebration surface's input, TASK-034).
    public let bondStage: BondStage

    /// The wakefulness machine state (§3.1; the Nap pill's waking-hours gate).
    public let wakefulness: Wakefulness

    /// The mood word key (the OBS-1 vocabulary — 04 §3.5's words).
    public let moodWordKey: String

    /// The energy word key (`momo.line.status.energy.<band>`).
    public let energyWordKey: String

    /// The VoiceOver energy phrase key (the OBS-1 vocabulary — the a11y
    /// formula's phrase half; the visible row shows the WORD, the label the
    /// PHRASE).
    public let energyPhraseKey: String

    /// The stage-name key (`momo.line.status.stage.<stage>`).
    public let stageNameKey: String

    /// The stage descriptor key (the OBS-1 vocabulary — the stage element's
    /// a11y label's second sentence).
    public let bondDescriptorKey: String

    // MARK: Contextual line (UX-12's single rotating slot)

    /// The contextual line's key: the latest care-moment line when one is
    /// in effect, else the greeting, else the day-stable ambient slot draw
    /// (`HomeCopyKeys.contextualLineKey` — UX-12's priority verbatim:
    /// interaction reaction > greeting > ambient).
    public let contextualLineKey: String

    // MARK: Quest card (UX §5.5: "Today's little wishes")

    /// Today's quest rows in the day record's order (the engine's fixed
    /// catalog order — Q1 first, never shuffled). An absent day record
    /// yields an EMPTY list (no wishes can exist without a record — the same
    /// semantics as `makeDisplayState`'s cascade; unreachable post-launch,
    /// where every day has a record).
    public let questRows: [HomeQuestRow]

    /// The all-wishes-done truth (TASK-036 R5; UX §5.5 M3): the §4.8
    /// cascade's `.allDone` state for today's set at the current local
    /// hour — the SAME derivation `makeDisplayState`'s quest line uses,
    /// never a "all visible rows completed" proxy (a closed-window row is
    /// still a wish). Mirrors the engine's empty-set reading: with no day
    /// record the cascade falls through to `.allDone`; the card's M3 line
    /// renders only over an existing record (rows present).
    public let isAllDone: Bool

    // MARK: Action row (UX §5.1/§5.4)

    /// The visible action pills, in row order: feed, play, then the
    /// conditional tuck-in (evening) and nap (drowsy/exhausted waking hours).
    /// Out-of-window pills are ABSENT, never disabled ghosts (§5.4). The view
    /// routes each through `appModel.interact` — the ONE sanctioned path.
    public let actionPills: [InteractionIntent.Kind]

    public init(
        petName: String,
        moodBand: MoodBand,
        energyBand: EnergyBand,
        bondStage: BondStage,
        wakefulness: Wakefulness,
        moodWordKey: String,
        energyWordKey: String,
        energyPhraseKey: String,
        stageNameKey: String,
        bondDescriptorKey: String,
        contextualLineKey: String,
        questRows: [HomeQuestRow],
        isAllDone: Bool,
        actionPills: [InteractionIntent.Kind]
    ) {
        self.petName = petName
        self.moodBand = moodBand
        self.energyBand = energyBand
        self.bondStage = bondStage
        self.wakefulness = wakefulness
        self.moodWordKey = moodWordKey
        self.energyWordKey = energyWordKey
        self.energyPhraseKey = energyPhraseKey
        self.stageNameKey = stageNameKey
        self.bondDescriptorKey = bondDescriptorKey
        self.contextualLineKey = contextualLineKey
        self.questRows = questRows
        self.isAllDone = isAllDone
        self.actionPills = actionPills
    }
}

// MARK: - The derivation (the `makeDisplayState` pattern, TASK-033 R2)

/// §4.11's Home read-model derivation — mirrors `makeDisplayState`'s inputs
/// exactly (state + `now` + the INJECTED calendar; no ambient reads, D20),
/// plus TASK-035 R5's presentation-side `latestCareMoment` (the app model's
/// in-memory memory of the latest visual care moment — never persisted).
/// Every decision delegates to the frozen surfaces: bands via `Bands`, the
/// line via `HomeCopyKeys.contextualLineKey`, quest windows via
/// `QuestCatalog`/`QuestWindow`, and — TASK-035 R4 — the pill gates via the
/// ENGINE's own acceptance rules (`InteractionRules.isTuckInWindow` and the
/// `applyTuckIn`/`applyNap` guard structure), so a chip is visible exactly
/// when the engine would accept or warmly reaffirm the action: a tap can
/// never route into a guaranteed-declined state.
public func makeHomeReadModel(
    _ state: EngineState,
    at now: Instant,
    calendar: Calendar,
    latestCareMoment: CareMomentKind? = nil
) -> HomeReadModel {
    let petState = state.state
    let dayKey = DayKey.make(from: now, calendar: calendar)
    let localHour = calendar.component(.hour, from: now)
    let slot = CopyRules.timeSlot(forLocalHour: localHour)
    let moodBand = makeMoodBand(petState.mood)
    let energyBand = makeEnergyBand(petState.energy)
    let bondStage = makeBondStage(petState.bond)

    // Today's quest rows, in record order; window visibility from the
    // catalog (UX §5.5 — the view silently drops closed windows).
    let todaysQuests = state.days.first(where: { $0.dayKey == dayKey })?.questSet ?? []
    let questRows = todaysQuests.map { progress in
        HomeQuestRow(
            questID: progress.questID,
            wishKey: HomeCopyKeys.questWishKey(for: progress.questID),
            isCompleted: progress.completed,
            isWindowVisible: QuestCatalog.entry(for: progress.questID).window.contains(hour: localHour)
        )
    }

    // The action row (UX §5.4): feed and play are always present. TASK-035
    // R4 pins the conditional chips to the ENGINE's exact acceptance rules —
    // chip visible ⟺ the engine would accept (count) or warmly reaffirm:
    //
    // - Tuck-in (InteractionSemantics.applyTuckIn's guards): the tuck-in
    //   window (`InteractionRules.isTuckInWindow` — the engine's own
    //   predicate, evening onset through the night half), and neither the
    //   waking decline (the never-cancelled .wake token holds the slot) nor
    //   the round-in-flight decline. Asleep (blanket-adjust, counts) and
    //   settling (warm reaffirm) both stay visible.
    //
    // - Nap (InteractionSemantics.applyNap's guards): the offered bands
    //   (drowsy/exhausted), and none of the decline cells — not already
    //   sleeping (night-asleep OR mid-nap), not settling, not a round in
    //   flight. The engine accepts a nap in `.waking` (band-gated
    //   interactions apply during waking), so `.waking` stays visible.
    //
    // `isSleeping` is InteractionSemantics' private two-clause predicate
    // (night-asleep ∨ mid-nap); the two clauses here mirror it exactly and
    // the parity is pinned by tests against the engine's own outcomes.
    var pills: [InteractionIntent.Kind] = [.feed, .play]
    let isRoundInFlight = petState.activity == .playing
    if InteractionRules.isTuckInWindow(now, calendar: calendar),
        petState.wakefulness != .waking,
        !isRoundInFlight {
        pills.append(.tuckIn)
    }
    let isSleeping = petState.wakefulness == .asleep || petState.activity == .napping
    if (energyBand == .drowsy || energyBand == .exhausted),
        !isSleeping,
        petState.wakefulness != .settling,
        !isRoundInFlight {
        pills.append(.nap)
    }

    return HomeReadModel(
        petName: state.pet.name,
        moodBand: moodBand,
        energyBand: energyBand,
        bondStage: bondStage,
        wakefulness: petState.wakefulness,
        moodWordKey: VocabularyKeys.moodWordKey(for: moodBand),
        energyWordKey: HomeCopyKeys.energyWordKey(for: energyBand),
        energyPhraseKey: VocabularyKeys.energyPhraseKey(for: energyBand),
        stageNameKey: HomeCopyKeys.stageNameKey(for: bondStage),
        bondDescriptorKey: VocabularyKeys.bondDescriptorKey(for: bondStage),
        contextualLineKey: HomeCopyKeys.contextualLineKey(
            greeting: state.lastGreeting?.kind,
            petID: state.pet.id,
            dayKey: dayKey,
            slot: slot,
            careMoment: latestCareMoment
        ),
        questRows: questRows,
        isAllDone: QuestGeneration.cascade(questSet: todaysQuests, localHour: localHour) == .allDone,
        actionPills: pills
    )
}
