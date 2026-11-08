import SaltmarshEngine

/// What the seat could build next, in the order the heuristic prefers them.
enum BuildGoal: CaseIterable, Sendable {
    case city, settlement, road, devCard

    var cost: ResourceCounts {
        switch self {
        case .city: Cost.city
        case .settlement: Cost.settlement
        case .road: Cost.road
        case .devCard: Cost.devCard
        }
    }
}

/// A goal and the cards the hand still lacks for it.
struct GoalPlan: Equatable, Sendable {
    var goal: BuildGoal
    var missing: ResourceCounts
}

enum Goals {
    /// The available goal with the fewest missing cards; ties go to the order city, settlement, road, devCard,
    /// or to the order of `goals` when given.
    static func nearest(view: PlayerView, among goals: [BuildGoal] = BuildGoal.allCases) -> GoalPlan? {
        var best: GoalPlan?
        for goal in goals where available(goal, view: view) {
            let plan = GoalPlan(goal: goal, missing: missing(goal.cost, from: view.hand))
            if best == nil || plan.missing.total < best!.missing.total { best = plan }
        }
        return best
    }

    /// 3 per card the goal needs and the hand holds, 1 per card beyond the goal, minus 2 per card over 7.
    /// With no plan every card counts 1.
    static func handValue(_ hand: ResourceCounts, toward plan: GoalPlan?) -> Int {
        let over = 2 * max(0, hand.total - 7)
        guard let plan else { return hand.total - over }
        var value = 0
        for r in Resource.allCases {
            let need = plan.goal.cost[r]
            value += 3 * min(hand[r], need) + max(0, hand[r] - need)
        }
        return value - over
    }

    /// The hand minus the goal's cost, clipped at 0; the whole hand when there is no plan.
    static func surplus(of hand: ResourceCounts, over plan: GoalPlan?) -> ResourceCounts {
        guard let plan else { return hand }
        return missing(hand, from: plan.goal.cost)
    }

    /// Exactly `count` cards: one at a time from the largest surplus (ties in resource order), then from the
    /// kept cards the same way.
    static func discard(from hand: ResourceCounts, count: Int, keeping plan: GoalPlan?) -> ResourceCounts {
        var out = ResourceCounts()
        var spare = surplus(of: hand, over: plan)
        var kept = hand - spare
        for _ in 0..<count {
            if let r = largest(spare) { spare[r] -= 1; out[r] += 1 }
            else if let r = largest(kept) { kept[r] -= 1; out[r] += 1 }
        }
        return out
    }

    // MARK: Pieces

    /// `wanted` minus `held`, clipped at 0 per resource.
    static func missing(_ wanted: ResourceCounts, from held: ResourceCounts) -> ResourceCounts {
        var m = ResourceCounts()
        for r in Resource.allCases { m[r] = max(0, wanted[r] - held[r]) }
        return m
    }

    private static func available(_ goal: BuildGoal, view: PlayerView) -> Bool {
        let board = view.board, me = view.me
        let left = BoardFacts.piecesLeft(of: me, board: board)
        switch goal {
        case .city:
            return left.cities > 0 && board.corners.contains { $0.owner == me && !$0.isCity }
        case .settlement:
            guard left.settlements > 0 else { return false }
            let d = BoardFacts.distances(from: BoardFacts.network(of: me, board: board), board: board, seat: me)
            return board.corners.indices.contains { d[$0] == 0 && BoardFacts.settleable($0, board: board) }
        case .road:
            guard left.roads > 0 else { return false }
            let produces = BoardFacts.production(of: me, board: board)
            return (BoardFacts.bestTarget(for: me, board: board, produces: produces, roadsLeft: left.roads)?.distance ?? 0) >= 1
        case .devCard:
            return view.deckCount > 0
        }
    }

    /// The resource with the most cards, or nil when there are none; ties go to the earlier resource.
    private static func largest(_ c: ResourceCounts) -> Resource? {
        var best: Resource?
        for r in Resource.allCases where c[r] > 0 && (best == nil || c[r] > c[best!]) { best = r }
        return best
    }
}
