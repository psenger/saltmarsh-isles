import SaltmarshEngine

/// An AI seat. It only ever sees a `PlayerView` (its own cards, everyone else's counts) and the
/// legal moves; the live game never enters this module.
public protocol Opponent: Sendable {
    func chooseMove(view: PlayerView, legal: [Move]) async -> Move
    func respondToTrade(_ offer: TradeOffer, view: PlayerView) async -> TradeResponse
}

public enum OpponentFactory {
    /// The opponent for an effort level: the heuristic alone for Deckhand, Sailor and Mate; the heuristic with
    /// rollout search for Captain and Admiral.
    public static func make(level: EffortLevel, seed: UInt64) -> any Opponent {
        LevelProfile.forLevel(level).search == nil ? HeuristicOpponent(level: level, seed: seed) : SearchOpponent(level: level, seed: seed)
    }
}
