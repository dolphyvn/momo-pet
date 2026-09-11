import Foundation
import MomoCharacter

/// The view-side copy resolver (TASK-041 R6; INV-11's last hop) — the
/// `Apps/Momo/MomoCopyText.swift` funnel's Watch twin (ADR-013's per-target
/// duplication): MomoKit and `WatchCopyKeys` emit catalog KEYS only, and
/// every W1 surface renders them through this helper — `MomoCopy.resolve`
/// over the app bundle's compiled String Catalog (no string literals in
/// views; a missing key trips the DEBUG assertion). One funnel so the
/// resolution discipline is greppable.
enum MomoCopyText {

    /// The localized text for a catalog key.
    static func render(_ key: String) -> String {
        MomoCopy.resolve(key, bundle: .main)
    }
}
