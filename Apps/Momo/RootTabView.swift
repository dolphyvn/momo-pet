import SwiftUI
import MomoKit

/// The navigation shell implementing UX-1 (03-ux-architecture §2):
/// three native tabs — Home · Room · Settings — flat IA, no push navigation,
/// no badges. The tab bar is the real Phase 1 navigation. All three tabs are
/// composed (Home TASK-033, Room TASK-037, Settings TASK-038). The three tab
/// labels render from the catalog's `momo.tab.*` chrome class through
/// `MomoCopyText` (D12: no string literals in views).
struct RootTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label(MomoCopyText.render(HomeCopyKeys.tabLabelKey(for: .home)), systemImage: "house") }
            RoomView()
                .tabItem { Label(MomoCopyText.render(HomeCopyKeys.tabLabelKey(for: .room)), systemImage: "door.left.hand.open") }
            SettingsView()
                .tabItem { Label(MomoCopyText.render(HomeCopyKeys.tabLabelKey(for: .settings)), systemImage: "gearshape") }
        }
    }
}
