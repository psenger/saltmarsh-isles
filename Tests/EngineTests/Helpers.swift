import Foundation
import Testing
@testable import SaltmarshEngine

enum TestGames {
    /// A new game of all-human seats, still rolling for first player.
    static func fresh(players: Int = 3, seed: UInt64 = 1) -> GameState {
        Engine.newGame(GameConfig(controllers: Array(repeating: .human, count: players), seed: seed))
    }

    /// First roll forced so `first` wins, setup completed with the first legal corner and edge at every step.
    static func afterSetup(players: Int = 3, seed: UInt64 = 1, first: Int = 0) -> GameState {
        var s = fresh(players: players, seed: seed)
        s.forcedRolls = (0..<players).map { $0 == first ? [6, 6] : [1, 1] }
        for _ in 0..<players { try! Engine.apply(.rollForFirst, to: &s) }
        while case .setup = s.phase { try! Engine.apply(Engine.legalMoves(s).first!, to: &s) }
        return s
    }

    /// `afterSetup`, then the first player rolls `roll`.
    static func rolled(_ roll: Int, players: Int = 3, seed: UInt64 = 1) -> GameState {
        var s = afterSetup(players: players, seed: seed)
        s.force(roll: roll)
        try! Engine.apply(.roll, to: &s)
        return s
    }

    /// A fresh 3-player game driven by random legal moves from `SeededRNG(seed:)`, calling `check` after
    /// every move, until the game ends or `maxMoves` is reached. Each pick chooses a move kind uniformly,
    /// then a move of that kind uniformly, so the dozens of trade offers do not drown out builds and
    /// games can actually finish. The same seed feeds the game config, so `Engine.replay` reproduces it.
    static func randomGame(seed: UInt64, maxMoves: Int = 6000, check: ((GameState) -> Void)? = nil) -> (final: GameState, moves: [Move]) {
        var s = Engine.newGame(GameConfig(controllers: [.human, .human, .human], seed: seed))
        var rng = SeededRNG(seed: seed)
        var moves: [Move] = []
        for _ in 0..<maxMoves {
            if case .gameOver = s.phase { break }
            let legal = Engine.legalMoves(s)
            guard !legal.isEmpty else { break }
            let kinds = Array(Set(legal.map(kind))).sorted()
            let chosenKind = kinds[Int(rng.next() % UInt64(kinds.count))]
            let ofKind = legal.filter { kind($0) == chosenKind }
            let move = ofKind[Int(rng.next() % UInt64(ofKind.count))]
            try! Engine.apply(move, to: &s)
            moves.append(move)
            check?(s)
        }
        return (s, moves)
    }

    /// The enum case name of a move, without its payload.
    private static func kind(_ m: Move) -> String { String("\(m)".prefix { $0 != "(" }) }

    /// `afterSetup(seed:)`, then `moves` uniformly random legal moves drawn from `SeededRNG(seed:)`,
    /// stopping early when the game ends.
    static func midGame(seed: UInt64, moves: Int = 60) -> GameState {
        var s = afterSetup(seed: seed)
        var rng = SeededRNG(seed: seed)
        for _ in 0..<moves {
            if case .gameOver = s.phase { break }
            let legal = Engine.legalMoves(s)
            guard !legal.isEmpty else { break }
            try! Engine.apply(legal[Int(rng.next() % UInt64(legal.count))], to: &s)
        }
        return s
    }
}

extension GameState {
    /// Queues a dice pair summing to `roll` for the next roll.
    mutating func force(roll: Int) {
        let a = min(6, roll - 1)
        forcedRolls.append([a, roll - a])
    }

    /// Replaces a hand, then rebalances the bank so bank + all hands = 19 of each resource.
    mutating func set(hand: ResourceCounts, for player: Int) {
        players[player].hand = hand
        bank = players.reduce(ResourceCounts.uniform(19)) { $0 - $1.hand }
    }

    mutating func clearHands() {
        for i in players.indices { players[i].hand = ResourceCounts() }
        bank = .uniform(19)
    }

    /// Removes every building and road from the board.
    mutating func clearBoard() {
        for i in board.corners.indices { board.corners[i].owner = nil; board.corners[i].isCity = false }
        for i in board.edges.indices { board.edges[i].owner = nil }
    }

    mutating func place(settlement corner: Int, owner: Int) {
        board.corners[corner].owner = owner
        board.corners[corner].isCity = false
    }

    mutating func place(city corner: Int, owner: Int) {
        board.corners[corner].owner = owner
        board.corners[corner].isCity = true
    }

    mutating func place(road edge: Int, owner: Int) { board.edges[edge].owner = owner }

    /// A path of `length` edges from `start` through corners not in `avoiding`, preferring lower-index
    /// corners and backtracking when a branch dead-ends. Adds every corner on the path (start included)
    /// to `avoiding`. Returns the edge indices walked.
    func chain(from start: Int, length: Int, avoiding: inout Set<Int>) -> [Int] {
        guard let corners = chainCorners(from: start, length: length, avoiding: avoiding) else {
            preconditionFailure("no chain of \(length) edges from corner \(start)")
        }
        avoiding.formUnion(corners)
        return zip(corners, corners.dropFirst()).map { board.edgeIndex(between: $0, $1)! }
    }

    /// Like `chain`, starting at the lowest-index corner not in `avoiding` that satisfies `startWhere`
    /// and from which such a chain exists.
    func firstChain(length: Int, avoiding: inout Set<Int>, startWhere: (Int) -> Bool = { _ in true }) -> [Int] {
        for start in board.corners.indices where !avoiding.contains(start) && startWhere(start) {
            if chainCorners(from: start, length: length, avoiding: avoiding) != nil {
                return chain(from: start, length: length, avoiding: &avoiding)
            }
        }
        preconditionFailure("no chain of \(length) edges available")
    }

    private func chainCorners(from start: Int, length: Int, avoiding: Set<Int>) -> [Int]? {
        var visited = avoiding
        visited.insert(start)
        var path = [start]
        func search(_ at: Int, _ remaining: Int) -> Bool {
            if remaining == 0 { return true }
            for next in board.corners[at].adjacent.sorted() where !visited.contains(next) {
                visited.insert(next)
                path.append(next)
                if search(next, remaining - 1) { return true }
                visited.remove(next)
                path.removeLast()
            }
            return false
        }
        return search(start, length) ? path : nil
    }

    mutating func placeChain(_ edges: [Int], owner: Int) {
        for e in edges { board.edges[e].owner = owner }
    }

    /// The first `n` corners in index order that are unowned, not in `avoiding`, and not adjacent to
    /// an owned or already chosen corner.
    func spreadCorners(_ n: Int, avoiding: Set<Int> = []) -> [Int] {
        var chosen: [Int] = []
        for c in board.corners.indices where chosen.count < n {
            guard !avoiding.contains(c), board.corners[c].owner == nil else { continue }
            let clear = board.corners[c].adjacent.allSatisfy { board.corners[$0].owner == nil && !chosen.contains($0) }
            if clear { chosen.append(c) }
        }
        precondition(chosen.count == n, "only \(chosen.count) of \(n) spread corners available")
        return chosen
    }

    /// Places two roads `owned → x → y` along the lowest-index free corners such that `owner` may
    /// settle at `y`; returns `y`.
    mutating func addReach(from owned: Int, owner: Int) -> Int {
        for x in board.corners[owned].adjacent.sorted() where board.corners[x].owner == nil {
            for y in board.corners[x].adjacent.sorted() where y != owned && board.corners[y].owner == nil {
                var trial = self
                trial.place(road: board.edgeIndex(between: owned, x)!, owner: owner)
                trial.place(road: board.edgeIndex(between: x, y)!, owner: owner)
                if Engine.canSettle(trial, corner: y, player: owner, setup: false) {
                    self = trial
                    return y
                }
            }
        }
        preconditionFailure("no settlement spot reachable from corner \(owned)")
    }

    func tile(numbered n: Int) -> Int { board.tiles.firstIndex { $0.number == n }! }

    func corner(onTileNumbered n: Int, index k: Int = 0) -> Int { board.tiles[tile(numbered: n)].corners[k] }
}
