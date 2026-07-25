// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NotchDeck",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/MrKai77/DynamicNotchKit.git", from: "1.0.0")
    ],
    targets: [
        .target(name: "NotchDeckCore"),
        .executableTarget(
            name: "NotchDeckApp",
            dependencies: [
                "NotchDeckCore",
                .product(name: "DynamicNotchKit", package: "DynamicNotchKit")
            ]
        ),
        .executableTarget(name: "notch-bridge", dependencies: ["NotchDeckCore"]),
        .testTarget(name: "NotchDeckCoreTests", dependencies: ["NotchDeckCore"])
    ],
    swiftLanguageModes: [.v5]
)
