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
        .executable(name: "help-book", targets: ["help-book"]),
    ],
    targets: [
        // Optimized in Debug too, so a search run from Xcode gets its real budget; a Debug build is about twenty
        // times slower otherwise. `-DDEBUG` still applies, so `#if DEBUG` code still sees a Debug build.
        .target(name: "SaltmarshEngine", swiftSettings: [.unsafeFlags(["-O"], .when(configuration: .debug))]),
        .target(name: "SaltmarshAI", dependencies: ["SaltmarshEngine"], swiftSettings: [.unsafeFlags(["-O"], .when(configuration: .debug))]),
        .target(name: "SaltmarshGame", dependencies: ["SaltmarshEngine", "SaltmarshAI"]),
        // Test-only state mutators and seeded game builders, shared by every test target; not an app product.
        .target(name: "SaltmarshTestSupport", dependencies: ["SaltmarshEngine"]),
        .executableTarget(name: "ai-bench", dependencies: ["SaltmarshEngine", "SaltmarshAI"]),
        .executableTarget(name: "help-book", dependencies: ["SaltmarshGame"]),
        .testTarget(name: "EngineTests", dependencies: ["SaltmarshEngine", "SaltmarshTestSupport"]),
        .testTarget(name: "AITests", dependencies: ["SaltmarshEngine", "SaltmarshAI", "SaltmarshTestSupport"]),
        .testTarget(name: "GameTests", dependencies: ["SaltmarshEngine", "SaltmarshAI", "SaltmarshGame", "SaltmarshTestSupport"]),
        .testTarget(name: "GherkinTests", dependencies: ["SaltmarshEngine", "SaltmarshAI", "SaltmarshGame", "SaltmarshTestSupport"]),
    ],
    swiftLanguageModes: [.v6]
)
