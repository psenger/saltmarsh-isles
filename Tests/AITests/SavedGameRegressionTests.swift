import Foundation
import Testing
import SaltmarshEngine
import SaltmarshTestSupport
@testable import SaltmarshAI

/// Real saved games the app once crashed on. Each must now search without trapping and return a legal move.
@Suite struct SavedGameRegressionTests {
    static func fixture(_ name: String) throws -> GameState {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/\(name)")
        return try JSONDecoder().decode(GameState.self, from: Data(contentsOf: url))
    }
    /// 2026-11-07: Amber (Admiral) had to answer Cobalt's counter-offer; playouts executed the counter against
    /// guessed Cobalt hands that held no grain, drove a count below zero, and the discard enumeration trapped.
    @Test func anAdmiralSurvivesACounterAgainstGuessedHands() async throws {
        let s = try Self.fixture("counter-pending-2026-11-07.json")
        guard case .tradeOffered = s.phase else { Issue.record("fixture is not in a trade phase"); return }
        let seat = Engine.actingPlayer(s); #expect(seat == 2)
        let legal = Engine.legalMoves(s)
        let bot = SearchOpponent(level: .admiral, seed: UInt64(seat), budget: SearchBudget(samples: 96, rounds: 1, playouts: 600, timeCap: nil, holdBack: 4))
        let move = await bot.chooseMove(view: Engine.view(s, for: seat), legal: legal)
        #expect(Engine.isLegal(move, in: s))
    }
}
