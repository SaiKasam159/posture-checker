// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Apollo",
    // Bumped from v13: CameraManager's device discovery uses .external and
    // .continuityCamera, which need macOS 14. Matches the backend's own
    // PostureChecker.xcodeproj deployment target.
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "PostureCore")
    ],
    targets: [
        .executableTarget(
            name: "Apollo",
            dependencies: [
                .product(name: "PostureCore", package: "PostureCore")
            ],
            path: "Sources/Apollo"
        )
    ]
)
