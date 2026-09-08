import SwiftUI

/// Placeholder W1 glance (03-ux-architecture §6.1) — static content, no logic:
/// the four W1 slots (status · pet canvas · quest line · pat pill) rendered as
/// inert placeholders. Real snapshot rendering, the LOD character and pat
/// capture arrive in EPIC-008 (TASK-041/042). Copy is placeholder text, not
/// product copy (String Catalogs land in TASK-011).
struct PlaceholderGlanceView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Feeling happy") // placeholder status slot
                .font(.headline)
            Rectangle() // placeholder pet canvas (~40% of surface height)
                .fill(.quaternary)
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            Text("Wish placeholder") // placeholder quest line
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text("Pat") // placeholder pat pill — intentionally inert (no action in the shell)
                .font(.body.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(.quaternary, in: Capsule())
        }
        .padding()
    }
}
