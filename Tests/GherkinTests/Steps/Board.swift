import Foundation
import SaltmarshEngine
import SaltmarshTestSupport
@testable import SaltmarshGame

/// Rule: The board is generated fairly
@MainActor
func registerBoard(_ r: StepRegistry) {
    r.then(#"the board has 19 tiles, 54 corners, 72 edges and 30 coastal edges"#) { w, _, _ in
        let b = w.state.board
        try expectEqual([b.tiles.count, b.corners.count, b.edges.count, b.edges.filter(\.isCoastal).count], [19, 54, 72, 30], "board counts")
    }
    r.then(#"the centre tile is the desert labelled "DUNES" with no number"#) { w, _, _ in
        let b = w.state.board, d = b.tiles[b.desertTile]
        try expectTrue(abs(d.center.x) < 0.001 && abs(d.center.y) < 0.001, "desert is not at the centre")
        try expectTrue(d.terrain == .desert && d.number == nil, "centre tile is not a numberless desert")
        try expectTrue(w.screen.desertLabelBelowRobber, "desert label not marked")
    }
    r.then(#"the robber starts on the desert"#) { w, _, _ in try expectEqual(w.state.robberTile, w.state.board.desertTile, "robber tile") }
    r.then(#"the 18 land tiles are 4 timber, 3 clay, 4 wool, 4 grain and 3 ore"#) { w, _, _ in
        let res = w.state.board.tiles.compactMap(\.resource)
        try expectEqual(Resource.allCases.map { r in res.filter { $0 == r }.count }, [4, 3, 4, 4, 3], "resource mix")
    }
    r.then(#"the number discs are (.+)"#) { w, c, _ in
        try expectEqual(w.state.board.tiles.compactMap(\.number).sorted(), c[0].components(separatedBy: ", ").map { Int($0)! }, "numbers")
    }
    r.then(#"each number disc shows dots equal to its pips"#) { w, _, _ in
        for t in w.state.board.tiles { if let n = t.number { try expectEqual(t.pips, 6 - abs(7 - n), "pips of \(n)") } }
    }
    r.then(#"the number discs 6 and 8 are marked hot"#) { w, _, _ in try expectEqual(w.screen.hotNumbers, [6, 8], "hot numbers") }

    r.when(#"(\d+) boards are generated"#) { w, c, _ in
        w.boards = (0..<Int(c[0])!).map { seed in var rng = SeededRNG(seed: UInt64(seed)); return BoardGenerator.generate(using: &rng) }
    }
    r.then(#"on every board (.+)"#) { w, c, _ in
        let check: (Board) -> Bool
        switch c[0] {
        case "no two tiles of the same resource are neighbours":
            check = { b in !b.tiles.enumerated().contains { i, t in t.resource != nil && t.neighbours.contains { b.tiles[$0].resource == t.resource } } }
        case "no 6 or 8 neighbours another 6 or 8":
            check = { b in !b.tiles.contains { t in [6, 8].contains(t.number ?? 0) && t.neighbours.contains { [6, 8].contains(b.tiles[$0].number ?? 0) } } }
        case "no number neighbours the same number":
            check = { b in !b.tiles.contains { t in t.number != nil && t.neighbours.contains { b.tiles[$0].number == t.number } } }
        case "no corner touches more than 11 pips":
            check = { b in !b.corners.contains { c in c.tiles.reduce(0) { $0 + b.tiles[$1].pips } > 11 } }
        case "each resource's pip total is within 3 of its fair share of 58 / 18":
            check = { b in
                Resource.allCases.allSatisfy { r in
                    let tiles = b.tiles.filter { $0.resource == r }
                    return abs(Double(tiles.reduce(0) { $0 + $1.pips }) - Double(tiles.count) * 58 / 18) <= 3
                }
            }
        default:
            throw StepError.failed("unknown balancing rule: \(c[0])")
        }
        for (i, b) in w.boards.enumerated() { try expectTrue(check(b), "board \(i) breaks: \(c[0])") }
    }

    r.then(#"there are 9 harbours on coastal edges"#) { w, _, _ in
        let b = w.state.board
        try expectEqual(b.harbours.count, 9, "harbour count")
        try expectTrue(b.harbours.allSatisfy { b.edges[$0.edge].isCoastal }, "a harbour is not on a coastal edge")
    }
    r.then(#"4 harbours trade at 3:1 and there is one 2:1 harbour for each resource"#) { w, _, _ in
        let hs = w.state.board.harbours
        try expectEqual(hs.filter { $0.kind == .any && $0.ratio == 3 }.count, 4, "3:1 harbours")
        for res in Resource.allCases { try expectEqual(hs.filter { $0.kind == .specific(res) && $0.ratio == 2 }.count, 1, "2:1 \(res) harbours") }
    }
    r.then(#"no two 3:1 harbours are neighbours around the coast"#) { w, _, _ in
        let b = w.state.board
        func angle(_ e: Int) -> Double {
            let p = b.corners[b.edges[e].a].point, q = b.corners[b.edges[e].b].point
            return atan2((p.y + q.y) / 2, (p.x + q.x) / 2)
        }
        let ring = b.edges.indices.filter { b.edges[$0].isCoastal }.sorted { angle($0) < angle($1) }
        let ordered = b.harbours.sorted { ring.firstIndex(of: $0.edge)! < ring.firstIndex(of: $1.edge)! }
        for i in ordered.indices {
            let next = ordered[(i + 1) % ordered.count]
            try expectTrue(!(ordered[i].kind == .any && next.kind == .any), "two 3:1 harbours are neighbours")
        }
    }
    r.then(#"each harbour is joined by jetties to the 2 corners of its edge"#) { w, _, _ in
        let b = w.state.board
        for h in b.harbours { try expectEqual(Set([h.a, h.b]), Set([b.edges[h.edge].a, b.edges[h.edge].b]), "harbour corners") }
    }
}
