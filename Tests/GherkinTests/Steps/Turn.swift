import Foundation
import SaltmarshEngine
import SaltmarshTestSupport
@testable import SaltmarshGame

/// Rules: Rolling and production; Ending the turn. Shared "setup is complete" backgrounds.
@MainActor
func registerTurn(_ r: StepRegistry) {
    r.given(#"setup is complete"#) { w, _, _ in w.afterSetup() }
    r.given(#"it is (\w+)'s turn and \w+ has not rolled"#) { w, c, _ in
        w.mutate { s in s.current = w.seat(c[0]); s.phase = .awaitingRoll; s.dice = nil }
    }
    r.given(#"setup is complete and it is (\w+)'s turn"#) { w, c, _ in
        w.afterSetup()
        w.mutate { s in s.current = w.seat(c[0]); s.phase = .awaitingRoll }
    }
    r.given(#"setup is complete and (\w+) has rolled"#) { w, c, _ in
        w.afterSetup()
        w.mutate { s in s.current = w.seat(c[0]); s.phase = .awaitingRoll; s.force(roll: 8) }
        w.vm.rollDice()
    }
    r.given(#"(\w+) has rolled"#) { w, c, _ in
        w.mutate { s in s.current = w.seat(c[0]); s.phase = .awaitingRoll; s.force(roll: 8) }
        w.vm.rollDice()
    }
    r.given(#"(\w+) has not rolled( yet)?"#) { w, c, _ in
        w.mutate { s in s.current = w.seat(c[0]); s.phase = .awaitingRoll; s.dice = nil }
    }
    r.given(#"setup is complete and it is (\w+)'s turn and \w+ has not rolled"#) { w, c, _ in
        w.afterSetup()
        w.mutate { s in s.current = w.seat(c[0]); s.phase = .awaitingRoll }
    }

    r.then(#"of the turn actions, only "Roll dice" and playable Knights are enabled"#) { w, _, _ in
        for b in ["Road", "Settlement", "City", "Buy a card", "Trade 4 for 1", "Offer", "End turn"] {
            try expectEqual(w.screen.buttons[b] ?? false, false, "button \(b)")
        }
        try expectEqual(w.screen.buttons["Roll dice"] ?? false, true, "Roll dice")
        for row in w.screen.devCards { try expectEqual(row.playEnabled, row.name == "Knight" && row.note == nil, "play button on \(row.name)") }
    }

    r.given(#"(\w+) has a settlement and (\w+) has a city on a tile numbered (\d+)"#) { w, c, _ in
        w.mutate { s in
            let t = s.tile(numbered: Int(c[2])!)
            s.place(settlement: s.board.tiles[t].corners[0], owner: w.seat(c[0]))
            s.place(city: s.board.tiles[t].corners[3], owner: w.seat(c[1]))
        }
        w.rememberedTile = w.state.tile(numbered: Int(c[2])!)
    }
    r.when(#"(\w+) rolls (\d+)"#) { w, c, _ in
        try expectEqual(w.state.current, w.seat(c[0]), "current seat")
        w.rememberedHands = w.state.players.map(\.hand)
        w.forceRoll(Int(c[1])!)
        w.vm.rollDice()
    }
    r.then(#"(\w+) receives (\d) cards? of that tile's resource"#) { w, c, _ in
        let res = w.state.board.tiles[w.rememberedTile!].resource!
        let seat = w.seat(c[0])
        try expectEqual(w.state.players[seat].hand[res] - w.rememberedHands[seat][res], Int(c[1])!, "\(c[0])'s \(res.rawValue)")
    }
    r.then(#"the number discs showing (\d+) are marked hit"#) { w, c, _ in try expectEqual(w.screen.hitNumber, Int(c[0])!, "hit number") }
    r.when(#"(\w+) rolls a number no building touches"#) { w, c, _ in
        w.mutate { s in s.clearBoard() }
        w.forceRoll(8)
        w.vm.rollDice()
    }
    r.given(#"the robber is on (\w+)'s tile numbered (\d+)"#) { w, c, _ in
        w.mutate { s in
            let t = s.tile(numbered: Int(c[1])!)
            s.place(settlement: s.board.tiles[t].corners[0], owner: w.seat(c[0]))
            s.robberTile = t
        }
        w.rememberedTile = w.state.tile(numbered: Int(c[1])!)
    }
    r.then(#"(\w+) receives nothing from that tile"#) { w, c, _ in
        let seat = w.seat(c[0])
        try expectEqual(w.state.players[seat].hand, w.rememberedHands[seat], "\(c[0])'s hand")
    }
    r.when(#"(\w+) rolls a number other than 7"#) { w, c, _ in
        w.forceRoll(5)
        w.vm.rollDice()
    }
    r.then(#""Roll dice" is disabled until the next turn"#) { w, _, _ in
        try expectEqual(w.screen.buttons["Roll dice"] ?? false, false, "Roll dice")
        w.vm.endTurn()
        try expectEqual(w.screen.buttons["Roll dice"] ?? false, true, "Roll dice on the next turn")
    }

    // Ending the turn
    r.given(#"no discard, robber move, steal or free road is pending"#) { w, _, _ in
        guard case .main = w.state.phase else { throw StepError.failed("not in the main phase: \(w.state.phase)") }
    }
    r.when(#"(\w+) taps "End turn""#) { w, c, _ in
        try expectEqual(w.state.current, w.seat(c[0]), "current seat")
        w.vm.toggleBuildMode(.road)
        w.vm.endTurn()
    }
    r.then(#"it is (\w+)'s turn"#) { w, c, _ in try expectEqual(w.state.current, w.seat(c[0]), "current seat") }
    r.then(#"any build mode is cleared"#) { w, _, _ in try expectTrue(w.screen.activeBuildMode == nil, "build mode still active") }
    r.then(#"(\w+) may play a development card this turn"#) { w, c, _ in
        try expectEqual(w.state.current, w.seat(c[0]), "current seat")
        try expectTrue(!w.state.devCardPlayedThisTurn, "a card counts as played already")
    }
}
