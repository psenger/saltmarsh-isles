import SaltmarshEngine

enum RobberStyle: Sendable { case random, richest, leader }

/// The knobs that differ between effort levels. Captain and Admiral play Mate's heuristic with rollout search on top.
struct LevelProfile: Sendable {
    /// One move in N is random; 0 never.
    var blunderOdds: Int
    var robber: RobberStyle
    /// Accept an offer whose gain reaches this; nil declines every offer.
    var acceptThreshold: Int?
    var counters: Bool
    var proposes: Bool
    /// Rollout search above the heuristic; nil for the levels that play the heuristic alone.
    var search: SearchBudget? = nil

    static func forLevel(_ level: EffortLevel) -> LevelProfile {
        switch level {
        case .deckhand: return LevelProfile(blunderOdds: 3, robber: .random, acceptThreshold: nil, counters: false, proposes: false)
        case .sailor: return LevelProfile(blunderOdds: 8, robber: .richest, acceptThreshold: 3, counters: false, proposes: true)
        case .mate: return LevelProfile(blunderOdds: 0, robber: .leader, acceptThreshold: 1, counters: true, proposes: true)
        case .captain:
            var p = forLevel(.mate); p.search = SearchBudget(samples: 16, rounds: 1, playouts: 300, timeCap: .milliseconds(750)); return p
        case .admiral:
            var p = forLevel(.mate); p.search = SearchBudget(samples: 32, rounds: 2, playouts: 1500, timeCap: .milliseconds(1500)); return p
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
