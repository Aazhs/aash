// swift-tools-version: 6.0
// Targets and what may import what: docs/architecture.md#targets
import PackageDescription

let package = Package(
    name: "Aash",
    platforms: [.macOS(.v14)],
    targets: [
        // Pixel art data and rendering. Foundation + CoreGraphics only.
        .target(name: "AashSprites"),
        // Pure logic: behaviour engine, menu bar geometry maths, reminder phrase parsing. Foundation only.
        .target(name: "AashCore"),
        // Chat providers (Gemini, later Claude Code) and the Keychain store. Foundation + Security only.
        .target(name: "AashAI"),
        // The AppKit app. The only target that may import AppKit, EventKit or ServiceManagement.
        .executableTarget(
            name: "Aash",
            dependencies: ["AashSprites", "AashCore", "AashAI"]
        ),
        .testTarget(name: "AashSpritesTests", dependencies: ["AashSprites"]),
        .testTarget(name: "AashCoreTests", dependencies: ["AashCore"]),
        .testTarget(name: "AashAITests", dependencies: ["AashAI"]),
    ]
)
