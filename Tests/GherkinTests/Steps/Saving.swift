import Foundation
import SaltmarshEngine
@testable import SaltmarshGame

@MainActor
func registerSaving(_ r: StepRegistry) {
    func named(_ w: World, _ name: String) throws -> SavedGameSummary {
        guard let save = w.vm.savedGames().first(where: { $0.name == name }) else { throw StepError.failed("no save called \(name)") }
        return save
    }
    r.when(#"I save the game as "([^"]*)""#) { w, c, _ in
        w.rememberedState = w.state
        w.saveRefused = false
        do { try w.vm.saveGame(named: c[0]) } catch { w.saveRefused = true }
    }
    r.when(#"I save the game as "([^"]*)" over "([^"]*)""#) { w, c, _ in
        try w.vm.saveGame(named: c[0], replacing: named(w, c[1]).id)
    }
    r.when(#"the game moves on a turn"#) { w, _, _ in w.vm.endTurn() }
    r.given(#"the last launch died while resuming the game"#) { w, _, _ in try w.store.markResuming() }
    r.when(#"the app is relaunched"#) { w, _, _ in _ = w.relaunch() }
    r.then(#"no game is on the board"#) { w, _, _ in try expectTrue(w.vm.state == nil, "a game is on the board") }
    r.then(#"the crashed game is kept aside for a replay"#) { w, _, _ in try expectEqual(w.store.setAsideGames.count, 1, "games set aside") }
    r.when(#"I load the save called "([^"]*)""#) { w, c, _ in try w.vm.loadGame(id: named(w, c[0]).id) }
    r.when(#"I delete the save called "([^"]*)""#) { w, c, _ in try w.vm.deleteSavedGame(id: named(w, c[0]).id) }
    r.given(#"all 5 saves are used"#) { w, _, _ in
        for i in 1...SaveLimit.maxSaves { try w.vm.saveGame(named: "Save \(i)") }
    }
    r.then(#"the saves list "([^"]*)""#) { w, c, _ in _ = try named(w, c[0]) }
    r.then(#"the saves do not list "([^"]*)""#) { w, c, _ in
        try expectTrue(!w.vm.savedGames().map(\.name).contains(c[0]), "\(c[0]) is still listed")
    }
    r.then(#"there are (\d+) saves"#) { w, c, _ in try expectEqual(w.vm.savedGames().count, Int(c[0])!, "save count") }
    r.then(#"the save is refused"#) { w, _, _ in try expectTrue(w.saveRefused, "the save went through") }
    r.then(#"the game on the board is the one that was saved"#) { w, _, _ in
        try expectTrue(w.state == w.rememberedState, "the game differs from the save")
    }
    r.given(#"the game has ended"#) { w, _, _ in
        var s = w.state
        s.phase = .gameOver(winner: 0)
        w.load(s)
    }
    r.then(#"saving is not offered"#) { w, _, _ in try expectEqual(w.screen.buttons[Strings.saveGame] ?? true, false, "Save Game") }
}
