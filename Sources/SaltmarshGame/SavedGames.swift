import Foundation
import SaltmarshEngine

public enum SaveLimit {
    public static let maxSaves = 5, maxNameLength = 30

    /// What a typed name becomes: no surrounding spaces, and no longer than the limit.
    public static func clipped(_ name: String) -> String {
        String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxNameLength))
    }
}

public enum SaveError: Error, Equatable {
    case blankName, full, notFound, noGame
}

public struct SavedGameSummary: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var savedAt: Date
}

public struct SavedGame: Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var savedAt: Date
    public var state: GameState

    var summary: SavedGameSummary { SavedGameSummary(id: id, name: name, savedAt: savedAt) }
}

/// The player's named saves, up to `SaveLimit.maxSaves`. Separate from `GameStore`, which keeps the
/// one automatic game and does not count toward the limit.
public protocol SaveSlots: AnyObject {
    /// Newest first. A save that cannot be read is left out, so it cannot break the list.
    func list() -> [SavedGameSummary]
    func load(id: UUID) throws -> SavedGame
    /// Stores the game under its id, overwriting any save with that id.
    func put(_ game: SavedGame) throws
    func remove(id: UUID) throws
}

extension SaveSlots {
    /// Saves under `name`, overwriting `replacing` when given. Nothing is ever removed to make room.
    @discardableResult
    public func write(name: String, state: GameState, replacing: UUID? = nil, now: Date = .now) throws -> SavedGameSummary {
        let clean = SaveLimit.clipped(name)
        guard !clean.isEmpty else { throw SaveError.blankName }
        let existing = list()
        if let replacing {
            guard existing.contains(where: { $0.id == replacing }) else { throw SaveError.notFound }
        } else if existing.count >= SaveLimit.maxSaves {
            throw SaveError.full
        }
        let game = SavedGame(id: replacing ?? UUID(), name: clean, savedAt: now, state: state)
        try put(game)
        return game.summary
    }
}

public final class InMemorySaveSlots: SaveSlots {
    private var games: [UUID: SavedGame] = [:]

    public init() {}

    public func list() -> [SavedGameSummary] {
        games.values.map(\.summary).sorted { $0.savedAt > $1.savedAt }
    }

    public func load(id: UUID) throws -> SavedGame {
        guard let game = games[id] else { throw SaveError.notFound }
        return game
    }

    public func put(_ game: SavedGame) throws { games[game.id] = game }

    public func remove(id: UUID) throws { games[id] = nil }
}

/// One JSON file per save, named by its id.
public final class FileSaveSlots: SaveSlots {
    private let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    private func file(_ id: UUID) -> URL { directory.appending(path: "\(id.uuidString).json") }

    public func list() -> [SavedGameSummary] {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "json" }
            .compactMap { try? JSONDecoder().decode(SavedGame.self, from: Data(contentsOf: $0)).summary }
            .sorted { $0.savedAt > $1.savedAt }
    }

    public func load(id: UUID) throws -> SavedGame {
        guard FileManager.default.fileExists(atPath: file(id).path) else { throw SaveError.notFound }
        return try JSONDecoder().decode(SavedGame.self, from: Data(contentsOf: file(id)))
    }

    public func put(_ game: SavedGame) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(game).write(to: file(game.id), options: .atomic)
    }

    public func remove(id: UUID) throws {
        guard FileManager.default.fileExists(atPath: file(id).path) else { return }
        try FileManager.default.removeItem(at: file(id))
    }
}
