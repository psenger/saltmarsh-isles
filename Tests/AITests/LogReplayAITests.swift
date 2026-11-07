import Testing
import SaltmarshEngine
import SaltmarshTestSupport
@testable import SaltmarshAI

/// Games the AI plays, searching included, replay from their logs exactly.
@Suite struct LogReplayAITests {
    @Test func anAIGameReplaysExactly() async throws {
        let tiny = SearchBudget(samples: 2, rounds: 1, playouts: 8, timeCap: nil)
        let levels: [EffortLevel] = [.captain, .mate, .sailor]
        let d = await Arena.play(levels: levels, seed: 21, maxMoves: 600, make: { level, seed in
            level == .captain ? SearchOpponent(level: .captain, seed: seed, budget: tiny) : OpponentFactory.make(level: level, seed: seed) })
        let played = try Engine.replay(GameConfig(controllers: levels.map { .ai($0) }, seed: 21), moves: d.moves)
        #expect(played.log.contains("Crimson is an AI Captain."))
        let replayed = try LogReplay.replay(played.log)
        #expect(replayed == played)
    }
}
