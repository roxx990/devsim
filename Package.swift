// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "DevSim",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "DevSim",
            path: "Sources/DevSim",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .defaultIsolation(MainActor.self)
            ]
        )
    ]
)
