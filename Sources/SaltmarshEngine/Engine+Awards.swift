extension Engine {
    /// Longest trail of the player's roads without reusing an edge. A trail may end at, but not pass
    /// through, a corner holding an opponent's building.
    public static func roadLength(_ s: GameState, player p: Int) -> Int {
        let mine = s.board.edges.indices.filter { s.board.edges[$0].owner == p }
        guard !mine.isEmpty else { return 0 }
        var used = Set<Int>()
        var best = 0
        func walk(from corner: Int, length: Int) {
            best = max(best, length)
            if let owner = s.board.corners[corner].owner, owner != p { return }
            for e in s.board.corners[corner].edges where s.board.edges[e].owner == p && !used.contains(e) {
                used.insert(e)
                walk(from: s.board.edges[e].other(corner), length: length + 1)
                used.remove(e)
            }
        }
        for e in mine {
            walk(from: s.board.edges[e].a, length: 0)
            walk(from: s.board.edges[e].b, length: 0)
        }
        return best
    }

    /// Re-evaluates longest road (5 or more; holder keeps on a tie; strictly longer takes it; a cut holder
    /// yields to a unique leader or to nobody) and largest army (first to 3 knights; strictly more takes it).
    public static func updateAwards(_ s: inout GameState) {
        let lengths = s.players.indices.map { roadLength(s, player: $0) }
        let longest = lengths.max() ?? 0
        let leaders = longest >= 5 ? s.players.indices.filter { lengths[$0] == longest } : []
        let roadHolder: Int?
        if let h = s.longestRoadHolder, leaders.contains(h) {
            roadHolder = h
        } else if leaders.count == 1 {
            roadHolder = leaders[0]
        } else {
            roadHolder = nil
        }
        if roadHolder != s.longestRoadHolder {
            s.longestRoadHolder = roadHolder
            if let h = roadHolder {
                s.log("\(s.players[h].name) takes longest road (\(lengths[h])).")
            } else {
                s.log("Nobody holds longest road now.")
            }
        }

        let knights = s.players.map(\.knightsPlayed)
        var armyHolder = s.largestArmyHolder
        if let h = armyHolder {
            if let top = knights.indices.max(by: { knights[$0] < knights[$1] }), knights[top] > knights[h] { armyHolder = top }
        } else if let top = knights.max(), top >= 3 {
            armyHolder = knights.firstIndex(of: top)
        }
        if armyHolder != s.largestArmyHolder, let h = armyHolder {
            s.largestArmyHolder = h
            s.log("\(s.players[h].name) takes largest army (\(knights[h]) knights).")
        }
    }
}
