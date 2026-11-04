/// What everyone can see about another seat.
public struct OpponentSummary: Codable, Equatable, Sendable {
    public var index: Int
    public var seat: Seat
    public var controller: Controller
    public var cardCount: Int
    public var devCardCount: Int
    public var knightsPlayed: Int
    public var roadLength: Int
    public var publicPoints: Int
}

/// The game as one seat sees it: own cards in full, everyone else's as counts, no deck order.
public struct PlayerView: Codable, Equatable, Sendable {
    public var me: Int
    public var playerCount: Int
    public var controllers: [Controller]
    public var hand: ResourceCounts
    public var devCards: [DevCard]
    public var knightsPlayed: Int
    /// Every other seat, in seat order.
    public var opponents: [OpponentSummary]
    public var board: Board
    public var robberTile: Int
    public var bank: ResourceCounts
    public var dice: [Int]?
    public var deckCount: Int
    public var devCardPlayedThisTurn: Bool
    public var longestRoadHolder: Int?
    public var largestArmyHolder: Int?
    public var phase: Phase
    public var turn: Int
    public var firstPlayer: Int
    public var current: Int
}

extension Engine {
    public static func view(_ s: GameState, for player: Int) -> PlayerView {
        let me = s.players[player]
        let opponents = s.players.indices.filter { $0 != player }.map { i in
            OpponentSummary(index: i, seat: s.players[i].seat, controller: s.players[i].controller,
                            cardCount: s.players[i].hand.total, devCardCount: s.players[i].devCards.count,
                            knightsPlayed: s.players[i].knightsPlayed, roadLength: roadLength(s, player: i),
                            publicPoints: publicPoints(s, player: i))
        }
        return PlayerView(me: player, playerCount: s.playerCount, controllers: s.players.map(\.controller),
                          hand: me.hand, devCards: me.devCards, knightsPlayed: me.knightsPlayed, opponents: opponents,
                          board: s.board, robberTile: s.robberTile, bank: s.bank, dice: s.dice, deckCount: s.devDeck.count,
                          devCardPlayedThisTurn: s.devCardPlayedThisTurn, longestRoadHolder: s.longestRoadHolder,
                          largestArmyHolder: s.largestArmyHolder, phase: s.phase, turn: s.turn,
                          firstPlayer: s.firstPlayer, current: s.current)
    }

    /// A guessed full state consistent with the view: opponents' hands are drawn with weights from what
    /// their buildings produce, their development cards and the deck from the cards not yet seen.
    public static func sampleFullState(from v: PlayerView, using rng: inout SeededRNG) -> GameState {
        var remaining = DevCardType.deckComposition
        for card in v.devCards { remaining[card.type, default: 0] -= 1 }
        remaining[.knight, default: 0] -= v.knightsPlayed + v.opponents.reduce(0) { $0 + $1.knightsPlayed }
        var pool: [DevCardType] = []
        for type in DevCardType.allCases { pool += Array(repeating: type, count: max(0, remaining[type] ?? 0)) }
        pool.shuffle(using: &rng)

        var players: [Player] = []
        for i in 0..<v.playerCount {
            if i == v.me {
                players.append(Player(seat: Seat(rawValue: i)!, controller: v.controllers[i], hand: v.hand,
                                      devCards: v.devCards, knightsPlayed: v.knightsPlayed))
                continue
            }
            let o = v.opponents.first { $0.index == i }!
            var weight = ResourceCounts.uniform(1)
            for corner in v.board.corners where corner.owner == i {
                for t in corner.tiles {
                    if let r = v.board.tiles[t].resource { weight[r] += v.board.tiles[t].pips * (corner.isCity ? 2 : 1) }
                }
            }
            var hand = ResourceCounts()
            for _ in 0..<o.cardCount {
                var k = Int.random(in: 0..<weight.total, using: &rng)
                for r in Resource.allCases {
                    if k < weight[r] { hand[r] += 1; break }
                    k -= weight[r]
                }
            }
            var cards: [DevCard] = []
            for _ in 0..<o.devCardCount {
                if let type = pool.popLast() { cards.append(DevCard(type: type, boughtOnTurn: -1)) }
            }
            players.append(Player(seat: o.seat, controller: o.controller, hand: hand, devCards: cards, knightsPlayed: o.knightsPlayed))
        }

        var deck = Array(pool.prefix(v.deckCount))
        while deck.count < v.deckCount { deck.append(.knight) }

        return GameState(board: v.board, players: players, firstPlayer: v.firstPlayer, current: v.current, turn: v.turn,
                         robberTile: v.robberTile, dice: v.dice, bank: v.bank, devDeck: deck,
                         devCardPlayedThisTurn: v.devCardPlayedThisTurn, longestRoadHolder: v.longestRoadHolder,
                         largestArmyHolder: v.largestArmyHolder, phase: v.phase, log: [],
                         rng: SeededRNG(seed: rng.next()), seed: 0, forcedRolls: [])
    }
}
