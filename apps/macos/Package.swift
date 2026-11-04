// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "IsleNestMac",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "IsleNest", targets: ["IsleNest"]),
        .library(name: "IsleNestCore", targets: ["IsleNestCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts.git", exact: "3.1.0")
    ],
    targets: [
        .target(
            name: "IsleNestCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "IsleNest",
            dependencies: [
                "IsleNestCore",
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts")
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "IsleNestCoreTests",
            dependencies: ["IsleNestCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
