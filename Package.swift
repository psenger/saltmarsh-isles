// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SaltmarshCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SaltmarshEngine", targets: ["SaltmarshEngine"]),
        .library(name: "SaltmarshAI", targets: ["SaltmarshAI"]),
        .library(name: "SaltmarshGame", targets: ["SaltmarshGame"]),
        .executable(name: "ai-bench", targets: ["ai-bench"]),
    ],
    targets: [
        .target(name: "SaltmarshEngine"),
        .target(name: "SaltmarshAI", dependencies: ["SaltmarshEngine"]),
        .target(name: "SaltmarshGame", dependencies: ["SaltmarshEngine", "SaltmarshAI"]),
        .executableTarget(name: "ai-bench", dependencies: ["SaltmarshEngine", "SaltmarshAI"]),
        .testTarget(name: "EngineTests", dependencies: ["SaltmarshEngine"]),
        .testTarget(name: "AITests", dependencies: ["SaltmarshEngine", "SaltmarshAI"]),
        .testTarget(name: "GherkinTests", dependencies: ["SaltmarshEngine", "SaltmarshAI", "SaltmarshGame"]),
    ],
    swiftLanguageModes: [.v6]
)
