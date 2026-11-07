import SaltmarshEngine
import SaltmarshAI

/// Drives AI seats: builds the seat's redacted view, asks its opponent, and passes the answer
/// through the safety net. The live `GameState` never reaches the opponent.
enum TurnRunner {
    struct Step {
        var move: Move
        /// How hard the seat thought, when it searched; the log gets a line for it.
        var thought: Thought?
    }

    /// The acting AI seat's next move, or nil when a human must act or the game is over.
    static func step(state: GameState, opponents: [Int: any Opponent]) async -> Step? {
        if case .gameOver = state.phase { return nil }
        let seat = Engine.actingPlayer(state)
        guard let opponent = opponents[seat] else { return nil }
        let legal = Engine.legalMoves(state)
        guard !legal.isEmpty else { return nil }
        let view = Engine.view(state, for: seat)

        if case .tradeOffered(let offer, let responses) = state.phase, responses[seat] == .pending {
            let response = await opponent.respondToTrade(offer, view: view)
            let move = Move.respondToTrade(seat: seat, response)
            return Step(move: Engine.isLegal(move, in: state) ? move : .respondToTrade(seat: seat, .declined), thought: await opponent.lastThought())
        }

        let proposed = await opponent.chooseMove(view: view, legal: legal)
        // When the opponent's choice is illegal, the heuristic plays instead; failing that, a move that
        // keeps the game moving (design section 6.5).
        let isLegal = { Engine.isLegal($0, in: state) }
        let move = MoveResolver.resolve(proposed, isLegal: isLegal, legal: legal) {
            let steady = HeuristicPolicy.fallback(view: view, legal: legal)
            return isLegal(steady) ? steady : [Move.endTurn, .withdrawTrade, .roll].first { legal.contains($0) }
        }
        return Step(move: move, thought: await opponent.lastThought())
    }
}
