import SwiftUI

/// Placeholder navigation shell implementing UX-1 (03-ux-architecture §2):
/// three native tabs — Home · Room · Settings — flat IA, no push navigation,
/// no badges. The tab bar is the real Phase 1 navigation; tab content below is
/// placeholder. Composed screens arrive in EPIC-007 (TASK-033/037/038).
struct RootTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }
            PlaceholderRoomView()
                .tabItem { Label("Room", systemImage: "door.left.hand.open") }
            PlaceholderSettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}
