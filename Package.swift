// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ClaudeNotch",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/MrKai77/DynamicNotchKit.git", from: "1.0.0")
    ],
    targets: [
        .target(name: "ClaudeNotchCore"),
        .executableTarget(
            name: "ClaudeNotchApp",
            dependencies: [
                "ClaudeNotchCore",
                .product(name: "DynamicNotchKit", package: "DynamicNotchKit")
            ]
        ),
        .executableTarget(name: "notch-bridge", dependencies: ["ClaudeNotchCore"]),
        .testTarget(name: "ClaudeNotchCoreTests", dependencies: ["ClaudeNotchCore"])
    ],
    swiftLanguageModes: [.v5]
)
