import SwiftUI

/// MomoWatch (watchOS) app entry point — placeholder shell (TASK-009, EPIC-002).
///
/// The W1 surface, snapshot restore, pat capture + intent journaling and the
/// WatchConnectivity Watch-side session land in EPIC-008 (TASK-040…044, 05 §2.1).
/// This target's permitted package edges (MomoCore + MomoCharacter + MomoKit;
/// never Momo — D-R3) are wired as product dependencies in the project's
/// Frameworks phase.
@main
struct MomoWatchApp: App {
    var body: some Scene {
        WindowGroup {
            PlaceholderGlanceView()
        }
    }
}
