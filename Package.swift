// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BannerHither",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    targets: [
        // Platform-independent engine: models, geometry, placement policy, settings.
        // No AppKit or Accessibility imports, so everything in it is unit-testable.
        .target(
            name: "BannerHitherCore",
            path: "Sources/BannerHitherCore"
        ),
        // The menu bar application: AppKit UI, Accessibility probing, screen lookup.
        .executableTarget(
            name: "BannerHither",
            dependencies: ["BannerHitherCore"],
            path: "Sources/BannerHither",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "BannerHitherCoreTests",
            dependencies: ["BannerHitherCore"],
            path: "Tests/BannerHitherCoreTests"
        ),
    ]
)
