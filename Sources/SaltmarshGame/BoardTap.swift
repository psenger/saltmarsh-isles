import SaltmarshEngine

/// What a tap on the board landed on.
public enum BoardTap: Equatable, Sendable {
    case corner(Int), edge(Int), tile(Int)
}

extension ScreenState {
    /// The nearest target the screen currently offers, in board space (origin at the board centre).
    /// Only offered targets count, so a tap that is not the player's moment finds nothing.
    public func boardTap(x: Double, y: Double) -> BoardTap? {
        func distance(_ px: Double, _ py: Double) -> Double {
            ((px - x) * (px - x) + (py - y) * (py - y)).squareRoot()
        }
        var targets: [(tap: BoardTap, distance: Double, reach: Double)] = []
        let corners = glowingCorners.union(pulsingSettlements).union(stealTargets.flatMap(\.corners))
        for c in corners {
            let p = board.corners[c].point
            targets.append((.corner(c), distance(p.x, p.y), 40))
        }
        for e in dashedEdges {
            let a = board.corners[board.edges[e].a].point, b = board.corners[board.edges[e].b].point
            targets.append((.edge(e), distance((a.x + b.x) / 2, (a.y + b.y) / 2), 40))
        }
        for t in selectableTiles {
            let p = board.tiles[t].center
            targets.append((.tile(t), distance(p.x, p.y), 58))
        }
        return targets.filter { $0.distance <= $0.reach }.min { $0.distance < $1.distance }?.tap
    }
}

extension GameViewModel {
    /// A tap on the board, in board space.
    public func tapBoard(x: Double, y: Double) {
        switch screen.boardTap(x: x, y: y) {
        case .corner(let c): tapCorner(c)
        case .edge(let e): tapEdge(e)
        case .tile(let t): tapTile(t)
        case nil: break
        }
    }
}
