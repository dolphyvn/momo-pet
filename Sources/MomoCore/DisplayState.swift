import Foundation

// MARK: - DisplayState + the §4.11 read-model derivations (05-technical-
// architecture §4.11; 04-character-system §3.5, §9.2; TASK-019 Requirements
// 1, 2, 5)

/// The app-facing read-model (05 §4.11's sketch, field-for-field). One
/// snapshot of everything the presentation needs to render the pet — INV-11
/// by field inventory: the only Strings are catalog KEYS (never composed
/// prose; FR-20 AC-4's no-literals rule consumes them), everything else is an
/// enum or the quest line. Consumers: 05 §4.11's consumption paragraph — the
/// app layer derives it per foreground open; it derives nothing itself.
public struct DisplayState: Equatable, Sendable {

    /// The pet's name (05 §3.1; direct projection of `pet.name`).
    public let petName: String

    /// The VoiceOver mood word key (OBS-1: 04 §3.5's formula renders from the
    /// catalog; this carries the resolved key).
    public let moodWordKey: String

    /// The VoiceOver energy phrase key (OBS-1).
    public let energyPhraseKey: String

    /// The bond stage (PRD §3.3; the `Bands` derivation).
    public let bondStage: BondStage

    /// The stage descriptor key (PRD §3.3's normative lines).
    public let bondDescriptorKey: String

    /// Today's one wish, or all-done (§5.5's cascade over TODAY's quest set;
    /// the wish's own copy key is rendering's — EPIC-007/008).
    public let questLine: QuestGeneration.QuestLine

    /// The wakefulness machine state (§3.1).
    public let wakefulness: Wakefulness

    /// The greeting in effect for the current open (the stamp's kind; nil
    /// before the first greeting — onboarding's own flow is the greeting).
    public let greeting: GreetingKind?

    public init(
        petName: String,
        moodWordKey: String,
        energyPhraseKey: String,
        bondStage: BondStage,
        bondDescriptorKey: String,
        questLine: QuestGeneration.QuestLine,
        wakefulness: Wakefulness,
        greeting: GreetingKind?
    ) {
        self.petName = petName
        self.moodWordKey = moodWordKey
        self.energyPhraseKey = energyPhraseKey
        self.bondStage = bondStage
        self.bondDescriptorKey = bondDescriptorKey
        self.questLine = questLine
        self.wakefulness = wakefulness
        self.greeting = greeting
    }
}

/// §4.11's app read-model derivation. Pure: the only time input is `now` +
/// the INJECTED calendar (no ambient reads — `Calendar.current` and `Date()`
/// never appear; D20). The quest cascade runs over TODAY's `DayRecord`
/// quest set — the record matching `DayKey.make(from: now, calendar:)` — and
/// the local hour comes from `now` through the same calendar. An absent
/// record cascades over an EMPTY set → `.allDone` (no wishes can exist
/// without a record; the engine's absent-days-stay-absent semantics —
/// TASK-019 Requirement 1's recorded reading). The greeting projects the
/// state's stamp (nil before the first).
public func makeDisplayState(
    _ state: EngineState,
    at now: Instant,
    calendar: Calendar
) -> DisplayState {
    let petState = state.state
    let dayKey = DayKey.make(from: now, calendar: calendar)
    let todaysQuests = state.days.first(where: { $0.dayKey == dayKey })?.questSet ?? []
    let localHour = calendar.component(.hour, from: now)
    let bondStage = makeBondStage(petState.bond)
    return DisplayState(
        petName: state.pet.name,
        moodWordKey: VocabularyKeys.moodWordKey(for: makeMoodBand(petState.mood)),
        energyPhraseKey: VocabularyKeys.energyPhraseKey(for: makeEnergyBand(petState.energy)),
        bondStage: bondStage,
        bondDescriptorKey: VocabularyKeys.bondDescriptorKey(for: bondStage),
        questLine: QuestGeneration.cascade(questSet: todaysQuests, localHour: localHour),
        wakefulness: petState.wakefulness,
        greeting: state.lastGreeting?.kind
    )
}

/// §4.11's character read-model derivation (04 §9.2's shape). Pure over the
/// state ALONE — no time input at all: bands/stage via the `Bands`
/// derivations, wakefulness/activity direct, the satiety hint carried from
/// the total phase (the field's optionality is the 04 §9.2 shape's), and the
/// moment request is the in-effect L4 request — the current greeting stamp
/// (recorded reading: stage/quest moments are event-transient and already
/// delivered via `EngineOutcome.moments`; the only L4 request that OUTLIVES
/// its event is the open greeting). Presentation owns the stamp's
/// transience/fading; the stamp persists until the next greeting.
public func makeCharacterDisplayState(_ state: EngineState) -> CharacterDisplayState {
    let petState = state.state
    return CharacterDisplayState(
        moodBand: makeMoodBand(petState.mood),
        energyBand: makeEnergyBand(petState.energy),
        bondStage: makeBondStage(petState.bond),
        wakefulness: petState.wakefulness,
        activity: petState.activity,
        satietyHint: petState.satietyPhase,
        momentRequest: state.lastGreeting.map { .greeting($0.kind) }
    )
}

// MARK: - Greeting — the greeting selector (FR-12 AC-2; UX §4; D11;
// TASK-019 Requirement 5)

/// The greeting selector: whether an open of the pet greets, and with which
/// kind. Pure over (previousOpen, now, calendar) — the caller passes the
/// PRE-stamp `lastOpenedAt` (the previous open, before `reduce` stamps
/// `lastOpenedAt = now`). The rule table, IN ORDER (first match wins):
///
/// 1. gap below the re-greet floor → nil (an in-session re-evaluation is not
///    an arrival — scenePhase flapping must not re-greet; the floor is
///    `Thresholds.Greeting.regreetFloorMinutes`);
/// 2. gap ≥ 36 h → `.missedYou` (FR-12 AC-2 — warm, no guilt vocabulary —
///    even inside the night window: the absence outranks the hour);
/// 3. `now` inside the night window (D11 22:00–07:00, the `FoldRules`
///    hours) → `.nightGlance` (UX §4 flow 8's "Shhh… Momo is sleeping"
///    class — including a midnight-crossing first open: the DAY changed, but
///    the hour governs first);
/// 4. the previous open's local dayKey ≠ now's → `.freshMorning` (first open
///    of the local day, UX §4 flow 1 — including a 14:00 first open);
/// 5. else → `.welcomeBack` (same-day return past the floor).
///
/// A backward gap (a `now` before the previous open — never produced by the
/// forward-only engine) falls out of rule 1 as nil: no greeting is invented
/// for time that did not pass.
public enum Greeting {

    /// Selects the greeting kind for an open, or nil below the floor.
    public static func select(previousOpen: Instant, now: Instant, calendar: Calendar) -> GreetingKind? {
        let gapMinutes = now.timeIntervalSince(previousOpen) / 60.0
        if gapMinutes < Double(Thresholds.Greeting.regreetFloorMinutes) { return nil }
        if gapMinutes >= Double(Thresholds.Greeting.missedYouAfterHours) * 60.0 { return .missedYou }
        let hour = calendar.component(.hour, from: now)
        if hour >= FoldRules.nightOnsetHour || hour < FoldRules.morningWakeHour { return .nightGlance }
        if DayKey.make(from: previousOpen, calendar: calendar) != DayKey.make(from: now, calendar: calendar) {
            return .freshMorning
        }
        return .welcomeBack
    }
}
