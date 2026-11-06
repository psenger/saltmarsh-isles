import Testing
import SaltmarshEngine
import SaltmarshTestSupport
@testable import SaltmarshAI

/// Design section 8: seeded heuristic games finish, and the engine's invariants hold after every move.
@Suite struct HeuristicSoakTests {
    @Test func threeMatesFinishWithTheInvariantsIntact() async throws {
        for seed in 0..<30 {
            let r = try await Match.play([.mate, .mate, .mate], seed: UInt64(seed), maxMoves: 6000) { s in #expect(Engine.invariantViolations(s).isEmpty) }
            #expect(r.winner != nil, "seed \(seed) hit the move cap after \(r.moves.count) moves")
            #expect(r.illegalChoices == 0, "seed \(seed): \(r.illegalSamples.map { "\($0.move) in \($0.phase)" }.joined(separator: "; "))")
        }
    }
}
