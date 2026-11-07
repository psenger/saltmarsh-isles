import Foundation
import SaltmarshEngine

/// Keeps the current game as JSON in one file, so a game survives quitting the app.
public final class FileGameStore: GameStore {
    private let directory: URL
    private var file: URL { directory.appending(path: "game.json") }
    /// Exists from `markResuming()` to `resumeSucceeded()`; found at launch, it means the last launch died in between.
    private var marker: URL { directory.appending(path: "resuming") }

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

    public var resumeWasInterrupted: Bool { FileManager.default.fileExists(atPath: marker.path) }

    public func markResuming() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data().write(to: marker)
    }

    public func resumeSucceeded() throws {
        guard FileManager.default.fileExists(atPath: marker.path) else { return }
        try FileManager.default.removeItem(at: marker)
    }

    /// Moves `game.json` to `game-crashed-<date>.json` beside it, so the game can be replayed from its log.
    public func setAside() throws -> URL? {
        try resumeSucceeded()
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        var kept = directory.appending(path: "game-crashed-\(formatter.string(from: Date())).json")
        var n = 2
        while FileManager.default.fileExists(atPath: kept.path) {
            kept = directory.appending(path: "game-crashed-\(formatter.string(from: Date()))-\(n).json"); n += 1
        }
        try FileManager.default.moveItem(at: file, to: kept)
        return kept
    }
}
