import SwiftUI
import MomoCharacter

/// The view-side copy resolver (TASK-033 Requirement 6; INV-11's last hop):
/// MomoKit emits catalog KEYS only, and every Home surface renders them
/// through this helper — `MomoCopy.resolve` over the app bundle's compiled
/// String Catalog (D12: no string literals in views; a missing key trips the
/// DEBUG assertion). One funnel so the resolution discipline is greppable.
enum MomoCopyText {

    /// The localized text for a catalog key.
    static func render(_ key: String) -> String {
        MomoCopy.resolve(key, bundle: .main)
    }
}
