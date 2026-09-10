import Foundation
import MomoCore

// MARK: - The reaction key set (04 §4.3/§6 + §8.4's namespace; TASK-028 R1)

/// The 21 mintable reaction keys the engine emits, as the clip table's
/// enum. Raw values are digit-for-digit the `ReactionKeys` strings; the
/// failable `init(reactionID:)` maps a `ReactionID` in. The clip spec and
/// choreography switches over this enum are EXHAUSTIVE with no `default`:
/// a future engine key with no clip fails the build (the TASK-023 pattern,
/// realized here as the case-set pins in `MomoReactionClipTests`, because
/// `ReactionID` is deliberately a String-backed struct in MomoCore —
/// INV-11 keeps the namespace catalog-owned).
enum MomoReactionKey: String, CaseIterable, Sendable {

    // 04 §6.1's touch map
    case tapHead = "react.tap.head"
    case tapBelly = "react.tap.belly"
    case tap = "react.tap"
    case doubleTap = "react.doubleTap"
    case longPressHead = "react.longPress.head"
    case longPressBelly = "react.longPress.belly"
    case longPress = "react.longPress"
    case strokeHead = "react.stroke.head"
    case strokeBelly = "react.stroke.belly"
    case stroke = "react.stroke"

    // 04 §4.3's vocabulary
    case stir = "react.stir"
    case politelyFull = "react.politelyFull"
    case gentleDecline = "react.gentleDecline"
    case sleepyNibbles = "react.sleepyNibbles"
    case settling = "react.settling"
    case blanketAdjust = "react.blanketAdjust"

    // Meal / play / decline beats (extension keys — see ReactionKeys' header)
    case eating = "state.eating"
    case nibble = "react.nibble"
    case playReady = "react.playReady"
    case cheer = "react.cheer"
    case decline = "react.decline"

    /// The `ReactionID` → key mapping (nil for an unminted key — the
    /// director treats that as the vocabulary's fail-loud edge).
    init?(_ reactionID: ReactionID) {
        self.init(rawValue: reactionID.rawValue)
    }
}

// MARK: - The clip spec (durations, channel budgets, tempo scope)

/// One clip row: its baseline timing (digit-pinned to the doc row it
/// realizes, or marked AUTHORED), the rig channels it can ever touch
/// (the ≤ 8 concurrent-channel budget of TASK-028 R11 is pinned per clip
/// in the tests), and how tempo/band rules scope it.
struct MomoReactionClipSpec: Equatable, Sendable {

    /// The awake-baseline duration in seconds — the fixed clips' full run,
    /// and for `pressShaped` clips the post-release beat (the hold itself
    /// is input-length). For `cyclical` clips this is the PER-CYCLE length
    /// (§6.1's "~1.2 s/cycle" rows). Doc rows are pinned digit-for-digit;
    /// AUTHORED values cite their band.
    let baselineSeconds: Double

    /// Every rig channel this clip's choreography can write — never more
    /// than 8 concurrently (§9.4's render budget; TASK-028 R11).
    let channels: RigChannel

    /// The band tempo law (§3.3 via `MomoReactionTempo`) scales this clip —
    /// strictly the touch family; the stir is exempt (it is the asleep
    /// beat) and the state beats carry their own sleepy pacing already.
    let tempoScaled: Bool

    /// The reaction's shape follows the touch: the hold phase lasts until
    /// `touchEnded` (press-length is input, §6.1's long-press rows).
    let pressShaped: Bool

    /// The clip renders repeating cycles (the strokes) until the touch
    /// ends; one cycle is `baselineSeconds` long.
    let cyclical: Bool

    /// Press-shaped rows: the AUTHORED release-beat length (the visible
    /// exhale that plays once the boundary resolves), which the director
    /// resolves the slot end from at every tempo — the press-length
    /// itself stays input (§6.1). The row's OTHER role (a cyclical hold
    /// figure such as the belly's 0.9 s rock) lives in `baselineSeconds`.
    /// nil elsewhere (the baseline IS the beat). Defaulted so the 19
    /// non-press rows need no argument; specs are values — never mutated.
    var pressReleaseSeconds: Double? = nil

    /// The doc row (or AUTHORED note) this row's numbers realize — carried
    /// so reviewers and the tests can cite authority per clip.
    let authority: String

    /// The effective one-shot duration at a tempo: baseline × tempo, the
    /// sequencer's band-vs-tempo reading (the baseline stays in its doc
    /// band; tempo multiplies the drawn value).
    func duration(tempo: Double) -> Double {
        tempoScaled ? baselineSeconds * tempo : baselineSeconds
    }

    /// The number of rig channels this row can write — the R11 budget
    /// (≤ 8) is pinned against this count.
    var channelCount: Int {
        channels.rawValue.nonzeroBitCount
    }
}

/// The clip table (TASK-028 R1): one spec per key, exhaustive — a key
/// without a row fails the build.
enum MomoReactionClips {

    static func spec(for key: MomoReactionKey) -> MomoReactionClipSpec {
        switch key {
        case .tapHead:
            MomoReactionClipSpec(
                baselineSeconds: 0.4,
                channels: [.earLeftRotation, .earRightRotation,
                           .eyeLeftLidScaleY, .eyeRightLidScaleY,
                           .eyeLeftPupilOffset, .eyeRightPupilOffset],
                tempoScaled: true, pressShaped: false, cyclical: false,
                authority: "04 §6.1 tap·head 0.4 s")
        case .tapBelly:
            MomoReactionClipSpec(
                baselineSeconds: 0.45,
                channels: [.bodyScale, .eyeLeftLidScaleY, .eyeRightLidScaleY,
                           .eyeLeftPupilOffset, .eyeRightPupilOffset],
                tempoScaled: true, pressShaped: false, cyclical: false,
                authority: "04 §6.1 tap·belly 0.45 s")
        case .tap:
            MomoReactionClipSpec(
                baselineSeconds: 0.6,
                channels: [.bodyScale, .tailRotation, .headRotation],
                tempoScaled: true, pressShaped: false, cyclical: false,
                authority: "AUTHORED 0.6 — §6.4 whole-body beat, in §7.1's 0.4–1.2")
        case .doubleTap:
            MomoReactionClipSpec(
                baselineSeconds: 0.7,
                channels: [.tailRotation, .bodyScale,
                           .earLeftRotation, .earRightRotation],
                tempoScaled: true, pressShaped: false, cyclical: false,
                authority: "04 §6.1 double-tap 0.7 s")
        case .longPressHead:
            MomoReactionClipSpec(
                baselineSeconds: 0.6,
                channels: [.bodyScale, .headRotation, .headPosition,
                           .eyeLeftLidScaleY, .eyeRightLidScaleY, .tailRotation],
                tempoScaled: true, pressShaped: true, cyclical: false,
                pressReleaseSeconds: 0.6,
                authority: "AUTHORED 0.6 release — §6.1 press-length hold; §7.1 band")
        case .longPressBelly:
            MomoReactionClipSpec(
                baselineSeconds: 0.9,
                channels: [.bodyRotation, .bodyPosition, .bodyScale,
                           .eyeLeftLidScaleY, .eyeRightLidScaleY],
                tempoScaled: true, pressShaped: true, cyclical: false,
                pressReleaseSeconds: 0.45,
                authority: "04 §6.1 long-press·belly 0.9 s rock + AUTHORED 0.45 release")
        case .longPress:
            MomoReactionClipSpec(
                baselineSeconds: 0.9,
                channels: [.bodyScale, .headRotation,
                           .eyeLeftLidScaleY, .eyeRightLidScaleY],
                tempoScaled: true, pressShaped: false, cyclical: false,
                authority: "AUTHORED 0.9 — the belly-row digit, in §7.1's 0.4–1.2 band (zone-less form; §6.4 is pat-only)")
        case .strokeHead:
            MomoReactionClipSpec(
                baselineSeconds: 1.2,
                channels: [.eyeLeftLidScaleY, .eyeRightLidScaleY,
                           .earLeftRotation, .earRightRotation, .tailRotation,
                           .eyeLeftPupilOffset, .eyeRightPupilOffset],
                tempoScaled: true, pressShaped: false, cyclical: true,
                authority: "04 §6.1 stroke·head ~1.2 s/cycle")
        case .strokeBelly:
            MomoReactionClipSpec(
                baselineSeconds: 1.0,
                channels: [.bodyRotation, .bodyPosition, .bodyScale,
                           .eyeLeftLidScaleY, .eyeRightLidScaleY,
                           .eyeLeftPupilOffset, .eyeRightPupilOffset],
                tempoScaled: true, pressShaped: false, cyclical: true,
                authority: "04 §6.1 stroke·belly ~1.0 s/cycle")
        case .stroke:
            MomoReactionClipSpec(
                baselineSeconds: 1.2,
                channels: [.bodyRotation, .bodyScale,
                           .eyeLeftLidScaleY, .eyeRightLidScaleY],
                tempoScaled: true, pressShaped: false, cyclical: true,
                authority: "AUTHORED zone-less form at the stroke·head cycle")
        case .stir:
            MomoReactionClipSpec(
                baselineSeconds: 1.0,
                channels: [.bodyScale, .tailRotation, .headRotation],
                tempoScaled: false, pressShaped: false, cyclical: false,
                authority: "AUTHORED 1.0 — §4.3's 0.8–1.2 band mid; tempo-exempt")
        case .politelyFull:
            MomoReactionClipSpec(
                baselineSeconds: 1.2,
                channels: [.bodyScale, .headRotation, .eyeLeftLidScaleY,
                           .eyeRightLidScaleY, .cheekOpacity],
                tempoScaled: false, pressShaped: false, cyclical: false,
                authority: "04 §4.3 politelyFull 1.2 s")
        case .gentleDecline:
            MomoReactionClipSpec(
                baselineSeconds: 1.0,
                channels: [.bodyRotation, .headRotation,
                           .eyeLeftLidScaleY, .eyeRightLidScaleY],
                tempoScaled: false, pressShaped: false, cyclical: false,
                authority: "04 §4.3 gentleDecline 1.0 s")
        case .sleepyNibbles:
            MomoReactionClipSpec(
                baselineSeconds: 3.5,
                channels: [.mouthPose, .propFood, .bodyScale, .headRotation,
                           .eyeLeftLidScaleY, .eyeRightLidScaleY],
                tempoScaled: false, pressShaped: false, cyclical: false,
                authority: "AUTHORED 3.5 — §4.3's 3–4 s band mid (L2-variant)")
        case .settling:
            MomoReactionClipSpec(
                baselineSeconds: 3.0,
                channels: [.bodyScale, .headRotation, .eyeLeftLidScaleY,
                           .eyeRightLidScaleY, .propBlanket, .tailRotation],
                tempoScaled: false, pressShaped: false, cyclical: false,
                authority: "AUTHORED 3.0 — §4.3's 2.5–3.5 band mid (the settle handshake)")
        case .blanketAdjust:
            MomoReactionClipSpec(
                baselineSeconds: 1.5,
                channels: [.propBlanket, .bodyScale, .headRotation, .tailRotation],
                tempoScaled: false, pressShaped: false, cyclical: false,
                authority: "04 §4.3 blanketAdjust 1.5 s")
        case .eating:
            MomoReactionClipSpec(
                baselineSeconds: 3.2,
                channels: [.mouthPose, .propFood, .bodyScale, .headRotation,
                           .eyeLeftLidScaleY, .eyeRightLidScaleY,
                           .eyeLeftPupilOffset, .eyeRightPupilOffset],
                tempoScaled: false, pressShaped: false, cyclical: false,
                authority: "AUTHORED 3.2 — §7.1's 2.5–4.0 row, 3 bites of the 2–3 band")
        case .nibble:
            MomoReactionClipSpec(
                baselineSeconds: 1.6,
                channels: [.mouthPose, .propFood, .bodyScale, .headRotation],
                tempoScaled: false, pressShaped: false, cyclical: false,
                authority: "AUTHORED 1.6 — 05 §4.5 satiety window's I-2 shortened eating animation (02-mvp-prd §4)")
        case .playReady:
            MomoReactionClipSpec(
                baselineSeconds: 2.4,
                channels: [.earLeftRotation, .earRightRotation, .tailRotation,
                           .bodyScale, .eyeLeftLidScaleY, .eyeRightLidScaleY],
                tempoScaled: false, pressShaped: false, cyclical: false,
                authority: "AUTHORED 2.4 — §6.3 phase 1 invite, ≤ 3 s band")
        case .cheer:
            MomoReactionClipSpec(
                baselineSeconds: 0.6,
                channels: [.earLeftRotation, .earRightRotation,
                           .bodyScale, .headRotation],
                tempoScaled: false, pressShaped: false, cyclical: false,
                authority: "AUTHORED 0.6 — §4.1 rule 6's small cheer, in §7.1 band")
        case .decline:
            MomoReactionClipSpec(
                baselineSeconds: 1.0,
                channels: [.headRotation, .bodyRotation, .mouthPose,
                           .earLeftRotation, .earRightRotation],
                tempoScaled: false, pressShaped: false, cyclical: false,
                authority: "AUTHORED 1.0 — §6.2 refusal pose's warm framing")
        }
    }
}
