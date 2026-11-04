extension Engine {
    static func applyRoll(_ s: inout GameState) {
        let total = rollDice(&s).reduce(0, +)
        let name = s.players[s.current].name
        if total == 7 {
            s.log("\(name) rolled 7.")
            let queue = s.players.indices.filter { s.players[$0].hand.total > 7 }
            s.phase = queue.isEmpty ? .movingRobber(returnTo: .main) : .discarding(queue: queue)
        } else {
            let mark = s.log.count
            let fragment = produce(roll: total, in: &s)
            s.log.insert("\(name) rolled \(total). \(fragment)", at: mark)
            s.phase = .main
        }
    }

    /// Pays every building on a tile numbered `roll` (robber tile excluded), one card per settlement
    /// and two per city, subject to the bank rule: when the bank cannot cover a resource, a single
    /// claimant takes what is left and several claimants get nothing. Shortages are logged.
    /// Returns "Cobalt +1, Amber +2" (recipients in seat order) or "Nobody harvested.".
    static func produce(roll: Int, in s: inout GameState) -> String {
        var owed = Array(repeating: ResourceCounts(), count: s.playerCount)
        for (ti, tile) in s.board.tiles.enumerated() where tile.number == roll && ti != s.robberTile {
            guard let r = tile.resource else { continue }
            for c in tile.corners {
                if let o = s.board.corners[c].owner { owed[o][r] += s.board.corners[c].isCity ? 2 : 1 }
            }
        }
        var received = Array(repeating: 0, count: s.playerCount)
        func pay(_ p: Int, _ r: Resource, _ n: Int) {
            s.players[p].hand[r] += n
            s.bank[r] -= n
            received[p] += n
        }
        for r in Resource.allCases {
            let claimants = owed.indices.filter { owed[$0][r] > 0 }
            guard !claimants.isEmpty else { continue }
            let total = claimants.reduce(0) { $0 + owed[$1][r] }
            if s.bank[r] >= total {
                for p in claimants { pay(p, r, owed[p][r]) }
            } else {
                if claimants.count == 1 { pay(claimants[0], r, min(owed[claimants[0]][r], s.bank[r])) }
                s.log("Bank is out of \(r.rawValue).")
            }
        }
        let recipients = received.indices.filter { received[$0] > 0 }
        if recipients.isEmpty { return "Nobody harvested." }
        return recipients.map { "\(s.players[$0].name) +\(received[$0])" }.joined(separator: ", ")
    }
}
