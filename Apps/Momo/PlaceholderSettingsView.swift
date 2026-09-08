import SwiftUI

/// Placeholder Settings tab (UX-1, third tab) — settings, haptics toggle and
/// the erase-all flow (FR-19, the product's only modal) arrive with TASK-038.
struct PlaceholderSettingsView: View {
    var body: some View {
        ContentUnavailableView(
            "Settings — placeholder",
            systemImage: "gearshape",
            description: Text("Settings are not built yet.")
        )
    }
}
