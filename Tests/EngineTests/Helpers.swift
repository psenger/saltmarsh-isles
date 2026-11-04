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

    /// Walks `length` edges from `start`, each step to the lowest-index adjacent corner not in `avoiding`,
    /// adding every visited corner (start included) to `avoiding`. Returns the edge indices walked.
    func chain(from start: Int, length: Int, avoiding: inout Set<Int>) -> [Int] {
        var edges: [Int] = []
        var at = start
        avoiding.insert(start)
        for _ in 0..<length {
            guard let next = board.corners[at].adjacent.filter({ !avoiding.contains($0) }).min() else { break }
            edges.append(board.edgeIndex(between: at, next)!)
            avoiding.insert(next)
            at = next
        }
        precondition(edges.count == length, "chain from corner \(start) stopped after \(edges.count) of \(length) edges")
        return edges
    }

    mutating func placeChain(_ edges: [Int], owner: Int) {
        for e in edges { board.edges[e].owner = owner }
    }

    func tile(numbered n: Int) -> Int { board.tiles.firstIndex { $0.number == n }! }

    func corner(onTileNumbered n: Int, index k: Int = 0) -> Int { board.tiles[tile(numbered: n)].corners[k] }
}
