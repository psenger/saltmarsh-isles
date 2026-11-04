import Foundation
import SaltmarshEngine
import SaltmarshTestSupport
@testable import SaltmarshGame

/// Steps every rule uses: header, status, log, hands and button states.
@MainActor
func registerCommon(_ r: StepRegistry) {
    r.given(#"a new 3-player game with human seats"#) { w, _, _ in w.newGame([.human, .human, .human]) }

    r.then(#"the header shows "([^"]*)""#) { w, c, _ in try expectEqual(w.screen.header, c[0], "header") }
    r.then(#"the header shows "([^"]*)" with (\w+)'s colour"#) { w, c, _ in
        try expectEqual(w.screen.header, c[0], "header")
        try expectEqual(w.screen.headerSeat, w.state.players[w.seat(c[1])].seat, "header colour")
    }
    r.then(#"the status reads "([^"]*)""#) { w, c, _ in try expectEqual(w.screen.status, c[0], "status") }
    r.then(#"the status does not read "([^"]*)""#) { w, c, _ in try expectTrue(w.screen.status != c[0], "status should not read \(c[0])") }
    r.then(#"the log reads "([^"]*)""#) { w, c, _ in try expectEqual(w.state.log.last ?? "", c[0], "last log line") }
    r.then(#"the log contains "([^"]*)""#) { w, c, _ in try expectTrue(w.state.log.contains(c[0]), "log should contain \(c[0])") }
    r.then(#"the log ends with "([^"]*)""#) { w, c, _ in try expectTrue((w.state.log.last ?? "").hasSuffix(c[0]), "log should end with \(c[0]); got \(w.state.log.last ?? "")") }
    r.then(#"the log twice reads "([^"]*)""#) { w, c, _ in try expectEqual(Array(w.state.log.suffix(2)), [c[0], c[0]], "last two log lines") }

    r.then(#""([^"]*)" is (enabled|disabled)"#) { w, c, _ in try expectEqual(w.screen.buttons[c[0]] ?? false, c[1] == "enabled", "button \(c[0])") }
    r.then(#"the "([^"]*)" button is (enabled|disabled)"#) { w, c, _ in try expectEqual(w.screen.buttons[c[0]] ?? false, c[1] == "enabled", "button \(c[0])") }
    r.then(#""([^"]*)" is disabled with "([^"]*)""#) { w, c, _ in
        try expectEqual(w.screen.buttons[c[0]] ?? false, false, "button \(c[0])")
        try expectEqual(w.screen.acceptProblem ?? "", c[1], "accept problem")
    }
    r.then(#""Roll dice", the build buttons, "Buy a card", trading and "End turn" are disabled"#) { w, _, _ in
        for b in ["Roll dice", "Road", "Settlement", "City", "Buy a card", "Trade 4 for 1", "Offer", "End turn"] {
            try expectEqual(w.screen.buttons[b] ?? false, false, "button \(b)")
        }
    }
    r.then(#"every action button is disabled"#) { w, _, _ in
        for b in ["Roll for first", "Roll dice", "Road", "Settlement", "City", "Buy a card", "Trade 4 for 1", "Offer", "End turn", "Withdraw", "Accept", "Decline"] {
            try expectEqual(w.screen.buttons[b] ?? false, false, "button \(b)")
        }
    }

    r.then(#"the hold is labelled "([^"]*)" and shows (\w+)'s cards"#) { w, c, _ in
        try expectEqual(w.screen.holdTitle, c[0], "hold title")
        try expectEqual(w.screen.handCounts, w.state.players[w.seat(c[1])].hand, "hand shown")
    }
    r.then(#"the hold is labelled "([^"]*)""#) { w, c, _ in try expectEqual(w.screen.holdTitle, c[0], "hold title") }
    r.then(#"no hand is shown"#) { w, _, _ in try expectTrue(w.screen.handCounts.isEmpty && w.screen.holdTitle.isEmpty, "a hand is shown: \(w.screen.holdTitle)") }
    r.then(#"both dice show "–""#) { w, _, _ in try expectEqual(w.screen.dice, ["–", "–"], "dice") }

    // Hands
    r.given(#"(\w+) holds (\d+) cards?"#) { w, c, _ in
        let n = Int(c[1])!
        var hand = ResourceCounts()
        for i in 0..<n { hand[Resource.allCases[i % 5]] += 1 }
        w.set(hand: hand, for: w.seat(c[0]))
    }
    r.given(#"(\w+) holds (\d+) cards, (\w+) holds (\d+) cards and (\w+) holds (\d+) cards"#) { w, c, _ in
        for (name, count) in [(c[0], c[1]), (c[2], c[3]), (c[4], c[5])] {
            var hand = ResourceCounts()
            for i in 0..<Int(count)! { hand[Resource.allCases[i % 5]] += 1 }
            w.set(hand: hand, for: w.seat(name))
        }
    }
    r.given(#"(\w+) holds (\d+ \w+(?:, \d+ \w+)*(?: and \d+ \w+)?)"#) { w, c, _ in
        w.set(hand: World.resources(c[1]), for: w.seat(c[0]))
    }
    r.then(#"(\w+) holds (\d+ \w+(?:, \d+ \w+)*(?: and \d+ \w+)?)"#) { w, c, _ in
        try expectEqual(w.state.players[w.seat(c[0])].hand, World.resources(c[1]), "\(c[0])'s hand")
    }
    r.then(#"(\w+) receives (\d+ \w+(?:, \d+ \w+)*(?: and \d+ \w+)?)"#) { w, c, _ in
        let before = w.rememberedHands.isEmpty ? ResourceCounts() : w.rememberedHands[w.seat(c[0])]
        try expectEqual(w.state.players[w.seat(c[0])].hand - before, World.resources(c[1]), "\(c[0]) received")
    }
    r.then(#"(\w+) pays (\d+ \w+(?:, \d+ \w+)*(?: and \d+ \w+)?)"#) { w, c, _ in
        let before = w.rememberedHands[w.seat(c[0])]
        try expectEqual(before - w.state.players[w.seat(c[0])].hand, World.resources(c[1]), "\(c[0]) paid")
    }
    r.then(#"(\w+) loses (\d+ \w+) and gains (\d+ \w+)"#) { w, c, _ in
        let seat = w.seat(c[0]), before = w.rememberedHands[seat], after = w.state.players[seat].hand
        let lost = World.resources(c[1]), gained = World.resources(c[2])
        try expectEqual(after, before - lost + gained, "\(c[0])'s hand after the trade")
    }
    r.then(#"every hand is unchanged"#) { w, _, _ in try expectEqual(w.state.players.map(\.hand), w.rememberedHands, "hands") }
}
