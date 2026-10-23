// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "WindowFrames",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "WindowFrames",
            path: "Sources/WindowFrames",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Carbon"),
            ]
        ),
    ]
)
