import Testing
import SaltmarshEngine
import SaltmarshTestSupport
@testable import SaltmarshAI

@Suite struct HeuristicOpponentTests {
    @Test func factoryMapsEveryLevelToTheHeuristic() {
        for level in EffortLevel.allCases { #expect(OpponentFactory.make(level: level, seed: 1) is HeuristicOpponent) }
    }
    @Test func sameSeedSameGame() async throws {
        let a = try await Match.play([.deckhand, .mate], seed: 5, maxMoves: 300), b = try await Match.play([.deckhand, .mate], seed: 5, maxMoves: 300)
        #expect(a.moves == b.moves); #expect(a.moves.count == 300 || a.winner != nil); #expect(a.illegalChoices == 0)
    }
    @Test func differentSeedsDiffer() async throws {
        let a = try await Match.play([.deckhand, .deckhand], seed: 1, maxMoves: 120), b = try await Match.play([.deckhand, .deckhand], seed: 2, maxMoves: 120)
        #expect(a.moves != b.moves)
    }
}
