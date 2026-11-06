import Testing
@testable import SaltmarshEngine
import SaltmarshTestSupport
@testable import SaltmarshAI

@Suite struct EvaluatorTests {
    @Test func pointsDominateAndProductionCounts() {
        var s = TestGames.afterSetup(seed: 1); s.clearHands()
        let before = Evaluator.score(s, for: 0)
        let mine = s.board.corners.firstIndex { $0.owner == 0 }!
        s.place(city: mine, owner: 0)                                              // +1 point, more production
        #expect(Evaluator.score(s, for: 0) >= before + 10)
        var t = s; t.longestRoadHolder = 0
        #expect(Evaluator.score(t, for: 0) == Evaluator.score(s, for: 0) + 20 + 3)   // 2 points and the award bonus
    }
    @Test func marginIsOwnMinusBestOpponent() {
        let s = TestGames.midGame(seed: 2)
        let scores = (0..<s.playerCount).map { Evaluator.score(s, for: $0) }
        #expect(Evaluator.margin(s, for: 0) == scores[0] - max(scores[1], scores[2]))
    }
    @Test func bigHandsCost() {
        var s = TestGames.afterSetup(seed: 1); s.clearHands(); s.set(hand: [.timber: 7], for: 0)
        let seven = Evaluator.score(s, for: 0); s.set(hand: [.timber: 9], for: 0)
        #expect(Evaluator.score(s, for: 0) < seven)
    }
}
