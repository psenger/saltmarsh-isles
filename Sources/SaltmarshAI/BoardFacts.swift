import SaltmarshEngine

/// Pure facts about a board that the heuristic reads: production, pieces, spot scores and how far a
/// seat's road network is from each corner. Only a `PlayerView`'s board ever reaches this file.
enum BoardFacts {
    /// Pips per resource from the seat's buildings; a city counts twice; a tile under `robber` counts nothing.
    static func production(of seat: Int, board: Board, robber: Int? = nil) -> ResourceCounts {
        var out = ResourceCounts()
        for corner in board.corners where corner.owner == seat {
            for t in corner.tiles where t != robber {
                if let r = board.tiles[t].resource { out[r] += board.tiles[t].pips * (corner.isCity ? 2 : 1) }
            }
        }
        return out
    }

    static func pieces(of seat: Int, board: Board) -> (settlements: Int, cities: Int, roads: Int) {
        let mine = board.corners.filter { $0.owner == seat }
        return (mine.filter { !$0.isCity }.count, mine.filter(\.isCity).count, board.edges.filter { $0.owner == seat }.count)
    }

    static func piecesLeft(of seat: Int, board: Board) -> (settlements: Int, cities: Int, roads: Int) {
        let p = pieces(of: seat, board: board)
        return (PieceLimit.settlements - p.settlements, PieceLimit.cities - p.cities, PieceLimit.roads - p.roads)
    }

    static func tilePips(_ tile: Int, board: Board) -> Int { board.tiles[tile].pips }

    static func cornerPips(_ corner: Int, board: Board) -> Int {
        board.corners[corner].tiles.reduce(0) { $0 + tilePips($1, board: board) }
    }

    /// Unowned, and no neighbouring corner has a building: the distance rule.
    static func settleable(_ corner: Int, board: Board) -> Bool {
        board.corners[corner].owner == nil && board.corners[corner].adjacent.allSatisfy { board.corners[$0].owner == nil }
    }

    /// Pips, plus 2 per resource at the corner the seat does not yet produce, plus a harbour bonus:
    /// 3 for a 2:1 harbour whose resource the seat already produces 4 or more pips of, 1 for a 3:1 harbour.
    static func spotScore(_ corner: Int, board: Board, produces: ResourceCounts) -> Int {
        let resources = Set(board.corners[corner].tiles.compactMap { board.tiles[$0].resource })
        let lack = resources.filter { produces[$0] == 0 }.count
        var harbourBonus = 0
        for h in board.harbours where h.a == corner || h.b == corner {
            switch h.kind {
            case .any: harbourBonus = max(harbourBonus, 1)
            case .specific(let r): if produces[r] >= 4 { harbourBonus = max(harbourBonus, 3) }
            }
        }
        return cornerPips(corner, board: board) + 2 * lack + harbourBonus
    }

    /// The corners the seat owns, plus every end of its roads that no other seat has built on: an
    /// opponent's building at the end of a road blocks continuing from that end.
    static func network(of seat: Int, board: Board) -> Set<Int> {
        var out = Set(board.corners.indices.filter { board.corners[$0].owner == seat })
        for e in board.edges where e.owner == seat {
            for end in [e.a, e.b] where board.corners[end].owner == nil || board.corners[end].owner == seat { out.insert(end) }
        }
        return out
    }

    /// Per corner, how many roads the seat must build to reach it; nil when unreachable. Own edges cost 0,
    /// unowned edges 1; an edge another seat owns, or whose far corner another seat owns, is never crossed.
    static func distances(from network: Set<Int>, board: Board, seat: Int) -> [Int?] {
        var dist = [Int?](repeating: nil, count: board.corners.count)
        for c in network { dist[c] = 0 }
        var changed = true
        while changed {
            changed = false
            for e in board.edges where e.owner == nil || e.owner == seat {
                let cost = e.owner == seat ? 0 : 1
                for (from, to) in [(e.a, e.b), (e.b, e.a)] {
                    guard let d = dist[from] else { continue }
                    if let owner = board.corners[from].owner, owner != seat { continue }
                    if let owner = board.corners[to].owner, owner != seat { continue }
                    if dist[to] == nil || dist[to]! > d + cost { dist[to] = d + cost; changed = true }
                }
            }
        }
        return dist
    }

    /// The settleable corner maximising spotScore − 2 × distance over distance ≤ roadsLeft; ties go to the
    /// smaller distance, then the lower index.
    static func bestTarget(for seat: Int, board: Board, produces: ResourceCounts, roadsLeft: Int) -> (corner: Int, distance: Int)? {
        let d = distances(from: network(of: seat, board: board), board: board, seat: seat)
        var best: (corner: Int, distance: Int, value: Int)?
        for c in board.corners.indices where settleable(c, board: board) {
            guard let dc = d[c], dc <= roadsLeft else { continue }
            let value = spotScore(c, board: board, produces: produces) - 2 * dc
            if let b = best, (value, -dc, -c) <= (b.value, -b.distance, -b.corner) { continue }
            best = (c, dc, value)
        }
        return best.map { ($0.corner, $0.distance) }
    }

    /// Among the legal `.placeRoad` moves, the one that leaves the smallest distance to `target` once owned;
    /// ties go to the lower edge index. nil when no legal road lowers the distance.
    static func roadToward(_ target: Int, legal: [Move], board: Board, seat: Int) -> Move? {
        let now = distances(from: network(of: seat, board: board), board: board, seat: seat)[target] ?? Int.max
        var best: (edge: Int, distance: Int)?
        for move in legal {
            guard case .placeRoad(let e) = move else { continue }
            var after = board; after.edges[e].owner = seat
            guard let d = distances(from: network(of: seat, board: after), board: after, seat: seat)[target], d < now else { continue }
            if let b = best, (d, e) >= (b.distance, b.edge) { continue }
            best = (e, d)
        }
        return best.map { .placeRoad(edge: $0.edge) }
    }
}
