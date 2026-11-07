extension Engine {
    /// Index of a playable card of `type` in the current player's hand: not bought this turn, no card
    /// played yet this turn, and never a Victory point card.
    static func playableCard(_ s: GameState, _ type: DevCardType) -> Int? {
        guard !s.devCardPlayedThisTurn, type != .victoryPoint else { return nil }
        return s.players[s.current].devCards.firstIndex { $0.type == type && $0.boughtOnTurn != s.turn }
    }

    /// Knight may be played before the roll; buying and every other card wait for the main phase.
    static func devCardMoves(_ s: GameState) -> [Move] {
        var moves: [Move] = []
        switch s.phase {
        case .awaitingRoll:
            if playableCard(s, .knight) != nil { moves.append(.playKnight) }
        case .main:
            if !s.devDeck.isEmpty && s.players[s.current].hand.contains(Cost.devCard) { moves.append(.buyDevCard) }
            if playableCard(s, .knight) != nil { moves.append(.playKnight) }
            if playableCard(s, .roadCrew) != nil { moves.append(.playRoadCrew) }
            if playableCard(s, .bumperHarvest) != nil {
                let all = Resource.allCases
                for (i, a) in all.enumerated() {
                    for b in all[i...] {
                        let need: ResourceCounts = a == b ? [a: 2] : [a: 1, b: 1]
                        if s.bank.contains(need) { moves.append(.playBumperHarvest(a, b)) }
                    }
                }
            }
            if playableCard(s, .cornerMarket) != nil { moves += Resource.allCases.map { .playCornerMarket($0) } }
        default:
            break
        }
        return moves
    }

    static func freeRoadMoves(_ s: GameState) -> [Move] {
        s.board.edges.indices.filter { canRoad(s, edge: $0, player: s.current) }.map { .placeRoad(edge: $0) }
    }

    private static func spend(_ s: inout GameState, _ type: DevCardType) {
        if let i = playableCard(s, type) { s.players[s.current].devCards.remove(at: i) }
        s.players[s.current].cardsPlayed = (s.players[s.current].cardsPlayed ?? []) + [type]
        s.devCardPlayedThisTurn = true
    }

    static func applyBuyDevCard(_ s: inout GameState) {
        pay(&s, Cost.devCard)
        let type = s.devDeck.removeLast()
        s.players[s.current].devCards.append(DevCard(type: type, boughtOnTurn: s.turn))
        s.log("\(s.players[s.current].name) bought a development card: \(type.displayName).")
        checkWin(&s)
    }

    static func applyPlayKnight(_ s: inout GameState) {
        let returnTo = s.phase
        spend(&s, .knight)
        s.players[s.current].knightsPlayed += 1
        s.log("\(s.players[s.current].name) played a Knight.")
        updateAwards(&s)
        s.phase = .movingRobber(returnTo: returnTo)
        checkWin(&s)
    }

    static func applyPlayRoadCrew(_ s: inout GameState) {
        spend(&s, .roadCrew)
        s.log("\(s.players[s.current].name) played Road crew.")
        s.phase = .placingFreeRoads(remaining: 2)
        endFreeRoadsIfStuck(&s)
    }

    /// Leaves `.placingFreeRoads` when the roads are placed, the player has no road piece left,
    /// or no legal edge remains, logging the reason in the last two cases.
    private static func endFreeRoadsIfStuck(_ s: inout GameState) {
        guard case .placingFreeRoads(let remaining) = s.phase else { return }
        if remaining == 0 {
            s.phase = .main
        } else if piecesLeft(s, player: s.current).roads == 0 {
            s.log("No roads left to build.")
            s.phase = .main
        } else if freeRoadMoves(s).isEmpty {
            s.log("No room for new roads.")
            s.phase = .main
        }
    }

    static func applyFreeRoad(_ s: inout GameState, edge e: Int) {
        guard case .placingFreeRoads(let remaining) = s.phase else { return }
        s.board.edges[e].owner = s.current
        s.log("\(s.players[s.current].name) built a free road \(s.board.edgeID(e)).")
        updateAwards(&s)
        s.phase = .placingFreeRoads(remaining: remaining - 1)
        endFreeRoadsIfStuck(&s)
        checkWin(&s)
    }

    static func applyBumperHarvest(_ s: inout GameState, _ a: Resource, _ b: Resource) {
        spend(&s, .bumperHarvest)
        for r in [a, b] {
            s.bank[r] -= 1
            s.players[s.current].hand[r] += 1
        }
        s.log("\(s.players[s.current].name) played Bumper harvest: \(a.rawValue) and \(b.rawValue).")
    }

    static func applyCornerMarket(_ s: inout GameState, _ r: Resource) {
        spend(&s, .cornerMarket)
        var taken = 0, paid: [String] = []
        for i in s.players.indices where i != s.current {
            let n = s.players[i].hand[r]
            if n > 0 { paid.append("\(s.players[i].name) \(n)") }
            taken += n
            s.players[i].hand[r] = 0
        }
        s.players[s.current].hand[r] += taken
        let detail = paid.isEmpty ? "" : " (\(paid.joined(separator: ", ")))"
        s.log("\(s.players[s.current].name) cornered the \(r.rawValue) market and took \(taken)\(detail).")
    }
}
