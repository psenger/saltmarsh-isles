import Testing
@testable import SaltmarshEngine
import SaltmarshTestSupport
@testable import SaltmarshAI

@Suite struct RolloutSearchTests {
    let count = SearchBudget(samples: 4, rounds: 1, playouts: 100, timeCap: nil)

    @Test func prefersTheWinningMove() {                                          // Review Focus 4
        var s = TestGames.rolled(8); s.set(hand: Cost.city, for: 0)
        let mine = s.board.corners.indices.filter { s.board.corners[$0].owner == 0 && !s.board.corners[$0].isCity }
        for c in mine.dropFirst() { s.place(city: c, owner: 0) }
        let avoid = Set(s.board.corners.indices.filter { s.board.corners[$0].owner != nil })
        for (i, corner) in s.spreadCorners(4, avoiding: avoid).enumerated() {                 // 3 cities and 3 settlements: 9 points, a city still in hand
            if i < 2 { s.place(city: corner, owner: 0) } else { s.place(settlement: corner, owner: 0) }
        }
        #expect(Engine.publicPoints(s, player: 0) == 9); #expect(Engine.piecesLeft(s, player: 0).cities == 1)
        #expect(Engine.legalMoves(s).contains(.upgradeCity(corner: mine[0])))
        var rng = SeededRNG(seed: 1)
        let d = RolloutSearch.choose(view: Engine.view(s, for: 0), candidates: [.endTurn, .upgradeCity(corner: mine[0])], budget: count, rng: &rng)
        #expect(d.move == .upgradeCity(corner: mine[0])); #expect(d.playouts == 8)
    }
    @Test func deterministicUnderACountBudget() {
        let s = TestGames.midGame(seed: 5, moves: 70); let v = Engine.view(s, for: Engine.actingPlayer(s))
        var m = TurnMemory(), r0 = SeededRNG(seed: 3)
        let c = HeuristicPolicy.candidates(view: v, legal: Engine.legalMoves(s), profile: .forLevel(.captain), memory: &m, rng: &r0)
        guard c.count >= 2 else { return }
        var a = SeededRNG(seed: 9), b = SeededRNG(seed: 9)
        #expect(RolloutSearch.choose(view: v, candidates: c, budget: count, rng: &a) == RolloutSearch.choose(view: v, candidates: c, budget: count, rng: &b))
    }
    @Test func capBeforeAnyPlayoutReturnsTheHeuristicsChoice() {                   // Review Focus 2
        let s = TestGames.rolled(8); var rng = SeededRNG(seed: 1)
        let spent = SearchBudget(samples: 4, rounds: 1, playouts: 100, timeCap: .zero)
        let d = RolloutSearch.choose(view: Engine.view(s, for: 0), candidates: [.endTurn, .buyDevCard], budget: spent, rng: &rng)
        #expect(d.move == .endTurn); #expect(d.playouts == 0)
    }
    @Test func aCandidateIllegalInASampleIsSkipped() {                             // Review Focus 3
        var s = TestGames.afterSetup(seed: 1); s.clearHands(); s.set(hand: [.ore: 1], for: 1)
        s.current = 0; s.phase = .choosingVictim(candidates: [1], returnTo: .main)
        var rng = SeededRNG(seed: 2)
        let d = RolloutSearch.choose(view: Engine.view(s, for: 0), candidates: [.steal(from: 1), .steal(from: 2)], budget: count, rng: &rng)
        #expect(d.move == .steal(from: 1))                                         // seat 2 is no candidate in any sample: that steal never applies
    }
    @Test func playoutCountIsCutByTheBudget() {
        let s = TestGames.rolled(8); var rng = SeededRNG(seed: 1)
        let d = RolloutSearch.choose(view: Engine.view(s, for: 0), candidates: [.endTurn, .buyDevCard], budget: SearchBudget(samples: 10, rounds: 1, playouts: 5, timeCap: nil), rng: &rng)
        #expect(d.playouts <= 5)
    }
}
