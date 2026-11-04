import Foundation
import SaltmarshEngine
import SaltmarshTestSupport
@testable import SaltmarshGame

/// Rule: Moving the robber and stealing
@MainActor
func registerRobber(_ r: StepRegistry) {
    /// "The chosen tile" is a numbered tile the robber is not on.
    func chosenTile(_ w: World) -> Int {
        if let t = w.rememberedTile { return t }
        let t = w.state.board.tiles.indices.first { $0 != w.state.robberTile && w.state.board.tiles[$0].number == 8 }!
        w.rememberedTile = t
        return t
    }

    r.given(#"(\w+) must move the robber"#) { w, c, _ in
        w.mutate { s in s.current = w.seat(c[0]); s.phase = .movingRobber(returnTo: .main); s.dice = [6, 1] }
    }
    r.then(#"every tile except the robber's current tile is selectable"#) { w, _, _ in
        try expectEqual(w.screen.selectableTiles, Set(w.state.board.tiles.indices).subtracting([w.state.robberTile]), "selectable tiles")
    }
    r.then(#"the robber's current tile cannot be chosen"#) { w, _, _ in
        let before = w.state.robberTile
        w.vm.tapTile(before)
        try expectEqual(w.state.robberTile, before, "robber tile")
        guard case .movingRobber = w.state.phase else { throw StepError.failed("phase changed: \(w.state.phase)") }
    }
    r.when(#"(\w+) taps a numbered tile"#) { w, c, _ in
        let t = chosenTile(w)
        w.vm.tapTile(t)
    }
    r.then(#"the robber is on that tile"#) { w, _, _ in try expectEqual(w.state.robberTile, w.rememberedTile!, "robber tile") }
    r.then(#"that tile's number disc is marked as sitting below the robber"#) { w, _, _ in
        try expectTrue(w.screen.numberDiscBelowRobber, "number disc not marked below the robber")
    }
    r.when(#"the robber is on the desert"#) { w, _, _ in w.mutate { s in s.robberTile = s.board.desertTile } }
    r.then(#"the desert label is marked as sitting below the robber"#) { w, _, _ in
        try expectTrue(w.screen.desertLabelBelowRobber, "desert label not marked below the robber")
    }

    r.given(#"(\w+) has a building and (\d+) cards on the chosen tile"#) { w, c, _ in
        let t = chosenTile(w), seat = w.seat(c[0])
        w.mutate { s in s.place(settlement: s.board.tiles[t].corners[0], owner: seat) }
        var hand = ResourceCounts()
        for i in 0..<Int(c[1])! { hand[Resource.allCases[i % 5]] += 1 }
        w.set(hand: hand, for: seat)
    }
    r.given(#"(\w+) and (\w+) both have buildings and cards on the chosen tile"#) { w, c, _ in
        let t = chosenTile(w)
        w.mutate { s in
            s.place(settlement: s.board.tiles[t].corners[0], owner: w.seat(c[0]))
            s.place(settlement: s.board.tiles[t].corners[3], owner: w.seat(c[1]))
        }
        w.set(hand: .uniform(1), for: w.seat(c[0]))
        w.set(hand: .uniform(1), for: w.seat(c[1]))
    }
    r.given(#"the chosen tile has a (\w+) settlement and an? (\w+) settlement"#) { w, c, _ in
        let t = chosenTile(w)
        w.mutate { s in
            s.place(settlement: s.board.tiles[t].corners[0], owner: w.seat(c[0]))
            s.place(settlement: s.board.tiles[t].corners[3], owner: w.seat(c[1]))
        }
    }
    r.when(#"(\w+) moves the robber there"#) { w, c, _ in
        w.rememberedHands = w.state.players.map(\.hand)
        w.vm.tapTile(chosenTile(w))
    }
    r.then(#"the panel shows "Steal from (\w+)" with "(\d+) cards""#) { w, c, _ in
        let target = w.screen.stealTargets.first { $0.name == c[0] }
        try expectEqual(target?.cards, Int(c[1])!, "cards shown for \(c[0])")
    }
    r.then(#"(\w+)'s buildings on that tile are steal targets"#) { w, c, _ in
        let seat = w.seat(c[0]), t = chosenTile(w)
        let mine = Set(w.state.board.tiles[t].corners.filter { w.state.board.corners[$0].owner == seat })
        try expectEqual(w.screen.stealTargets.first { $0.name == c[0] }?.corners ?? [], mine, "\(c[0])'s steal-target buildings")
    }
    r.then(#"the panel shows "Steal from (\w+)" and "Steal from (\w+)""#) { w, c, _ in
        try expectEqual(w.screen.stealTargets.map(\.name), [c[0], c[1]], "steal buttons")
    }
    r.when(#"(\w+) taps (\w+)'s building on that tile"#) { w, c, _ in
        let victim = w.seat(c[1]), t = chosenTile(w)
        let corner = w.state.board.tiles[t].corners.first { w.state.board.corners[$0].owner == victim }!
        w.rememberedHands = w.state.players.map(\.hand)
        w.vm.tapCorner(corner)
    }
    r.when(#"(\w+) taps the "Steal from (\w+)" button"#) { w, c, _ in
        w.rememberedHands = w.state.players.map(\.hand)
        w.vm.steal(from: w.seat(c[1]))
    }
    r.then(#"1 random card moves from (\w+) to (\w+)"#) { w, c, _ in
        let from = w.seat(c[0]), to = w.seat(c[1])
        try expectEqual(w.state.players[from].hand.total, w.rememberedHands[from].total - 1, "\(c[0])'s card count")
        try expectEqual(w.state.players[to].hand.total, w.rememberedHands[to].total + 1, "\(c[1])'s card count")
    }
    r.then(#"the steal buttons disappear"#) { w, _, _ in try expectTrue(w.screen.stealTargets.isEmpty, "steal buttons still showing") }
    r.then(#"no steal step appears"#) { w, _, _ in
        try expectTrue(w.screen.stealTargets.isEmpty, "steal buttons showing")
        guard case .main = w.state.phase else { throw StepError.failed("expected the main phase, got \(w.state.phase)") }
    }
    r.given(#"the robber was moved because of a 7"#) { w, _, _ in
        guard case .movingRobber(.main) = w.state.phase else { throw StepError.failed("not moving the robber after a 7: \(w.state.phase)") }
    }
    r.when(#"(\w+) finishes stealing"#) { w, c, _ in
        let t = chosenTile(w)
        w.mutate { s in s.place(settlement: s.board.tiles[t].corners[0], owner: 1) }
        w.set(hand: .uniform(1), for: 1)
        w.vm.tapTile(t)
        w.vm.steal(from: 1)
    }
}
