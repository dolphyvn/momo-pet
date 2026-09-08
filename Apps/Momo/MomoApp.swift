import SwiftUI

/// Momo (iPhone) app entry point — placeholder shell (TASK-009, EPIC-002).
///
/// The app model facade, engine host, evaluation scheduling and the
/// WatchConnectivity iPhone-side session land in EPIC-007/008 (05 §2.1).
/// This target's permitted package edges (MomoCore + MomoCharacter + MomoKit;
/// never MomoWatch — D-R3) are wired as product dependencies in the project's
/// Frameworks phase.
@main
struct MomoApp: App {
    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
    }
}
