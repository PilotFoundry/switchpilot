// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "SwitchPilot",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "SwitchPilot", targets: ["SwitchPilot"])],
    targets: [
        .target(name: "PilotCore"),
        .executableTarget(name: "SwitchPilot", dependencies: ["PilotCore"]),
        .executableTarget(name: "PilotChecks", dependencies: ["PilotCore"], path: "Checks")
    ]
)
