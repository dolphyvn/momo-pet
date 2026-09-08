import SwiftUI

/// Placeholder Home tab (UX-1, first tab) — the placeholder pet canvas is a
/// rectangle; the composed Home (status row, pet canvas, action row, quest card;
/// FR-2) arrives with TASK-033 and the rig with TASK-025/026. Copy here is
/// inert placeholder text, not product copy (String Catalogs land in TASK-011).
struct PlaceholderHomeView: View {
    var body: some View {
        VStack(spacing: 24) {
            // Placeholder pet canvas — replaced by the Direction-C rig (TASK-025/026).
            Rectangle()
                .fill(.quaternary)
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: 240)
                .clipShape(RoundedRectangle(cornerRadius: 24))
            Text("Home — placeholder")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
