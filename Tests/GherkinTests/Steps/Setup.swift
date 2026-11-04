import Foundation
import SaltmarshEngine
import SaltmarshTestSupport
@testable import SaltmarshGame

/// Rule: Setup uses snake order
@MainActor
func registerSetup(_ r: StepRegistry) {
    r.then(#"players place in the order (.+)"#) { w, c, _ in
        var seen: [String] = []
        while case .setup = w.state.phase {
            seen.append(w.state.players[w.state.current].name)
            try w.vm.apply(Engine.legalMoves(w.state).first!)   // settlement
            try w.vm.apply(Engine.legalMoves(w.state).first!)   // road
        }
        try expectEqual(seen, World.names(c[0]), "placement order")
    }
    r.then(#"after the last placement the log reads "([^"]*)""#) { w, c, _ in try expectEqual(w.state.log.last ?? "", c[0], "last log line") }

    r.given(#"it is (\w+)'s setup step"#) { w, c, _ in
        w.forceFirstRoll(winner: w.seat(c[0]))
        try expectEqual(w.state.current, w.seat(c[0]), "current seat")
    }
    r.given(#"the game is in setup"#) { w, _, _ in w.forceFirstRoll(winner: 0) }
    r.then(#"every corner that obeys the distance rule glows"#) { w, _, _ in
        let legal = Set(w.state.board.corners.indices.filter { Engine.canSettle(w.state, corner: $0, player: w.state.current, setup: true) })
        try expectEqual(w.screen.glowingCorners, legal, "glowing corners")
    }
    r.when(#"(\w+) taps a glowing corner"#) { w, c, _ in
        try expectEqual(w.state.current, w.seat(c[0]), "current seat")
        guard let corner = w.screen.glowingCorners.min() else { throw StepError.failed("no glowing corner") }
        w.rememberedCorner = corner
        w.rememberedHands = w.state.players.map(\.hand)
        w.vm.tapCorner(corner)
    }
    r.then(#"a (\w+) settlement is placed there"#) { w, c, _ in
        let corner = w.state.board.corners[w.rememberedCorner!]
        try expectTrue(corner.owner == w.seat(c[0]) && !corner.isCity, "no \(c[0]) settlement at corner \(w.rememberedCorner!)")
    }
    r.then(#"only edges touching that settlement are dashed"#) { w, _, _ in
        let touching = Set(w.state.board.corners[w.rememberedCorner!].edges.filter { w.state.board.edges[$0].owner == nil })
        try expectEqual(w.screen.dashedEdges, touching, "dashed edges")
    }
    r.given(#"(\w+) has just placed a setup settlement"#) { w, c, _ in
        w.forceFirstRoll(winner: w.seat(c[0]))
        let corner = w.screen.glowingCorners.min()!
        w.rememberedCorner = corner
        w.vm.tapCorner(corner)
    }
    r.when(#"(\w+) taps a dashed edge"#) { w, c, _ in
        try expectEqual(w.state.current, w.seat(c[0]), "current seat")
        guard let edge = w.screen.dashedEdges.min() else { throw StepError.failed("no dashed edge") }
        w.rememberedEdge = edge
        w.rememberedHands = w.state.players.map(\.hand)
        w.vm.tapEdge(edge)
    }
    r.then(#"a (\w+) road is placed there"#) { w, c, _ in
        try expectEqual(w.state.board.edges[w.rememberedEdge!].owner, w.seat(c[0]), "road owner at edge \(w.rememberedEdge!)")
    }
    r.then(#"it becomes the next player's setup step"#) { w, _, _ in
        guard case .setup(_, false, _) = w.state.phase else { throw StepError.failed("not at a settlement step: \(w.state.phase)") }
        try expectEqual(w.state.current, 1, "current seat")
        try expectEqual(w.screen.header, "Cobalt · setup", "header")
    }

    // Starting cards: the chosen corner's three tiles are given the named terrains.
    func settle(_ w: World, touching terrains: [Terrain], player: Int) throws {
        guard let corner = w.screen.glowingCorners.sorted().first(where: { w.state.board.corners[$0].tiles.count == terrains.count }) else {
            throw StepError.failed("no legal corner touching \(terrains.count) tiles")
        }
        w.mutate { s in
            for (t, terrain) in zip(s.board.corners[corner].tiles, terrains) { s.board.tiles[t].terrain = terrain }
        }
        w.rememberedHands = w.state.players.map(\.hand)
        w.vm.tapCorner(corner)
        try expectEqual(w.state.board.corners[corner].owner, player, "settlement placed")
    }
    func terrains(_ list: String) -> [Terrain] {
        World.names(list).map { $0 == "desert" ? Terrain.desert : .land(Resource(rawValue: $0)!) }
    }
    r.given(#"(\w+)'s first setup settlement touches (.+)"#) { w, c, _ in
        w.forceFirstRoll(winner: w.seat(c[0]))
        try settle(w, touching: terrains(c[1]), player: w.seat(c[0]))
    }
    r.then(#"(\w+) holds 0 cards after the first placement"#) { w, c, _ in
        try expectTrue(w.state.players[w.seat(c[0])].hand.isEmpty, "\(c[0]) holds cards after the first placement")
    }
    r.when(#"(\w+)'s second setup settlement touches (.+)"#) { w, c, _ in
        let seat = w.seat(c[0])
        try w.vm.apply(Engine.legalMoves(w.state).first!)                 // the first setup road
        while case .setup(let step, _, _) = w.state.phase, !(w.state.current == seat && step >= w.state.playerCount) {
            try w.vm.apply(Engine.legalMoves(w.state).first!)
        }
        try settle(w, touching: terrains(c[1]), player: seat)
    }
    r.when(#"a player's second setup settlement touches the desert and 2 grain tiles"#) { w, _, _ in
        w.forceFirstRoll(winner: 0)
        while case .setup(let step, _, _) = w.state.phase, !(w.state.current == 0 && step >= w.state.playerCount) {
            try w.vm.apply(Engine.legalMoves(w.state).first!)
        }
        let desert = w.state.board.desertTile
        guard let corner = w.screen.glowingCorners.sorted().first(where: { w.state.board.corners[$0].tiles.contains(desert) && w.state.board.corners[$0].tiles.count == 3 }) else {
            throw StepError.failed("no legal corner on the desert")
        }
        w.mutate { s in for t in s.board.corners[corner].tiles where t != desert { s.board.tiles[t].terrain = .land(.grain) } }
        w.rememberedHands = w.state.players.map(\.hand)
        w.vm.tapCorner(corner)
    }
    r.then(#"that player receives 2 grain only"#) { w, _, _ in try expectEqual(w.state.players[0].hand, [.grain: 2], "hand") }
}
