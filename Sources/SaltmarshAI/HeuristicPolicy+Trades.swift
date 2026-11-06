import SaltmarshEngine

/// Trading: offers that complete a build, harbour and bank trades, answers to offers, and what the
/// proposer does once everyone has answered.
extension HeuristicPolicy {
    /// handValue after paying and receiving, minus handValue now, toward the nearest goal.
    static func gain(view: PlayerView, paying: ResourceCounts, receiving: ResourceCounts) -> Int {
        let plan = Goals.nearest(view: view)
        return Goals.handValue(view.hand - paying + receiving, toward: plan) - Goals.handValue(view.hand, toward: plan)
    }

    /// Main-phase step 9. Only when the nearest goal is exactly one card short: an offer of surplus for it
    /// (1 for 1, then 2 for 1), never the same offer twice in a turn; else the cheapest harbour trade that
    /// completes it without breaking it; else the bank.
    static func tradeToComplete(view: PlayerView, legal: [Move], profile: LevelProfile, memory: inout TurnMemory) -> Move? {
        guard let plan = Goals.nearest(view: view), plan.missing.total == 1,
              let wanted = Resource.allCases.first(where: { plan.missing[$0] > 0 }) else { return nil }
        let surplus = Goals.surplus(of: view.hand, over: plan)
        if profile.proposes, let give = largest(surplus) {
            for count in 1...2 where surplus[give] >= count {
                let offer = TradeOffer(proposer: view.me, give: [give: count], want: [wanted: 1], to: nil)
                if memory.proposed.insert(offer).inserted { return .proposeTrade(offer) }
            }
        }
        var harbour: (move: Move, rank: (Int, Int, Int))?
        for move in legal {
            guard case .harbourTrade(let h, let give, let get) = move, get == wanted else { continue }
            let ratio = view.board.harbours[h].ratio
            guard view.hand[give] - ratio >= plan.goal.cost[give] else { continue }
            let rank = (-ratio, surplus[give], -h)
            if harbour == nil || rank > harbour!.rank { harbour = (move, rank) }
        }
        if let harbour { return harbour.move }
        var bank: (move: Move, surplus: Int)?
        for move in legal {
            guard case .bankTrade(let give, let get) = move, get == wanted, view.hand[give] - 4 >= plan.goal.cost[give] else { continue }
            if bank == nil || surplus[give] > bank!.surplus { bank = (move, surplus[give]) }
        }
        return bank?.move
    }

    /// Declines when the level never trades or the hand cannot pay; accepts a gain at or above the level's
    /// threshold; a Mate counters by asking for one more card of what it still lacks; otherwise declines.
    static func respond(to offer: TradeOffer, view: PlayerView, profile: LevelProfile) -> TradeResponse {
        guard let threshold = profile.acceptThreshold, view.hand.contains(offer.want) else { return .declined }
        if gain(view: view, paying: offer.want, receiving: offer.give) >= threshold { return .accepted }
        guard profile.counters, let plan = Goals.nearest(view: view) else { return .declined }
        var stillMissing = Goals.missing(plan.goal.cost, from: view.hand - offer.want + offer.give)
        for r in Resource.allCases where offer.want[r] > 0 { stillMissing[r] = 0 }
        guard let extra = largest(stillMissing) else { return .declined }
        var counter = offer
        counter.give[extra] += 1
        counter.to = view.me
        return gain(view: view, paying: counter.want, receiving: counter.give) >= threshold ? .countered(counter) : .declined
    }

    /// Every answer is in: execute the best one, on the counter's terms where there was one; ties go to the
    /// seat with the fewest points. An accepted offer was the seat's own and completes a build, so any gain
    /// takes it; a counter has to clear the level's threshold. Otherwise withdraw.
    static func proposerDecision(view: PlayerView, legal: [Move], profile: LevelProfile) -> Move {
        let withdraw = legal.contains(.withdrawTrade) ? Move.withdrawTrade : legal[0]
        guard case .tradeOffered(let offer, let responses) = view.phase else { return withdraw }
        var best: (move: Move, rank: (Int, Int, Int))?
        for move in legal {
            guard case .executeTrade(let seat) = move else { continue }
            var terms = offer, bar = 1
            if case .countered(let counter)? = responses[seat] { terms = counter; bar = profile.acceptThreshold ?? 1 }
            let g = gain(view: view, paying: terms.give, receiving: terms.want)
            guard g >= bar else { continue }
            let points = view.opponents.first { $0.index == seat }?.publicPoints ?? 0
            let rank = (g, -points, -seat)
            if best == nil || rank > best!.rank { best = (move, rank) }
        }
        return best?.move ?? withdraw
    }

    /// The resource with the most cards; nil when there are none; ties go to the earlier resource.
    private static func largest(_ c: ResourceCounts) -> Resource? {
        var best: Resource?
        for r in Resource.allCases where c[r] > 0 && (best == nil || c[r] > c[best!]) { best = r }
        return best
    }
}
