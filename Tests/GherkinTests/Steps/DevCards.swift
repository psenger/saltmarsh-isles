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
    func rowFor(_ w: World, _ type: DevCardType) -> DevCardRow? { w.screen.devCards.first { $0.type == type } }
    /// The row for the card a step gave or drew last; the hand is grouped by type, so it need not be the last row.
    func givenRow(_ w: World) -> DevCardRow? {
        w.state.players[w.state.current].devCards.last.flatMap { rowFor(w, $0.type) }
    }
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
        guard let row = givenRow(w) else { throw StepError.failed("no card row") }
        try expectEqual(row.playEnabled, false, "Play on \(row.name)")
    }
    r.then(#"the card notes "([^"]*)""#) { w, c, _ in try expectEqual(givenRow(w)?.note ?? "", c[0], "card note") }
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
    r.then(#"the (.+) tile reads "([^"]*)""#) { w, c, _ in
        try expectEqual(Strings.ready, c[1], "ready label")
        let row = rowFor(w, card(c[0]))
        try expectTrue(row?.note == nil && row?.playEnabled == true, "the \(c[0]) tile is not ready to play")
    }
    r.then(#"the Victory point tile shows "([^"]*)""#) { w, c, _ in
        try expectEqual(Strings.plusOnePoint, c[0], "point badge")
        try expectTrue(rowFor(w, .victoryPoint) != nil, "no Victory point tile")
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
    r.given(#"(\w+) also holds a (.+) bought on an earlier turn"#) { w, c, _ in give(w, w.seat(c[0]), card(c[1]), turn: -1) }
    r.given(#"(\w+) holds one of each development card"#) { w, c, _ in
        for type in DevCardType.allCases { give(w, w.seat(c[0]), type, turn: -1) }
    }
    r.given(#"(\w+) holds (\d+) (.+) cards and (\d+) (.+)"#) { w, c, _ in
        for _ in 0..<Int(c[1])! { give(w, w.seat(c[0]), card(c[2]), turn: -1) }
        for _ in 0..<Int(c[3])! { give(w, w.seat(c[0]), card(c[4]), turn: -1) }
    }
    r.then(#"the cards read:"#) { w, _, table in
        guard let table else { throw StepError.failed("no table") }
        let rows = w.screen.devCards
        try expectEqual(rows.map(\.name), table.dropFirst().map { $0[0] }, "card names")
        try expectEqual(rows.map(\.text), table.dropFirst().map { $0[1] }, "card texts")
    }
    r.then(#"(\w+)'s hand shows one (.+) tile holding (\d+) cards"#) { w, c, _ in
        let rows = w.screen.devCards.filter { $0.type == card(c[1]) }
        try expectEqual(rows.count, 1, "\(c[1]) tiles")
        try expectEqual(rows.first?.count, Int(c[2])!, "cards on the \(c[1]) tile")
    }
    r.then(#"the (.+) tile has no note"#) { w, c, _ in
        guard let row = rowFor(w, card(c[0])) else { throw StepError.failed("no \(c[0]) tile") }
        try expectEqual(row.note, nil, "note on the \(c[0]) tile")
    }
    r.when(#"(\w+) taps "Play" on the (.+) tile"#) { w, c, _ in
        guard let row = rowFor(w, card(c[1])) else { throw StepError.failed("no \(c[1]) tile") }
        w.vm.playCard(row.index)
    }
    r.then(#"(\w+) still holds the (.+) bought this turn"#) { w, c, _ in
        let held = w.state.players[w.seat(c[0])].devCards.filter { $0.type == card(c[1]) }
        try expectEqual(held.map(\.boughtOnTurn), [w.state.turn], "\(c[1]) cards left")
    }
    r.when(#"(\w+)'s turn comes round again"#) { w, c, _ in
        w.mutate { s in
            s.turn += s.playerCount
            s.current = w.seat(c[0])
            s.dice = nil
            s.devCardPlayedThisTurn = false
            s.phase = .awaitingRoll
        }
    }
    r.then(#"the played pills read "([^"]*)""#) { w, c, _ in
        try expectEqual(w.screen.playedPills.joined(separator: ", "), c[0], "played pills")
    }
    r.given(#"a game saved before played cards were recorded, in which (\w+) has played (\d+) Knights"#) { w, c, _ in
        w.mutate { s in
            for i in s.players.indices { s.players[i].cardsPlayed = nil }
            s.players[w.seat(c[0])].knightsPlayed = Int(c[1])!
        }
    }
    r.then(#"the played line is labelled "([^"]*)""#) { w, c, _ in
        try expectEqual(Strings.played, c[0], "played label")
        try expectTrue(!w.screen.playedPills.isEmpty, "no played line")
    }
    r.then(#"beside it the hint reads "([^"]*)""#) { _, c, _ in try expectEqual(Strings.oneCardPerTurnHint, c[0], "heading hint") }
    r.then(#"the hand reads "([^"]*)""#) { w, c, _ in
        try expectEqual(Strings.noCardsYet, c[0], "empty hand")
        try expectTrue(w.screen.devCards.isEmpty, "the hand is not empty")
    }
    r.then(#"the hand heading reads "([^"]*)""#) { w, c, _ in try expectEqual(w.screen.handHeading, c[0], "hand heading") }
    r.then(#"(\w+) and (\w+) hold 0 (\w+)"#) { w, c, _ in
        for name in [c[0], c[1]] { try expectEqual(w.state.players[w.seat(name)].hand[Resource(rawValue: c[2])!], 0, "\(name)'s \(c[2])") }
    }
}
