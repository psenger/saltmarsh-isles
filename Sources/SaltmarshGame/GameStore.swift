import Foundation
import SaltmarshEngine

/// Where the current game is kept between launches. The app saves to Application Support;
/// tests keep it in memory.
public protocol GameStore: AnyObject {
    func save(_ state: GameState) throws
    func load() throws -> GameState?
    func clear() throws
    /// The resume guard. `markResuming()` goes down before anything risky runs on a saved game (installing it,
    /// each AI step) and `resumeSucceeded()` once it is through. A mark still standing at the next launch means
    /// the app died in the middle, and `resumeWasInterrupted` says so; `setAside()` then moves the save out of
    /// the way, keeping it for a replay, and returns where it went (nil when there was nothing to move).
    var resumeWasInterrupted: Bool { get }
    func markResuming() throws
    func resumeSucceeded() throws
    func setAside() throws -> URL?
}

public final class InMemoryGameStore: GameStore {
    private var saved: GameState?
    public private(set) var saveCount = 0
    public private(set) var resumeWasInterrupted = false
    /// Games `setAside()` moved out of the way, oldest first.
    public private(set) var setAsideGames: [GameState] = []

    public init() {}

    public func save(_ state: GameState) throws {
        saved = state
        saveCount += 1
    }

    public func load() throws -> GameState? { saved }

    public func clear() throws { saved = nil }

    public func markResuming() throws { resumeWasInterrupted = true }

    public func resumeSucceeded() throws { resumeWasInterrupted = false }

    public func setAside() throws -> URL? {
        resumeWasInterrupted = false
        if let saved { setAsideGames.append(saved) }
        saved = nil
        return nil
    }
}
