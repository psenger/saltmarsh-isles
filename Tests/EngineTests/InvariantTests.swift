import Foundation
import Testing
@testable import SaltmarshEngine
import SaltmarshTestSupport

@Suite struct InvariantTests {
    /// Random games run per test. A game takes about two seconds in a debug build, so the default stays
    /// small; `SALTMARSH_GAMES=1000 swift test --filter InvariantTests` runs the full set.
    static let games = Int(ProcessInfo.processInfo.environment["SALTMARSH_GAMES"] ?? "") ?? 20
    @Test func randomGamesKeepEveryInvariant() {
        var finished = 0
        for seed in 0..<Self.games {
            let (final, _) = TestGames.randomGame(seed: UInt64(seed)) { s in
                let bad = Engine.invariantViolations(s); #expect(bad.isEmpty, "seed \(seed) turn \(s.turn): \(bad)")
            }
            if case .gameOver = final.phase { finished += 1 }
        }
        #expect(finished > 0)
    }
    @Test func replayReproducesFinalState() throws {
        for seed in 0..<50 {
            let (final, moves) = TestGames.randomGame(seed: UInt64(seed), maxMoves: 800)
            let config = GameConfig(controllers: [.human, .human, .human], seed: UInt64(seed))
            #expect(try Engine.replay(config, moves: moves) == final, "seed \(seed)")
        }
    }
    @Test func invariantsDetectBrokenStates() {
        var s = TestGames.afterSetup(); s.players[0].hand[.ore] = -1
        #expect(Engine.invariantViolations(s).contains { $0.contains("negative") || $0.contains("-1") })
        var t = TestGames.afterSetup(); t.longestRoadHolder = 1
        #expect(!Engine.invariantViolations(t).isEmpty)
        var u = TestGames.afterSetup(); u.bank[.timber] += 1
        #expect(Engine.invariantViolations(u).contains { $0.contains("timber") })
    }
    @Test func cleanStatesHaveNoViolations() {
        #expect(Engine.invariantViolations(TestGames.afterSetup()).isEmpty)
        #expect(Engine.invariantViolations(TestGames.midGame(seed: 2)).isEmpty)
    }
}
