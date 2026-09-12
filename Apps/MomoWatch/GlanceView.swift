import SwiftUI
import MomoKit
import MomoCore
import MomoCharacter

// MARK: - GlanceView — the W1 surface (TASK-041 R6/R7; 03-ux-architecture
// §6.1, §6.4, §6.5, §9, §10)

/// W1, the one glanceable surface, exactly UX §6.1's layout: status slot
/// (mood word — the glance — + the compact bond-stage secondary), the pet
/// canvas (a §2.1 glance-band stage in a fixed slot — `.glance` rig
/// foreground / `.glyph` static in luminance-reduced), the single quest
/// line, and the full-width Pat pill. Everything resolves through String Catalog keys (`MomoCopyText`;
/// INV-11 — no composed prose, no product-copy literals here): mood word and
/// energy phrase through the snapshot's own vocabulary keys, stage and quest
/// through the SHARED `HomeCopyKeys` lookups, W1's own slots through
/// `WatchCopyKeys`.
///
/// **States.** A renderable snapshot shows the four slots; nil (fresh
/// install, post-wipe, unrecoverable store) shows ONLY the settling-in line
/// — calm, no error, no retry affordance (UX §9) — and structurally exposes
/// NO pat targets. A nil assembled character (cross-version skew, ADR-014's
/// degraded shape) keeps the words + quest line and holds the canvas slot
/// with the palette blanket — never a crash, never a layout jump.
///
/// **The pat capture (TASK-042).** Both targets — the canvas by touch, the
/// pill as a real button — land in `MomoWatchAppModel.pat()`: an immediate
/// local micro-reaction (the `.tap`/`.stir` clip per the CURRENT snapshot's
/// wakefulness, ADR-015 D1) + the toggle-honoring haptic (UX §6.3 exact),
/// fully offline. VoiceOver acts through the pill; the canvas tap is a
/// touch-only affordance inside the composite element (no duplicate a11y
/// action — the composite's contract is UX §10's exact wording).
///
/// **AOD (R7).** Foreground binds the `.glance` tier through
/// `RigLOD.tier(for: .watchForeground)`; the luminance-reduced environment
/// binds the STATIC `.glyph` tier (that rig branch never binds a clock) over
/// the SAME assembled `CharacterDisplayState` — no Watch-side derivation.
/// The DEBUG `-momo-aod-preview` launch argument forces the glyph branch for
/// the whole launch (the O4 true-size evidence vehicle; release builds never
/// force it). Apple Watch SE has no always-on display — the branch is
/// evidenced structurally + by true-size stills, not by runtime observation
/// (§25, routed to TASK-044's device obligations).
struct GlanceView: View {

    /// The app model — W1's only state source (D-R5). Property access is
    /// tracked through `@Observable`; receives re-render this body.
    let model: MomoWatchAppModel

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        if let snapshot = model.snapshot {
            glance(for: snapshot)
        } else {
            settlingIn
        }
    }

    // MARK: The four slots (UX §6.1)

    private func glance(for snapshot: WatchSnapshot) -> some View {
        // The quest line's LIVE value (TASK-043 R1): the app model's stored
        // re-cascade — recomputed at init, receive, and scene activation,
        // never on a timer. The fallback reads the FROZEN push-time output
        // and exists only as belt-and-braces for the never-expected window
        // where the stored line is nil beside a snapshot; the app model sets
        // and clears both together at every leg, so the single read here is
        // the whole view-side story (the scan census pins it).
        let questLine = model.liveQuestLine ?? snapshot.display.questLine
        return VStack(alignment: .leading, spacing: MomoSpacing.small) {
            // The composite VoiceOver element: status + canvas + quest
            // announce as ONE, in UX §10's exact W1 wording; the pill stays
            // its own element below.
            Group {
                statusSlot(for: snapshot.display)
                petCanvas
                questSlot(for: questLine)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(compositeLabel(for: snapshot, questLine: questLine))
            .accessibilityIdentifier("watch.glance")
            patPill
        }
        .padding(MomoSpacing.medium)
    }

    /// The status slot: the mood word (the glance) over the compact
    /// bond-stage secondary — words, never numbers or bars (FR-17 AC-4).
    private func statusSlot(for display: DisplayState) -> some View {
        VStack(alignment: .leading, spacing: MomoSpacing.extraSmall) {
            Text(MomoCopyText.render(display.moodWordKey))
                .font(MomoTypography.heading)
                .foregroundStyle(MomoUIColors.textPrimary.resolve(colorScheme))
            Text(MomoCopyText.render(HomeCopyKeys.stageNameKey(for: display.bondStage)))
                .font(MomoTypography.caption)
                .foregroundStyle(MomoUIColors.textSecondary.resolve(colorScheme))
        }
    }

    /// The pet canvas: the assembled character through the surface's LOD
    /// tier. The fixed slot height IS the placeholder's deterministic-height
    /// lesson; the rig centers inside it, so the AOD tier's smaller stage
    /// never moves the layout. A nil character (ADR-014's degraded shape)
    /// holds the slot with the palette blanket. A tap anywhere on the slot
    /// captures ONE pat (TASK-042 R9; UX §6.2's "tap anywhere on the Watch
    /// stage") — by touch only: the slot stays INSIDE the composite a11y
    /// element (children ignored), so VoiceOver users act through the pill
    /// below and no duplicate a11y action exists.
    private var petCanvas: some View {
        ZStack {
            if let character = model.characterDisplay {
                if tier == .glyph {
                    // AOD/glyph binds NO sampler (R5; 04 §6.4 "AOD: no
                    // reaction") — the parameter's `.identity` default IS
                    // the stillness posture; the rig call keeps TASK-041's
                    // exact shape.
                    MomoRigView(
                        displayState: character,
                        tier: tier,
                        clock: model.canvasClock,
                        stageSide: stageSide
                    )
                } else {
                    // Foreground: the pat reaction rides the rig's existing
                    // sampler seam (ADR-015 D1 — the ONLY MomoCharacter
                    // touch, and it is additive at this call site).
                    MomoRigView(
                        displayState: character,
                        tier: tier,
                        clock: model.canvasClock,
                        stageSide: stageSide,
                        reactionMotion: model.reactionMotion()
                    )
                }
            } else {
                RoundedRectangle(cornerRadius: MomoRadius.medium)
                    .fill(MomoCharacterPalette.blanket.resolve(colorScheme))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: GlanceLayout.canvasHeight)
        .contentShape(Rectangle())
        .onTapGesture { model.pat() }
        .accessibilityLabel(MomoCopyText.render(WatchCopyKeys.patLabelKey))
        .accessibilityIdentifier("watch.canvas")
    }

    /// The quest line: the LIVE cascade output (TASK-043 R1 — the Watch
    /// re-runs the shared derivation over the carried inputs under its own
    /// local hour), display-only by construction: a `Text`, no action
    /// affordance — the pat canvas and Pat pill below are the ONLY
    /// tappables (UX §6.1). The wish key or the all-done key through the
    /// SHARED `HomeCopyKeys` lookups.
    private func questSlot(for questLine: QuestGeneration.QuestLine) -> some View {
        Text(MomoCopyText.render(questLineKey(for: questLine)))
            .font(MomoTypography.caption)
            .foregroundStyle(MomoUIColors.textSecondary.resolve(colorScheme))
            .lineLimit(2)
    }

    /// The Pat pill: a REAL button (TASK-042 R9) — full-width, ≥ 44 pt,
    /// button trait from the `Button`, its TASK-041 label unchanged (the
    /// composite above still pre-announces "Pat button."), the same action
    /// the canvas offers (UX-11). `.plain` keeps the pill's own capsule
    /// surface and text colors (the default bordered style would tint them).
    private var patPill: some View {
        Button(action: { model.pat() }) {
            Text(MomoCopyText.render(WatchCopyKeys.patLabelKey))
                .font(MomoTypography.body.weight(.medium))
                .foregroundStyle(MomoUIColors.textPrimary.resolve(colorScheme))
                .frame(maxWidth: .infinity)
                .frame(minHeight: GlanceLayout.minimumTargetSide)
                .padding(.vertical, MomoSpacing.small)
                .background(MomoUIColors.surface.resolve(colorScheme), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(MomoCopyText.render(WatchCopyKeys.patLabelKey))
        .accessibilityIdentifier("watch.patPill")
    }

    // MARK: The settling-in state (UX §9)

    /// Pre-first-sync / post-wipe: the calm single line, centered, and
    /// NOTHING else — no error, no badge, no retry affordance, ever.
    private var settlingIn: some View {
        Text(MomoCopyText.render(WatchCopyKeys.settlingInKey))
            .font(MomoTypography.body)
            .foregroundStyle(MomoUIColors.textSecondary.resolve(colorScheme))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(MomoSpacing.large)
            .accessibilityIdentifier("watch.settlingLine")
    }

    // MARK: The LOD leg (R7) + the a11y composite (UX §10)

    /// The surface's tier: `.glance` foreground (the `RigLOD` mapping —
    /// never spelled locally), the STATIC `.glyph` when the display is
    /// luminance-reduced or the DEBUG AOD-preview argument forces it. The
    /// glyph rig branch binds no clock — stillness IS the AOD posture.
    private var tier: RigLODTier {
        if isLuminanceReduced || model.aodPreview {
            return .glyph
        }
        return RigLOD.tier(for: .watchForeground)
    }

    /// The stage side within the tier's band (`RigLOD.glanceStagePoints`
    /// 60–80, `RigLOD.glyphStagePoints` 24–32): 68 foreground, 28 in AOD.
    /// The frozen §2.1 glance band — not UX §6.1's "~40 % of the screen"
    /// canvas share, which is unreachable inside it (80/448 = 17.9 %) —
    /// governs the stage size; the deviation is recorded in the task file's
    /// Implementation Notes. The AOD true-size legibility judgment over
    /// these values is recorded there too (the O4 closure).
    private var stageSide: CGFloat {
        tier == .glyph ? GlanceLayout.glyphStageSide : GlanceLayout.glanceStageSide
    }

    /// The quest line's catalog key — the snapshot carries the cascade's
    /// STATE; the key minting is the SHARED Home composition's (a wish names
    /// its `momo.line.quest.q<n>`, all-done names `momo.line.moment.02`).
    private func questLineKey(for questLine: QuestGeneration.QuestLine) -> String {
        switch questLine {
        case .wish(let questID): return HomeCopyKeys.questWishKey(for: questID)
        case .allDone: return HomeCopyKeys.allDoneLineKey
        }
    }

    /// The W1 VoiceOver composite (UX §10's W1 row, verbatim template):
    /// "{name} feels {mood} and {energy}. {Stage}. Today's wish: {wish}.
    /// Pat button." — resolved over the SHIPPED strings through the catalog
    /// template's five positional placeholders (the `moment.01` formatting
    /// precedent). The quest placeholder is the SAME live line the visual
    /// slot renders (TASK-043 R1 — one value, both surfaces). The trailing
    /// "Pat button." pre-announces the pill element that follows the
    /// composite.
    private func compositeLabel(
        for snapshot: WatchSnapshot,
        questLine: QuestGeneration.QuestLine
    ) -> String {
        let display = snapshot.display
        return String(
            format: MomoCopyText.render(WatchCopyKeys.glanceAccessibilityTemplateKey),
            display.petName,
            MomoCopyText.render(display.moodWordKey),
            MomoCopyText.render(display.energyPhraseKey),
            MomoCopyText.render(HomeCopyKeys.stageNameKey(for: display.bondStage)),
            MomoCopyText.render(questLineKey(for: questLine))
        )
    }
}

/// The W1 layout constants (one auditable home; the tier bands live in
/// `RigLOD` and are referenced, never re-stated).
private enum GlanceLayout {

    /// The foreground canvas: 68 pt — mid-band inside
    /// `RigLOD.glanceStagePoints` (60–80), which governs (see the stageSide
    /// note on the `stageSide` property for the §6.1 share deviation).
    static let glanceStageSide: CGFloat = 68

    /// The AOD canvas: 28 pt — inside `RigLOD.glyphStagePoints` (24–32).
    /// True-size legibility at this value is the O4 judgment of record.
    static let glyphStageSide: CGFloat = 28

    /// The canvas slot's height: the glance rig's side plus breathing room,
    /// so the AOD glyph centers in an UNCHANGED slot (no layout jump at the
    /// luminance transition) and the tappable target clears 44 pt.
    static let canvasHeight: CGFloat = glanceStageSide + MomoSpacing.small

    /// The ≥ 44 pt pat-target floor (UX §6.1/§10).
    static let minimumTargetSide: CGFloat = 44
}
