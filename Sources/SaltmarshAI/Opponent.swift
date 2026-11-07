import SaltmarshEngine

/// An AI seat. It only ever sees a `PlayerView` (its own cards, everyone else's counts) and the
/// legal moves; the live game never enters this module.
public protocol Opponent: Sendable {
    func chooseMove(view: PlayerView, legal: [Move]) async -> Move
    func respondToTrade(_ offer: TradeOffer, view: PlayerView) async -> TradeResponse
    /// How hard the seat thought about its last answer, reported once; nil when it did not search.
    func lastThought() async -> Thought?
}

public extension Opponent {
    func lastThought() async -> Thought? { nil }
}

/// What a searching seat did before a decision, for the game log.
public struct Thought: Sendable, Equatable {
    /// Candidate moves weighed.
    public var moves: Int
    /// Guessed full states played out.
    public var hands: Int
    public var playouts: Int
    public var seconds: Double
    /// The wall-clock cap stopped the search before its count was spent.
    public var outOfTime: Bool
    /// The search overruled the heuristic's own choice.
    public var changedMind: Bool
}

public enum OpponentFactory {
    /// The opponent for an effort level: the heuristic alone for Deckhand, Sailor and Mate; the heuristic with
    /// rollout search for Captain and Admiral.
    public static func make(level: EffortLevel, seed: UInt64) -> any Opponent {
        LevelProfile.forLevel(level).search == nil ? HeuristicOpponent(level: level, seed: seed) : SearchOpponent(level: level, seed: seed)
    }
}
