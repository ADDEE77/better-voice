// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "BetterVoice",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "BetterVoice", targets: ["BetterVoice"]),
        .library(name: "BetterVoiceCore", targets: ["BetterVoiceCore"])
    ],
    targets: [
        .target(name: "BetterVoiceCore"),
        .executableTarget(name: "BetterVoice", dependencies: ["BetterVoiceCore"]),
        .testTarget(name: "BetterVoiceCoreTests", dependencies: ["BetterVoiceCore"])
    ]
)
