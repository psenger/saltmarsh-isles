import Foundation

public enum BoardGenerator {
    /// Geometry only: every tile is desert with no number, and there are no harbours.
    public static func layout() -> Board {
        let s = Board.hexSize
        var tiles: [Tile] = [], corners: [Corner] = [], edges: [Edge] = []
        var cornerKeys: [String: Int] = [:], edgeKeys: [String: Int] = [:]
        var desert = 0
        for q in -2...2 {
            for r in max(-2, -q - 2)...min(2, -q + 2) {
                if q == 0 && r == 0 { desert = tiles.count }
                let ti = tiles.count
                let cx = s * 3.0.squareRoot() * (Double(q) + Double(r) / 2), cy = s * 1.5 * Double(r)
                var cs: [Int] = []
                for i in 0..<6 {
                    let a = Double.pi / 180 * Double(60 * i - 30)
                    let x = cx + s * cos(a), y = cy + s * sin(a)
                    let key = "\(Int(x.rounded())),\(Int(y.rounded()))"
                    if cornerKeys[key] == nil {
                        cornerKeys[key] = corners.count
                        corners.append(Corner(point: Point(x: x, y: y), tiles: [], adjacent: [], edges: [], owner: nil, isCity: false))
                    }
                    let ci = cornerKeys[key]!
                    cs.append(ci)
                    corners[ci].tiles.append(ti)
                }
                var es: [Int] = []
                for i in 0..<6 {
                    let a = cs[i], b = cs[(i + 1) % 6]
                    let key = "\(min(a, b))-\(max(a, b))"
                    if edgeKeys[key] == nil {
                        edgeKeys[key] = edges.count
                        edges.append(Edge(a: a, b: b, tiles: [], owner: nil))
                    }
                    let ei = edgeKeys[key]!
                    es.append(ei)
                    edges[ei].tiles.append(ti)
                }
                tiles.append(Tile(center: Point(x: cx, y: cy), terrain: .desert, number: nil, corners: cs, edges: es, neighbours: []))
            }
        }
        for (ei, e) in edges.enumerated() {
            corners[e.a].edges.append(ei); corners[e.a].adjacent.append(e.b)
            corners[e.b].edges.append(ei); corners[e.b].adjacent.append(e.a)
        }
        for i in tiles.indices {
            tiles[i].neighbours = tiles.indices.filter {
                $0 != i && Set(tiles[$0].corners).intersection(tiles[i].corners).count == 2
            }
        }
        return Board(tiles: tiles, corners: corners, edges: edges, harbours: [], desertTile: desert)
    }
    public static let harbourOffsets = [0, 3, 7, 10, 13, 17, 20, 23, 27]

    private static func shuffle<T>(_ a: inout [T], using rng: inout SeededRNG) {
        guard a.count > 1 else { return }
        for i in stride(from: a.count - 1, to: 0, by: -1) {
            a.swapAt(i, Int(rng.next() % UInt64(i + 1)))
        }
    }

    /// Coastal edge indices in ring order, sorted by the angle of the edge midpoint.
    private static func coastalRing(_ board: Board) -> [Int] {
        func angle(_ ei: Int) -> Double {
            let e = board.edges[ei], a = board.corners[e.a].point, b = board.corners[e.b].point
            return atan2((a.y + b.y) / 2, (a.x + b.x) / 2)
        }
        return board.edges.indices.filter { board.edges[$0].isCoastal }.sorted { angle($0) < angle($1) }
    }

    public static func generate(using rng: inout SeededRNG) -> Board {
        var board = layout()
        let land = board.tiles.indices.filter { $0 != board.desertTile }
        var types: [Resource] = []
        for (r, n) in [(Resource.timber, 4), (.clay, 3), (.wool, 4), (.grain, 4), (.ore, 3)] {
            types += Array(repeating: r, count: n)
        }
        for _ in 0..<20_000 {
            shuffle(&types, using: &rng)
            for (k, i) in land.enumerated() { board.tiles[i].terrain = .land(types[k]) }
            if !land.contains(where: { i in board.tiles[i].neighbours.contains { board.tiles[$0].resource == board.tiles[i].resource } }) { break }
        }
        var numbers = [2, 3, 3, 4, 4, 5, 5, 6, 6, 8, 8, 9, 9, 10, 10, 11, 11, 12]
        // The retry loop works on flat arrays; numberViolations(_:) is the readable statement of the same rules.
        // Each trial is a uniform random permutation, drawn one place at a time so a clash abandons the trial early.
        let neighbours = board.tiles.map(\.neighbours)
        let cornerTiles = board.corners.map(\.tiles)
        let groups = Resource.allCases.map { r in land.filter { board.tiles[$0].resource == r } }
        let blank = [Int](repeating: 0, count: board.tiles.count)
        var num = blank
        var pip = blank
        for _ in 0..<50_000 {
            num = blank; pip = blank
            var ok = true
            for k in 0..<land.count {
                numbers.swapAt(k, k + Int(rng.next() % UInt64(land.count - k)))
                let i = land[k], n = numbers[k], p = Board.pips(n)
                for j in neighbours[i] where num[j] == n || (p == 5 && pip[j] == 5) { ok = false; break }
                if !ok { break }
                num[i] = n; pip[i] = p
            }
            if !ok { continue }
            for ct in cornerTiles {
                var sum = 0
                for t in ct { sum += pip[t] }
                if sum > 11 { ok = false; break }
            }
            if !ok { continue }
            for g in groups {
                var sum = 0
                for t in g { sum += pip[t] }
                if abs(Double(sum) - Double(g.count) * 58 / 18) > 3 { ok = false; break }
            }
            if !ok { continue }
            break
        }
        for i in land { board.tiles[i].number = num[i] }
        var kinds: [Harbour.Kind] = []
        var specifics = Resource.allCases
        shuffle(&specifics, using: &rng)
        for i in 0..<harbourOffsets.count { kinds.append(i % 2 == 1 ? .any : .specific(specifics[i / 2])) }
        let ring = coastalRing(board)
        let start = Int.random(in: 0..<ring.count, using: &rng)
        for (i, off) in harbourOffsets.enumerated() {
            let ei = ring[(off + start) % ring.count], e = board.edges[ei]
            let pa = board.corners[e.a].point, pb = board.corners[e.b].point
            let mx = (pa.x + pb.x) / 2, my = (pa.y + pb.y) / 2
            let c = board.tiles[e.tiles[0]].center
            let dx = mx - c.x, dy = my - c.y, d = hypot(dx, dy)
            let kind = kinds[i]
            board.harbours.append(Harbour(kind: kind, ratio: kind == .any ? 3 : 2, a: e.a, b: e.b, edge: ei,
                                          position: Point(x: mx + dx / d * 30, y: my + dy / d * 30)))
        }
        return board
    }

    /// Rules 2 to 5, the ones the number shuffle enforces.
    private static func numberViolations(_ board: Board) -> [String] {
        var out: [String] = []
        func red(_ n: Int) -> Bool { n == 6 || n == 8 }
        for (i, t) in board.tiles.enumerated() {
            guard let n = t.number else { continue }
            for j in t.neighbours where j > i {
                guard let m = board.tiles[j].number else { continue }
                if n == m { out.append("tiles \(i) and \(j) are neighbours with the same number \(n)") }
                if red(n) && red(m) { out.append("tiles \(i) and \(j) are neighbouring 6/8 tiles") }
            }
        }
        for (ci, c) in board.corners.enumerated() {
            let sum = c.tiles.reduce(0) { $0 + board.tiles[$1].pips }
            if sum > 11 { out.append("corner \(ci) touches \(sum) pips (limit 11)") }
        }
        for r in Resource.allCases {
            let ts = board.tiles.filter { $0.resource == r }
            let total = ts.reduce(0) { $0 + $1.pips }
            let fair = Double(ts.count) * 58 / 18
            if abs(Double(total) - fair) > 3 { out.append("\(r.rawValue) has \(total) pips, fair share is \(fair)") }
        }
        return out
    }

    public static func violations(_ board: Board) -> [String] {
        var out: [String] = []
        for (i, t) in board.tiles.enumerated() {
            guard let r = t.resource else { continue }
            for j in t.neighbours where j > i && board.tiles[j].resource == r {
                out.append("tiles \(i) and \(j) are neighbours with the same resource \(r.rawValue)")
            }
        }
        out += numberViolations(board)
        if board.harbours.count != 9 { out.append("expected 9 harbours, found \(board.harbours.count)") }
        if board.harbours.contains(where: { !board.edges[$0.edge].isCoastal }) { out.append("a harbour is not on a coastal edge") }
        if board.harbours.filter({ $0.kind == .any && $0.ratio == 3 }).count != 4 { out.append("expected four 3:1 harbours") }
        for r in Resource.allCases where board.harbours.filter({ $0.kind == .specific(r) && $0.ratio == 2 }).count != 1 {
            out.append("expected one 2:1 \(r.rawValue) harbour")
        }
        let ring = coastalRing(board)
        let pos = board.harbours.filter { $0.kind == .any }.compactMap { h in ring.firstIndex(of: h.edge) }.sorted()
        for (k, p) in pos.enumerated() {
            let q = pos[(k + 1) % pos.count]
            if pos.count > 1 && (q - p + ring.count) % ring.count == 1 { out.append("3:1 harbours are adjacent on the coast") }
        }
        return out
    }
}
