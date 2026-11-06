import Testing
import SaltmarshEngine
import SaltmarshTestSupport
@testable import SaltmarshAI

/// Design sections 6.4 and 8: the effort dial must measurably matter, checked here at the heuristic levels.
@Suite struct DialTests {
    func wins(_ strong: EffortLevel, over weak: EffortLevel, games: Int = 40) async throws -> Int {
        var wins = 0
        for g in 0..<games {
            let strongSeat = g % 2
            let r = await Arena.play(strongSeat == 0 ? [strong, weak] : [weak, strong], seed: UInt64(1000 + g))
            if r.winner == strongSeat { wins += 1 }
        }
        return wins
    }
    @Test func mateBeatsDeckhand() async throws { #expect(try await wins(.mate, over: .deckhand) >= 26) }      // 65% of 40, design 8
    @Test func sailorBeatsDeckhand() async throws { #expect(try await wins(.sailor, over: .deckhand) >= 21) }  // more often than not, design 6.4
    @Test func mateBeatsSailor() async throws { #expect(try await wins(.mate, over: .sailor) >= 21) }
}
