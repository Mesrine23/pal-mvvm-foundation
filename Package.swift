// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "pal-mvvm-foundation",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "PalCore", targets: ["PalCore"]),
        .library(name: "PalPersistence", targets: ["PalPersistence"]),
        .library(name: "PalNetworking", targets: ["PalNetworking"]),
        .library(name: "PalAuth", targets: ["PalAuth"]),
        .library(name: "PalPresentation", targets: ["PalPresentation"]),
        .library(name: "PalNavigation", targets: ["PalNavigation"]),
        .library(name: "PalDesignSystem", targets: ["PalDesignSystem"]),
        .library(name: "PalAnalytics", targets: ["PalAnalytics"]),
        .library(name: "PalFeatureFlags", targets: ["PalFeatureFlags"]),
        .library(name: "PalDebugKit", targets: ["PalDebugKit"]),
        .library(name: "PalNotifications", targets: ["PalNotifications"]),
    ],
    targets: [
        .target(
            name: "PalCore",
            resources: [.copy("PrivacyInfo.xcprivacy")]
        ),
        .target(
            name: "PalPersistence",
            dependencies: ["PalCore"],
            resources: [.copy("PrivacyInfo.xcprivacy")]
        ),
        .target(name: "PalNetworking", dependencies: ["PalCore"]),
        .target(name: "PalAuth", dependencies: ["PalCore", "PalNetworking", "PalPersistence"]),
        .target(
            name: "PalPresentation",
            dependencies: ["PalCore"],
            resources: [.process("Localizable.xcstrings")]
        ),
        .target(name: "PalNavigation"),
        .target(
            name: "PalDesignSystem",
            dependencies: ["PalCore", "PalPresentation"],
            resources: [.process("Localizable.xcstrings")]
        ),
        .target(name: "PalAnalytics", dependencies: ["PalCore"]),
        .target(name: "PalFeatureFlags", dependencies: ["PalCore"]),
        .target(name: "PalDebugKit", dependencies: ["PalCore", "PalNetworking", "PalPersistence"]),
        .target(name: "PalNotifications", dependencies: ["PalCore"]),
        .testTarget(
            name: "PalNotificationsTests",
            dependencies: ["PalNotifications"]
        ),
        .testTarget(
            name: "PalDesignSystemTests",
            dependencies: ["PalDesignSystem"]
        ),
        .testTarget(
            name: "PalPersistenceTests",
            dependencies: ["PalPersistence"]
        ),
        .testTarget(
            name: "PalNetworkingTests",
            dependencies: ["PalNetworking"]
        ),
        .testTarget(
            name: "PalNavigationTests",
            dependencies: ["PalNavigation"]
        ),
        .testTarget(
            name: "PalPresentationTests",
            dependencies: ["PalPresentation"]
        ),
        .testTarget(
            name: "PalDebugKitTests",
            dependencies: ["PalDebugKit"]
        ),
        .testTarget(
            name: "PalSmokeTests",
            dependencies: [
                "PalCore", "PalPersistence", "PalNetworking", "PalAuth", "PalPresentation",
                "PalNavigation", "PalDesignSystem", "PalAnalytics", "PalFeatureFlags", "PalDebugKit",
                "PalNotifications",
            ]
        ),
    ]
)
