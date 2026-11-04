import SaltmarshEngine

/// Where the current game is kept between launches. The app saves to Application Support;
/// tests keep it in memory.
public protocol GameStore: AnyObject {
    func save(_ state: GameState) throws
    func load() throws -> GameState?
    func clear() throws
}

public final class InMemoryGameStore: GameStore {
    private var saved: GameState?
    public private(set) var saveCount = 0

    public init() {}

    public func save(_ state: GameState) throws {
        saved = state
        saveCount += 1
    }

    public func load() throws -> GameState? { saved }

    public func clear() throws { saved = nil }
}
