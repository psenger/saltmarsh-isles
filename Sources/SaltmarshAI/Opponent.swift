import SaltmarshEngine

/// An AI seat. It only ever sees a `PlayerView` (its own cards, everyone else's counts) and the
/// legal moves; the live game never enters this module.
public protocol Opponent: Sendable {
    func chooseMove(view: PlayerView, legal: [Move]) async -> Move
    func respondToTrade(_ offer: TradeOffer, view: PlayerView) async -> TradeResponse
}

public enum OpponentFactory {
    /// The opponent for an effort level. Every level is the seeded random stand-in until the
    /// heuristic and search opponents land (Plans 2 and 4).
    public static func make(level: EffortLevel, seed: UInt64) -> any Opponent {
        RandomOpponent(seed: seed)
    }
}
