extension Engine {
    /// A corner can take a settlement when it is unowned, no neighbouring corner has a building,
    /// and (outside setup) one of the player's roads touches it.
    public static func canSettle(_ s: GameState, corner c: Int, player p: Int, setup: Bool) -> Bool {
        let corner = s.board.corners[c]
        guard corner.owner == nil else { return false }
        guard corner.adjacent.allSatisfy({ s.board.corners[$0].owner == nil }) else { return false }
        if setup { return true }
        return corner.edges.contains { s.board.edges[$0].owner == p }
    }

    /// An edge can take a road when it is unowned and connects to the player's network:
    /// during setup it must touch the settlement just placed; in play one end holds the player's
    /// building, or is an empty corner where another of the player's roads ends. An opponent's
    /// building at an end blocks continuing from that end.
    public static func canRoad(_ s: GameState, edge e: Int, player p: Int) -> Bool {
        let edge = s.board.edges[e]
        guard edge.owner == nil else { return false }
        if case .setup(_, true, let last?) = s.phase {
            return edge.a == last || edge.b == last
        }
        return [edge.a, edge.b].contains { end in
            let corner = s.board.corners[end]
            if corner.owner == p { return true }
            if corner.owner != nil { return false }
            return corner.edges.contains { $0 != e && s.board.edges[$0].owner == p }
        }
    }

    // MARK: Paid builds in the main phase

    static func buildMoves(_ s: GameState) -> [Move] {
        let p = s.current, hand = s.players[p].hand, left = piecesLeft(s, player: p)
        var moves: [Move] = []
        if left.roads > 0 && hand.contains(Cost.road) {
            moves += s.board.edges.indices.filter { canRoad(s, edge: $0, player: p) }.map { .placeRoad(edge: $0) }
        }
        if left.settlements > 0 && hand.contains(Cost.settlement) {
            moves += s.board.corners.indices.filter { canSettle(s, corner: $0, player: p, setup: false) }.map { .placeSettlement(corner: $0) }
        }
        if left.cities > 0 && hand.contains(Cost.city) {
            moves += s.board.corners.indices.filter { s.board.corners[$0].owner == p && !s.board.corners[$0].isCity }.map { .upgradeCity(corner: $0) }
        }
        return moves
    }

    /// Moves `cost` from the current player's hand to the bank.
    static func pay(_ s: inout GameState, _ cost: ResourceCounts) {
        s.players[s.current].hand = s.players[s.current].hand - cost
        s.bank = s.bank + cost
    }

    static func applyBuildRoad(_ s: inout GameState, edge e: Int) {
        pay(&s, Cost.road)
        s.board.edges[e].owner = s.current
        s.log("\(s.players[s.current].name) built a road \(s.board.edgeID(e)).")
        updateAwards(&s)
        checkWin(&s)
    }

    static func applyBuildSettlement(_ s: inout GameState, corner c: Int) {
        pay(&s, Cost.settlement)
        s.board.corners[c].owner = s.current
        s.log("\(s.players[s.current].name) built a settlement at \(s.board.vertexID(c)).")
        updateAwards(&s)
        checkWin(&s)
    }

    static func applyUpgradeCity(_ s: inout GameState, corner c: Int) {
        pay(&s, Cost.city)
        s.board.corners[c].isCity = true
        s.log("\(s.players[s.current].name) upgraded to a city at \(s.board.vertexID(c)).")
        checkWin(&s)
    }
}
