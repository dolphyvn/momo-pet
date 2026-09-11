import SwiftUI
import MomoKit

/// MomoWatch (watchOS) app entry point — W1 (TASK-041; 03-ux-architecture
/// §6.1). The app model is constructed here with its launch read (the ONE
/// sanctioned synchronous main-thread read, OBS-1) and binds the receive-only
/// WC transport (the ADR-013 twin) sink-first; `GlanceView` renders the
/// last-synced snapshot — or the settling-in line — and the scene-phase
/// handler persists on every background transition (TR9). Pat capture, the
/// intent journal, and the send transport surface land in TASK-042; the
/// Watch-side quest re-cascade in TASK-043. This target's permitted package
/// edges (MomoCore + MomoCharacter + MomoKit; never Momo — D-R3) are wired
/// as product dependencies in the project's Frameworks phase.
@main
struct MomoWatchApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var appModel = MomoWatchAppModel(
        storeDirectory: MomoWatchAppModel.testStoreDirectory(),
        transport: LiveWatchTransport()
    )

    var body: some Scene {
        WindowGroup {
            GlanceView(model: appModel)
                .onChange(of: scenePhase) { _, phase in
                    appModel.scenePhaseChanged(to: phase)
                }
        }
    }
}
