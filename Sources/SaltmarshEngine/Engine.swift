public enum Engine {}

extension Engine {
    public static func newGame(_ config: GameConfig) -> GameState {
        let n = config.playerCount
        precondition((2...4).contains(n), "a game has 2 to 4 players")
        var rng = SeededRNG(seed: config.seed)
        let board = BoardGenerator.generate(using: &rng)
        var deck: [DevCardType] = []
        for type in DevCardType.allCases { deck += Array(repeating: type, count: DevCardType.deckComposition[type]!) }
        deck.shuffle(using: &rng)
        var state = GameState(
            board: board,
            players: config.controllers.enumerated().map {
                Player(seat: Seat(rawValue: $0.offset)!, controller: $0.element, hand: ResourceCounts(), devCards: [], knightsPlayed: 0)
            },
            firstPlayer: 0, current: 0, turn: 0, robberTile: board.desertTile, dice: nil,
            bank: .uniform(19), devDeck: deck, devCardPlayedThisTurn: false,
            longestRoadHolder: nil, largestArmyHolder: nil,
            phase: .rollingForFirst(rolls: Array(repeating: nil, count: n), contenders: Array(0..<n)),
            log: [], rng: rng, seed: config.seed, forcedRolls: [])
        state.log("New game with \(n) players. Everyone rolls for first player.")
        return state
    }

    public static func legalMoves(_ s: GameState) -> [Move] {
        if case .rollingForFirst = s.phase { return [.rollForFirst] }
        return []
    }

    public static func isLegal(_ m: Move, in s: GameState) -> Bool { legalMoves(s).contains(m) }

    public static func apply(_ m: Move, to s: inout GameState) throws {
        throw EngineError.illegalMove(m)
    }

    public static func actingPlayer(_ s: GameState) -> Int {
        switch s.phase {
        case .rollingForFirst(let rolls, let contenders):
            return contenders.first { rolls[$0] == nil } ?? s.current
        case .discarding(let queue):
            return queue.first ?? s.current
        case .tradeOffered(_, let responses):
            return responses.keys.sorted().first { responses[$0] == .pending } ?? s.current
        default:
            return s.current
        }
    }
}
