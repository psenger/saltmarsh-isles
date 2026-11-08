import SaltmarshEngine

/// The deterministic brain: from the view, the legal list, a level's knobs, the turn's memory and the
/// opponent's own generator, one move. Trading lives in HeuristicPolicy+Trades.swift.
public enum HeuristicPolicy {
    static func choose(view: PlayerView, legal: [Move], profile: LevelProfile, memory: inout TurnMemory, rng: inout SeededRNG) -> Move {
        precondition(!legal.isEmpty, "no legal moves to choose from")
        if memory.turn != view.turn { memory = TurnMemory(); memory.turn = view.turn }
        if canBlunder(in: view.phase), profile.blunderOdds > 0, rng.next() % UInt64(profile.blunderOdds) == 0 {
            let pool = legal.filter { if case .proposeTrade = $0 { false } else { true } }
            return RandomOpponent.pick(from: pool.isEmpty ? legal : pool, using: &rng)
        }
        switch view.phase {
        case .rollingForFirst: return .rollForFirst
        case .setup(_, false, _): return setupSettlement(view: view, legal: legal)
        case .setup(_, true, let last): return setupRoad(view: view, legal: legal, last: last)
        case .awaitingRoll: return beforeRoll(view: view, legal: legal)
        case .discarding: return .discard(Goals.discard(from: view.hand, count: view.hand.total / 2, keeping: Goals.nearest(view: view)))
        case .movingRobber: return robber(view: view, legal: legal, profile: profile, rng: &rng)
        case .choosingVictim: return victim(view: view, legal: legal)
        case .placingFreeRoads: return freeRoad(view: view, legal: legal)
        case .main: return mainMove(view: view, legal: legal, profile: profile, memory: &memory)
        case .tradeOffered: return proposerDecision(view: view, legal: legal, profile: profile)
        default: return legal[0]
        }
    }

    /// Mate without proposals, fresh memory, a generator seeded by the turn: the safety net's substitute move.
    /// The one entry point the game layer uses; everything else stays inside the AI package.
    public static func fallback(view: PlayerView, legal: [Move]) -> Move {
        var memory = TurnMemory(), rng = SeededRNG(seed: UInt64(max(0, view.turn)))
        return choose(view: view, legal: legal, profile: .fallback, memory: &memory, rng: &rng)
    }

    // MARK: Phases

    private static func canBlunder(in phase: Phase) -> Bool {
        switch phase {
        case .setup, .main, .placingFreeRoads, .movingRobber, .discarding: true
        default: false
        }
    }

    private static func setupSettlement(view: PlayerView, legal: [Move]) -> Move {
        let produces = BoardFacts.production(of: view.me, board: view.board)
        let corners = legal.compactMap { if case .placeSettlement(let c) = $0 { c } else { nil } }
        return bestBy(corners) { BoardFacts.spotScore($0, board: view.board, produces: produces) }.map { .placeSettlement(corner: $0) } ?? legal[0]
    }

    /// The road whose far end has the best settleable corner on or next to it: the best spot within two edges.
    static func setupRoad(view: PlayerView, legal: [Move], last: Int?) -> Move {
        let board = view.board, produces = BoardFacts.production(of: view.me, board: board)
        let roads = legal.compactMap { if case .placeRoad(let e) = $0 { e } else { nil } }
        func prospect(_ e: Int) -> Int {
            let edge = board.edges[e], far = edge.a == last ? edge.b : edge.a
            return ([far] + board.corners[far].adjacent).filter { BoardFacts.settleable($0, board: board) }
                .map { BoardFacts.spotScore($0, board: board, produces: produces) }.max() ?? -1
        }
        return bestBy(roads, score: prospect).map { .placeRoad(edge: $0) } ?? legal[0]
    }

    private static func beforeRoll(view: PlayerView, legal: [Move]) -> Move {
        if legal.contains(.playKnight), robberOnMyTile(view) { return .playKnight }
        return legal.contains(.roll) ? .roll : legal[0]
    }

    static func robber(view: PlayerView, legal: [Move], profile: LevelProfile, rng: inout SeededRNG) -> Move {
        let pool = robberPool(view: view, legal: legal)
        guard !pool.isEmpty else { return legal[0] }
        switch profile.robber {
        case .random: return .moveRobber(tile: pool[Int(rng.next() % UInt64(pool.count))])
        case .richest: return .moveRobber(tile: rankedRobberTiles(view: view, legal: legal, of: Set(view.opponents.map(\.index)))[0])
        case .leader: return .moveRobber(tile: rankedRobberTiles(view: view, legal: legal, of: leader(view).map { [$0] } ?? [])[0])
        }
    }

    /// The legal robber tiles that touch none of the seat's own buildings, or all of them when every tile does.
    static func robberPool(view: PlayerView, legal: [Move]) -> [Int] {
        let board = view.board
        let candidates = legal.compactMap { if case .moveRobber(let t) = $0 { t } else { nil } }
        let notMine = candidates.filter { t in !board.tiles[t].corners.contains { board.corners[$0].owner == view.me } }
        return notMine.isEmpty ? candidates : notMine
    }

    /// The pool, best first: the pips `seats` lose on the tile (a city counts twice), then the cards held by
    /// everyone built there, then the lower index.
    static func rankedRobberTiles(view: PlayerView, legal: [Move], of seats: Set<Int>) -> [Int] {
        let board = view.board
        func weight(_ t: Int) -> Int {
            board.tiles[t].corners.filter { board.corners[$0].owner.map(seats.contains) ?? false }
                .reduce(0) { $0 + board.tiles[t].pips * (board.corners[$1].isCity ? 2 : 1) }
        }
        func cards(_ t: Int) -> Int {
            let owners = Set(board.tiles[t].corners.compactMap { board.corners[$0].owner })
            return view.opponents.filter { owners.contains($0.index) }.reduce(0) { $0 + $1.cardCount }
        }
        return robberPool(view: view, legal: legal).sorted { (weight($0), cards($0), -$0) > (weight($1), cards($1), -$1) }
    }

    private static func victim(view: PlayerView, legal: [Move]) -> Move {
        let seats = legal.compactMap { if case .steal(let from) = $0 { from } else { nil } }
        func rank(_ seat: Int) -> (Int, Int, Int) {
            let o = view.opponents.first { $0.index == seat }
            return (o?.cardCount ?? 0, o?.publicPoints ?? 0, -seat)
        }
        return seats.max { rank($0) < rank($1) }.map { .steal(from: $0) } ?? legal[0]
    }

    private static func freeRoad(view: PlayerView, legal: [Move]) -> Move {
        if let target = roadTarget(view), let road = BoardFacts.roadToward(target.corner, legal: legal, board: view.board, seat: view.me) { return road }
        return legal.first { if case .placeRoad = $0 { true } else { false } } ?? legal[0]
    }

    static func mainMove(view: PlayerView, legal: [Move], profile: LevelProfile, memory: inout TurnMemory) -> Move {
        let board = view.board, me = view.me
        let plan = Goals.nearest(view: view)
        let maxOppKnights = view.opponents.map(\.knightsPlayed).max() ?? 0
        let maxOppRoad = view.opponents.map(\.roadLength).max() ?? 0
        if legal.contains(.playKnight) {
            let mine = view.knightsPlayed
            let takes = view.largestArmyHolder != me && mine + 1 >= 3 && mine + 1 > maxOppKnights
            let keeps = view.largestArmyHolder == me && maxOppKnights >= mine
            if takes || keeps || robberOnMyTile(view) { return .playKnight }
        }
        if let plan, let harvest = bumperHarvest(completing: plan, hand: view.hand, legal: legal) { return harvest }
        if legal.contains(.playRoadCrew) {
            let left = BoardFacts.piecesLeft(of: me, board: board), produces = BoardFacts.production(of: me, board: board)
            let near = BoardFacts.bestTarget(for: me, board: board, produces: produces, roadsLeft: min(2, left.roads), minDistance: 1) != nil
            let wins = view.roadLength + 2 >= 5 && view.roadLength + 2 > maxOppRoad && view.longestRoadHolder != me
            if near || wins { return .playRoadCrew }
        }
        if let plan, let r = singleMissing(plan), legal.contains(.playCornerMarket(r)), heldByOpponents(r, view: view) > 0,
           view.opponents.reduce(0, { $0 + BoardFacts.production(of: $1.index, board: board)[r] }) >= 4 {
            return .playCornerMarket(r)
        }
        let cities = legal.compactMap { if case .upgradeCity(let c) = $0 { c } else { nil } }
        if let c = bestBy(cities, score: { BoardFacts.cornerPips($0, board: board) }) { return .upgradeCity(corner: c) }
        let produces = BoardFacts.production(of: me, board: board)
        let spots = legal.compactMap { if case .placeSettlement(let c) = $0 { c } else { nil } }
        if let c = bestBy(spots, score: { BoardFacts.spotScore($0, board: board, produces: produces) }) { return .placeSettlement(corner: c) }
        if let road = roadMove(view: view, legal: legal, maxOppRoad: maxOppRoad) { return road }
        // The card itself is always an affordable goal here, so the close goal is the nearest build.
        if legal.contains(.buyDevCard),
           !spendsGoalCards(Cost.devCard, hand: view.hand, plan: Goals.nearest(view: view, among: [.city, .settlement, .road])) { return .buyDevCard }
        if let trade = tradeToComplete(view: view, legal: legal, profile: profile, memory: &memory) { return trade }
        return legal.contains(.endTurn) ? .endTurn : legal[0]
    }

    // MARK: Pieces of the main phase

    /// A pair whose cards complete the goal, when the goal is one or two cards short.
    static func bumperHarvest(completing plan: GoalPlan, hand: ResourceCounts, legal: [Move]) -> Move? {
        guard (1...2).contains(plan.missing.total) else { return nil }
        return legal.first { move in
            guard case .playBumperHarvest(let a, let b) = move else { return false }
            var after = hand; after[a] += 1; after[b] += 1
            return after.contains(plan.goal.cost)
        }
    }

    /// Paying `cost` from `hand` would spend cards the plan needs, and the plan is one or two cards short.
    static func spendsGoalCards(_ cost: ResourceCounts, hand: ResourceCounts, plan: GoalPlan?) -> Bool {
        guard let plan, (1...2).contains(plan.missing.total) else { return false }
        return !Goals.surplus(of: hand, over: plan).contains(cost)
    }

    /// Cards of `r` in the other hands: 19 of each exist, and the bank's count and my hand are public to me.
    static func heldByOpponents(_ r: Resource, view: PlayerView) -> Int {
        max(0, 19 - view.bank[r] - view.hand[r])
    }

    /// The one resource the plan is short of, when it is short of exactly one kind.
    static func singleMissing(_ plan: GoalPlan) -> Resource? {
        let short = Resource.allCases.filter { plan.missing[$0] > 0 }
        return short.count == 1 ? short[0] : nil
    }

    /// A road that takes or defends longest road, else one step toward the best target.
    static func roadMove(view: PlayerView, legal: [Move], maxOppRoad: Int) -> Move? {
        let board = view.board, me = view.me
        let roads = legal.compactMap { if case .placeRoad(let e) = $0 { e } else { nil } }
        guard !roads.isEmpty else { return nil }
        var longest: (edge: Int, length: Int)?
        for e in roads {
            var after = board; after.edges[e].owner = me
            let length = Engine.roadLength(board: after, player: me)
            if longest == nil || length > longest!.length { longest = (e, length) }
        }
        if let l = longest, l.length >= 5, l.length > maxOppRoad,
           view.longestRoadHolder != me || maxOppRoad >= view.roadLength {
            return .placeRoad(edge: l.edge)
        }
        guard let target = roadTarget(view) else { return nil }
        return BoardFacts.roadToward(target.corner, legal: legal, board: board, seat: me)
    }

    /// The best settleable corner at least one road away, within the roads the seat has left.
    private static func roadTarget(_ view: PlayerView) -> (corner: Int, distance: Int)? {
        let left = BoardFacts.piecesLeft(of: view.me, board: view.board)
        let produces = BoardFacts.production(of: view.me, board: view.board)
        return BoardFacts.bestTarget(for: view.me, board: view.board, produces: produces, roadsLeft: left.roads, minDistance: 1)
    }

    private static func robberOnMyTile(_ view: PlayerView) -> Bool {
        view.board.tiles[view.robberTile].corners.contains { view.board.corners[$0].owner == view.me }
    }

    /// The opponent with the most public points; ties go to the most cards, then the lowest seat.
    static func leader(_ view: PlayerView) -> Int? {
        view.opponents.max { ($0.publicPoints, $0.cardCount, -$0.index) < ($1.publicPoints, $1.cardCount, -$1.index) }?.index
    }

    /// The candidate with the highest score; ties go to the lowest candidate.
    static func bestBy(_ candidates: [Int], score: (Int) -> Int) -> Int? {
        var best: (value: Int, score: Int)?
        for c in candidates {
            let s = score(c)
            if best == nil || s > best!.score || (s == best!.score && c < best!.value) { best = (c, s) }
        }
        return best?.value
    }
}
