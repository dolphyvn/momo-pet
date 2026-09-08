import SwiftUI

/// Placeholder Room tab (UX-1, second tab) — the room scene (FR-3) arrives
/// with TASK-037. No logic, no state, placeholder copy only.
struct PlaceholderRoomView: View {
    var body: some View {
        ContentUnavailableView(
            "Room — placeholder",
            systemImage: "door.left.hand.open",
            description: Text("The room scene is not built yet.")
        )
    }
}
