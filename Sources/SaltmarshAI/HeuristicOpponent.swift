import SaltmarshEngine

/// The heuristic brain behind every effort level. Owns its generator and its memory of the turn. Captain
/// and Admiral share Mate's profile until Plan 4 puts rollout search on top.
public actor HeuristicOpponent: Opponent {
    public let level: EffortLevel
    private let profile: LevelProfile
    private var rng: SeededRNG
    private var memory = TurnMemory()

    public init(level: EffortLevel, seed: UInt64) {
        self.level = level
        profile = .forLevel(level)
        rng = SeededRNG(seed: seed)
    }

    public func chooseMove(view: PlayerView, legal: [Move]) async -> Move {
        HeuristicPolicy.choose(view: view, legal: legal, profile: profile, memory: &memory, rng: &rng)
    }

    public func respondToTrade(_ offer: TradeOffer, view: PlayerView) async -> TradeResponse {
        HeuristicPolicy.respond(to: offer, view: view, profile: profile)
    }
}
