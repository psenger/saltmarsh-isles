import Foundation
import SaltmarshEngine
import SaltmarshTestSupport
@testable import SaltmarshGame

/// Rule: Development cards
@MainActor
func registerDevCards(_ r: StepRegistry) {
    func card(_ name: String) -> DevCardType {
        let lower = name.lowercased()
        if lower.hasPrefix("victory point") { return .victoryPoint }
        return DevCardType.allCases.first { $0.displayName.lowercased() == lower }!
    }
    func roll(_ w: World, _ seat: Int) {
        w.mutate { s in s.current = seat; s.phase = .awaitingRoll; s.force(roll: 8) }
        w.vm.rollDice()
    }
    func give(_ w: World, _ seat: Int, _ type: DevCardType, turn: Int) {
        w.mutate { s in s.players[seat].devCards.append(DevCard(type: type, boughtOnTurn: turn)) }
    }
    func rowFor(_ w: World, _ type: DevCardType) -> DevCardRow? { w.screen.devCards.first { $0.name == type.displayName } }
    func indexOf(_ w: World, _ type: DevCardType) -> Int { w.state.players[w.state.current].devCards.firstIndex { $0.type == type }! }
    /// A Cobalt settlement with cards on the chosen tile, then the robber moves there and Crimson steals.
    func moveAndSteal(_ w: World) {
        let t = w.state.board.tiles.indices.first { $0 != w.state.robberTile && w.state.board.tiles[$0].number == 8 }!
        w.mutate { s in s.place(settlement: s.board.tiles[t].corners[0], owner: 1) }
        w.set(hand: .uniform(1), for: 1)
        w.vm.tapTile(t)
        w.vm.steal(from: 1)
    }

    r.when(#"(\w+) taps "Buy a card""#) { w, c, _ in
        w.rememberedHands = w.state.players.map(\.hand)
        w.rememberedDeckCount = w.state.devDeck.count
        w.rememberedPoints = w.state.players[w.seat(c[0])].devCards.count
        try expectEqual(w.screen.buttons["Buy a card"] ?? false, true, "Buy a card")
        w.vm.buyCard()
    }
    r.then(#"(\w+) gains 1 development card"#) { w, c, _ in
        try expectEqual(w.state.players[w.seat(c[0])].devCards.count, w.rememberedPoints + 1, "development cards")
    }
    r.then(#"the deck count on the button drops by 1"#) { w, _, _ in
        try expectEqual(w.screen.deckCount, w.rememberedDeckCount - 1, "deck count")
    }
    r.given(#"(\w+) cannot afford wool, grain and ore"#) { w, c, _ in
        roll(w, w.seat(c[0]))
        w.set(hand: [:], for: w.seat(c[0]))
    }
    r.given(#"the deck is empty"#) { w, _, _ in
        roll(w, 0)
        w.set(hand: Cost.devCard, for: 0)
        w.mutate { s in s.devDeck = [] }
    }
    r.given(#"(\w+) bought a (.+) this turn"#) { w, c, _ in
        roll(w, w.seat(c[0]))
        give(w, w.seat(c[0]), card(c[1]), turn: w.state.turn)
    }
    r.then(#"that card's "Play" button is disabled"#) { w, _, _ in
        guard let row = w.screen.devCards.last else { throw StepError.failed("no card row") }
        try expectEqual(row.playEnabled, false, "Play on \(row.name)")
    }
    r.then(#"the card notes "([^"]*)""#) { w, c, _ in try expectEqual(w.screen.devCards.last?.note ?? "", c[0], "card note") }
    r.given(#"(\w+) has played a development card this turn"#) { w, c, _ in
        roll(w, w.seat(c[0]))
        give(w, w.seat(c[0]), .knight, turn: -1)
        give(w, w.seat(c[0]), .roadCrew, turn: -1)
        w.mutate { s in s.devCardPlayedThisTurn = true }
    }
    r.then(#"every other card's "Play" button is disabled"#) { w, _, _ in
        try expectTrue(!w.screen.devCards.isEmpty && w.screen.devCards.allSatisfy { !$0.playEnabled }, "a Play button is enabled")
    }
    r.then(#"those cards note "([^"]*)""#) { w, c, _ in try expectTrue(w.screen.devCards.allSatisfy { $0.note == c[0] }, "a card has another note") }
    r.given(#"(\w+) has not rolled and holds a (.+) bought on an earlier turn"#) { w, c, _ in
        w.mutate { s in s.current = w.seat(c[0]); s.phase = .awaitingRoll; s.dice = nil }
        give(w, w.seat(c[0]), card(c[1]), turn: -1)
    }
    r.given(#"(\w+) has not rolled and holds a playable (.+)"#) { w, c, _ in
        w.mutate { s in s.current = w.seat(c[0]); s.phase = .awaitingRoll; s.dice = nil }
        give(w, w.seat(c[0]), card(c[1]), turn: -1)
    }
    r.given(#"(\w+) has rolled and holds a playable (.+)"#) { w, c, _ in
        w.ensureCrimsonBase()
        roll(w, w.seat(c[0]))
        give(w, w.seat(c[0]), card(c[1]), turn: -1)
    }
    r.then(#"that Knight's "Play" button is enabled"#) { w, _, _ in try expectEqual(rowFor(w, .knight)?.playEnabled, true, "Play on the Knight") }
    r.when(#"(\w+) taps "Play" on the Knight"#) { w, c, _ in
        w.rememberedPoints = w.state.players[w.seat(c[0])].knightsPlayed
        w.vm.playCard(indexOf(w, .knight))
    }
    r.then(#"the Knight leaves (\w+)'s cards"#) { w, c, _ in
        try expectTrue(!w.state.players[w.seat(c[0])].devCards.contains { $0.type == .knight }, "the Knight is still held")
    }
    r.then(#"(\w+)'s "Knights" badge increases by 1"#) { w, c, _ in
        try expectEqual(w.screen.scoreboard[w.seat(c[0])].knights, w.rememberedPoints + 1, "Knights badge")
    }
    r.then(#"no discard step happens"#) { w, _, _ in
        if case .discarding = w.state.phase { throw StepError.failed("a discard step started") }
    }
    r.when(#"(\w+) moves the robber and steals"#) { w, _, _ in moveAndSteal(w) }
    r.when(#"(\w+) plays the Knight, moves the robber and steals"#) { w, _, _ in
        w.vm.playCard(indexOf(w, .knight))
        moveAndSteal(w)
    }
    r.given(#"(\w+) draws a victory point card"#) { w, c, _ in
        roll(w, w.seat(c[0]))
        give(w, w.seat(c[0]), .victoryPoint, turn: w.state.turn)
    }
    r.then(#"the card shows "counts automatically" and has no "Play" button"#) { w, _, _ in
        let row = rowFor(w, .victoryPoint)
        try expectEqual(row?.note ?? "", "counts automatically", "note")
        try expectEqual(row?.playEnabled, false, "Play on a victory point card")
    }
    r.then(#"(\w+)'s score shows "\+1" only while it is \w+'s turn"#) { w, c, _ in
        let seat = w.seat(c[0])
        try expectEqual(w.screen.scoreboard[seat].hidden, "+1", "hidden points on \(c[0])'s turn")
        w.mutate { s in s.current = (seat + 1) % s.playerCount }
        try expectEqual(w.screen.scoreboard[seat].hidden, nil, "hidden points on another turn")
    }
    r.then(#"other players' views do not show (\w+)'s hidden point"#) { w, c, _ in
        let seat = w.seat(c[0])
        let view = Engine.view(w.state, for: (seat + 1) % w.state.playerCount)
        try expectTrue(view.opponents.first { $0.index == seat }?.devCardCount == 1, "card count missing")
        try expectEqual(w.screen.scoreboard[seat].hidden, nil, "hidden points shown to others")
    }
    r.when(#"(\w+) taps "Play" on it"#) { w, c, _ in
        let index = w.state.players[w.seat(c[0])].devCards.firstIndex { $0.type != .victoryPoint }!
        w.vm.playCard(index)
    }
    r.then(#"building, trading and ending the turn are disabled"#) { w, _, _ in
        for b in ["Road", "Settlement", "City", "Buy a card", "Trade 4 for 1", "Offer", "End turn"] {
            try expectEqual(w.screen.buttons[b] ?? false, false, "button \(b)")
        }
    }
    r.when(#"(\w+) taps 2 dashed edges"#) { w, c, _ in
        w.rememberedHands = w.state.players.map(\.hand)
        w.rememberedPoints = w.state.roads(of: w.seat(c[0]))
        for _ in 0..<2 {
            guard let edge = w.screen.dashedEdges.min() else { throw StepError.failed("no dashed edge") }
            w.vm.tapEdge(edge)
        }
    }
    r.then(#"2 (\w+) roads are placed without paying"#) { w, c, _ in
        let seat = w.seat(c[0])
        try expectEqual(w.state.roads(of: seat), w.rememberedPoints + 2, "roads")
        try expectEqual(w.state.players[seat].hand, w.rememberedHands[seat], "hand")
    }
    r.given(#"(\w+) has no legal edge to build on"#) { w, c, _ in
        roll(w, w.seat(c[0]))
        w.mutate { s in
            s.clearBoard()
            s.place(settlement: 0, owner: 0)
            for e in s.board.corners[0].edges { s.place(road: e, owner: 1) }
        }
        give(w, w.seat(c[0]), .roadCrew, turn: -1)
    }
    r.when(#"(\w+) plays Road crew"#) { w, _, _ in w.vm.playCard(indexOf(w, .roadCrew)) }
    r.when(#"(\w+) chooses (\w+) and (\w+) and taps "Play""#) { w, c, _ in
        w.rememberedHands = w.state.players.map(\.hand)
        w.vm.playCard(indexOf(w, .bumperHarvest), bumper: (Resource(rawValue: c[1])!, Resource(rawValue: c[2])!))
    }
    r.then(#"(\w+) gains (\#(resList))"#) { w, c, _ in
        let seat = w.seat(c[0])
        try expectEqual(w.state.players[seat].hand - w.rememberedHands[seat], World.resources(c[1]), "\(c[0]) gained")
    }
    r.when(#"(\w+) chooses (\w+) and taps "Play""#) { w, c, _ in
        w.rememberedHands = w.state.players.map(\.hand)
        w.vm.playCard(indexOf(w, .cornerMarket), market: Resource(rawValue: c[1])!)
    }
    r.then(#"(\w+) and (\w+) hold 0 (\w+)"#) { w, c, _ in
        for name in [c[0], c[1]] { try expectEqual(w.state.players[w.seat(name)].hand[Resource(rawValue: c[2])!], 0, "\(name)'s \(c[2])") }
    }
}
