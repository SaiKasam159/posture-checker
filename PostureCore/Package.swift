// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PostureCore",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "PostureCore", targets: ["PostureCore"])
    ],
    targets: [
        .target(name: "PostureCore"),
        .testTarget(name: "PostureCoreTests", dependencies: ["PostureCore"]),
    ]
)
