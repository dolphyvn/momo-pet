import SwiftUI

/// Momo (iPhone) app entry point (TASK-009 placeholder shell; TASK-031 wires
/// the app model behind it).
///
/// The app model facade's thin executor (`MomoAppModel`) is constructed here
/// — its launch read (the one sanctioned synchronous main-thread I/O, 05
/// §5.2) happens at that construction — published into the environment as
/// the shell's only state source (D-R5: views never invoke the engine), and
/// handed `scenePhase` so the §4.2 trigger table's foreground/background
/// behavior is driven. The WatchConnectivity iPhone-side session lands in
/// EPIC-008. This target's permitted package edges (MomoCore + MomoCharacter
/// + MomoKit; never MomoWatch — D-R3) are wired as product dependencies in
/// the project's Frameworks phase.
@main
struct MomoApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var appModel = MomoAppModel()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(appModel)
                .onChange(of: scenePhase) { _, phase in
                    appModel.scenePhaseChanged(to: phase)
                }
        }
    }
}
