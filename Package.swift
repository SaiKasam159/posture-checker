// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PostureChecker",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "PostureChecker",
            path: "Sources/PostureChecker"
        )
    ]
)
