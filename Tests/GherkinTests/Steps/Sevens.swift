import Foundation
import SaltmarshEngine
import SaltmarshTestSupport
@testable import SaltmarshGame

/// Rule: Rolling a 7 makes players over 7 cards discard half, chosen by them
@MainActor
func registerSevens(_ r: StepRegistry) {
    func rollSeven(_ w: World) {
        w.rememberedHands = w.state.players.map(\.hand)
        w.forceRoll(7)
        w.vm.rollDice()
    }
    r.then(#"no tile produces"#) { w, _, _ in try expectEqual(w.state.players.map(\.hand), w.rememberedHands, "hands") }
    r.then(#"(\w+) must discard (\d+) and then (\w+) must discard (\d+)"#) { w, c, _ in
        guard case .discarding(let queue) = w.state.phase else { throw StepError.failed("not discarding: \(w.state.phase)") }
        try expectEqual(queue, [w.seat(c[0]), w.seat(c[2])], "discard queue")
        try expectEqual(w.state.players[queue[0]].hand.total / 2, Int(c[1])!, "\(c[0]) discards")
        try expectEqual(w.state.players[queue[1]].hand.total / 2, Int(c[3])!, "\(c[2]) discards")
    }
    r.then(#"(\w+) does not discard"#) { w, c, _ in
        guard case .discarding(let queue) = w.state.phase else { throw StepError.failed("not discarding: \(w.state.phase)") }
        try expectTrue(!queue.contains(w.seat(c[0])), "\(c[0]) is in the discard queue")
    }
    r.then(#"the discard box is outlined in (\w+)'s colour"#) { w, c, _ in
        try expectEqual(w.screen.discardBox?.outlineSeat, w.state.players[w.seat(c[0])].seat, "discard box outline")
    }
    r.then(#"the discard box reads "([^"]*)" with a counter "([^"]*)""#) { w, c, _ in
        try expectEqual(w.screen.discardBox?.title ?? "", c[0], "discard box title")
        try expectEqual(w.screen.discardBox?.counter ?? "", c[1], "discard counter")
    }
    r.then(#"the discard box reads "([^"]*)""#) { w, c, _ in try expectEqual(w.screen.discardBox?.title ?? "", c[0], "discard box title") }
    r.then(#"the discard box lists only resources (\w+) holds, each as "0 of N""#) { w, c, _ in
        let hand = w.state.players[w.seat(c[0])].hand
        let rows = w.screen.discardBox?.rows ?? []
        try expectEqual(rows.map(\.resource), hand.nonZero.map(\.0), "discard rows")
        for row in rows { try expectEqual(row.label, "0 of \(hand[row.resource])", "row label for \(row.resource)") }
    }
    r.then(#"the discard box shows "Next: (\w+)""#) { w, c, _ in try expectEqual(w.screen.discardBox?.next ?? "", "Next: \(c[0])", "next discarder") }
    r.then(#""Roll dice", the build buttons, "Buy a card", every "Play" button, trading and "End turn" are disabled"#) { w, _, _ in
        for b in ["Roll dice", "Road", "Settlement", "City", "Buy a card", "Trade 4 for 1", "Offer", "End turn"] {
            try expectEqual(w.screen.buttons[b] ?? false, false, "button \(b)")
        }
        try expectTrue(w.screen.devCards.allSatisfy { !$0.playEnabled }, "a Play button is enabled")
    }
    r.then(#"tapping a tile does not move the robber"#) { w, _, _ in
        let before = w.state.robberTile
        w.vm.tapTile((before + 1) % 19)
        try expectEqual(w.state.robberTile, before, "robber tile")
    }
    r.given(#"(\w+) is discarding (\d+)"#) { w, c, _ in
        // Enough timber for the picking scenario: 4 timber, 2 clay, 2 wool, 1 grain is 9 cards.
        w.set(hand: [.timber: 4, .clay: 2, .wool: 2, .grain: 1], for: w.seat(c[0]))
        rollSeven(w)
        try expectEqual(Engine.actingPlayer(w.state), w.seat(c[0]), "discarder")
        try expectEqual(w.vm.discardRequired, Int(c[1])!, "cards to discard")
    }
    r.when(#"(\w+) taps "\+" on (\w+) (\d+) times and "\+" on (\w+) once"#) { w, c, _ in
        for _ in 0..<Int(c[2])! { w.vm.discardAdjust(Resource(rawValue: c[1])!, by: 1) }
        w.vm.discardAdjust(Resource(rawValue: c[3])!, by: 1)
    }
    r.then(#"the counter reads "([^"]*)""#) { w, c, _ in try expectEqual(w.screen.discardBox?.counter ?? "", c[0], "discard counter") }
    r.then(#"every "\+" button is disabled"#) { w, _, _ in try expectTrue((w.screen.discardBox?.rows ?? []).allSatisfy { !$0.plusEnabled }, "a + button is enabled") }
    r.when(#"(\w+) taps "−" on (\w+)"#) { w, c, _ in w.vm.discardAdjust(Resource(rawValue: c[1])!, by: -1) }
    r.given(#"(\w+) is discarding and has picked 0 (\w+)"#) { w, c, _ in
        rollSeven(w)
        try expectEqual(Engine.actingPlayer(w.state), w.seat(c[0]), "discarder")
    }
    r.then(#"the "−" button on (\w+) is disabled"#) { w, c, _ in
        let row = w.screen.discardBox?.rows.first { $0.resource.rawValue == c[0] }
        try expectEqual(row?.minusEnabled ?? true, false, "minus on \(c[0])")
    }
    r.given(#"(\w+) holds 1 (\w+) and has picked 1 \w+"#) { w, c, _ in
        let seat = w.seat(c[0]), res = Resource(rawValue: c[1])!
        var hand = ResourceCounts.uniform(2)
        hand[res] = 1
        w.set(hand: hand, for: seat)                                        // 9 cards, one of them `res`
        rollSeven(w)
        try expectEqual(Engine.actingPlayer(w.state), seat, "discarder")
        w.vm.discardAdjust(res, by: 1)
    }
    r.then(#"the "\+" button on (\w+) is disabled"#) { w, c, _ in
        let row = w.screen.discardBox?.rows.first { $0.resource.rawValue == c[0] }
        try expectEqual(row?.plusEnabled ?? true, false, "plus on \(c[0])")
    }
    r.given(#"(\w+) has picked (\#(resList))"#) { w, c, _ in
        // A hand of exactly twice the picks plus one, so the picks are the whole discard.
        let seat = w.seat(c[0]), picks = World.resources(c[1])
        var hand = picks
        var filler = Resource.allCases.reversed().makeIterator()
        while hand.total < 2 * picks.total + 1 { hand[filler.next() ?? .ore] += 1 }
        w.set(hand: hand, for: seat)
        rollSeven(w)
        try expectEqual(Engine.actingPlayer(w.state), seat, "discarder")
        for (res, n) in picks.nonZero { w.vm.discardAdjust(res, by: n) }
        w.rememberedHands = w.state.players.map(\.hand)
    }
    r.when(#"(\w+) taps "Discard (\d+) cards""#) { w, c, _ in
        try expectEqual(w.screen.buttons["Discard \(c[1]) cards"] ?? false, true, "Discard button")
        w.vm.confirmDiscard()
    }
    r.then(#"(\w+) loses exactly (\#(resList))"#) { w, c, _ in
        let seat = w.seat(c[0])
        try expectEqual(w.rememberedHands[seat] - w.state.players[seat].hand, World.resources(c[1]), "\(c[0]) lost")
    }
    r.given(#"(\w+) is the last player discarding"#) { w, c, _ in
        rollSeven(w)
        while case .discarding(let queue) = w.state.phase, queue.first != w.seat(c[0]) {
            try w.vm.apply(Engine.legalMoves(w.state).first!)
        }
        guard case .discarding(let queue) = w.state.phase, queue == [w.seat(c[0])] else { throw StepError.failed("\(c[0]) is not the last discarder: \(w.state.phase)") }
    }
    r.when(#"(\w+) confirms her discard"#) { w, c, _ in
        try expectEqual(Engine.actingPlayer(w.state), w.seat(c[0]), "discarder")
        try w.vm.apply(Engine.legalMoves(w.state).first!)
    }
    r.given(#"every player holds 7 cards or fewer"#) { w, _, _ in w.mutate { s in s.clearHands() } }
    r.then(#"no discard box appears"#) { w, _, _ in try expectTrue(w.screen.discardBox == nil, "a discard box is showing") }
}
