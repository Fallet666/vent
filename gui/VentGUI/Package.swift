// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "VentGUI",
    defaultLocalization: "Base",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "VentGUIModels",
            path: "Sources/VentGUI",
            resources: [.process("Resources")]),
        .executableTarget(
            name: "VentGUI",
            dependencies: ["VentGUIModels"],
            path: "Sources/VentGUIExecutable",
            resources: []),
        .executableTarget(
            name: "VentGUITests",
            dependencies: ["VentGUIModels"],
            path: "Tests/VentGUITests")
    ]
)
