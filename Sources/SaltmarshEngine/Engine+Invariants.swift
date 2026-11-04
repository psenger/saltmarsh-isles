extension Engine {
    /// One line per rule the state breaks; empty for a consistent state.
    public static func invariantViolations(_ s: GameState) -> [String] {
        var out: [String] = []
        let board = s.board

        for r in Resource.allCases {
            if s.bank[r] < 0 { out.append("bank has negative \(r.rawValue): \(s.bank[r])") }
            for (i, p) in s.players.enumerated() where p.hand[r] < 0 {
                out.append("\(p.name) (seat \(i)) has negative \(r.rawValue): \(p.hand[r])")
            }
            let total = s.bank[r] + s.players.reduce(0) { $0 + $1.hand[r] }
            if total != 19 { out.append("\(r.rawValue) total is \(total), not 19") }
        }

        for (c, corner) in board.corners.enumerated() where corner.owner != nil {
            for a in corner.adjacent where a > c && board.corners[a].owner != nil {
                out.append("corners \(c) and \(a) are adjacent and both owned")
            }
        }

        for (e, edge) in board.edges.enumerated() {
            guard let p = edge.owner else { continue }
            let connected = [edge.a, edge.b].contains { end in
                board.corners[end].owner == p || board.corners[end].edges.contains { $0 != e && board.edges[$0].owner == p }
            }
            if !connected { out.append("road \(e) of seat \(p) touches neither an own building nor an own road") }
        }

        if case .setup = s.phase {} else {
            for (c, corner) in board.corners.enumerated() {
                guard let p = corner.owner else { continue }
                if !corner.edges.contains(where: { board.edges[$0].owner == p }) {
                    out.append("building at corner \(c) of seat \(p) has no road")
                }
            }
        }

        let lengths = s.players.indices.map { roadLength(s, player: $0) }
        if let h = s.longestRoadHolder {
            if !s.players.indices.contains(h) {
                out.append("longest road holder \(h) out of range")
            } else if lengths[h] < 5 {
                out.append("longest road holder seat \(h) has only \(lengths[h]) roads")
            } else if lengths.contains(where: { $0 > lengths[h] }) {
                out.append("longest road holder seat \(h) (\(lengths[h])) is not the longest")
            }
        }
        if let h = s.largestArmyHolder {
            let knights = s.players.map(\.knightsPlayed)
            if !s.players.indices.contains(h) {
                out.append("largest army holder \(h) out of range")
            } else if knights[h] < 3 {
                out.append("largest army holder seat \(h) has only \(knights[h]) knights")
            } else if knights.contains(where: { $0 > knights[h] }) {
                out.append("largest army holder seat \(h) does not have the most knights")
            }
        }

        let cardsOut = s.players.reduce(0) { $0 + $1.devCards.count }
        if s.devDeck.count + cardsOut > 25 { out.append("\(s.devDeck.count + cardsOut) development cards exist, more than 25") }

        for (i, p) in s.players.enumerated() {
            if s.settlements(of: i) > PieceLimit.settlements { out.append("\(p.name) has \(s.settlements(of: i)) settlements") }
            if s.cities(of: i) > PieceLimit.cities { out.append("\(p.name) has \(s.cities(of: i)) cities") }
            if s.roads(of: i) > PieceLimit.roads { out.append("\(p.name) has \(s.roads(of: i)) roads") }
        }

        if !board.tiles.indices.contains(s.robberTile) { out.append("robber tile \(s.robberTile) out of range") }
        if !s.players.indices.contains(s.current) { out.append("current player \(s.current) out of range") }
        if !s.players.indices.contains(s.firstPlayer) { out.append("first player \(s.firstPlayer) out of range") }
        return out
    }

    /// Replays a move list from a fresh game with the same configuration.
    public static func replay(_ config: GameConfig, moves: [Move]) throws -> GameState {
        var s = newGame(config)
        for m in moves { try apply(m, to: &s) }
        return s
    }
}
