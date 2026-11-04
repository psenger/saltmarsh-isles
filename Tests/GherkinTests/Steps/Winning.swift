import Foundation
import SaltmarshEngine
import SaltmarshTestSupport
@testable import SaltmarshGame

/// Rules: Winning; Victory screen
@MainActor
func registerWinning(_ r: StepRegistry) {
    /// Crimson at `points` (8 or 9) with a reachable settlement spot remembered, in the main phase.
    func crimson(at points: Int, _ w: World) {
        var s = TestGames.rolled(8); s.clearBoard(); s.clearHands()
        let (settlements, cities) = points == 9 ? (3, 3) : (4, 2)
        let spots = s.spreadCorners(settlements + cities)
        for c in spots.prefix(settlements) { s.place(settlement: c, owner: 0) }
        for c in spots.dropFirst(settlements) { s.place(city: c, owner: 0) }
        w.rememberedCorner = s.addReach(from: spots[0], owner: 0)
        w.load(s)
        precondition(Engine.publicPoints(w.state, player: 0) == points)
    }

    r.given(#"Crimson has (\d) points"#) { w, c, _ in crimson(at: Int(c[0])!, w) }
    r.when(#"Crimson builds a settlement"#) { w, _, _ in
        w.set(hand: Cost.settlement, for: 0)
        w.vm.toggleBuildMode(.settlement)
        w.vm.tapCorner(w.rememberedCorner!)
    }
    r.when(#"Crimson builds a city"#) { w, _, _ in
        w.set(hand: Cost.city, for: 0)
        w.vm.toggleBuildMode(.city)
        guard let corner = w.screen.pulsingSettlements.min() else { throw StepError.failed("no settlement to upgrade") }
        w.vm.tapCorner(corner)
    }
    r.when(#"Crimson builds a road that takes longest road"#) { w, _, _ in
        w.used.formUnion(w.blockedCorners)
        var s = w.state
        let chain = s.chain(from: w.rememberedCorner!, length: 3, avoiding: &w.used)
        s.placeChain(Array(chain.prefix(2)), owner: 0)
        s.set(hand: Cost.road, for: 0)
        w.load(s)
        w.vm.toggleBuildMode(.road)
        w.vm.tapEdge(chain[2])
    }
    r.when(#"Crimson plays a third Knight and takes largest army"#) { w, _, _ in
        w.mutate { s in s.players[0].knightsPlayed = 2; s.players[0].devCards = [DevCard(type: .knight, boughtOnTurn: -1)] }
        w.vm.playCard(0)
    }
    r.when(#"Crimson buys a victory point card"#) { w, _, _ in
        w.set(hand: Cost.devCard, for: 0)
        w.mutate { s in s.devDeck[s.devDeck.count - 1] = .victoryPoint }
        w.vm.buyCard()
    }
    r.then(#"(\w+) wins"#) { w, c, _ in try expectEqual(w.state.phase, .gameOver(winner: w.seat(c[0])), "phase") }
    r.given(#"Crimson has 8 public points and 2 victory point cards"#) { w, _, _ in
        crimson(at: 8, w)
        w.mutate { s in s.players[0].devCards = [DevCard(type: .victoryPoint, boughtOnTurn: 0), DevCard(type: .victoryPoint, boughtOnTurn: 0)] }
    }
    r.when(#"the win check runs on Crimson's turn"#) { w, _, _ in
        w.mutate { s in s.current = 2; s.phase = .main }
        w.vm.endTurn()
    }
    r.then(#"the banner reads "([^"]*)""#) { w, c, _ in try expectEqual(w.screen.victory?.banner ?? "(no card)", c[0], "banner") }
    r.given(#"Crimson has 8 points and a 6-segment road"#) { w, _, _ in
        crimson(at: 8, w)
        w.rememberedChain = w.layChain(length: 6, owner: 0)
    }
    r.given(#"Amber holds longest road with a 7-segment road"#) { w, _, _ in
        w.rememberedChain = w.layChain(length: 7, owner: 2) { w.state.board.corners[$0].edges.count == 3 }
        try expectEqual(w.state.longestRoadHolder, 2, "longest road holder")
        try expectEqual(Engine.totalPoints(w.state, player: 0), 8, "Crimson's points")
    }
    r.given(#"it is (\w+)'s turn"#) { w, c, _ in w.mutate { s in s.current = w.seat(c[0]); s.phase = .main; s.dice = [4, 4] } }
    r.when(#"Cobalt builds a settlement that cuts Amber's road below 6"#) { w, _, _ in
        let amber = w.rememberedChain, b = w.state.board
        let inner = (1..<5).map { w.junction(amber[$0], amber[$0 + 1]) }
        guard let m = inner.first(where: { b.corners[$0].edges.count == 3 }), let spur = b.corners[m].edges.first(where: { b.edges[$0].owner == nil }) else {
            throw StepError.failed("no inner corner with a free edge on Amber's road")
        }
        w.mutate { s in s.place(road: spur, owner: 1) }
        w.set(hand: Cost.settlement, for: 1)
        w.vm.toggleBuildMode(.settlement)
        w.vm.tapCorner(m)
        try expectEqual(w.state.board.corners[m].owner, 1, "Cobalt's cutting settlement")
    }
    r.then(#"Crimson holds longest road and has 10 points"#) { w, _, _ in
        try expectEqual(w.state.longestRoadHolder, 0, "longest road holder")
        try expectEqual(Engine.totalPoints(w.state, player: 0), 10, "Crimson's points")
    }
    r.then(#"Crimson has not won yet, because it is Cobalt's turn"#) { w, _, _ in
        if case .gameOver = w.state.phase { throw StepError.failed("the game ended on Cobalt's turn") }
        try expectEqual(w.state.current, 1, "current seat")
    }
    r.when(#"Cobalt ends the turn"#) { w, _, _ in
        w.vm.endTurn()
        try expectEqual(w.state.current, 2, "current seat")
        if case .gameOver = w.state.phase { throw StepError.failed("the game ended on Amber's turn") }
    }
    r.then(#"Crimson wins at the start of Crimson's turn"#) { w, _, _ in
        w.mutate { s in s.phase = .main }
        w.vm.endTurn()
        try expectEqual(w.state.phase, .gameOver(winner: 0), "phase")
    }
    r.given(#"Crimson has won"#) { w, _, _ in w.crimsonWins() }
    r.then(#"the board stays visible"#) { w, _, _ in try expectEqual(w.screen.board.tiles.count, 19, "board") }

    // Victory screen
    r.when(#"Crimson wins"#) { w, _, _ in w.crimsonWins() }
    r.when(#"a player wins"#) { w, _, _ in w.crimsonWins() }
    r.then(#"the victory card is showing"#) { w, _, _ in try expectTrue(w.screen.victory != nil, "no victory card") }
    r.then(#"the card carries (\w+)'s colour"#) { w, c, _ in try expectEqual(w.screen.victory?.seat, w.state.players[w.seat(c[0])].seat, "card colour") }
    r.then(#"it reads "([^"]*)" and "([^"]*)""#) { w, c, _ in
        try expectEqual(w.screen.victory?.title ?? "", c[0], "card title")
        try expectEqual(w.screen.victory?.winner ?? "", c[1], "card winner")
    }
    r.then(#"it shows "Rules the isles after N rounds\.""#) { w, _, _ in
        let subtitle = w.screen.victory?.subtitle ?? ""
        try expectTrue(subtitle.range(of: #"^Rules the isles after \d+ rounds\.$"#, options: .regularExpression) != nil, "subtitle: \(subtitle)")
    }
    r.then(#"the breakdown lists only sources worth more than 0, then the total"#) { w, _, _ in
        guard let card = w.screen.victory else { throw StepError.failed("no victory card") }
        try expectTrue(!card.breakdown.isEmpty && card.breakdown.allSatisfy { $0.points > 0 }, "a zero row is listed")
        try expectEqual(card.breakdown.reduce(0) { $0 + $1.points }, card.total, "total")
    }
    r.then(#"the confetti schedule has a centre burst, two corner cannons and a second wave 0.55 seconds later"#) { w, _, _ in
        guard let bursts = w.screen.victory?.confetti?.bursts else { throw StepError.failed("no confetti schedule") }
        try expectEqual(bursts.map(\.origin), ["centre", "bottom-left", "bottom-right", "bottom-left", "bottom-right"], "burst origins")
        try expectEqual(bursts.map(\.delay), [0, 0, 0, 0.55, 0.55], "burst delays")
    }
    r.then(#"(\w+)'s settlements and cities are marked as the champion's"#) { w, c, _ in
        let seat = w.seat(c[0]), b = w.state.board
        try expectEqual(w.screen.championCorners, Set(b.corners.indices.filter { b.corners[$0].owner == seat }), "champion corners")
    }
    r.when(#"I tap "See the board""#) { w, _, _ in
        try expectEqual(w.screen.buttons["See the board"] ?? false, true, "See the board")
        w.vm.dismissOverlay()
    }
    r.then(#"the overlay closes"#) { w, _, _ in try expectTrue(w.screen.victory == nil, "overlay still showing") }
    r.then(#"the winner's pieces stay marked as the champion's"#) { w, _, _ in try expectTrue(!w.screen.championCorners.isEmpty, "champion marks gone") }
    r.when(#"I tap "Preview win""#) { w, _, _ in
        try expectEqual(w.screen.buttons["Preview win"] ?? false, true, "Preview win")
        w.rememberedState = w.state
        w.vm.showPreviewWin()
    }
    r.then(#"the overlay reads "([^"]*)" and "([^"]*)""#) { w, c, _ in
        try expectEqual(w.screen.victory?.title ?? "", c[0], "overlay title")
        try expectEqual(w.screen.victory?.winner ?? "", c[1], "overlay winner")
    }
    r.then(#"it reads "([^"]*)""#) { w, c, _ in try expectEqual(w.screen.victory?.subtitle ?? "", c[0], "overlay subtitle") }
    r.then(#""New game" is not offered"#) { w, _, _ in try expectTrue(!(w.screen.victory?.buttons ?? []).contains("New game"), "New game is offered") }
    r.when(#"I tap "Back to the game""#) { w, _, _ in
        try expectEqual(w.screen.buttons["Back to the game"] ?? false, true, "Back to the game")
        w.vm.dismissOverlay()
    }
    r.then(#"the overlay closes and the game continues unchanged"#) { w, _, _ in
        try expectTrue(w.screen.victory == nil, "overlay still showing")
        try expectTrue(w.state == w.rememberedState, "the game changed")
    }
    r.given(#"the device has Reduce Motion turned on"#) { w, _, _ in w.vm.reduceMotion = true }
    r.then(#"the victory card appears without confetti or animation"#) { w, _, _ in
        try expectTrue(w.screen.victory != nil, "no victory card")
        try expectTrue(w.screen.victory?.confetti == nil, "confetti scheduled")
        try expectEqual(w.screen.victoryAnimation, .reduced, "animation mode")
    }
}
