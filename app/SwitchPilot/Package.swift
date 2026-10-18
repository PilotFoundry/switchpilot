// swift-tools-version: 6.0
import PackageDescription

let swiftSettings: [SwiftSetting] = [.swiftLanguageMode(.v5)]

let package = Package(
    name: "SwitchPilot",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "SwitchPilot", targets: ["SwitchPilot"]),
        .executable(name: "SwitchPilotChecks", targets: ["SwitchPilotChecks"])
    ],
    targets: [
        .target(name: "SwitchPilotCore", swiftSettings: swiftSettings),
        .executableTarget(name: "SwitchPilot", dependencies: ["SwitchPilotCore"], swiftSettings: swiftSettings),
        .executableTarget(name: "SwitchPilotChecks", dependencies: ["SwitchPilotCore"], swiftSettings: swiftSettings)
    ]
)
