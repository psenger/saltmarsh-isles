import SaltmarshEngine

/// The short list a Captain or Admiral searches over at one decision (design section 6.3), the heuristic's
/// own choice first. Empty for a step that is never searched (rolling, a forced move); a single entry when
/// the step had one option, so the caller need not ask the policy twice.
extension HeuristicPolicy {
    static let candidateCap = 6

    static func candidates(view: PlayerView, legal: [Move], profile: LevelProfile, memory: inout TurnMemory, rng: inout SeededRNG) -> [Move] {
        if memory.turn != view.turn { memory = TurnMemory(); memory.turn = view.turn }
        let board = view.board, me = view.me
        let list: [Move]
        switch view.phase {
        case .setup(_, false, _):
            let produces = BoardFacts.production(of: me, board: board)
            let corners = legal.compactMap { if case .placeSettlement(let c) = $0 { c } else { nil } }
            list = corners.sorted { (BoardFacts.spotScore($0, board: board, produces: produces), -$0) > (BoardFacts.spotScore($1, board: board, produces: produces), -$1) }
                .prefix(4).map { .placeSettlement(corner: $0) }
        case .setup(_, true, let last):
            list = [setupRoad(view: view, legal: legal, last: last)] + legal.filter { if case .placeRoad = $0 { true } else { false } }
        case .main:
            list = mainCandidates(view: view, legal: legal, profile: profile, memory: &memory)
        case .movingRobber:
            let seats: Set<Int> = profile.robber == .leader ? (leader(view).map { [$0] } ?? []) : Set(view.opponents.map(\.index))
            list = rankedRobberTiles(view: view, legal: legal, of: seats).prefix(3).map { .moveRobber(tile: $0) }
        case .discarding:
            let count = view.hand.total / 2
            list = [.discard(Goals.discard(from: view.hand, count: count, keeping: Goals.nearest(view: view))),
                    .discard(Goals.discard(from: view.hand, count: count, keeping: nil))]
        case .tradeOffered:
            list = [proposerDecision(view: view, legal: legal, profile: profile)]
                + legal.filter { if case .executeTrade = $0 { return true } else { return $0 == .withdrawTrade } }
        default:
            return []
        }
        var seen = Set<Move>(), out: [Move] = []
        for move in list where legal.contains(move) && seen.insert(move).inserted { out.append(move) }
        if out.count > candidateCap { out = Array(out.prefix(candidateCap)) }
        return out
    }

    /// The main order's own pick, then the best of each kind it would consider, then ending the turn.
    private static func mainCandidates(view: PlayerView, legal: [Move], profile: LevelProfile, memory: inout TurnMemory) -> [Move] {
        let board = view.board, me = view.me
        var list = [mainMove(view: view, legal: legal, profile: profile, memory: &memory)]
        let cities = legal.compactMap { if case .upgradeCity(let c) = $0 { c } else { nil } }
        if let c = bestBy(cities, score: { BoardFacts.cornerPips($0, board: board) }) { list.append(.upgradeCity(corner: c)) }
        let produces = BoardFacts.production(of: me, board: board)
        let spots = legal.compactMap { if case .placeSettlement(let c) = $0 { c } else { nil } }
        if let c = bestBy(spots, score: { BoardFacts.spotScore($0, board: board, produces: produces) }) { list.append(.placeSettlement(corner: c)) }
        let maxOppRoad = view.opponents.map(\.roadLength).max() ?? 0
        if let road = roadMove(view: view, legal: legal, maxOppRoad: maxOppRoad) { list.append(road) }
        if legal.contains(.buyDevCard) { list.append(.buyDevCard) }
        for card in [Move.playKnight, .playRoadCrew] where legal.contains(card) { list.append(card) }
        if let plan = Goals.nearest(view: view) {
            if let harvest = bumperHarvest(completing: plan, hand: view.hand, legal: legal) { list.append(harvest) }
            if let r = singleMissing(plan), legal.contains(.playCornerMarket(r)) { list.append(.playCornerMarket(r)) }
        }
        list.append(.endTurn)
        return list
    }
}
