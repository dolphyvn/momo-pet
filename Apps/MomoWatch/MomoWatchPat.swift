import Foundation
import MomoCharacter
import MomoCore
import MomoKit
import WatchKit
import os

// MARK: - The Watch pat's presentation seams + the app model's pat flow
// (TASK-042 R3/R5/R6; 05-technical-architecture §6.4; UX §6.2–6.4;
// ADR-015 D1–D3)

/// The pat's two haptic semantics (ADR-015 D2/D3): the soft tick every pat
/// plays, and the celebratory double that REPLACES the tick on the pat the
/// completion estimator fires for — ONE haptic carries the moment (two
/// back-to-back watchOS haptics read as one messy buzz). The seam speaks
/// SEMANTICS; only the live conformance names `WKHapticType` (the D3
/// VERIFY-AT-BUILD choices, recorded on the mapping below).
enum WatchPatHaptic: Equatable, Sendable {
    /// UX §6.3's "Pat = single soft tick".
    case tick
    /// UX §6.3's "quest completed by an on-wrist action = gentle celebratory
    /// double" — REPLACES the tick, never stacks with it.
    case celebration
}

/// The injectable haptic seam (R6): the app model calls this; tests/fakes
/// record kinds; the live conformance owns `WKInterfaceDevice`.
protocol MomoWatchHaptics: AnyObject {

    /// Plays the haptic — UNCONDITIONALLY: the `hapticsEnabled` gate is the
    /// CALLER's (the snapshot's toggle is read at pat time, the TASK-036
    /// delivery-time discipline; the seam must not re-decide).
    func play(_ haptic: WatchPatHaptic)
}

/// The live seam over `WKInterfaceDevice.play(_:)`.
///
/// **D3's VERIFY-AT-BUILD record (resolved against the watchOS 26.5 SDK
/// header `WKInterfaceDevice.h:16–33`):** the `WKHapticType` cases are
/// Notification, DirectionUp, DirectionDown, Success, Failure, Retry, Start,
/// Stop, Click (plus the session-gated navigation/underwater cases a pat
/// never touches); the Swift overlay renames the header's `playHaptic:` to
/// `play(_:)` (watchOS 2.0+). The mappings:
/// - **tick → `.click`** — the single-pulse "user interaction" tick; the
///   softest default in the set and UX §6.3's "single soft tick" read
///   literally.
/// - **celebration → `.retry`** — the set's DOUBLE-pulse case. The NAME is
///   mismatched (its iOS-meaning is "retry"); it is chosen for the PULSE
///   SHAPE — a double is exactly the "celebratory double" — while `.success`
///   is a single pulse (and `.notification` a triple: too loud for the calm
///   ethos). The pulse patterns are not stated in the header (this is
///   observed platform behavior); the on-wrist FEEL verdict is TASK-044's
///   paired-hardware obligation (§25/§27 — no simulator feel claims).
final class LiveWatchHaptics: MomoWatchHaptics {

    func play(_ haptic: WatchPatHaptic) {
        let type: WKHapticType
        switch haptic {
        case .tick: type = .click
        case .celebration: type = .retry
        }
        WKInterfaceDevice.current().play(type)
    }
}

// MARK: The app model's pat flow (R3; §6.4's five steps, the Watch half)
//
// Cross-file extension: Swift's `private` is file-scoped, so the app-model
// members this flow shares — `snapshot`, `persister`, `storeDirectory`,
// `wallClock`, `calendar`, `haptics`, `transport`, `reactionDirector`,
// `debugLoud` — are `internal` on the type, annotated there (the
// `MomoAppModel+Canvas` precedent).

extension MomoWatchAppModel {

    /// The pat capture (R3) — BOTH W1 targets (the canvas tap and the Pat
    /// pill) land here. The local answer is IMMEDIATE and unconditional
    /// (R3's "journaling and reaction/haptic NEVER fail together"): the
    /// state-distinct clip folds into the reaction director on this main
    /// actor before anything else runs; the durable leg (estimate → haptic →
    /// journal → drain) follows in a task. Nothing here can fail visibly —
    /// I/O failures are the journal's DEBUG-loud, keep-as-is discipline; a
    /// lost journal line is a lost pat (disclosed degradation, never an
    /// error surface — UX-9).
    func pat() {
        // The reaction (ADR-015 D1): the state-distinct KIND is selected
        // from the CURRENT snapshot's wakefulness; the clip itself is the
        // frozen vocabulary's — `.tap` (the happy micro-bounce) or `.stir`
        // (stays asleep). The fold is presentation-local: no state moves,
        // nothing is sent for the reaction itself.
        if let director = reactionDirector,
            let snapshot,
            case let kind = WatchPatPlan.reactionKind(for: snapshot.display.wakefulness) {
            var folded = director
            folded.apply(
                .plan(
                    ResponsePlan(
                        reaction: kind == .bounce ? ReactionKeys.tap : ReactionKeys.stir,
                        lineKey: nil,
                        haptic: nil
                    ),
                    at: canvasClock.elapsed()
                )
            )
            reactionDirector = folded
        }
        Task { await self.finishPat() }
    }

    /// The durable leg, in order: the estimate's pending read (mailbox,
    /// off-main), the haptic (main actor, BEFORE any journal I/O — R3's
    /// "fires first"), then the journal append + drain. The haptic's inputs
    /// are read fresh here; the pending count's read is a MAILBOX read (the
    /// journal's every touch goes through the one-writer actor — the census
    /// guard's premise), so two hair-trigger pats can both read the same
    /// pre-append count: the estimate is presentation-only (ADR-015 D2) and
    /// a doubled celebration in that sub-second window is its disclosed
    /// benign false-positive shape.
    func finishPat() async {
        guard let snapshot, !Task.isCancelled else { return }
        let pendingPatCount = await persister.pendingPatCount(
            directory: storeDirectory,
            epoch: watchSessionEpoch
        )
        // The haptic gate (R6/ADR-015 D2): the toggle is honored AT PAT
        // TIME; the estimate decides WHICH haptic plays and nothing else.
        if snapshot.hapticsEnabled {
            haptics.play(
                WatchPatPlan.isCompletingPat(
                    questLine: snapshot.display.questLine,
                    questInputs: snapshot.questInputs,
                    pendingPatCount: pendingPatCount
                ) ? .celebration : .tick
            )
        }
        // The journal append + §6.4 step-1's drain attempt. The watermark
        // pair is read HERE — immediately before the submission, on this
        // main actor with no suspension between — the freshness
        // `appendPat`'s ordering argument leans on (a receive either
        // completed before this stretch, leaving this read the newest pair,
        // or its mailbox jobs follow the append's).
        guard let event = await persister.appendPat(
            directory: storeDirectory,
            now: wallClock.now(),
            calendar: calendar,
            watchSessionEpoch: watchSessionEpoch,
            lastAppliedEpoch: snapshot.lastAppliedEpoch,
            lastAppliedIntentSeq: snapshot.lastAppliedIntentSeq
        ) else {
            return // the append did not land: no journal line, no send
        }
        guard let payload = event.encoded() else {
            Self.debugLoud("pat event failed to encode — undrainable (a valid IntentEvent always encodes)")
            return
        }
        transport.sendUserInfo(payload: payload)
    }

    // MARK: The rig's reaction-motion seam (R5; ADR-015 D1)

    /// The W1 canvas's `reactionMotion` sampler — the SAME capture-by-value
    /// shape as the iPhone's `MomoAppModel+Canvas.reactionMotion()`: the
    /// director is captured BY VALUE so the closure never touches the main
    /// actor, and reading this method from the view's body tracks
    /// `reactionDirector`, re-evaluating `MomoRigView`'s closure with the
    /// successor value on each fold.
    ///
    /// **Why a `MomoDirectorState` at all (disclosed for the reviewer):**
    /// ADR-015's rejected alternative is PORTING the director — forking the
    /// machinery into the Watch target as a presentation engine. This is not
    /// that: the frozen `MomoCharacter` keeps its per-clip choreography
    /// PRIVATE (`MomoReactionChoreography.motion(for:)` is internal; the
    /// clips are unreachable from any app target), and the type's public
    /// `overlay(at:)`/`reduceMotionOverlay(at:)` pair is the ONLY public
    /// path to the authored `.tap`/`.stir` motion — and to the Reduce
    /// Motion machinery R5 names ("per MomoReduceMotion's render-only
    /// law"). It is used as a clip renderer and nothing more: no
    /// `.displayState`, no touch, no moment folds — the Watch still derives
    /// nothing (EPIC-008 AC-5); it plays one authored clip per pat.
    func reactionMotion() -> @Sendable (Double, Bool) -> MomoReactionMotion {
        guard let director = reactionDirector else {
            return { _, _ in .identity }
        }
        return { time, reduceMotion in
            reduceMotion
                ? director.reduceMotionOverlay(at: time)
                : director.overlay(at: time)
        }
    }
}
