extension Engine {
    /// Rolls two dice through the state's generator, or pops a forced roll when one is queued.
    static func rollDice(_ s: inout GameState) -> [Int] {
        let pair = s.forcedRolls.isEmpty ? [s.rng.d6(), s.rng.d6()] : s.forcedRolls.removeFirst()
        s.dice = pair
        return pair
    }

    /// Placement order for setup: seats from `first` wrapping round, then the same seats reversed.
    public static func setupOrder(players n: Int, first: Int) -> [Int] {
        let forward = (0..<n).map { (first + $0) % n }
        return forward + forward.reversed()
    }

    static func applyRollForFirst(_ s: inout GameState) {
        guard case .rollingForFirst(var rolls, let contenders) = s.phase else { return }
        let p = actingPlayer(s)
        let pair = rollDice(&s), total = pair.reduce(0, +)
        rolls[p] = total
        s.log("\(s.players[p].name) rolled \(total) (\(pair[0])+\(pair[1])) for first player.")
        guard contenders.allSatisfy({ rolls[$0] != nil }) else {
            s.phase = .rollingForFirst(rolls: rolls, contenders: contenders)
            return
        }
        let best = contenders.map { rolls[$0]! }.max()!
        let tied = contenders.filter { rolls[$0] == best }
        if tied.count == 1 {
            let winner = tied[0]
            s.firstPlayer = winner
            s.current = winner
            s.dice = nil
            s.phase = .setup(step: 0, placingRoad: false, lastSettlement: nil)
            s.log("\(s.players[winner].name) goes first. Place your first settlement.")
        } else {
            s.log("Tie between \(nameList(tied.map { s.players[$0].name })). Roll again.")
            s.phase = .rollingForFirst(rolls: Array(repeating: nil, count: s.playerCount), contenders: tied)
        }
    }

    /// "A", "A and B", "A, B and C".
    static func nameList(_ names: [String]) -> String {
        guard names.count > 1 else { return names.first ?? "" }
        return names.dropLast().joined(separator: ", ") + " and " + names.last!
    }
}
