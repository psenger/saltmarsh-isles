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

    // MARK: The noise guard (GitHub issue 1)

    static let starved = SearchBudget(samples: 14, rounds: 1, playouts: 60, timeCap: nil, holdBack: 4)
    static var guarded: SearchBudget { var b = starved; b.minPlayouts = 24; b.noiseMultiple = 2; return b }

    /// No position `midGame(seed:moves: 70)` reaches for seeds 1 to 30 makes the starved search change its mind; this
    /// one does: seed 1, then 23 moves of Mate's own play, where Cobalt's heuristic offers clay for timber.
    @Test func starvedSearchKeepsTheHeuristicsChoice() throws {
        var s = TestGames.midGame(seed: 1, moves: 70)
        RolloutSearch.playOut(&s, until: .max, moveCap: 23)
        let v = Engine.view(s, for: Engine.actingPlayer(s))
        var m = TurnMemory(), r0 = SeededRNG(seed: 1)
        let c = HeuristicPolicy.candidates(view: v, legal: Engine.legalMoves(s), profile: .forLevel(.captain), memory: &m, rng: &r0)
        var rng = SeededRNG(seed: 1)
        try #require(RolloutSearch.choose(view: v, candidates: c, budget: Self.starved, rng: &rng).changedMind, "the unguarded starved search kept \(c.first.map { "\($0)" } ?? "nothing")")
        for guarded in [Self.guarded, { var b = Self.starved; b.noiseMultiple = 2; return b }()] {           // the count, then the spread alone
            var rng = SeededRNG(seed: 1)
            let d = RolloutSearch.choose(view: v, candidates: c, budget: guarded, rng: &rng)
            #expect(!d.changedMind); #expect(d.move == c[0])
        }
    }
    @Test func aCertainWinStillOverrulesUnderTheGuard() {
        var s = TestGames.rolled(8); s.set(hand: Cost.city, for: 0)
        let mine = s.board.corners.indices.filter { s.board.corners[$0].owner == 0 && !s.board.corners[$0].isCity }
        for c in mine.dropFirst() { s.place(city: c, owner: 0) }
        let avoid = Set(s.board.corners.indices.filter { s.board.corners[$0].owner != nil })
        for (i, corner) in s.spreadCorners(4, avoiding: avoid).enumerated() {
            if i < 2 { s.place(city: corner, owner: 0) } else { s.place(settlement: corner, owner: 0) }
        }
        var budget = SearchBudget(samples: 30, rounds: 1, playouts: 200, timeCap: nil, holdBack: 4)
        budget.minPlayouts = 24; budget.noiseMultiple = 2
        var rng = SeededRNG(seed: 1)
        let d = RolloutSearch.choose(view: Engine.view(s, for: 0), candidates: [.endTurn, .upgradeCity(corner: mine[0])], budget: budget, rng: &rng)
        #expect(d.move == .upgradeCity(corner: mine[0])); #expect(d.changedMind)
    }
    /// The second steal never applies, so it never pairs with the first. No minimum count here, so the
    /// "at least one pair" rule is what keeps the first, not the minimum.
    @Test func guardWithNoPairsKeepsTheHeuristicsChoice() {
        var s = TestGames.afterSetup(seed: 1); s.clearHands(); s.set(hand: [.ore: 1], for: 1)
        s.current = 0; s.phase = .choosingVictim(candidates: [1], returnTo: .main)
        var budget = count; budget.holdBack = 4; budget.noiseMultiple = 2
        var rng = SeededRNG(seed: 2)
        let d = RolloutSearch.choose(view: Engine.view(s, for: 0), candidates: [.steal(from: 1), .steal(from: 2)], budget: budget, rng: &rng)
        #expect(d.move == .steal(from: 1)); #expect(!d.changedMind)
    }
    @Test func aZeroSpreadGapStillOverrules() {
        let margins: [[Int?]] = [Array(repeating: 0, count: 24), Array(repeating: 4, count: 24)]
        #expect(RolloutSearch.pick(margins, budget: Self.guarded) == 1)
    }
    @Test func theLargerClearGainWinsAndATieGoesToTheEarlierMove() {
        let base: [Int?] = Array(repeating: 0, count: 30)
        let small: [Int?] = Array(repeating: 6, count: 30), large: [Int?] = Array(repeating: 9, count: 30)
        #expect(RolloutSearch.pick([base, small, large], budget: Self.guarded) == 2)
        #expect(RolloutSearch.pick([base, large, large], budget: Self.guarded) == 1)
    }
    @Test func aGainBuriedInNoiseKeepsTheHeuristicsChoice() {
        let base: [Int?] = Array(repeating: 0, count: 30)
        let noisy: [Int?] = (0..<30).map { $0 % 2 == 0 ? 40 : -30 }                 // mean gain 5, standard error about 6.5
        #expect(RolloutSearch.pick([base, noisy], budget: Self.guarded) == 0)
        #expect(RolloutSearch.pick([base, noisy], budget: Self.starved) == 1)        // the unguarded rule takes it
    }
    @Test func theShippedSearchingLevelsHaveTheGuardOn() throws {
        for level in [EffortLevel.captain, .admiral] {
            let b = try #require(LevelProfile.forLevel(level).search)
            #expect(b.minPlayouts == 24); #expect(b.noiseMultiple == 2)
        }
    }
}
