import Foundation
import SaltmarshEngine
import SaltmarshTestSupport
@testable import SaltmarshGame

/// Rule: Choosing who goes first
@MainActor
func registerFirstRoll(_ r: StepRegistry) {
    r.when(#"(\w+) rolls (\d+) for first player"#) { w, c, _ in
        try expectEqual(Engine.actingPlayer(w.state), w.seat(c[0]), "seat due to roll for first player")
        w.forceRoll(Int(c[1])!)
        w.vm.rollForFirst()
    }
    r.when(#"the first-player rolls are (.+)"#) { w, c, _ in
        // "Crimson 3, Cobalt 12 and Amber 7"
        let pairs = World.names(c[0]).map { $0.split(separator: " ") }
        var s = w.state
        s.forcedRolls = []
        for pair in pairs {
            let seat = w.seat(String(pair[0])), total = Int(pair[1])!
            try expectEqual(seat, pairs.firstIndex(where: { $0 == pair })!, "rolls listed in seat order")
            let a = min(6, total - 1)
            s.forcedRolls.append([a, total - a])
        }
        w.load(s)
        for _ in pairs { w.vm.rollForFirst() }
    }
    r.then(#"the order strip shows (.+)"#) { w, c, _ in
        try expectEqual(w.screen.orderStrip?.map(\.name) ?? [], World.names(c[0]), "order strip")
    }
    r.given(#"(\w+) won the first roll"#) { w, c, _ in w.forceFirstRoll(winner: w.seat(c[0])) }
    r.when(#"every setup placement is made"#) { w, _, _ in w.completeSetup() }
}
