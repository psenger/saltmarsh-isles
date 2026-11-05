import Foundation
import SaltmarshEngine
import SaltmarshAI
import SaltmarshTestSupport
@testable import SaltmarshGame

/// Rules: Piece limits; Playing against AI seats
@MainActor
func registerNewRules(_ r: StepRegistry) {
    func mode(_ name: String) -> BuildMode {
        switch name {
        case "Road": .road
        case "Settlement": .settlement
        default: .city
        }
    }

    // Piece limits
    r.given(#"Crimson has the 2 settlements and 2 roads from setup on the board"#) { w, _, _ in
        w.afterSetup(clear: false)
        w.mutate { s in s.clearHands(); s.force(roll: 8) }
        w.vm.rollDice()
        try expectEqual([w.state.settlements(of: 0), w.state.roads(of: 0)], [2, 2], "setup pieces")
    }
    r.then(#"the "(Road|Settlement|City)" button costs (\#(resList))"#) { w, c, _ in
        try expectEqual(w.screen.buildCost[mode(c[0])], World.resources(c[1]), "\(c[0]) cost")
    }
    r.then(#"the "Buy a card" button costs (\#(resList))"#) { w, c, _ in
        try expectEqual(w.screen.cardCost, World.resources(c[0]), "card cost")
    }
    r.then(#"the "(Road|Settlement|City)" button shows "(\d+) left""#) { w, c, _ in
        try expectEqual(w.screen.buildLeft[mode(c[0])], Int(c[1])!, "\(c[0]) pieces left")
    }
    r.given(#"Crimson has 5 settlements on the board and can afford a (settlement|city)"#) { w, c, _ in
        w.mutate { s in
            s.clearBoard()
            let spots = s.spreadCorners(5)
            for corner in spots { s.place(settlement: corner, owner: 0) }
            _ = s.addReach(from: spots[0], owner: 0)
        }
        w.set(hand: c[0] == "settlement" ? Cost.settlement : Cost.city, for: 0)
    }
    r.when(#"Crimson upgrades one of them to a city"#) { w, _, _ in
        w.vm.toggleBuildMode(.city)
        guard let corner = w.screen.pulsingSettlements.min() else { throw StepError.failed("no settlement pulses") }
        w.vm.tapCorner(corner)
        try expectTrue(w.state.board.corners[corner].isCity, "no city built")
    }
    r.given(#"Crimson has 14 roads on the board and holds a playable Road crew"#) { w, _, _ in
        w.ensureCrimsonBase()
        w.mutate { s in
            for e in s.board.edges.indices where s.board.edges[e].owner == nil && s.roads(of: 0) < 14 { s.place(road: e, owner: 0) }
            s.players[0].devCards = [DevCard(type: .roadCrew, boughtOnTurn: -1)]
        }
        try expectEqual(w.state.roads(of: 0), 14, "roads on the board")
    }
    r.when(#"Crimson plays Road crew and places one free road"#) { w, _, _ in
        w.vm.playCard(0)
        guard let edge = w.screen.dashedEdges.min() else { throw StepError.failed("no free road offered") }
        w.vm.tapEdge(edge)
    }

    // Playing against AI seats
    func aiGame(_ w: World, _ controllers: [Controller]) async {
        w.newGame(controllers, seed: 7)
        await w.vm.waitForAI()
    }
    r.when(#"I start a 3-player game with Crimson human, Cobalt an AI (\w+) and Amber an AI (\w+)"#) { w, c, _ in
        let levels = Dictionary(uniqueKeysWithValues: EffortLevel.allCases.map { ($0.name, $0) })
        await aiGame(w, [.human, .ai(levels[c[0]]!), .ai(levels[c[1]]!)])
    }
    r.then(#"(\w+) and (\w+) are AI seats"#) { w, c, _ in
        for name in [c[0], c[1]] { try expectTrue(w.state.players[w.seat(name)].controller.isAI, "\(name) is not an AI seat") }
    }
    r.given(#"a 3-player game with Crimson human and the others AI"#) { w, _, _ in await aiGame(w, [.human, .ai(.mate), .ai(.mate)]) }
    r.given(#"a 3-player game with Crimson and Cobalt human and Amber AI"#) { w, _, _ in await aiGame(w, [.human, .human, .ai(.mate)]) }
    r.when(#"the AI seats have finished acting"#) { w, _, _ in await w.vm.waitForAI() }

    // Handing the device to another human
    r.given(#"(\w+) has the device"#) { w, c, _ in w.vm.ui.revealedTo = w.seat(c[0]) }
    r.then(#"the handover reads "([^"]*)" with the button "([^"]*)""#) { w, c, _ in
        try expectEqual(w.screen.handover?.message ?? "(none)", c[0], "handover message")
        try expectEqual(w.screen.handover?.button ?? "(none)", c[1], "handover button")
    }
    r.then(#"no handover is shown"#) { w, _, _ in try expectEqual(w.screen.handover?.button ?? "(none)", "(none)", "handover") }
    r.when(#"the handover button is tapped"#) { w, _, _ in w.vm.revealHand() }
    r.when(#"the game is reopened"#) { w, _, _ in w.vm.load(w.state) }
    r.when(#"the app goes to the background"#) { w, _, _ in w.vm.concealHand() }
    r.then(#"it is Crimson who must act"#) { w, _, _ in
        try expectEqual(Engine.actingPlayer(w.state), 0, "acting seat")
        try expectTrue(!w.vm.aiThinking, "an AI is still thinking")
    }
    /// Freezes a screen as it looks while `seat` (an AI) is acting, after setup, with the game's controllers.
    func thinking(_ w: World, seat: Int) {
        var s = TestGames.afterSetup(seed: 7)
        for i in s.players.indices { s.players[i].controller = w.state.players[i].controller }
        s.current = seat; s.phase = .awaitingRoll
        w.frozenScreen = ScreenState.derive(state: s, ui: UIState(), aiThinking: true, reduceMotion: false)
    }
    r.when(#"(\w+) is thinking"#) { w, c, _ in thinking(w, seat: w.seat(c[0])) }
    r.given(#"(\w+) holds a victory point card and it is \w+'s turn"#) { w, c, _ in
        var s = TestGames.afterSetup(seed: 7)
        for i in s.players.indices { s.players[i].controller = w.state.players[i].controller }
        let seat = w.seat(c[0])
        s.current = seat; s.phase = .main; s.dice = [4, 4]
        s.players[seat].devCards = [DevCard(type: .victoryPoint, boughtOnTurn: -1)]
        w.frozenScreen = ScreenState.derive(state: s, ui: UIState(), aiThinking: false, reduceMotion: false)
    }
    r.then(#"(\w+)'s row shows no "\+N""#) { w, c, _ in
        try expectEqual(w.screen.scoreboard[w.seat(c[0])].hidden, nil, "hidden points on \(c[0])'s row")
    }
    r.then(#"(\w+)'s answer is in without passing the device"#) { w, c, _ in
        await w.vm.waitForAI()
        guard case .tradeOffered(_, let responses) = w.state.phase else { throw StepError.failed("no offer pending: \(w.state.phase)") }
        try expectTrue(responses[w.seat(c[0])] != .pending, "\(c[0]) has not answered")
        try expectEqual(Engine.actingPlayer(w.state), 0, "acting seat")
    }
    r.given(#"(\w+) has offered (\#(resList)) for (\#(resList)) to (\w+)"#) { w, c, _ in
        var s = TestGames.afterSetup(seed: 7)
        for i in s.players.indices { s.players[i].controller = w.state.players[i].controller }
        s.clearHands()
        let proposer = w.seat(c[0]), target = w.seat(c[3])
        let give = World.resources(c[1]), want = World.resources(c[2])
        s.set(hand: give, for: proposer); s.set(hand: want, for: target)
        s.current = proposer; s.dice = [4, 4]
        s.phase = .tradeOffered(offer: TradeOffer(proposer: proposer, give: give, want: want, to: target), responses: [target: .pending])
        w.load(s)
    }
    r.then(#""Accept" and "Decline" are offered"#) { w, _, _ in
        try expectEqual(w.screen.buttons["Accept"], true, "Accept")
        try expectEqual(w.screen.buttons["Decline"], true, "Decline")
    }
}
