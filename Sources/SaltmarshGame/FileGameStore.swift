import Foundation
import SaltmarshEngine

/// Keeps the current game as JSON in one file, so a game survives quitting the app.
public final class FileGameStore: GameStore {
    private let directory: URL
    private var file: URL { directory.appending(path: "game.json") }

    public init(directory: URL) {
        self.directory = directory
    }

    public func save(_ state: GameState) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(state).write(to: file, options: .atomic)
    }

    /// Nil when nothing is saved; throws when the file cannot be read as a game.
    public func load() throws -> GameState? {
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        return try JSONDecoder().decode(GameState.self, from: Data(contentsOf: file))
    }

    public func clear() throws {
        guard FileManager.default.fileExists(atPath: file.path) else { return }
        try FileManager.default.removeItem(at: file)
    }
}
