import SaltmarshEngine

enum RobberStyle: Sendable { case random, richest, leader }

/// The knobs that differ between effort levels. Captain and Admiral share Mate's until Plan 4 adds search.
struct LevelProfile: Sendable {
    /// One move in N is random; 0 never.
    var blunderOdds: Int
    var robber: RobberStyle
    /// Accept an offer whose gain reaches this; nil declines every offer.
    var acceptThreshold: Int?
    var counters: Bool
    var proposes: Bool

    static func forLevel(_ level: EffortLevel) -> LevelProfile {
        switch level {
        case .deckhand: LevelProfile(blunderOdds: 3, robber: .random, acceptThreshold: nil, counters: false, proposes: false)
        case .sailor: LevelProfile(blunderOdds: 8, robber: .richest, acceptThreshold: 3, counters: false, proposes: true)
        case .mate, .captain, .admiral: LevelProfile(blunderOdds: 0, robber: .leader, acceptThreshold: 1, counters: true, proposes: true)
        }
    }

    /// Mate that never proposes: what the safety net plays when an opponent's own choice is illegal.
    static let fallback = LevelProfile(blunderOdds: 0, robber: .leader, acceptThreshold: 1, counters: false, proposes: false)
}

/// What an opponent remembers within one turn: the offers it has already made.
struct TurnMemory: Sendable {
    var turn = -1
    var proposed: Set<TradeOffer> = []
}
