import Foundation
import MomoCore

// MARK: - AppModelLaunch — the §5.2/§5.3 launch-read inputs (TASK-031)

/// The launch path's pure inputs, split out of the executor so the
/// fresh-vs-loaded detection is headlessly testable (05 §10.1's
/// no-app-unit-test-target constraint — the executor stays thin by pushing
/// every decision that can be decided into the package).
///
/// The launch path (05 §5.2–§5.3): the app model reads the store ONCE at
/// launch — the ONLY synchronous main-thread I/O in the app ("the main
/// thread never blocks on I/O beyond launch's initial read", §5.2; the
/// OBS-1 property routed from REVIEW-TASK-024) — and `SnapshotStore.load`
/// returns a state, never an error: total absence AND total corruption both
/// fall through to the injected fresh default, invisibly (§5.3's stance:
/// recovery is indistinguishable from a normal open). The "not onboarded"
/// flow input is therefore carried by the LOADED STATE's
/// `settings.onboardingComplete` flag (the injected fresh default ships it
/// `false`; a loaded state ships it `true` once onboarding completed) — the
/// detection below distinguishes fresh-vs-loaded for diagnostics and for
/// onboarding's later "first run" surface (TASK-032), never for recovery:
/// a torn store whose generations all fail is `hasGenerations == true` with
/// the fallback state served, which is exactly §5.3's invisible recovery.
public enum AppModelLaunch {

    /// Whether ANY persisted generation exists in the store directory (any
    /// of `StoreRules.generationFileNamesInReadOrder`, in any validity) —
    /// the fresh-vs-loaded launch input. A pure existence probe over the
    /// injected directory; no reads of file content (the content decision
    /// belongs to `SnapshotStore.load`'s gate order).
    public static func hasGenerations(
        directory: URL,
        fileManager: FileManager = .default
    ) -> Bool {
        StoreRules.generationFileNamesInReadOrder.contains { fileName in
            fileManager.fileExists(
                atPath: directory.appendingPathComponent(fileName).path(percentEncoded: false)
            )
        }
    }
}
