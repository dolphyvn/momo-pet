import Foundation

// MARK: - Reaction keys (04-character-system §8.4 namespace; INV-11; TASK-016
// Requirement 1)

/// The reaction keys the §4 response matrix produces, in 04 §8.4's
/// dot-namespace. MomoCore deliberately carries the key TYPE (`ReactionID`),
/// not the enumeration, so the namespace stays catalog-owned (INV-11) — this
/// home holds the concrete keys the engine emits, each citing the 04 §4.3/§6
/// vocabulary row it realizes, so the catalog manifest (04 §8.5; EPIC-006)
/// can enumerate them one-to-one. Keys are identifiers, never composed prose.
///
/// **`lineKey`/`haptic` seams.** `lineKey` is filled as of TASK-019 — every
/// plan carries its day-stable family key via `LineSelection.reactLineKey`
/// (05 §4.9); haptics remain the presentation seam, nil at every plan site
/// (04 §9.2's `ResponsePlan.haptic`). The engine mints the reaction and the
/// line key only.
///
/// **Extension keys.** Eight keys this engine emits sit beyond 04 §4.3's
/// vocabulary table (they postdate it, are Watch-only zone-less forms, or are
/// named only in prose); all follow the §8.4 convention (`react.<gesture>
/// [.<zone>]`) and are enumerated here for the catalog manifest (04 §8.5;
/// EPIC-006): `react.playReady` (the round-start invite beat, 04 §6.3 phase 1
/// "play-ready perk"), `react.cheer` (the mid-round small cheer, 04 §4.1
/// rule 6), `react.decline` (the general warm decline for cells whose offer
/// does not exist — declined nap, out-of-window tuck-in — the §6.2 refusal
/// pose's warm framing), `react.nibble` (the I-2 contented nibble,
/// owner-confirmed 2026-09-08 — §4.5's "small contented nibble (shortened
/// eating animation)"; it postdates 04 §4.3's table), the zone-less Watch
/// forms `react.tap` / `react.longPress` / `react.stroke` (FR-17 sends
/// `.pat(<gesture>, nil)` — single watch surface; REACTION-TASK-016
/// NITPICK-1 enumeration), and the state-convention key `state.eating`
/// naming §4.2's eating L2 state through the plan — the meal beat IS the
/// state entry (§4.2: "feed interaction (hungry class)").
public enum ReactionKeys {

    // MARK: Touch — 04 §6.1's gesture×zone map (FR-5 AC-1 "distinguishable")

    /// Tap · head — tiny ear flick + soft half-blink.
    public static let tapHead = ReactionID(rawValue: "react.tap.head")

    /// Tap · belly — small squash-bounce + brief eye widen.
    public static let tapBelly = ReactionID(rawValue: "react.tap.belly")

    /// Tap with no zone — the Watch's single surface (FR-17 sends
    /// `.pat(.tap, nil)`); the catalog maps it to §6.4's whole-body beat
    /// (the happy micro-bounce). The §8.4 convention's zone segment is
    /// optional (`react.<gesture>[.<zone>]`).
    public static let tap = ReactionID(rawValue: "react.tap")

    /// Double-tap · either zone — §6.1 gives one row for both zones, so no
    /// zone split exists (and none is minted for the zone-less Watch path).
    public static let doubleTap = ReactionID(rawValue: "react.doubleTap")

    /// Long-press · head — the lean-in "melting" premium signature beat.
    public static let longPressHead = ReactionID(rawValue: "react.longPress.head")

    /// Long-press · belly — gentle side-to-side rock + happy squint.
    public static let longPressBelly = ReactionID(rawValue: "react.longPress.belly")

    /// Long-press with no zone (Watch).
    public static let longPress = ReactionID(rawValue: "react.longPress")

    /// Stroke · head — eyes close fully in contentment, ears soften.
    public static let strokeHead = ReactionID(rawValue: "react.stroke.head")

    /// Stroke · belly — playful rock + bright eyes.
    public static let strokeBelly = ReactionID(rawValue: "react.stroke.belly")

    /// Stroke with no zone (Watch).
    public static let stroke = ReactionID(rawValue: "react.stroke")

    // MARK: Sleep/transitional beats — 04 §4.3 vocabulary

    /// The stir (asleep, any touch/play — stays asleep; also the settling
    /// soft-stir decline and the declined-warm play beat in unplayable
    /// states, §6.2).
    public static let stir = ReactionID(rawValue: "react.stir")

    /// Politely full (feed while full — the sated-sigh refusal beat; §6.2:
    /// "it must read as a sated sigh, never a rejection").
    public static let politelyFull = ReactionID(rawValue: "react.politelyFull")

    /// Gentle decline (feed while asleep/settling — half-turn away, eyes stay
    /// closed, §4.3; the asleep-nap warm no-op).
    public static let gentleDecline = ReactionID(rawValue: "react.gentleDecline")

    /// Sleepy nibbles (feed while Drowsy/Exhausted — §4.3's L2-variant; the
    /// PRD §4 matrix's "nibbles happily, smaller effect" /
    /// "sleepy nibbles, small effect" cells).
    public static let sleepyNibbles = ReactionID(rawValue: "react.sleepyNibbles")

    /// Settling (tuck-in's settle beat — yawn → lie down → blanket settles,
    /// §4.3; also the accepted-nap settle-down beat — the character
    /// differentiates nap vs night through the `activity` field).
    public static let settling = ReactionID(rawValue: "react.settling")

    /// Blanket-adjust (tuck-in while already asleep, and the mid-settle warm
    /// reaffirm — blanket nudge + deeper settle, §4.3).
    public static let blanketAdjust = ReactionID(rawValue: "react.blanketAdjust")

    // MARK: Meal beats

    /// The full meal: §4.2's eating L2 state, named through the plan
    /// (`state.` convention, §8.4) — the state entry IS the response.
    public static let eating = ReactionID(rawValue: "state.eating")

    /// The I-2 contented nibble (recently-fed feed class — extension key,
    /// see the header).
    public static let nibble = ReactionID(rawValue: "react.nibble")

    // MARK: Play round beats (extension keys, see the header)

    /// Round-start invite beat (04 §6.3 phase 1 "play-ready perk") — the
    /// round IS the response (TASK-016 Req 7); the Drowsy short low-key
    /// round authorizes the SAME key (pacing is character-side).
    public static let playReady = ReactionID(rawValue: "react.playReady")

    /// The mid-round small cheer (04 §4.1 rule 6 — a play intent while a
    /// round is already active never resets or extends it).
    public static let cheer = ReactionID(rawValue: "react.cheer")

    /// The general warm decline for cells whose offer does not exist —
    /// out-of-window tuck-in, nap in an unoffered band, a round in flight,
    /// the waking-state choreography declines (extension key, see the
    /// header; the §6.2 refusal pose's warm framing).
    public static let decline = ReactionID(rawValue: "react.decline")
}
