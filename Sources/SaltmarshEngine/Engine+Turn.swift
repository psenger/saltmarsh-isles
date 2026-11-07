extension Engine {
    static func applyRoll(_ s: inout GameState) {
        let pair = rollDice(&s), total = pair.reduce(0, +)
        let name = s.players[s.current].name, dice = "(\(pair[0])+\(pair[1]))"
        if total == 7 {
            s.log("\(name) rolled 7 \(dice).")
            let queue = s.players.indices.filter { s.players[$0].hand.total > 7 }
            s.phase = queue.isEmpty ? .movingRobber(returnTo: .main) : .discarding(queue: queue)
        } else {
            let mark = s.log.count
            let fragment = produce(roll: total, in: &s)
            s.log.insert("\(name) rolled \(total) \(dice). \(fragment)", at: mark)
            s.phase = .main
        }
    }

    /// Pays every building on a tile numbered `roll` (robber tile excluded), one card per settlement
    /// and two per city, subject to the bank rule: when the bank cannot cover a resource, a single
    /// claimant takes what is left and several claimants get nothing. Shortages are logged.
    /// Returns "Cobalt +1 grain, Amber +2 grain" (recipients in seat order, each resource named, in resource
    /// order: "Amber +1 grain +1 ore") or "Nobody harvested.".
    static func produce(roll: Int, in s: inout GameState) -> String {
        var owed = Array(repeating: ResourceCounts(), count: s.playerCount)
        for (ti, tile) in s.board.tiles.enumerated() where tile.number == roll && ti != s.robberTile {
            guard let r = tile.resource else { continue }
            for c in tile.corners {
                if let o = s.board.corners[c].owner { owed[o][r] += s.board.corners[c].isCity ? 2 : 1 }
            }
        }
        var received = Array(repeating: ResourceCounts(), count: s.playerCount)
        func pay(_ p: Int, _ r: Resource, _ n: Int) {
            s.players[p].hand[r] += n
            s.bank[r] -= n
            received[p][r] += n
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
        let recipients = received.indices.filter { received[$0].total > 0 }
        if recipients.isEmpty { return "Nobody harvested." }
        return recipients.map { p in
            let gains = Resource.allCases.filter { received[p][$0] > 0 }.map { "+\(received[p][$0]) \($0.rawValue)" }
            return "\(s.players[p].name) \(gains.joined(separator: " "))"
        }.joined(separator: ", ")
    }

    static func applyEndTurn(_ s: inout GameState) {
        s.log("\(s.players[s.current].name) ended the turn.")
        s.current = (s.current + 1) % s.playerCount
        s.dice = nil
        s.devCardPlayedThisTurn = false
        s.turn += 1
        s.phase = .awaitingRoll
        checkWin(&s)
    }

    // MARK: Sevens

    /// Every way to discard `count` cards from `hand` when there are at most 256 of them; otherwise the single
    /// greedy choice that repeatedly drops a card from the largest remaining pile (ties in `Resource` order).
    public static func discardOptions(hand: ResourceCounts, count: Int) -> [ResourceCounts] {
        let resources = Resource.allCases
        var options: [ResourceCounts] = []
        var current = ResourceCounts()
        func enumerate(_ i: Int, _ remaining: Int) {
            if options.count > 256 { return }
            if i == resources.count {
                if remaining == 0 { options.append(current) }
                return
            }
            let r = resources[i]
            for n in 0...max(0, min(hand[r], remaining)) {          // a hand below zero is a bug elsewhere, not a reason to trap
                current[r] = n
                enumerate(i + 1, remaining - n)
            }
            current[r] = 0
        }
        enumerate(0, count)
        if options.count <= 256 { return options }

        var left = hand, pick = ResourceCounts()
        for _ in 0..<count {
            var best = resources[0]
            for r in resources where left[r] > left[best] { best = r }
            left[best] -= 1
            pick[best] += 1
        }
        return [pick]
    }

    static func isValidDiscard(_ c: ResourceCounts, in s: GameState) -> Bool {
        guard case .discarding(let queue) = s.phase, let p = queue.first else { return false }
        let hand = s.players[p].hand
        return !c.hasNegative && c.total == hand.total / 2 && hand.contains(c)
    }

    static func applyDiscard(_ s: inout GameState, _ c: ResourceCounts) {
        guard case .discarding(var queue) = s.phase, !queue.isEmpty else { return }
        let p = queue.removeFirst()
        s.players[p].hand = s.players[p].hand - c
        s.bank = s.bank + c
        s.log("\(s.players[p].name) discarded \(c).")
        if queue.isEmpty {
            s.phase = .movingRobber(returnTo: .main)
            s.log("\(s.players[s.current].name) now moves the robber.")
        } else {
            s.phase = .discarding(queue: queue)
        }
    }

    static func applyMoveRobber(_ s: inout GameState, tile t: Int) {
        guard case .movingRobber(let returnTo) = s.phase else { return }
        s.robberTile = t
        s.log("\(s.players[s.current].name) moved the robber to \(s.board.hexID(t)).")
        var candidates: [Int] = []
        var opponentsOnTile = false
        for c in s.board.tiles[t].corners {
            if let o = s.board.corners[c].owner, o != s.current {
                opponentsOnTile = true
                if s.players[o].hand.total > 0, !candidates.contains(o) { candidates.append(o) }
            }
        }
        candidates.sort()
        if candidates.isEmpty {
            // Only worth saying when someone is there to rob and has nothing.
            if opponentsOnTile { s.log("Nobody on that tile has cards to steal.") }
            s.phase = returnTo
        } else {
            s.phase = .choosingVictim(candidates: candidates, returnTo: returnTo)
        }
    }

    static func applySteal(_ s: inout GameState, from victim: Int) {
        guard case .choosingVictim(_, let returnTo) = s.phase else { return }
        let hand = s.players[victim].hand
        var k = Int.random(in: 0..<hand.total, using: &s.rng)
        var stolen: Resource?
        for (r, n) in hand.nonZero {
            if k < n {
                s.players[victim].hand[r] -= 1
                s.players[s.current].hand[r] += 1
                stolen = r
                break
            }
            k -= n
        }
        s.log("\(s.players[s.current].name) stole 1 \(stolen?.rawValue ?? "card") from \(s.players[victim].name).")
        s.phase = returnTo
    }
}
