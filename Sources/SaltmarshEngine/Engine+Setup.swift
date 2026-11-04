extension Engine {
    static func setupMoves(_ s: GameState, placingRoad: Bool) -> [Move] {
        let p = s.current
        if placingRoad {
            return s.board.edges.indices.filter { canRoad(s, edge: $0, player: p) }.map { .placeRoad(edge: $0) }
        }
        return s.board.corners.indices.filter { canSettle(s, corner: $0, player: p, setup: true) }.map { .placeSettlement(corner: $0) }
    }

    static func applySetupSettlement(_ s: inout GameState, corner c: Int) {
        guard case .setup(let step, _, _) = s.phase else { return }
        let p = s.current
        s.board.corners[c].owner = p
        s.log("\(s.players[p].name) founded a settlement.")
        if step >= s.playerCount {
            // The second settlement pays one card per adjacent land tile.
            for t in s.board.corners[c].tiles {
                if let r = s.board.tiles[t].resource, s.bank[r] > 0 {
                    s.bank[r] -= 1
                    s.players[p].hand[r] += 1
                }
            }
        }
        s.phase = .setup(step: step, placingRoad: true, lastSettlement: c)
    }

    static func applySetupRoad(_ s: inout GameState, edge e: Int) {
        guard case .setup(let step, _, _) = s.phase else { return }
        let p = s.current
        s.board.edges[e].owner = p
        s.log("\(s.players[p].name) laid a road.")
        let next = step + 1
        if next == 2 * s.playerCount {
            s.current = s.firstPlayer
            s.phase = .awaitingRoll
            s.log("Setup done. \(s.players[s.current].name) rolls first.")
        } else {
            s.current = setupOrder(players: s.playerCount, first: s.firstPlayer)[next]
            s.phase = .setup(step: next, placingRoad: false, lastSettlement: nil)
        }
    }
}
