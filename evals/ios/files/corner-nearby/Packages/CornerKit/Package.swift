// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CornerKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Core", targets: ["Core"]),
        .library(name: "Networking", targets: ["Networking"]),
        .library(name: "Features", targets: ["Features"]),
    ],
    targets: [
        .target(name: "Core"),
        .target(name: "Networking", dependencies: ["Core"]),
        .target(name: "Features", dependencies: ["Core", "Networking"]),
        .testTarget(name: "NetworkingTests", dependencies: ["Networking"]),
        .testTarget(name: "FeaturesTests", dependencies: ["Features"]),
    ],
    swiftLanguageModes: [.v6]
)
