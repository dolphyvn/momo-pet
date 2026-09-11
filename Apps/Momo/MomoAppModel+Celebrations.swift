import Foundation
import MomoKit
import MomoCore

// MARK: - MomoAppModel + Celebrations — the quest moments + celebrations
// seam (TASK-036; TASK-039 R8 — the members moved verbatim from
// `MomoAppModel.swift`)

/// The quest moments' and celebrations' presentation machinery (TASK-036):
/// the M1 flip flourish memory, the M2 stage banner with its authored
/// auto-fade, the banner's tap dismissal and its full VoiceOver line, and
/// the onboarding-completion trigger entry. TASK-039 R8 extracted them
/// move-semantically — ZERO behavior change — to bring the main file back
/// inside the 800-line budget (the `+Settings` precedent: Swift's
/// `private` is file-scoped, so the members the seams share —
/// `celebratingQuests`' and `activeCelebrationStage`'s setters,
/// `celebrationTask`, `questFlipTask`, `announceText` — are `internal`,
/// annotated at their declaration sites; no accessor leaves the target).
extension MomoAppModel {

    /// Authored auto-fade of the M2 stage banner (TASK-036 R4, disclosed):
    /// 03 §5.6's "auto-fades ~4 s" — the banner dismisses itself at 4.0 s.
    static let celebrationAutoFadeSeconds: Double = 4.0

    /// Authored length of the M1 flip flourish on the quest card
    /// (TASK-036 R3, disclosed): the just-completed row's mark swells for
    /// 0.6 s — 03 §5.5's "tiny in-scene flourish" scale, no spring
    /// firework. Under Reduce Motion the swell is skipped (D16: the fill
    /// itself is the emphasis).
    static let questFlipFlourishSeconds: Double = 0.6

    /// The M1 flip half (R3): record the quests this application flipped
    /// to done — the card's flourish memory, latest-wins, cleared by the
    /// authored 0.6 s task — and speak each completion through the quest
    /// card's done-state line ("{wish}, done" — the row label's own
    /// shape, UX §10's words-never-symbols rule).
    func recordQuestFlips(_ flips: [QuestID]) {
        guard !flips.isEmpty else { return }
        celebratingQuests = flips
        questFlipTask?.cancel()
        questFlipTask = Task { await clearQuestFlips() }
        for questID in flips {
            announceText("\(MomoCopyText.render(HomeCopyKeys.questWishKey(for: questID))), done")
        }
    }

    /// The flip flourish's auto-clear (the authored
    /// `questFlipFlourishSeconds`); real-time sleep, so it runs under any
    /// clock. A superseding application cancelled this task before its
    /// sleep ends — the guard keeps a stale clear from erasing a NEWER
    /// flip set.
    func clearQuestFlips() async {
        try? await Task.sleep(for: .seconds(Self.questFlipFlourishSeconds))
        guard !Task.isCancelled else { return }
        celebratingQuests = []
    }

    /// The M2 celebration (R4): the banner stage goes visible, its
    /// authored ~4 s auto-fade is scheduled, and the FULL line
    /// ("{name} and you are now {Stage}. {descriptor line}.") is announced
    /// so the stage moment is never visual-only (UX §5.6). A new
    /// celebration replaces a showing one (the old fade task is
    /// cancelled first).
    func showStageCelebration(_ stage: BondStage) {
        celebrationTask?.cancel()
        activeCelebrationStage = stage
        celebrationTask = Task { await autoFadeCelebration() }
        announceText(celebrationLine(for: stage))
    }

    /// The banner's auto-fade: nil the stage after the authored 4.0 s —
    /// a REAL-TIME sleep (works under any clock; the banner is
    /// presentation time, not canvas time).
    func autoFadeCelebration() async {
        try? await Task.sleep(for: .seconds(Self.celebrationAutoFadeSeconds))
        guard !Task.isCancelled else { return }
        activeCelebrationStage = nil
    }

    /// UX §5.6: the banner dismisses on tap — the view's one banner
    /// action, routed here like every other intent (D-R5; never a
    /// UI-only dismissal).
    public func dismissCelebration() {
        celebrationTask?.cancel()
        celebrationTask = nil
        activeCelebrationStage = nil
    }

    /// The M2 banner's full line (UX §5.6's "{name} and you are now
    /// {Stage}. {descriptor line}."): the FIXED `moment.01` template —
    /// positional `%1$@`/`%2$@` placeholders keep a localized reordering
    /// locale-correct — over the pet's name and the catalog stage word,
    /// then the vocabulary descriptor sentence.
    public func celebrationLine(for stage: BondStage) -> String {
        let template = MomoCopyText.render(HomeCopyKeys.celebrationBannerTemplateKey)
        let stageWord = MomoCopyText.render(HomeCopyKeys.stageNameKey(for: stage))
        let descriptor = MomoCopyText.render(VocabularyKeys.bondDescriptorKey(for: stage))
        return String(format: template, state.pet.name, stageWord) + " " + descriptor
    }

    /// The onboarding completion tap (TASK-032 R5; FR-1 AC-2, FR-13 AC-1):
    /// mints the final pet identity AT THE TAP (the injected UUID keeps the
    /// plan core pure and determinism testable) and applies the completion
    /// trigger — the transformation whose `.persist` step is the atomic
    /// completion write. The S2 button's disabled state is INV-1's product
    /// face (whitespace-only names never reach here enabled); a violation
    /// now is an invariant regression — DEBUG-loud, inert in release (no
    /// plan applied, nothing persisted, the gate keeps the flow on S2).
    func completeOnboarding(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            Self.debugLoud("MomoAppModel: onboarding completion rejected a whitespace-only name")
            return
        }
        Task { await self.apply(trigger: .onboardingCompleted(petID: UUID(), name: trimmed)) }
    }
}
