import SwiftUI
import MomoKit

/// The navigation shell implementing UX-1 (03-ux-architecture §2):
/// three native tabs — Home · Room · Settings — flat IA, no push navigation,
/// no badges. The tab bar is the real Phase 1 navigation. Home (TASK-033)
/// and Room (TASK-037) are composed; Settings is placeholder until
/// TASK-038. The three tab labels render from the catalog's `momo.tab.*`
/// chrome class through `MomoCopyText` (D12: no string literals in views).
struct RootTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label(MomoCopyText.render(HomeCopyKeys.tabLabelKey(for: .home)), systemImage: "house") }
            RoomView()
                .tabItem { Label(MomoCopyText.render(HomeCopyKeys.tabLabelKey(for: .room)), systemImage: "door.left.hand.open") }
            PlaceholderSettingsView()
                .tabItem { Label(MomoCopyText.render(HomeCopyKeys.tabLabelKey(for: .settings)), systemImage: "gearshape") }
        }
    }
}
