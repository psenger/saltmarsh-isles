import Foundation
import SaltmarshEngine
import SaltmarshTestSupport
@testable import SaltmarshGame

/// Rule: Building
@MainActor
func registerBuilding(_ r: StepRegistry) {
    func mode(_ name: String) -> BuildMode {
        switch name {
        case "Road": .road
        case "Settlement": .settlement
        default: .city
        }
    }
    func cost(_ piece: String) -> ResourceCounts {
        switch piece {
        case "road": Cost.road
        case "settlement": Cost.settlement
        default: Cost.city
        }
    }
    /// Crimson's base plus a second road `mid → far`, so a settlement spot exists; returns (e, mid, e2, far).
    func extendBase(_ w: World) -> (Int, Int, Int, Int) {
        w.ensureCrimsonBase()
        let b = w.state.board
        let e = b.corners[0].edges[0], mid = b.edges[e].other(0)
        let e2 = b.corners[mid].edges.first { $0 != e }!
        let far = b.edges[e2].other(mid)
        w.mutate { s in s.place(road: e2, owner: 0) }
        return (e, mid, e2, far)
    }

    r.given(#"(\w+) (can|cannot) afford a (road|settlement|city)"#) { w, c, _ in
        if c[2] == "settlement" { _ = extendBase(w) } else { w.ensureCrimsonBase() }
        w.set(hand: c[1] == "can" ? cost(c[2]) : ResourceCounts(), for: w.seat(c[0]))
    }
    r.when(#"(\w+) taps "(Road|Settlement|City)""#) { w, c, _ in
        w.ensureCrimsonBase()
        w.vm.toggleBuildMode(mode(c[1]))
    }
    r.when(#"(\w+) taps "(Road|Settlement|City)" again"#) { w, c, _ in w.vm.toggleBuildMode(mode(c[1])) }
    r.then(#"the "(Road|Settlement|City)" button is highlighted"#) { w, c, _ in try expectEqual(w.screen.activeBuildMode, mode(c[0]), "active build mode") }
    r.then(#"no build mode is active"#) { w, _, _ in try expectTrue(w.screen.activeBuildMode == nil, "a build mode is active") }

    r.when(#"(\w+) taps "Road" and taps a dashed edge"#) { w, c, _ in
        w.ensureCrimsonBase()
        w.vm.toggleBuildMode(.road)
        guard let edge = w.screen.dashedEdges.min() else { throw StepError.failed("no dashed edge") }
        w.rememberedEdge = edge
        w.rememberedHands = w.state.players.map(\.hand)
        w.vm.tapEdge(edge)
    }
    r.then(#"only edges touching a (\w+) road, settlement or city are dashed"#) { w, c, _ in
        let seat = w.seat(c[0])
        w.ensureCrimsonBase()
        w.set(hand: Cost.road, for: seat)
        w.vm.toggleBuildMode(.road)
        let b = w.state.board
        try expectTrue(!w.screen.dashedEdges.isEmpty, "nothing is dashed")
        for e in w.screen.dashedEdges {
            let touches = [b.edges[e].a, b.edges[e].b].contains { c in b.corners[c].owner == seat || b.corners[c].edges.contains { $0 != e && b.edges[$0].owner == seat } }
            try expectTrue(touches, "edge \(e) is dashed but touches nothing of \(c[0])'s")
        }
    }
    r.given(#"a (\w+) road ends at a corner holding a (\w+) settlement"#) { w, c, _ in
        w.ensureCrimsonBase()
        let b = w.state.board, e = b.corners[0].edges[0], far = b.edges[e].other(0)
        w.mutate { s in s.place(settlement: far, owner: w.seat(c[1])) }
        w.rememberedCorner = far
        w.set(hand: Cost.road, for: w.seat(c[0]))
        w.vm.toggleBuildMode(.road)
    }
    r.then(#"no edge beyond that corner is offered to (\w+) from that road"#) { w, c, _ in
        let far = w.rememberedCorner!, b = w.state.board
        for e in w.screen.dashedEdges { try expectTrue(b.edges[e].a != far && b.edges[e].b != far, "edge \(e) beyond the blocked corner is dashed") }
    }
    r.given(#"a (\w+) road and a (\w+) road meet at an empty corner"#) { w, c, _ in
        w.ensureCrimsonBase()
        let b = w.state.board, e = b.corners[0].edges[0], far = b.edges[e].other(0)
        let other = b.corners[far].edges.first { $0 != e }!
        w.mutate { s in s.place(road: other, owner: w.seat(c[1])) }
        w.rememberedCorner = far
        w.set(hand: Cost.road, for: w.seat(c[0]))
        w.vm.toggleBuildMode(.road)
    }
    r.then(#"(\w+) can still build a road onward from that corner"#) { w, c, _ in
        let far = w.rememberedCorner!, b = w.state.board
        try expectTrue(w.screen.dashedEdges.contains { b.edges[$0].a == far || b.edges[$0].b == far }, "no dashed edge leaves corner \(far)")
    }
    r.when(#"(\w+) taps "Settlement" and taps a glowing corner"#) { w, c, _ in
        _ = extendBase(w)
        w.vm.toggleBuildMode(.settlement)
        guard let corner = w.screen.glowingCorners.min() else { throw StepError.failed("no glowing corner") }
        w.rememberedCorner = corner
        w.rememberedHands = w.state.players.map(\.hand)
        w.vm.tapCorner(corner)
    }
    r.then(#"glowing corners are empty"#) { w, _, _ in
        _ = extendBase(w)
        w.set(hand: Cost.settlement, for: 0)
        w.vm.toggleBuildMode(.settlement)
        try expectTrue(!w.screen.glowingCorners.isEmpty, "nothing glows")
        for c in w.screen.glowingCorners { try expectTrue(w.state.board.corners[c].owner == nil, "corner \(c) glows but is owned") }
    }
    r.then(#"no glowing corner is next to any building"#) { w, _, _ in
        let b = w.state.board
        for c in w.screen.glowingCorners {
            try expectTrue(b.corners[c].adjacent.allSatisfy { b.corners[$0].owner == nil }, "corner \(c) glows next to a building")
        }
    }
    r.then(#"every glowing corner touches a (\w+) road"#) { w, c, _ in
        let b = w.state.board, seat = w.seat(c[0])
        for corner in w.screen.glowingCorners {
            try expectTrue(b.corners[corner].edges.contains { b.edges[$0].owner == seat }, "corner \(corner) glows without a \(c[0]) road")
        }
    }
    r.given(#"a (\w+) road and a (\w+) road both reach an empty corner"#) { w, c, _ in
        // Crimson: 0 -e- mid -e2- far (far has three edges). Cobalt: a road into far from a settlement two segments away.
        w.ensureCrimsonBase()
        let b = w.state.board, e = b.corners[0].edges[0], mid = b.edges[e].other(0)
        let e2 = b.corners[mid].edges.first { $0 != e && b.corners[b.edges[$0].other(mid)].edges.count == 3 }!
        let far = b.edges[e2].other(mid)
        let e3 = b.corners[far].edges.first { $0 != e2 }!, cob = b.edges[e3].other(far)
        let e4 = b.corners[cob].edges.first { $0 != e3 }!, cobHome = b.edges[e4].other(cob)
        let other = w.seat(c[1])
        w.mutate { s in
            s.place(road: e2, owner: 0); s.place(road: e3, owner: other); s.place(road: e4, owner: other); s.place(settlement: cobHome, owner: other)
        }
        w.rememberedCorner = far
        w.set(hand: Cost.settlement, for: 0)
        w.set(hand: Cost.settlement, for: other)
    }
    r.given(#"no building is next to that corner"#) { w, _, _ in
        let far = w.rememberedCorner!, b = w.state.board
        try expectTrue(b.corners[far].adjacent.allSatisfy { b.corners[$0].owner == nil }, "a building is next to corner \(far)")
    }
    r.then(#"both (\w+) and (\w+) may settle there"#) { w, c, _ in
        let far = w.rememberedCorner!
        for name in [c[0], c[1]] { try expectTrue(Engine.canSettle(w.state, corner: far, player: w.seat(name), setup: false), "\(name) cannot settle at \(far)") }
    }
    r.when(#"(\w+) settles there first"#) { w, c, _ in
        w.vm.toggleBuildMode(.settlement)
        w.vm.tapCorner(w.rememberedCorner!)
        try expectEqual(w.state.board.corners[w.rememberedCorner!].owner, w.seat(c[0]), "settlement owner")
    }
    r.then(#"(\w+) can no longer settle there or build a road through it"#) { w, c, _ in
        let far = w.rememberedCorner!, seat = w.seat(c[0]), b = w.state.board
        try expectTrue(!Engine.canSettle(w.state, corner: far, player: seat, setup: false), "\(c[0]) can still settle at \(far)")
        for e in b.corners[far].edges where b.edges[e].owner == nil {
            try expectTrue(!Engine.canRoad(w.state, edge: e, player: seat), "\(c[0]) can still build through corner \(far)")
        }
    }
    r.given(#"each road reaching a corner is one segment from its owner's settlement"#) { w, _, _ in
        let b = w.state.board
        let x = b.corners.indices.first { b.corners[$0].edges.count == 3 }!
        let a = b.corners[x].adjacent[0], bb = b.corners[x].adjacent[1]
        w.mutate { s in
            s.place(settlement: a, owner: 0); s.place(road: s.board.edgeIndex(between: a, x)!, owner: 0)
            s.place(settlement: bb, owner: 1); s.place(road: s.board.edgeIndex(between: bb, x)!, owner: 1)
        }
        w.rememberedCorner = x
        w.set(hand: Cost.settlement, for: 0)
        w.set(hand: Cost.settlement, for: 1)
    }
    r.then(#"that corner does not glow for anyone"#) { w, _, _ in
        let x = w.rememberedCorner!
        for seat in 0..<2 { try expectTrue(!Engine.canSettle(w.state, corner: x, player: seat, setup: false), "seat \(seat) may settle at \(x)") }
        w.vm.toggleBuildMode(.settlement)
        try expectTrue(!w.screen.glowingCorners.contains(x), "corner \(x) glows")
    }
    r.then(#"(\w+)'s settlements are marked pulsing"#) { w, c, _ in
        let seat = w.seat(c[0]), b = w.state.board
        let mine = Set(b.corners.indices.filter { b.corners[$0].owner == seat && !b.corners[$0].isCity })
        try expectEqual(w.screen.pulsingSettlements, mine, "pulsing settlements")
    }
    r.when(#"(\w+) taps one of them"#) { w, c, _ in
        guard let corner = w.screen.pulsingSettlements.min() else { throw StepError.failed("nothing pulses") }
        w.rememberedCorner = corner
        w.rememberedHands = w.state.players.map(\.hand)
        w.vm.tapCorner(corner)
    }
    r.then(#"it becomes a city"#) { w, _, _ in try expectTrue(w.state.board.corners[w.rememberedCorner!].isCity, "corner \(w.rememberedCorner!) is not a city") }
}
