import Foundation
import SaltmarshEngine
import SaltmarshTestSupport
@testable import SaltmarshGame

/// Rules: Longest road; Largest army; Scoreboard
@MainActor
func registerAwards(_ r: StepRegistry) {
    func toMain(_ w: World, seat: Int) {
        w.mutate { s in s.current = seat; s.phase = .main; s.dice = [4, 4] }
    }

    // Longest road
    r.when(#"(\w+)'s longest continuous road reaches 5 segments and nobody holds the award"#) { w, c, _ in
        let seat = w.seat(c[0])
        toMain(w, seat: seat)
        w.rememberedPoints = Engine.publicPoints(w.state, player: seat)
        w.used.formUnion(w.blockedCorners)
        var s = w.state
        let chain = s.firstChain(length: 5, avoiding: &w.used)
        s.placeChain(Array(chain.prefix(4)), owner: seat)
        s.set(hand: Cost.road, for: seat)
        w.load(s)
        try w.vm.apply(.placeRoad(edge: chain[4]))
    }
    r.then(#"([A-Z]\w+) holds longest road"#) { w, c, _ in try expectEqual(w.state.longestRoadHolder, w.seat(c[0]), "longest road holder") }
    r.then(#"(\w+) still holds longest road"#) { w, c, _ in try expectEqual(w.state.longestRoadHolder, w.seat(c[0]), "longest road holder") }
    r.then(#"nobody holds longest road"#) { w, _, _ in try expectEqual(w.state.longestRoadHolder, nil, "longest road holder") }
    r.then(#"(\w+)'s "Road" badge is highlighted"#) { w, c, _ in try expectTrue(w.screen.scoreboard[w.seat(c[0])].roadHighlighted, "Road badge not highlighted") }
    r.then(#"(\w+)'s "Road" badge shows (\d+)"#) { w, c, _ in try expectEqual(w.screen.scoreboard[w.seat(c[0])].road, Int(c[1])!, "Road badge") }
    r.then(#"(\w+) gains (\d+) points"#) { w, c, _ in
        try expectEqual(Engine.publicPoints(w.state, player: w.seat(c[0])) - w.rememberedPoints, Int(c[1])!, "points gained")
    }
    r.then(#"(\w+) loses (\d+) points"#) { w, c, _ in
        try expectEqual(w.rememberedPoints - Engine.publicPoints(w.state, player: w.seat(c[0])), Int(c[1])!, "points lost")
    }
    r.given(#"(\w+) has 3 roads meeting at one corner in a Y shape"#) { w, c, _ in
        let seat = w.seat(c[0])
        let corner = w.state.board.corners.indices.first { w.state.board.corners[$0].edges.count == 3 }!
        w.mutate { s in for e in s.board.corners[corner].edges { s.place(road: e, owner: seat) } }
    }
    r.given(#"(\w+) holds longest road with (?:6 segments|a 6-segment road)"#) { w, c, _ in
        let seat = w.seat(c[0])
        w.rememberedChain = w.layChain(length: 6, owner: seat)
        try expectEqual(w.state.longestRoadHolder, seat, "longest road holder")
        w.rememberedPoints = Engine.publicPoints(w.state, player: seat)
    }
    r.given(#"([A-Z]\w+) holds longest road"#) { w, c, _ in
        let seat = w.seat(c[0])
        w.rememberedChain = w.layChain(length: 6, owner: seat)
        try expectEqual(w.state.longestRoadHolder, seat, "longest road holder")
    }
    r.when(#"(\w+)'s road reaches (\d+) segments"#) { w, c, _ in w.layChain(length: Int(c[1])!, owner: w.seat(c[0])) }
    r.when(#"(\w+) builds a settlement in the middle of it, leaving 3 and 3"#) { w, c, _ in
        let middle = w.junction(w.rememberedChain[2], w.rememberedChain[3])
        w.mutate { s in s.place(settlement: middle, owner: w.seat(c[0])); Engine.updateAwards(&s) }
    }
    r.given(#"(\w+) and (\w+) both have 6-segment roads"#) { w, c, _ in
        w.layChain(length: 6, owner: w.seat(c[0]))
        w.layChain(length: 6, owner: w.seat(c[1]))
    }
    r.when(#"(\w+)'s road is cut below 6"#) { w, c, _ in
        let middle = w.junction(w.rememberedChain[2], w.rememberedChain[3])
        w.mutate { s in s.place(settlement: middle, owner: 1); Engine.updateAwards(&s) }
        try expectTrue(Engine.roadLength(w.state, player: w.seat(c[0])) < 6, "road not cut")
    }

    // Largest army
    r.when(#"(\w+) plays a third Knight and nobody holds the award"#) { w, c, _ in
        let seat = w.seat(c[0])
        toMain(w, seat: seat)
        w.mutate { s in s.players[seat].knightsPlayed = 2; s.players[seat].devCards = [DevCard(type: .knight, boughtOnTurn: -1)] }
        w.rememberedPoints = Engine.publicPoints(w.state, player: seat)
        w.vm.playCard(0)
    }
    r.then(#"(\w+) holds largest army"#) { w, c, _ in try expectEqual(w.state.largestArmyHolder, w.seat(c[0]), "largest army holder") }
    r.then(#"(\w+) still holds largest army"#) { w, c, _ in try expectEqual(w.state.largestArmyHolder, w.seat(c[0]), "largest army holder") }
    r.then(#"(\w+)'s "Knights" badge is highlighted"#) { w, c, _ in try expectTrue(w.screen.scoreboard[w.seat(c[0])].knightsHighlighted, "Knights badge not highlighted") }
    r.given(#"(\w+) holds largest army with 3 Knights"#) { w, c, _ in
        let seat = w.seat(c[0])
        w.mutate { s in s.players[seat].knightsPlayed = 3; Engine.updateAwards(&s) }
        try expectEqual(w.state.largestArmyHolder, seat, "largest army holder")
    }
    r.when(#"(\w+) plays a (third|fourth) Knight"#) { w, c, _ in
        let seat = w.seat(c[0])
        toMain(w, seat: seat)
        w.mutate { s in s.players[seat].knightsPlayed = c[1] == "third" ? 2 : 3; s.players[seat].devCards = [DevCard(type: .knight, boughtOnTurn: -1)] }
        w.vm.playCard(0)
    }

    // Scoreboard
    r.then(#"each player row shows their colour, name, card count and development card count"#) { w, _, _ in
        for (i, row) in w.screen.scoreboard.enumerated() {
            let p = w.state.players[i]
            try expectEqual([row.colorHex, row.name], [p.seat.colorHex, p.name], "row \(i) colour and name")
            try expectEqual([row.cards, row.devCards], [p.hand.total, p.devCards.count], "row \(i) card counts")
        }
    }
    r.then(#"a "Road N" badge with their longest road length"#) { w, _, _ in
        for (i, row) in w.screen.scoreboard.enumerated() { try expectEqual(row.road, Engine.roadLength(w.state, player: i), "row \(i) road") }
    }
    r.then(#"a "Knights N" badge with their Knights played"#) { w, _, _ in
        for (i, row) in w.screen.scoreboard.enumerated() { try expectEqual(row.knights, w.state.players[i].knightsPlayed, "row \(i) knights") }
    }
    r.then(#"a score "N / 10" counting buildings and awards only"#) { w, _, _ in
        for (i, row) in w.screen.scoreboard.enumerated() { try expectEqual(row.score, "\(Engine.publicPoints(w.state, player: i)) / 10", "row \(i) score") }
    }
    r.then(#"a "\+N" for hidden victory points, shown only on the current player's row"#) { w, _, _ in
        w.mutate { s in
            s.players[0].devCards = [DevCard(type: .victoryPoint, boughtOnTurn: 0)]
            s.players[1].devCards = [DevCard(type: .victoryPoint, boughtOnTurn: 0)]
            s.current = 0
        }
        try expectEqual(w.screen.scoreboard.map(\.hidden), ["+1", nil, nil], "hidden points column")
    }
}
