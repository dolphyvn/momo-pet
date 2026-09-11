import Foundation
import MomoCharacter
import MomoCore
import MomoKit
import UIKit

// MARK: - MomoAppModel + Canvas — the touch/play/announcement seams
// (TASK-039 R8; the members moved verbatim from `MomoAppModel.swift`)

/// The canvas-adjacent executor entries (TASK-034's touch vocabulary,
/// TASK-035's play-round entries, TASK-034 R3's reaction-motion seam, and
/// the UX-8 VoiceOver announcements both the response arm and the
/// celebrations use), in their own same-target extension. TASK-039 R8
/// extracted them move-semantically — ZERO behavior change — to bring the
/// main file back inside the 800-line budget (the `+Settings` precedent:
/// Swift's `private` is file-scoped, so the members the seams share —
/// `isTouchOpen`, `foldDirector`, `lastPlayFingertipOffset`,
/// `announceSpokenLine`, `announceText` — are `internal`, annotated at
/// their declaration sites; no accessor leaves the target).
extension MomoAppModel {

    // MARK: The canvas touch entries (TASK-034 R2; 04 §6.1)

    /// A canvas touch BEGAN at `zone` — opens the director's L1 press
    /// layer (the §6.1 press-length input starts at the physical touch,
    /// which is what makes a long-press's hold length the press clip's
    /// length). Returns the `canvasClock` stamp the gesture layer
    /// classifies the touch with (the view reads no clock — D-R5).
    ///
    /// Recovery: one finger means touches cannot overlap, so a `touchBegan`
    /// arriving while one is still open means the gesture layer lost the
    /// old touch's end (a system cancellation SwiftUI never surfaced — the
    /// FIX1-NOTE-1 seam's residual gap). The stale press closes at THIS
    /// instant before the new one opens, so the open-touch invariant can
    /// never wedge; `touchEnded` stays the idempotent normal close.
    @discardableResult
    func touchBegan(zone: TouchZone?) -> Double {
        let now = canvasClock.elapsed()
        if isTouchOpen {
            isTouchOpen = false
            foldDirector(.touchEnded(at: now))
        }
        isTouchOpen = true
        foldDirector(.touchBegan(zone: zone, at: now))
        return now
    }

    /// The canvas touch ENDED (a lift OR a cancellation — the gesture
    /// layer's FIX1-NOTE-1 seam calls this on BOTH, so a system-stolen
    /// touch resolves exactly like a released one). Idempotent: without an
    /// open touch it is a no-op. Returns the close stamp.
    @discardableResult
    func touchEnded() -> Double {
        let now = canvasClock.elapsed()
        guard isTouchOpen else { return now }
        isTouchOpen = false
        foldDirector(.touchEnded(at: now))
        return now
    }

    // MARK: The play round entries (TASK-035 R2; 04 §6.3; UX-3)

    /// The play surface's fingertip sample (§6.3's pacer input): the
    /// gesture layer converts the touch to GRID units (offset from the
    /// stage center, y-down) and streams it here while a round is in
    /// flight — INSTEAD of the touch vocabulary's pat intents. The offset
    /// is remembered for the stillness ticker's solo samples.
    func sendFingertip(offset: CGPoint, moving: Bool) {
        lastPlayFingertipOffset = offset
        foldDirector(.fingertip(offset: offset, moving: moving, at: canvasClock.elapsed()))
    }

    /// The quiet "Done" pill's early exit (UX-3; TASK-035 R2→R6): folds the
    /// ONE stop event into the director, whose exactly-once
    /// `handshakeCancelled(.play)` drains into the engine (R1) and ceases
    /// the round there — the unified cease applies the round's effects and
    /// count exactly once. NOT `.appHidden` (no hide semantics fire), and
    /// not a local-only dismissal (the engine ceases; the count lands).
    func stopPlayRound() {
        foldDirector(.playStopped(at: canvasClock.elapsed()))
    }

    // MARK: The rig's reaction-motion seam (TASK-034 R3)

    /// The Home rig's `reactionMotion` closure (R3): a `@Sendable` sampler
    /// over the CURRENT director value — static reading under Reduce Motion
    /// (the RESOLVED flag arrives from `MomoRigView`, which owns the
    /// environment resolution). The director is captured BY VALUE, so the
    /// closure never touches the main-actor model and the rig re-renders
    /// its samples fresh on every fold (reading this method from the view's
    /// body tracks `director`, re-evaluating `MomoRigView`'s closure with
    /// the successor value). D-R5 holds: the view calls this one method and
    /// never touches the director itself.
    func reactionMotion() -> @Sendable (Double, Bool) -> MomoReactionMotion {
        let director = self.director
        return { time, reduceMotion in
            reduceMotion
                ? director.reduceMotionOverlay(at: time)
                : director.overlay(at: time)
        }
    }

    // MARK: The VoiceOver announcements (UX-8; 04 §10.1 rule 7)

    /// The R7 seam: a reaction's catalog line announced while VoiceOver
    /// runs — NEVER rendered as body copy (UX-8; 04 §10.1 rule 7). The
    /// gate (`SpokenReaction`) admits all four react families (touch ·
    /// feed · play · care — TASK-035's widening), still excluding the
    /// slots/greetings/vocab/moment classes, and plans without a line
    /// announce nothing. Internal: the apply loop's response arm (main
    /// file) and the celebrations extension both announce through it.
    func announceSpokenLine(for response: ResponsePlan) {
        guard let key = SpokenReaction.announcementKey(for: response.lineKey)
        else { return }
        announceText(MomoCopyText.render(key))
    }

    /// The VoiceOver announcement primitive (the UX-8 pattern all
    /// announcements share): a rendered line posted as an `.announcement`,
    /// silent when VoiceOver is off. TASK-036 uses it for the M1
    /// done-state lines and the M2 banner's full line (§5.6: the stage
    /// moment is never visual-only). Internal: shared by the response arm
    /// (main file) and the celebrations extension.
    func announceText(_ text: String) {
        guard UIAccessibility.isVoiceOverRunning else { return }
        UIAccessibility.post(notification: .announcement, argument: text)
    }
}
