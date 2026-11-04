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
        // Test-only state mutators and seeded game builders, shared by every test target; not an app product.
        .target(name: "SaltmarshTestSupport", dependencies: ["SaltmarshEngine"]),
        .executableTarget(name: "ai-bench", dependencies: ["SaltmarshEngine", "SaltmarshAI"]),
        .testTarget(name: "EngineTests", dependencies: ["SaltmarshEngine", "SaltmarshTestSupport"]),
        .testTarget(name: "AITests", dependencies: ["SaltmarshEngine", "SaltmarshAI", "SaltmarshTestSupport"]),
        .testTarget(name: "GameTests", dependencies: ["SaltmarshEngine", "SaltmarshAI", "SaltmarshGame", "SaltmarshTestSupport"]),
        .testTarget(name: "GherkinTests", dependencies: ["SaltmarshEngine", "SaltmarshAI", "SaltmarshGame", "SaltmarshTestSupport"]),
    ],
    swiftLanguageModes: [.v6]
)
