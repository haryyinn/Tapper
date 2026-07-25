// swift-tools-version: 6.0
//
// Tapper — Swift Package manifest.
//
// A tools-version of 6.0 selects the Swift 6 language mode with full
// concurrency checking by default, as required by the coding standards.
//
// The package exposes library products (not executables) so they can later be
// linked into a native Xcode application target without architectural changes.
// Subsystem targets are added in their own implementation phases rather than
// scaffolded up front. `Audio` is the first such subsystem (Phase 1).

import PackageDescription

let package = Package(
    name: "Tapper",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "Tapper", targets: ["Tapper"]),
        .library(name: "Audio", targets: ["Audio"]),
        .library(name: "DSP", targets: ["DSP"]),
        .library(name: "Features", targets: ["Features"]),
        .library(name: "Detection", targets: ["Detection"]),
        .library(name: "Calibration", targets: ["Calibration"]),
        .library(name: "Classification", targets: ["Classification"]),
        .library(name: "Commands", targets: ["Commands"]),
        .library(name: "Configuration", targets: ["Configuration"]),
        .library(name: "Diagnostics", targets: ["Diagnostics"]),
    ],
    targets: [
        .target(name: "Tapper"),
        .target(name: "Audio"),
        .target(name: "DSP"),
        .target(name: "Features", dependencies: ["DSP"]),
        .target(name: "Detection", dependencies: ["DSP", "Features"]),
        .target(name: "Calibration", dependencies: ["Features"]),
        .target(name: "Classification", dependencies: ["Features", "Calibration"]),
        .target(name: "Commands"),
        .target(name: "Configuration", dependencies: ["Calibration", "Commands"]),
        .target(
            name: "Diagnostics",
            dependencies: ["Calibration", "Classification", "Configuration"]
        ),
        .testTarget(name: "TapperTests", dependencies: ["Tapper"]),
        .testTarget(name: "AudioTests", dependencies: ["Audio"]),
        .testTarget(name: "DSPTests", dependencies: ["DSP"]),
        .testTarget(name: "FeaturesTests", dependencies: ["Features", "DSP"]),
        .testTarget(
            name: "DetectionTests", dependencies: ["Detection", "Features", "DSP", "Audio"]),
        .testTarget(name: "CalibrationTests", dependencies: ["Calibration", "Features"]),
        .testTarget(
            name: "ClassificationTests",
            dependencies: ["Classification", "Calibration", "Features"]
        ),
        .testTarget(name: "CommandsTests", dependencies: ["Commands"]),
        .testTarget(
            name: "ConfigurationTests",
            dependencies: ["Configuration", "Calibration", "Commands"]
        ),
        .testTarget(
            name: "DiagnosticsTests",
            dependencies: ["Diagnostics", "Classification", "Calibration", "Configuration"]
        ),
    ]
)
