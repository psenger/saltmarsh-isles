import SaltmarshEngine
import SaltmarshAI

/// Drives AI seats: builds the seat's redacted view, asks its opponent, and passes the answer
/// through the safety net. The live `GameState` never reaches the opponent.
enum TurnRunner {
    /// The acting AI seat's next move, or nil when a human must act or the game is over.
    static func step(state: GameState, opponents: [Int: any Opponent]) async -> Move? {
        if case .gameOver = state.phase { return nil }
        let seat = Engine.actingPlayer(state)
        guard let opponent = opponents[seat] else { return nil }
        let legal = Engine.legalMoves(state)
        guard !legal.isEmpty else { return nil }
        let view = Engine.view(state, for: seat)

        if case .tradeOffered(let offer, let responses) = state.phase, responses[seat] == .pending {
            let response = await opponent.respondToTrade(offer, view: view)
            let move = Move.respondToTrade(seat: seat, response)
            return Engine.isLegal(move, in: state) ? move : .respondToTrade(seat: seat, .declined)
        }

        let proposed = await opponent.chooseMove(view: view, legal: legal)
        // When the opponent's choice is illegal, the heuristic plays instead; failing that, a move that
        // keeps the game moving (design section 6.5).
        let isLegal = { Engine.isLegal($0, in: state) }
        return MoveResolver.resolve(proposed, isLegal: isLegal, legal: legal) {
            let steady = HeuristicPolicy.fallback(view: view, legal: legal)
            return isLegal(steady) ? steady : [Move.endTurn, .withdrawTrade, .roll].first { legal.contains($0) }
        }
    }
}
