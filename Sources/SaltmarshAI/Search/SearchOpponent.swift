import SaltmarshEngine

/// Captain and Admiral: the Plan 2 heuristic draws up the short list and gives the fallback answer, and
/// rollout search over guessed hands picks among them within the level's budget. One generator serves both.
public actor SearchOpponent: Opponent {
    public let level: EffortLevel
    private let profile: LevelProfile
    private let budget: SearchBudget
    private var rng: SeededRNG
    private var memory = TurnMemory()
    private var thought: Thought?

    public init(level: EffortLevel, seed: UInt64) {
        let profile = LevelProfile.forLevel(level)
        self.init(level: level, seed: seed, budget: profile.search ?? LevelProfile.forLevel(.captain).search!)
    }

    /// The tests and the benchmark's fast mode pass their own budget.
    init(level: EffortLevel, seed: UInt64, budget: SearchBudget) {
        self.level = level
        profile = .forLevel(level)
        self.budget = budget
        rng = SeededRNG(seed: seed)
    }

    public func chooseMove(view: PlayerView, legal: [Move]) async -> Move {
        let candidates = HeuristicPolicy.candidates(view: view, legal: legal, profile: profile, memory: &memory, rng: &rng)
        switch candidates.count {
        case 0: return HeuristicPolicy.choose(view: view, legal: legal, profile: profile, memory: &memory, rng: &rng)
        case 1: return candidates[0]
        default: return remember(RolloutSearch.choose(view: view, candidates: candidates, budget: budget, rng: &rng), over: candidates.count).move
        }
    }

    /// The last searched decision's measurements, reported once.
    public func lastThought() async -> Thought? {
        defer { thought = nil }
        return thought
    }

    private func remember(_ d: RolloutSearch.Decision, over moves: Int) -> RolloutSearch.Decision {
        let seconds = Double(d.elapsed.components.seconds) + Double(d.elapsed.components.attoseconds) / 1e18
        thought = Thought(moves: moves, hands: d.samples, playouts: d.playouts, seconds: seconds, outOfTime: d.outOfTime, changedMind: d.changedMind)
        return d
    }

    /// The heuristic's answer first; when accepting is also open, both are played out. A counter the heuristic
    /// suggests is tried too, and skipped in any sample where the guessed proposer could not pay it.
    public func respondToTrade(_ offer: TradeOffer, view: PlayerView) async -> TradeResponse {
        let first = HeuristicPolicy.respond(to: offer, view: view, profile: profile)
        guard view.hand.contains(offer.want) else { return .declined }
        var answers = [first]
        for answer in [TradeResponse.accepted, .declined] where answer != first { answers.append(answer) }
        let candidates = answers.map { Move.respondToTrade(seat: view.me, $0) }
        let decision = remember(RolloutSearch.choose(view: view, candidates: candidates, budget: budget, rng: &rng), over: candidates.count)
        if case .respondToTrade(_, let answer) = decision.move { return answer }
        return first
    }
}
