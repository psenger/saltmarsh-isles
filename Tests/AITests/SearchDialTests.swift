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
}
