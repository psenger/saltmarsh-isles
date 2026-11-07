public struct Player: Codable, Hashable, Sendable {
    public var seat: Seat
    public var controller: Controller
    public var hand: ResourceCounts
    public var devCards: [DevCard]
    public var knightsPlayed: Int
    public var name: String { seat.name }
}

public struct GameConfig: Codable, Hashable, Sendable {
    public var controllers: [Controller]
    public var seed: UInt64
    /// "Turn on logs" on the new game sheet: whether the app shows the Log tab. The log is written either way.
    public var showsLog: Bool
    public init(controllers: [Controller], seed: UInt64, showsLog: Bool = false) {
        self.controllers = controllers
        self.seed = seed
        self.showsLog = showsLog
    }
    public var playerCount: Int { controllers.count }
}

public struct GameState: Codable, Equatable, Sendable {
    public var board: Board
    public var players: [Player]
    public var firstPlayer: Int
    public var current: Int
    public var turn: Int
    public var robberTile: Int
    public var dice: [Int]?
    public var bank: ResourceCounts
    public var devDeck: [DevCardType]
    public var devCardPlayedThisTurn: Bool
    public var longestRoadHolder: Int?
    public var largestArmyHolder: Int?
    public var phase: Phase
    public var log: [String]
    public var rng: SeededRNG
    public var seed: UInt64
    /// Test/debug: when non-empty the next roll pops `first` instead of using `rng`.
    public var forcedRolls: [[Int]]
    /// Whether the app shows the Log tab, from `GameConfig.showsLog`. Nil in a game saved before the setting
    /// existed, which the app treats as shown.
    public var showsLog: Bool?

    public var playerCount: Int { players.count }

    public func settlements(of p: Int) -> Int { board.corners.filter { $0.owner == p && !$0.isCity }.count }
    public func cities(of p: Int) -> Int { board.corners.filter { $0.owner == p && $0.isCity }.count }
    public func roads(of p: Int) -> Int { board.edges.filter { $0.owner == p }.count }

    public mutating func log(_ line: String) { log.append(line) }
}

public enum EngineError: Error, Equatable {
    case illegalMove(Move)
    case invalidOffer(String)
}
