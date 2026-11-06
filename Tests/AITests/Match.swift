import SaltmarshEngine
import SaltmarshTestSupport
@testable import SaltmarshAI

/// A whole game between factory opponents, mirroring `TurnRunner` without importing `SaltmarshGame`.
enum Match {
    struct Result {
        var winner: Int?
        var moves: [Move]
        /// Choices the opponents made that the engine would have refused; the net replaced them.
        var illegalChoices: Int
    }

    /// Opponents are seeded seat by seat from `seed`. A pending responder answers through `respondToTrade`
    /// (an illegal answer becomes a decline); otherwise `chooseMove`, resolved through `MoveResolver` with
    /// `HeuristicPolicy.fallback`. Stops at game over or `maxMoves`. `check` runs after every applied move.
    static func play(_ levels: [EffortLevel], seed: UInt64, maxMoves: Int = 4000, check: (@Sendable (GameState) -> Void)? = nil) async throws -> Result {
        var s = Engine.newGame(GameConfig(controllers: levels.map { .ai($0) }, seed: seed))
        let bots = levels.enumerated().map { OpponentFactory.make(level: $1, seed: seed &* 31 &+ UInt64($0)) }
        var moves: [Move] = [], illegal = 0
        for _ in 0..<maxMoves {
            if case .gameOver = s.phase { break }
            let p = Engine.actingPlayer(s), legal = Engine.legalMoves(s)
            guard !legal.isEmpty else { break }
            let view = Engine.view(s, for: p)
            let state = s
            let isLegal = { Engine.isLegal($0, in: state) }
            let move: Move
            if case .tradeOffered(let offer, let responses) = s.phase, responses[p] == .pending {
                let answer = Move.respondToTrade(seat: p, await bots[p].respondToTrade(offer, view: view))
                if isLegal(answer) { move = answer } else { illegal += 1; move = .respondToTrade(seat: p, .declined) }
            } else {
                let proposed = await bots[p].chooseMove(view: view, legal: legal)
                if !isLegal(proposed) { illegal += 1 }
                move = MoveResolver.resolve(proposed, isLegal: isLegal, legal: legal) {
                    let steady = HeuristicPolicy.fallback(view: view, legal: legal)
                    return isLegal(steady) ? steady : [Move.endTurn, .withdrawTrade, .roll].first { legal.contains($0) }
                }
            }
            try Engine.apply(move, to: &s)
            moves.append(move)
            check?(s)
        }
        var winner: Int?
        if case .gameOver(let w) = s.phase { winner = w }
        return Result(winner: winner, moves: moves, illegalChoices: illegal)
    }
}
