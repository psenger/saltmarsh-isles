import Foundation
import SaltmarshEngine
import SaltmarshTestSupport
@testable import SaltmarshGame

/// Rule: Starting a new game
@MainActor
func registerStarting(_ r: StepRegistry) {
    r.then(#"a (\d)-player game has started"#) { w, c, _ in try expectEqual(w.state.playerCount, Int(c[0])!, "player count") }
    r.then(#"the players are (.+)"#) { w, c, _ in try expectEqual(w.state.players.map(\.name), World.names(c[0]), "players") }
    r.when(#"I start a (\d)-player game"#) { w, c, _ in w.newGame(Array(repeating: .human, count: Int(c[0])!)) }
    r.given(#"a new (\d)-player game"#) { w, c, _ in w.newGame(Array(repeating: .human, count: Int(c[0])!)) }
    r.then(#"every player has 0 resource cards and 0 development cards"#) { w, _, _ in
        try expectTrue(w.state.players.allSatisfy { $0.hand.isEmpty && $0.devCards.isEmpty }, "a player holds cards")
    }
    r.then(#"the development deck holds 25 cards"#) { w, _, _ in try expectEqual(w.state.devDeck.count, 25, "deck") }

    r.given(#"the victory screen is showing"#) { w, _, _ in
        w.crimsonWins()
        w.rememberedBoard = w.state.board
    }
    r.when(#"I tap "New game" on the victory screen"#) { w, _, _ in
        try expectEqual(w.screen.buttons["New game"] ?? false, true, "New game button")
        w.vm.newGame(GameConfig(controllers: [.human, .human, .human], seed: 2))
    }
    r.then(#"the victory screen is hidden"#) { w, _, _ in try expectTrue(w.screen.victory == nil && w.vm.ui.overlay == nil, "victory screen still showing") }
    r.then(#"a new board is generated"#) { w, _, _ in try expectTrue(w.state.board != w.rememberedBoard, "board unchanged") }
}
