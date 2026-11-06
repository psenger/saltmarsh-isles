import Foundation
import Testing

/// The AI package's boundary (design section 6.1): no public API carries a `GameState`; the only `GameState`
/// values inside the package are guessed ones under `Search/`, which never starts a game of its own, and the
/// whole games `Bench/` plays for the tests and the benchmark.
@Suite struct BoundaryTests {
    static let aiDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Sources/SaltmarshAI")

    static func swiftFiles(under dir: URL) throws -> [URL] {
        let all = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil)?.compactMap { $0 as? URL } ?? []
        return all.filter { $0.pathExtension == "swift" }.sorted { $0.path < $1.path }
    }
    /// The file without its `//` comment lines.
    static func code(_ file: URL) throws -> String {
        try String(contentsOf: file, encoding: .utf8).split(separator: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }.joined(separator: "\n")
    }

    @Test func gameStateLivesOnlyUnderSearchAndBench() throws {
        let files = try Self.swiftFiles(under: Self.aiDir)
        #expect(files.count >= 8, "the AI package should have its source files")
        for file in files where !file.path.contains("/Search/") && !file.path.contains("/Bench/") {
            #expect(!(try Self.code(file)).contains("GameState"), "\(file.lastPathComponent) mentions GameState")
        }
    }
    @Test func noPublicDeclarationCarriesAGameState() throws {
        for file in try Self.swiftFiles(under: Self.aiDir) {
            for line in try Self.code(file).split(separator: "\n") where line.contains("public") {
                #expect(!line.contains("GameState"), "\(file.lastPathComponent): \(line.trimmingCharacters(in: .whitespaces))")
            }
        }
    }
    @Test func searchOnlyHoldsGuessedStates() throws {
        for file in try Self.swiftFiles(under: Self.aiDir.appendingPathComponent("Search")) {
            let code = try Self.code(file)
            for forbidden in ["Engine.newGame", "GameStore", "GameViewModel", "TurnRunner"] {
                #expect(!code.contains(forbidden), "\(file.lastPathComponent) uses \(forbidden)")
            }
        }
    }
}
