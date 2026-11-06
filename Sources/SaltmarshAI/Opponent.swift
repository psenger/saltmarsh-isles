import SaltmarshEngine

/// An AI seat. It only ever sees a `PlayerView` (its own cards, everyone else's counts) and the
/// legal moves; the live game never enters this module.
public protocol Opponent: Sendable {
    func chooseMove(view: PlayerView, legal: [Move]) async -> Move
    func respondToTrade(_ offer: TradeOffer, view: PlayerView) async -> TradeResponse
}

public enum OpponentFactory {
    /// The opponent for an effort level: the heuristic at every level. Captain and Admiral play Mate's
    /// profile until Plan 4 adds rollout search above it.
    public static func make(level: EffortLevel, seed: UInt64) -> any Opponent {
        HeuristicOpponent(level: level, seed: seed)
    }
}
