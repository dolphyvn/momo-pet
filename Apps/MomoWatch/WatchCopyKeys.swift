import Foundation

// MARK: - WatchCopyKeys — W1's own copy-key minting (TASK-041 R6/R8; INV-11)

/// Fixed key-only lookups for the W1 surface's OWN chrome (INV-11: views
/// resolve catalog KEYS, never composed prose — MomoKit emits keys for the
/// SHARED vocabulary through `HomeCopyKeys`; the Watch's own slots mint
/// theirs here, the app-target home for Watch-only copy). The keys live in
/// `Apps/Shared/MomoCopy.xcstrings` under the `momo.line.watch.*` namespace
/// (the catalog's line grammar, Watch-scoped); the shipped strings are
/// pinned verbatim by the catalog-scaffolding suite, and the namespace is
/// admitted by the catalog law's fixed-pattern extension.
///
/// Pure: three fixed lookups — a named line class is a FIXED key, never a
/// seeded draw (the `HomeCopyKeys.allDoneLineKey` precedent: the settling-in
/// line must say THE settling-in line, the pat pill must say THE pat label,
/// and the a11y composite must say THE composite).
enum WatchCopyKeys {

    /// The pre-first-sync (and post-wipe) settling-in line — UX §9's calm
    /// single line, the W1 content when no snapshot is renderable. Never an
    /// error, never a retry affordance.
    static let settlingInKey = "momo.line.watch.settlingIn"

    /// The Pat pill's rendered label — the W1 pat target's one word. The
    /// pat CAPTURE is TASK-042's; the label exists from W1's first frame.
    static let patLabelKey = "momo.line.watch.pat"

    /// The W1 VoiceOver composite (UX §10's W1 row, verbatim template):
    /// "{name} feels {mood} and {energy}. {Stage}. Today's wish: {wish}.
    /// Pat button." Five positional `%1$@…%5$@` placeholders (name, mood
    /// word, energy phrase, stage name, quest line) so a localized
    /// reordering stays locale-correct (the `momo.line.moment.01`
    /// template precedent). Accessibility-ONLY — never rendered; the
    /// trailing "Pat button." pre-announces the pill element below it.
    static let glanceAccessibilityTemplateKey = "momo.line.watch.a11y.glance"
}
