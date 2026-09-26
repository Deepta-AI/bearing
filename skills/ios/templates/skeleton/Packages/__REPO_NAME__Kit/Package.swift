// swift-tools-version: 6.0
// __REPO_NAME__Kit: everything that is not a view lives here so it compiles and
// tests with `swift test` on Linux and macOS, without Xcode.
//
// Language mode: Swift 6, so complete strict concurrency checking is on and a
// data-race diagnostic is an error, not a warning. project.yml sets
// SWIFT_VERSION 6.0 for the app target to match. Unit tests use Swift Testing
// (`import Testing`), which ships with the Swift 6 toolchain on Linux and in
// Xcode; UI tests stay on XCTest, which is what drives XCUIApplication.
import PackageDescription

let package = Package(
    name: "__REPO_NAME__Kit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "__REPO_NAME__Kit", targets: ["Core", "Networking", "Features"]),
    ],
    targets: [
        .target(name: "Core"),
        .target(name: "Networking", dependencies: ["Core"]),
        .target(name: "Features", dependencies: ["Core", "Networking"]),
        .testTarget(name: "CoreTests", dependencies: ["Core"]),
        .testTarget(name: "NetworkingTests", dependencies: ["Networking"]),
        .testTarget(name: "FeaturesTests", dependencies: ["Features"]),
    ],
    swiftLanguageModes: [.v6]
)
