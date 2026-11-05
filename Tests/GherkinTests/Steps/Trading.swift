import Foundation
import SaltmarshEngine
import SaltmarshTestSupport
@testable import SaltmarshGame

/// Rules: Trading with the bank; Trading at captured harbours; Trading with other players; The bank can run out
@MainActor
func registerTrading(_ r: StepRegistry) {
    func harbour(_ w: World, _ kind: String) -> Int {
        let k: Harbour.Kind = kind == "3:1" || kind == "any" ? .any : .specific(Resource(rawValue: kind.replacingOccurrences(of: "2:1 ", with: ""))!)
        return w.state.board.harbours.firstIndex { $0.kind == k }!
    }
    func res(_ name: String) -> Resource { Resource(rawValue: name)! }

    // Bank
    r.when(#"(\w+) chooses (\w+) to give and (\w+) to get in "Trade with bank, 4 for 1""#) { w, c, _ in
        w.vm.ui.bankChoice = TradeChoice(give: res(c[1]), get: res(c[2]))
    }
    r.then(#"the bank trade row is (enabled|disabled)"#) { w, c, _ in
        try expectEqual(w.screen.bankRowEnabled, c[0] == "enabled", "bank trade row")
    }
    r.then(#"that harbour's trade row is (enabled|disabled)"#) { w, c, _ in
        try expectEqual(w.screen.harbours.rows.first?.rowEnabled ?? false, c[0] == "enabled", "harbour trade row")
    }
    r.when(#"taps "Trade 4 for 1""#) { w, _, _ in
        try expectEqual(w.screen.buttons["Trade 4 for 1"] ?? false, true, "Trade 4 for 1")
        w.rememberedHands = w.state.players.map(\.hand)
        w.vm.bankTrade(give: w.vm.ui.bankChoice.give, get: w.vm.ui.bankChoice.get)
    }
    r.given(#"(\w+) holds 3 timber and chooses to give timber"#) { w, c, _ in
        w.set(hand: [.timber: 3], for: w.seat(c[0]))
        w.vm.ui.bankChoice = TradeChoice(give: .timber, get: .ore)
    }
    r.given(#"(\w+) chooses the same resource to give and get"#) { w, c, _ in
        w.set(hand: [.timber: 4], for: w.seat(c[0]))
        w.vm.ui.bankChoice = TradeChoice(give: .timber, get: .timber)
    }
    r.given(#"(\w+) owns a 2:1 (\w+) harbour"#) { w, c, _ in
        let h = harbour(w, c[1])
        w.mutate { s in s.place(settlement: s.board.harbours[h].a, owner: w.seat(c[0])) }
        w.set(hand: [res(c[1]): 4], for: w.seat(c[0]))
        w.vm.ui.bankChoice = TradeChoice(give: res(c[1]), get: .ore)
    }
    r.then(#"the bank box still trades 4 for 1"#) { w, _, _ in
        try expectEqual(w.screen.bankTitle, "Trade with bank, 4 for 1", "bank title")
        try expectEqual(w.screen.buttons["Trade 4 for 1"] ?? false, true, "Trade 4 for 1 with 4 cards")
        try expectTrue(Engine.bestRate(w.state, player: 0, giving: w.vm.ui.bankChoice.give) == 2, "harbour rate not 2")
    }

    // Harbours
    r.given(#"(\w+) has no building on any harbour corner"#) { w, _, _ in w.mutate { s in s.clearBoard() } }
    r.then(#""Your harbours" reads "([^"]*)""#) { w, c, _ in try expectEqual(w.screen.harbours.emptyText ?? "", c[0], "harbours empty text") }
    r.given(#"(\w+) has a settlement on one corner of a (3:1|2:1 \w+) harbour"#) { w, c, _ in
        let h = harbour(w, c[1])
        w.mutate { s in s.place(settlement: s.board.harbours[h].a, owner: w.seat(c[0])) }
        w.rememberedTile = h
    }
    r.then(#""Your harbours" lists "([^"]*)" held by "([^"]*)""#) { w, c, _ in
        let row = w.screen.harbours.rows.first { $0.title == c[0] }
        try expectEqual(row?.heldBy ?? "(no row)", c[1], "held by for \(c[0])")
    }
    r.then(#"the harbour on the board carries a (\w+) ring"#) { w, c, _ in
        try expectEqual(w.screen.harbourRings[w.rememberedTile!] ?? [], [w.state.players[w.seat(c[0])].seat], "harbour rings")
    }
    r.then(#"the harbour on the board carries a (\w+) ring and a (\w+) ring"#) { w, c, _ in
        try expectEqual(w.screen.harbourRings[w.rememberedTile!] ?? [], [w.state.players[w.seat(c[0])].seat, w.state.players[w.seat(c[1])].seat], "harbour rings")
    }
    r.given(#"(\w+) has a settlement on one corner and a city on the other corner of a (2:1 \w+) harbour"#) { w, c, _ in
        let h = harbour(w, c[1]), seat = w.seat(c[0])
        w.mutate { s in s.place(settlement: s.board.harbours[h].a, owner: seat); s.place(city: s.board.harbours[h].b, owner: seat) }
    }
    r.given(#"(\w+) holds a (2:1 \w+) harbour and a 3:1 harbour"#) { w, c, _ in
        let a = harbour(w, c[1]), b = harbour(w, "3:1"), seat = w.seat(c[0])
        w.mutate { s in s.place(settlement: s.board.harbours[a].a, owner: seat); s.place(settlement: s.board.harbours[b].a, owner: seat) }
    }
    r.then(#""Your harbours" shows (\d+) rows, each with its own trade button"#) { w, c, _ in
        try expectEqual(w.screen.harbours.rows.count, Int(c[0])!, "harbour rows")
        try expectTrue(w.screen.harbours.rows.allSatisfy { $0.tradeLabel.hasPrefix("Trade ") }, "a row has no trade button")
    }
    r.given(#"(\w+) holds a (3:1|2:1 \w+) harbour and (\#(resList))"#) { w, c, _ in
        let h = harbour(w, c[1]), seat = w.seat(c[0])
        w.mutate { s in s.place(settlement: s.board.harbours[h].a, owner: seat) }
        w.set(hand: World.resources(c[2]), for: seat)
        w.rememberedTile = h
    }
    r.then(#"the give side of that row is fixed to "([^"]*)""#) { w, c, _ in
        let row = w.screen.harbours.rows.first { $0.index == w.rememberedTile! }
        try expectEqual(row?.giveFixed ?? "(none)", c[0], "fixed give side")
    }
    r.when(#"(\w+) chooses (\w+) to get and taps "Trade 2 for 1""#) { w, c, _ in
        let h = w.rememberedTile!, give = w.screen.harbours.rows.first { $0.index == h }!.give
        w.vm.ui.harbourChoice[h] = TradeChoice(give: give, get: res(c[1]))
        try expectEqual(w.screen.harbours.rows.first { $0.index == h }?.tradeEnabled, true, "Trade 2 for 1")
        w.rememberedHands = w.state.players.map(\.hand)
        w.vm.harbourTrade(h, give: give, get: res(c[1]))
    }
    r.when(#"(\w+) chooses (\w+) to give and (\w+) to get and taps "Trade 3 for 1""#) { w, c, _ in
        let h = w.rememberedTile!
        w.vm.ui.harbourChoice[h] = TradeChoice(give: res(c[1]), get: res(c[2]))
        try expectEqual(w.screen.harbours.rows.first { $0.index == h }?.tradeEnabled, true, "Trade 3 for 1")
        w.rememberedHands = w.state.players.map(\.hand)
        w.vm.harbourTrade(h, give: res(c[1]), get: res(c[2]))
    }
    r.then(#"that row's "Trade 2 for 1" is disabled"#) { w, _, _ in
        try expectEqual(w.screen.harbours.rows.first { $0.index == w.rememberedTile! }?.tradeEnabled, false, "Trade 2 for 1")
    }
    r.given(#"(\w+) holds one corner and (\w+) holds the other corner of a 3:1 harbour"#) { w, c, _ in
        let h = harbour(w, "3:1")
        w.mutate { s in s.place(settlement: s.board.harbours[h].a, owner: w.seat(c[0])); s.place(settlement: s.board.harbours[h].b, owner: w.seat(c[1])) }
        w.rememberedTile = h
    }
    r.then(#"the harbour appears in both players' lists on their turns"#) { w, _, _ in
        let h = w.rememberedTile!
        try expectTrue(w.screen.harbours.rows.contains { $0.index == h }, "missing from Crimson's list")
        w.mutate { s in s.current = 1 }
        try expectTrue(w.screen.harbours.rows.contains { $0.index == h }, "missing from Cobalt's list")
    }

    // Players
    r.when(#"(\w+) adds (\#(resItem)) to the (give|want) side"#) { w, c, _ in
        let (res, n) = World.resources(c[1]).nonZero[0]
        if c[2] == "give" { w.vm.offerAdjust(give: res, by: n) } else { w.vm.offerAdjust(want: res, by: n) }
    }
    r.given(#"(\w+) builds an offer of (\#(resList)) for (\#(resList))"#) { w, c, _ in
        w.vm.ui.offerGive = World.resources(c[1])
        w.vm.ui.offerWant = World.resources(c[2])
    }
    func offer(_ w: World, _ proposer: String, _ give: String, _ want: String, to: String?) {
        w.vm.ui.offerGive = World.resources(give)
        w.vm.ui.offerWant = World.resources(want)
        w.vm.ui.offerTarget = to.map { w.seat($0) }
        w.rememberedHands = w.state.players.map(\.hand)
        w.vm.proposeOffer()
    }
    r.when(#"(\w+) offers (\#(resList)) for (\#(resList))"#) { w, c, _ in offer(w, c[0], c[1], c[2], to: nil) }
    r.when(#"(\w+) offers (\#(resList)) for (\#(resList)) to (\w+)"#) { w, c, _ in offer(w, c[0], c[1], c[2], to: c[3]) }
    r.given(#"(\w+) offered (\#(resList)) for (\#(resList))"#) { w, c, _ in offer(w, c[0], c[1], c[2], to: nil) }
    r.when(#"(\w+) taps "(Accept|Decline)""#) { w, c, _ in
        try expectEqual(Engine.actingPlayer(w.state), w.seat(c[0]), "seat holding the device")
        w.vm.respondToOffer(accept: c[1] == "Accept")
    }
    r.then(#"the responses list shows (\w+) "([^"]*)" and (\w+) "([^"]*)""#) { w, c, _ in
        let rows = w.screen.tradeSection.responses
        try expectEqual(rows.first { $0.seat.name == c[0] }?.text ?? "(none)", c[1], "\(c[0])'s answer")
        try expectEqual(rows.first { $0.seat.name == c[2] }?.text ?? "(none)", c[3], "\(c[2])'s answer")
    }
    r.then(#"the responses list shows (\w+) "([^"]*)""#) { w, c, _ in
        try expectEqual(w.screen.tradeSection.responses.first { $0.seat.name == c[0] }?.text ?? "(none)", c[1], "\(c[0])'s answer")
    }
    r.when(#"(\w+) taps "Trade with (\w+)""#) { w, c, _ in
        let seat = w.seat(c[1])
        try expectEqual(w.screen.tradeSection.responses.first { $0.seat == w.state.players[seat].seat }?.canTrade, true, "Trade with \(c[1])")
        w.vm.executeTrade(with: seat)
    }
    r.when(#"(\w+) taps "Withdraw""#) { w, c, _ in
        try expectEqual(w.screen.buttons["Withdraw"] ?? false, true, "Withdraw")
        w.vm.withdrawOffer()
    }
    r.given(#"(\w+) holds (\d+) cards and (\w+) holds (\d+) cards"#) { w, c, _ in
        for (name, count) in [(c[0], c[1]), (c[2], c[3])] {
            var hand = ResourceCounts()
            for i in 0..<Int(count)! { hand[Resource.allCases[i % 5]] += 1 }
            w.set(hand: hand, for: w.seat(name))
        }
    }
    r.given(#"(\w+) countered with (\#(resList)) for (\#(resList))"#) { w, c, _ in
        guard case .tradeOffered(let o, _) = w.state.phase else { throw StepError.failed("no offer on the table") }
        let seat = w.seat(c[0])
        let counter = TradeOffer(proposer: o.proposer, give: World.resources(c[1]), want: World.resources(c[2]), to: seat)
        try w.vm.apply(.respondToTrade(seat: seat, .countered(counter)))
    }
    r.given(#"(\w+) declined"#) { w, c, _ in try w.vm.apply(.respondToTrade(seat: w.seat(c[0]), .declined)) }

    // The bank can run out
    r.then(#"the bank row shows 19 of each resource"#) { w, _, _ in try expectEqual(w.screen.bank, .uniform(19), "bank row") }
    r.given(#"the bank holds (\d+) (\w+)"#) { w, c, _ in
        // Cobalt holds the rest, so the bank is short without touching the roller's hand.
        var hand = w.state.players[1].hand
        hand[res(c[1])] = 19 - Int(c[0])!
        w.set(hand: hand, for: 1)
        try expectEqual(w.state.bank[res(c[1])], Int(c[0])!, "bank \(c[1])")
    }
    r.then(#"the bank holds (\d+) (\w+)"#) { w, c, _ in try expectEqual(w.screen.bank[res(c[1])], Int(c[0])!, "bank \(c[1])") }
    r.given(#"(\w+) has a city on a tile numbered (\d+) producing (\w+)"#) { w, c, _ in
        let t = w.state.tile(numbered: Int(c[1])!)
        w.mutate { s in s.board.tiles[t].terrain = .land(res(c[2])); s.place(city: s.board.tiles[t].corners[0], owner: w.seat(c[0])) }
        w.rememberedTile = t
    }
    r.given(#"(\w+) and (\w+) each have a settlement on a tile numbered (\d+) producing (\w+)"#) { w, c, _ in
        let t = w.state.tile(numbered: Int(c[2])!)
        w.mutate { s in
            s.board.tiles[t].terrain = .land(res(c[3]))
            s.place(settlement: s.board.tiles[t].corners[0], owner: w.seat(c[0]))
            s.place(settlement: s.board.tiles[t].corners[3], owner: w.seat(c[1]))
        }
        w.rememberedTile = t
    }
    r.then(#"(\w+) and (\w+) receive no (\w+)"#) { w, c, _ in
        for name in [c[0], c[1]] {
            let seat = w.seat(name)
            try expectEqual(w.state.players[seat].hand[res(c[2])], w.rememberedHands[seat][res(c[2])], "\(name)'s \(c[2])")
        }
    }
    r.given(#"(\w+) has rolled and holds (\#(resList))"#) { w, c, _ in
        w.mutate { s in s.current = w.seat(c[0]); s.phase = .awaitingRoll; s.force(roll: 8) }
        w.vm.rollDice()
        w.set(hand: World.resources(c[1]), for: w.seat(c[0]))
    }
    r.then(#"(\w+) cannot choose (\w+) and (\w+)"#) { w, c, _ in
        try expectTrue(!Engine.legalMoves(w.state).contains(.playBumperHarvest(res(c[1]), res(c[2]))), "\(c[1]) and \(c[2]) is offered")
    }
    r.then(#"(\w+) can choose (\w+) and (\w+)"#) { w, c, _ in
        try expectTrue(Engine.legalMoves(w.state).contains(.playBumperHarvest(res(c[1]), res(c[2]))), "\(c[1]) and \(c[2]) is not offered")
    }
}
