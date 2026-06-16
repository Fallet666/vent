// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "VentGUI",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "VentGUI",
            dependencies: [],
            resources: [.process("Resources")])
    ]
)
