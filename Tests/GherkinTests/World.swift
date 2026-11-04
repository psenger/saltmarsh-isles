import Foundation
import Testing
import SaltmarshEngine
import SaltmarshAI
import SaltmarshTestSupport
@testable import SaltmarshGame

/// One scenario's state: the view model under test plus whatever a step remembers for a later one.
@MainActor
final class World {
    let store = InMemoryGameStore()
    private(set) var vm: GameViewModel
    var remembered: [String: Int] = [:]

    init() {
        vm = GameViewModel(store: store, pacing: NoPacing())
        vm.newGame(GameConfig(controllers: [.human, .human, .human], seed: 1))
    }

    var screen: ScreenState { vm.screen }
    var state: GameState { vm.state! }

    func load(_ s: GameState) { vm.load(s) }

    /// Replaces the view model with one for a game whose seats are given (used by the AI-seat scenarios).
    func newGame(_ controllers: [Controller], seed: UInt64 = 1) {
        vm = GameViewModel(store: store, pacing: NoPacing())
        vm.newGame(GameConfig(controllers: controllers, seed: seed))
    }
}
