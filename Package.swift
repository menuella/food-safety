// swift-tools-version: 6.0

import PackageDescription

// At the repository ROOT because SwiftPM resolves the manifest from there and
// has no monorepo support — the same constraint Packagist imposes on
// composer.json. The target paths point into packages/swift/ instead.
let package = Package(
    name: "MenuellaFoodSafety",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .tvOS(.v15),
        .watchOS(.v8),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "MenuellaFoodSafety", targets: ["MenuellaFoodSafety"]),
    ],
    targets: [
        .target(
            name: "MenuellaFoodSafety",
            path: "packages/swift/Sources/MenuellaFoodSafety",
            // .copy, not .process: the loader looks resources up by
            // subdirectory ("Resources/bundles"), and .process is free to
            // flatten the tree. .copy preserves it verbatim.
            resources: [.copy("Resources")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "MenuellaFoodSafetyTests",
            dependencies: ["MenuellaFoodSafety"],
            path: "packages/swift/Tests/MenuellaFoodSafetyTests",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
