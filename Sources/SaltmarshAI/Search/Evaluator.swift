import SaltmarshEngine

/// A position's worth to one seat, for comparing the ends of playouts. Points dominate; production, its
/// spread and nearness to the awards break ties; the hand counts for what it can build next. Only guessed
/// states reach this file.
enum Evaluator {
    /// 10 per point held or hidden; production pips per resource capped at 8; 2 per resource produced; 3 for
    /// an award held, else 1 per Knight played (up to 2) and 1 for a road of 4; plus the hand's value toward
    /// the seat's nearest build.
    static func score(_ s: GameState, for seat: Int) -> Int {
        var value = 10 * Engine.totalPoints(s, player: seat)
        if case .gameOver(let winner) = s.phase { value += winner == seat ? 1000 : -1000 }   // a finished game outranks any position
        let production = BoardFacts.production(of: seat, board: s.board, robber: s.robberTile)
        for r in Resource.allCases where production[r] > 0 { value += min(production[r], 8) + 2 }
        value += s.largestArmyHolder == seat ? 3 : min(s.players[seat].knightsPlayed, 2)
        value += s.longestRoadHolder == seat ? 3 : (Engine.roadLength(board: s.board, player: seat) >= 4 ? 1 : 0)
        let view = Engine.view(s, for: seat)
        value += Goals.handValue(view.hand, toward: Goals.nearest(view: view))
        return value
    }

    /// The seat's score less the best other seat's: what the search maximises.
    static func margin(_ s: GameState, for seat: Int) -> Int {
        let best = s.players.indices.filter { $0 != seat }.map { score(s, for: $0) }.max() ?? 0
        return score(s, for: seat) - best
    }
}
