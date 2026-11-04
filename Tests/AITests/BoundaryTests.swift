import Foundation
import Testing

/// The AI target may only ever see a `PlayerView`; a `GameState` must never cross into it.
@Suite struct BoundaryTests {
    @Test func aiSourcesNeverMentionGameState() throws {
        let dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/SaltmarshAI")
        let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil).filter { $0.pathExtension == "swift" }
        #expect(!files.isEmpty)
        for file in files {
            let code = try String(contentsOf: file, encoding: .utf8).split(separator: "\n")
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }.joined(separator: "\n")
            #expect(!code.contains("GameState"), "\(file.lastPathComponent) mentions GameState")
        }
    }
}
