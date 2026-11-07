import Testing
import SaltmarshEngine
@testable import SaltmarshAI
import SaltmarshTestSupport
@testable import SaltmarshGame

/// A game the view model ran, thinking lines and all, replays from its log.
@MainActor @Suite struct LogReplayGameTests {
    @Test func aViewModelGameReplaysExactly() async throws {
        let tiny = SearchBudget(samples: 2, rounds: 1, playouts: 8, timeCap: nil)
        let vm = GameViewModel(store: InMemoryGameStore(), pacing: NoPacing()) { c, seat in
            c.isAI ? SearchOpponent(level: .captain, seed: UInt64(seat), budget: tiny) : nil
        }
        vm.newGame(GameConfig(controllers: [.ai(.captain), .ai(.captain)], seed: 5)); await vm.waitForAI()
        let played = vm.state!
        #expect(played.log.contains { $0.contains(" weighed ") })
        let replayed = try LogReplay.replay(played.log)
        var expected = played; expected.log = played.log.filter { !$0.contains(" weighed ") }
        #expect(replayed == expected)
    }
}
