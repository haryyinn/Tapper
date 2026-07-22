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
    ],
    targets: [
        .target(name: "Tapper"),
        .target(name: "Audio"),
        .target(name: "DSP"),
        .testTarget(name: "TapperTests", dependencies: ["Tapper"]),
        .testTarget(name: "AudioTests", dependencies: ["Audio"]),
        .testTarget(name: "DSPTests", dependencies: ["DSP"]),
    ]
)
