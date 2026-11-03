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
}
