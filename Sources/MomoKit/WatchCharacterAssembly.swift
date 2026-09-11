import Foundation
import MomoCore

// MARK: - Watch character read-model assembly (ADR-014; TASK-041 R1; 05 §4.11)

/// The wire-direction derivation: the SHARED `CharacterDisplayState` (04
/// §9.2) → the four-field `WatchCharacterDTO`. The iPhone executor calls this
/// with `makeCharacterDisplayState(state)`'s output — the derivation is never
/// re-implemented in any app target (04 §9.2: no consumer derives its own
/// view of engine state; EPIC-008 AC-5). Bond stage, wakefulness, and the
/// moment request are deliberately NOT carried — they already ride the
/// snapshot's `display` (the ADR's full-mirror alternative was rejected as
/// wire-redundant drift bait). Pure: value-in/value-out, nothing ambient.
public func makeWatchCharacter(
    _ characterDisplay: CharacterDisplayState
) -> WatchCharacterDTO {
    WatchCharacterDTO(
        moodBand: characterDisplay.moodBand,
        energyBand: characterDisplay.energyBand,
        activity: characterDisplay.activity,
        satietyHint: characterDisplay.satietyHint
    )
}

/// The Watch's one character assembly (ADR-014): the snapshot's `display` +
/// `character` → the `CharacterDisplayState` W1's rig renders — a faithful
/// mirror of what the iPhone's own rig received at push time. The ONLY
/// derivation is the moment projection: `display.greeting` maps to
/// `.greeting(kind)` (the open greeting is the one L4 request that OUTLIVES
/// its event — the same recorded reading `makeCharacterDisplayState`
/// documents; stage/quest moments are event-transient and never ride the
/// wire). Nil `character` (cross-version skew) is the PINNED degraded shape:
/// the caller renders the words + quest line and skips the pet-canvas slot —
/// never a crash, never an error surface (UX §9). Total and pure.
public func makeWatchCharacterDisplay(
    display: DisplayState,
    character: WatchCharacterDTO?
) -> CharacterDisplayState? {
    guard let character else { return nil }
    return CharacterDisplayState(
        moodBand: character.moodBand,
        energyBand: character.energyBand,
        bondStage: display.bondStage,
        wakefulness: display.wakefulness,
        activity: character.activity,
        satietyHint: character.satietyHint,
        momentRequest: display.greeting.map { CharacterMoment.greeting($0) }
    )
}
