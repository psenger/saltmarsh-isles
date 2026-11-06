import Testing
@testable import SaltmarshEngine
import SaltmarshTestSupport
@testable import SaltmarshAI

@Suite struct CandidateTests {
    func candidates(_ s: GameState, seat: Int = 0) -> [Move] {
        var m = TurnMemory(), rng = SeededRNG(seed: 1)
        return HeuristicPolicy.candidates(view: Engine.view(s, for: seat), legal: Engine.legalMoves(s), profile: .forLevel(.captain), memory: &m, rng: &rng)
    }
    @Test func mainPhaseListIsLegalDistinctCappedAndLedByTheHeuristic() {
        var s = TestGames.rolled(8); s.set(hand: Cost.city + Cost.settlement + Cost.road + Cost.devCard, for: 0)
        let c = candidates(s), legal = Engine.legalMoves(s)
        var m = TurnMemory(), rng = SeededRNG(seed: 1)
        #expect(c.first == HeuristicPolicy.choose(view: Engine.view(s, for: 0), legal: legal, profile: .forLevel(.captain), memory: &m, rng: &rng))
        #expect(c.count >= 3 && c.count <= 6); #expect(Set(c).count == c.count); #expect(c.allSatisfy { legal.contains($0) })
        #expect(c.contains(.endTurn)); #expect(c.contains(.buyDevCard))
    }
    @Test func rollingAndForcedStepsAreNotSearched() {
        var s = TestGames.afterSetup(seed: 1); s.current = 0; s.phase = .awaitingRoll
        #expect(candidates(s).isEmpty)
        s.phase = .choosingVictim(candidates: [1], returnTo: .main)
        #expect(candidates(s).isEmpty)
    }
    @Test func setupOffersTheBestFourCorners() {
        var s = TestGames.afterSetup(seed: 3); s.clearBoard(); s.current = 0; s.phase = .setup(step: 0, placingRoad: false, lastSettlement: nil)
        let c = candidates(s)
        #expect(c.count == 4); #expect(c.allSatisfy { if case .placeSettlement = $0 { true } else { false } })
    }
    @Test func robberOffersThreeTiles() {
        var s = TestGames.afterSetup(seed: 2); s.current = 0; s.phase = .movingRobber(returnTo: .main)
        #expect(candidates(s).count == 3)
    }
}
