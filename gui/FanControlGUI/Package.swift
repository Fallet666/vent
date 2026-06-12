// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "FanControlGUI",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "FanControlGUI",
            dependencies: [],
            resources: [.process("Resources")])
    ]
)
