// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TimerBrainRead",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "TimerBrainRead",
            path: "Sources/TimerBrainRead",
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        )
    ]
)
