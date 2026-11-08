import Testing
import SaltmarshEngine
import SaltmarshTestSupport
@testable import SaltmarshAI

/// Design section 8: a small-budget Captain beats Mate in at least 65% of 40 seeded two-player games. A searched
/// game takes seconds in a debug build, so this runs only as a release build: `make dial`.
let isDebugBuild: Bool = {
    #if DEBUG
    return true
    #else
    return false
    #endif
}()

@Suite struct SearchDialTests {
    /// The Admiral's shipped budget starved to what a Debug build reached on the owner's 2026-11-07 saves: 14 guessed
    /// hands and 60 playouts, with no clock so a game replays from its seed. Built from the shipped budget so its
    /// hold-back and guard come along.
    static let starvedBudget: SearchBudget = {
        var b = LevelProfile.forLevel(.admiral).search!
        b.samples = 14; b.playouts = 60; b.timeCap = nil
        return b
    }()

    @Test(.enabled(if: !isDebugBuild, "needs a release build: make dial"))
    func captainAtASmallBudgetBeatsMate() async {
        let small = SearchBudget(samples: 24, rounds: 1, playouts: 144, timeCap: nil, holdBack: 4)
        var wins = 0
        for g in 0..<40 {
            let strongSeat = g % 2
            let levels: [EffortLevel] = strongSeat == 0 ? [.captain, .mate] : [.mate, .captain]
            let r = await Arena.play(levels: levels, seed: UInt64(2000 + g), maxMoves: 4000, make: { level, seed in
                level == .captain ? SearchOpponent(level: .captain, seed: seed, budget: small) : OpponentFactory.make(level: level, seed: seed) })
            if r.winner == strongSeat { wins += 1 }
        }
        #expect(wins >= 26, "Captain won \(wins) of 40")
    }

    /// GitHub issue 1: a search with too little time must still win at least as often as Mate would in its seat.
    @Test(.enabled(if: !isDebugBuild, "needs a release build: make dial"))
    func aStarvedSearchIsNeverWorseThanMate() async {
        var mateWins = 0, searchWins = 0
        for g in 0..<40 {
            let seat = g % 2, seed = UInt64(3000 + g)
            let baseline = await Arena.play(levels: [.mate, .mate], seed: seed, maxMoves: 4000)
            if baseline.winner == seat { mateWins += 1 }
            let levels: [EffortLevel] = seat == 0 ? [.admiral, .mate] : [.mate, .admiral]
            let r = await Arena.play(levels: levels, seed: seed, maxMoves: 4000, make: { level, seed in
                level == .admiral ? SearchOpponent(level: .admiral, seed: seed, budget: Self.starvedBudget) : OpponentFactory.make(level: level, seed: seed) })
            if r.winner == seat { searchWins += 1 }
        }
        #expect(searchWins >= mateWins, "starved search won \(searchWins), Mate in the same seat \(mateWins)")
    }
}
