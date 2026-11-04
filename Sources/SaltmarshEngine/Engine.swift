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
        switch s.phase {
        case .rollingForFirst:
            return [.rollForFirst]
        case .setup(_, let placingRoad, _):
            return setupMoves(s, placingRoad: placingRoad)
        case .awaitingRoll:
            return [.roll] + devCardMoves(s)
        case .discarding(let queue):
            guard let p = queue.first else { return [] }
            let hand = s.players[p].hand
            return discardOptions(hand: hand, count: hand.total / 2).map { .discard($0) }
        case .movingRobber:
            return s.board.tiles.indices.filter { $0 != s.robberTile }.map { .moveRobber(tile: $0) }
        case .choosingVictim(let candidates, _):
            return candidates.map { .steal(from: $0) }
        case .placingFreeRoads:
            return freeRoadMoves(s)
        case .main:
            return buildMoves(s) + tradeMoves(s) + devCardMoves(s) + playerTradeMoves(s) + [.endTurn]
        case .tradeOffered(let offer, let responses):
            return tradeResponseMoves(s, offer: offer, responses: responses)
        default:
            return []
        }
    }

    public static func isLegal(_ m: Move, in s: GameState) -> Bool { legalityError(m, in: s) == nil }

    /// `legalMoves` enumerates choices; for moves with an unbounded choice space (discards, trade offers,
    /// counter-offers) legality is the predicate itself, so a valid move outside the listed set still applies.
    /// A well-placed but malformed offer reports `invalidOffer` with the reason.
    static func legalityError(_ m: Move, in s: GameState) -> EngineError? {
        switch m {
        case .discard(let c):
            return isValidDiscard(c, in: s) ? nil : .illegalMove(m)
        case .proposeTrade(let offer):
            guard case .main = s.phase, offer.proposer == s.current else { return .illegalMove(m) }
            return validate(offer, in: s).map { .invalidOffer($0) }
        case .respondToTrade(let seat, .countered(let counter)):
            guard case .tradeOffered(let offer, let responses) = s.phase, responses[seat] == .pending else { return .illegalMove(m) }
            return counterProblem(counter, from: seat, to: offer, in: s).map { .invalidOffer($0) }
        default:
            return legalMoves(s).contains(m) ? nil : .illegalMove(m)
        }
    }

    public static func apply(_ m: Move, to s: inout GameState) throws {
        if let error = legalityError(m, in: s) { throw error }
        switch m {
        case .rollForFirst:
            applyRollForFirst(&s)
        case .placeSettlement(let c):
            switch s.phase {
            case .setup: applySetupSettlement(&s, corner: c)
            case .main: applyBuildSettlement(&s, corner: c)
            default: throw EngineError.illegalMove(m)
            }
        case .placeRoad(let e):
            switch s.phase {
            case .setup: applySetupRoad(&s, edge: e)
            case .main: applyBuildRoad(&s, edge: e)
            case .placingFreeRoads: applyFreeRoad(&s, edge: e)
            default: throw EngineError.illegalMove(m)
            }
        case .upgradeCity(let c):
            applyUpgradeCity(&s, corner: c)
        case .buyDevCard:
            applyBuyDevCard(&s)
        case .playKnight:
            applyPlayKnight(&s)
        case .playRoadCrew:
            applyPlayRoadCrew(&s)
        case .playBumperHarvest(let a, let b):
            applyBumperHarvest(&s, a, b)
        case .playCornerMarket(let r):
            applyCornerMarket(&s, r)
        case .proposeTrade(let offer):
            applyProposeTrade(&s, offer)
        case .respondToTrade(let seat, let response):
            applyRespondToTrade(&s, seat: seat, response)
        case .executeTrade(let seat):
            applyExecuteTrade(&s, with: seat)
        case .withdrawTrade:
            applyWithdrawTrade(&s)
        case .endTurn:
            applyEndTurn(&s)
        case .bankTrade(let give, let get):
            applyBankTrade(&s, give: give, get: get)
        case .harbourTrade(let h, let give, let get):
            applyHarbourTrade(&s, harbour: h, give: give, get: get)
        case .roll:
            applyRoll(&s)
        case .discard(let c):
            applyDiscard(&s, c)
        case .moveRobber(let t):
            applyMoveRobber(&s, tile: t)
        case .steal(let v):
            applySteal(&s, from: v)
        }
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
