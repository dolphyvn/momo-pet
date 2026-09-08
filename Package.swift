// swift-tools-version: 6.2
// (6.2 is the minimum manifest API exposing the `.v26` platform pins required by ADR-008.)
// Momo — repo-local Swift package (ADR-005).
//
// Module map and dependency rules D-R1–D-R6: docs/architecture/05-technical-architecture.md §2.
//   MomoCore      — domain + engine; Foundation-only imports (D-R1).
//   MomoCharacter — rig/clock/sequencer/LOD; depends on MomoCore (+ SwiftUI permitted by D-R2).
//   MomoKit       — persistence + sync DTOs; depends on MomoCore only (D-R2), macOS-clean.
// Zero external dependencies (D-R4): the `dependencies:` field is deliberately absent.
// Platform pins are the ADR-008 bootstrap floors (min iOS 26.0 / watchOS 26.0). `swift test`
// hosts all three targets on macOS — the swift-test-hostability VERIFY item (05 Appendix B).

import PackageDescription

let package = Package(
    name: "Momo",
    platforms: [
        .iOS(.v26),
        .watchOS(.v26),
        // macOS is not a shipping platform (ADR-005/008); it is declared so `swift test`
        // hosts the three targets on the build machine's current-generation floor (05 §10)
        // instead of SwiftPM's low default, which breaks the SwiftUI-importing target.
        .macOS(.v26)
    ],
    products: [
        .library(name: "MomoCore", targets: ["MomoCore"]),
        .library(name: "MomoCharacter", targets: ["MomoCharacter"]),
        .library(name: "MomoKit", targets: ["MomoKit"])
    ],
    targets: [
        // D-R1: Foundation-only imports. Enforced mechanically from TASK-010
        // (import-whitelist scan in MomoCoreTests, 05 §10.2).
        .target(name: "MomoCore"),
        // D-R2: depends on MomoCore only; SwiftUI is the sole additional permitted import.
        .target(name: "MomoCharacter", dependencies: ["MomoCore"]),
        // D-R2: depends on MomoCore only; no SwiftUI (WatchConnectivity wrappers live in the app targets).
        .target(name: "MomoKit", dependencies: ["MomoCore"]),
        // Empty-but-present test targets: they prove `swift test` hostability (TASK-009 AC-4).
        // Suites are filled by EPIC-003…006; TASK-010 adds the harness + static scans.
        .testTarget(name: "MomoCoreTests", dependencies: ["MomoCore"]),
        .testTarget(name: "MomoKitTests", dependencies: ["MomoKit"]),
        .testTarget(name: "MomoCharacterTests", dependencies: ["MomoCharacter"])
    ]
)
