// swift-tools-version: 6.0
//
// Tapper — Swift Package manifest.
//
// A tools-version of 6.0 selects the Swift 6 language mode with full
// concurrency checking by default, as required by the coding standards.
//
// The package exposes a `Tapper` library product (not an executable) so it
// can later be linked into a native Xcode application target without
// architectural changes. Subsystem targets (Audio, DSP, Detection, …) are
// added in their own implementation phases rather than scaffolded here.

import PackageDescription

let package = Package(
    name: "Tapper",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "Tapper", targets: ["Tapper"])
    ],
    targets: [
        .target(name: "Tapper"),
        .testTarget(name: "TapperTests", dependencies: ["Tapper"]),
    ]
)
