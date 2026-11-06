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
        // When the opponent's choice is illegal, prefer a move that keeps the game moving.
        return MoveResolver.resolve(proposed, isLegal: { Engine.isLegal($0, in: state) }, legal: legal) {
            [Move.endTurn, .withdrawTrade, .roll].first { legal.contains($0) }
        }
    }
}
