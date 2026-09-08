import Foundation

/// Type-safe keys for the three engine-owned copy namespaces
/// (04-character-system §10.4; 05 §4.9).
///
/// The division of authority (05 §4.11 INV-11): the engine composes no
/// sentences — it emits only catalog keys from exactly these namespaces, and
/// app targets resolve them through String Catalogs (D12: no string literals
/// in views). The key grammar lives in one place so both sides are pinned to
/// it: `CopyKey` builds and validates keys; `MomoCopy` resolves them against a
/// bundle.
///
/// Index `00` is reserved for placeholders (real tone-guide pools number from
/// `01`); placeholder entries in the catalog carry a `PLACEHOLDER` comment —
/// the convention `MomoCatalogScaffoldingTests` pins.
public enum CopyKey {

    /// Visual body-copy slots (04 §10.4): `momo.line.<slot>.<nn>`.
    /// Slot selection is by local-time window (D11); `greeting` and
    /// `care-moment` are context-selected.
    public enum Slot: String, Sendable, CaseIterable {
        case morning, day, evening, night, greeting
        case careMoment = "care-moment"
    }

    /// VoiceOver-only reaction families (04 §6): `momo.line.react.<family>.<nn>`.
    /// These strings are announced by assistive tech and never rendered as
    /// body copy (§10.1 rule 7, UX-8).
    public enum Family: String, Sendable, CaseIterable {
        case touch, feed, play, care
    }

    /// `momo.line.<slot>.<nn>` — visual body copy.
    public static func line(_ slot: Slot, _ index: Int) -> String {
        "momo.line.\(slot.rawValue).\(padded(index))"
    }

    /// `momo.line.react.<family>.<nn>` — accessibility-only spoken lines.
    public static func react(_ family: Family, _ index: Int) -> String {
        "momo.line.react.\(family.rawValue).\(padded(index))"
    }

    /// `momo.line.moment.<nn>` — M2 stage banner + M3 all-done lines
    /// (structurally exempt from the 12-word max, 05 §4.9 OBS-2).
    public static func moment(_ index: Int) -> String {
        "momo.line.moment.\(padded(index))"
    }

    /// INV-11 conformance check: is `key` shaped like a key from an approved
    /// namespace? (Namespace membership, not pool bounds — engine read-models
    /// carry raw key strings, so consumers can assert what they were handed.)
    public static func isInApprovedNamespace(_ key: String) -> Bool {
        let slots = Slot.allCases.map(\.rawValue).joined(separator: "|")
        let families = Family.allCases.map(\.rawValue).joined(separator: "|")
        let pattern = "^momo\\.line\\.(?:(?:\(slots))|react\\.(?:\(families))|moment)\\.\\d{2}$"
        return key.range(of: pattern, options: .regularExpression) != nil
    }

    /// `<nn>` — exactly two digits, zero-padded. Index `00` is the placeholder
    /// index; real pools start at `01`.
    private static func padded(_ index: Int) -> String {
        precondition((0...99).contains(index), "copy key index must fit <nn>: \(index)")
        return String(format: "%02d", index)
    }
}

/// String-Catalog resolution for copy keys.
///
/// Bundle injection: package code cannot touch `Bundle.main` — app targets
/// pass their own bundle (`.main`) and the catalog is compiled into each app
/// bundle from `Apps/Shared/MomoCopy.xcstrings` (shared by Momo and
/// MomoWatch). The host test target injects a synthesized bundle, so the real
/// `Bundle.localizedString` path is unit-tested without an app.
public enum MomoCopy {

    /// The catalog's table name — the `.xcstrings` file stem.
    public static let tableName = "MomoCopy"

    /// Total lookup: the catalog value for `key`, or `nil` when the key has no
    /// entry. This is the "missing key surfaces" path (unit-tested).
    public static func lookup(_ key: String, bundle: Bundle, table: String = tableName) -> String? {
        // A real translation equal to this sentinel is implausible by
        // construction (REVIEW-TASK-011 NITPICK-2), so exact-equality
        // against it reliably distinguishes "missing" from any real value.
        let missing = "\u{0}momo.copy.missing\u{0}"
        let value = bundle.localizedString(forKey: key, value: missing, table: table)
        return value == missing ? nil : value
    }

    /// Resolution for view code: the localized value. In DEBUG a missing key
    /// trips `assertionFailure` — missing keys fail loudly in debug builds
    /// (String Catalog defaults surface unresolved keys); Release degrades to
    /// returning the key itself rather than crashing a shipped build.
    public static func resolve(_ key: String, bundle: Bundle, table: String = tableName) -> String {
        guard let value = lookup(key, bundle: bundle, table: table) else {
            #if DEBUG
            assertionFailure("MomoCopy: missing catalog key '\(key)' (table '\(table)')")
            #endif
            return key
        }
        return value
    }
}
