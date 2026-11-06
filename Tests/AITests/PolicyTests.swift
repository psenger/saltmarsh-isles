import Testing
@testable import SaltmarshEngine
import SaltmarshTestSupport
@testable import SaltmarshAI

@Suite struct PolicyTests {
    func decide(_ s: GameState, as seat: Int = 0, level: EffortLevel = .mate, seed: UInt64 = 1) -> Move {
        var memory = TurnMemory(), rng = SeededRNG(seed: seed)
        return HeuristicPolicy.choose(view: Engine.view(s, for: seat), legal: Engine.legalMoves(s), profile: .forLevel(level), memory: &memory, rng: &rng)
    }
    func robberMove(_ s: GameState, level: EffortLevel) -> Int {
        var rng = SeededRNG(seed: 1)
        guard case .moveRobber(let t) = HeuristicPolicy.robber(view: Engine.view(s, for: 0), legal: Engine.legalMoves(s), profile: .forLevel(level), rng: &rng) else { Issue.record("not a robber move"); return -1 }
        return t
    }
    @Test func setupTakesTheBestScoredCornerThenARoadWithProspects() {
        var s = TestGames.afterSetup(seed: 3); s.clearBoard(); s.current = 0; s.phase = .setup(step: 0, placingRoad: false, lastSettlement: nil)
        let best = s.board.corners.indices.filter { BoardFacts.settleable($0, board: s.board) }
            .max { (BoardFacts.spotScore($0, board: s.board, produces: ResourceCounts()), -$0) < (BoardFacts.spotScore($1, board: s.board, produces: ResourceCounts()), -$1) }!
        #expect(decide(s) == .placeSettlement(corner: best))
        s.place(settlement: best, owner: 0); s.phase = .setup(step: 0, placingRoad: true, lastSettlement: best)
        guard case .placeRoad(let e) = decide(s) else { Issue.record("expected a setup road"); return }
        #expect(s.board.edges[e].a == best || s.board.edges[e].b == best)
    }
    @Test func playsKnightBeforeRollingWhenRobbed() {                                             // Review Focus 4
        var s = TestGames.afterSetup(seed: 1); s.current = 0; s.phase = .awaitingRoll
        let own = s.board.corners.firstIndex { $0.owner == 0 }!; s.robberTile = s.board.corners[own].tiles[0]
        s.players[0].devCards = [DevCard(type: .knight, boughtOnTurn: -1)]
        #expect(decide(s) == .playKnight)
        s.players[0].devCards = [DevCard(type: .knight, boughtOnTurn: s.turn)]
        #expect(decide(s) == .roll)
        s.players[0].devCards = []; s.robberTile = s.board.desertTile
        #expect(decide(s) == .roll)
    }
    @Test func buildsCityBeforeSettlementOnTheRicherCorner() {
        var s = TestGames.rolled(8); s.set(hand: Cost.city + Cost.settlement, for: 0)
        let mine = s.board.corners.indices.filter { s.board.corners[$0].owner == 0 && !s.board.corners[$0].isCity }
        let richest = mine.max { (BoardFacts.cornerPips($0, board: s.board), -$0) < (BoardFacts.cornerPips($1, board: s.board), -$1) }!
        #expect(decide(s) == .upgradeCity(corner: richest))
    }
    @Test func discardsThroughGoals() {
        var s = TestGames.afterSetup(seed: 1); s.clearHands()
        s.set(hand: [.timber: 3, .clay: 1, .wool: 1, .grain: 1, .ore: 2], for: 1)
        s.current = 0; s.phase = .awaitingRoll; s.force(roll: 7); try! Engine.apply(.roll, to: &s)
        #expect(s.phase == .discarding(queue: [1]))
        let move = decide(s, as: 1)
        #expect(Engine.isLegal(move, in: s))
        #expect(move == .discard(Goals.discard(from: s.players[1].hand, count: 4, keeping: Goals.nearest(view: Engine.view(s, for: 1)))))
    }
    @Test func robberStyleFollowsTheLevel() {
        var s = TestGames.afterSetup(seed: 2); s.clearHands(); s.set(hand: [.ore: 4], for: 1); s.set(hand: [.wool: 1], for: 2)
        s.current = 0; s.phase = .movingRobber(returnTo: .main)
        let own = Set(s.board.corners.indices.filter { s.board.corners[$0].owner == 0 }.flatMap { s.board.corners[$0].tiles })
        let v = Engine.view(s, for: 0)
        func weight(_ t: Int, of seats: Set<Int>) -> Int { s.board.tiles[t].corners.filter { s.board.corners[$0].owner.map(seats.contains) ?? false }.reduce(0) { $0 + s.board.tiles[t].pips * (s.board.corners[$1].isCity ? 2 : 1) } }
        let leader = v.opponents.max { ($0.publicPoints, $0.cardCount, -$0.index) < ($1.publicPoints, $1.cardCount, -$1.index) }!.index
        for level in [EffortLevel.deckhand, .sailor, .mate] {
            let t = robberMove(s, level: level)
            #expect(!own.contains(t)); #expect(t != s.robberTile)
        }
        let rich = robberMove(s, level: .sailor), lead = robberMove(s, level: .mate)
        for t in s.board.tiles.indices where !own.contains(t) && t != s.robberTile {
            #expect(weight(rich, of: [1, 2]) >= weight(t, of: [1, 2])); #expect(weight(lead, of: [leader]) >= weight(t, of: [leader]))
        }
    }
    @Test func robberFallsBackWhenEveryTileIsItsOwn() {                                           // Review Focus 2
        var s = TestGames.afterSetup(seed: 1); s.clearBoard()
        for t in s.board.tiles.indices { s.place(settlement: s.board.tiles[t].corners[0], owner: 0) }
        s.current = 0; s.phase = .movingRobber(returnTo: .main)
        for level in EffortLevel.allCases { #expect(Engine.isLegal(decide(s, level: level), in: s)) }
    }
    @Test func stealsFromTheFullestHand() {
        var s = TestGames.afterSetup(seed: 1); s.clearHands(); s.set(hand: [.ore: 5], for: 1); s.set(hand: [.wool: 2], for: 2)
        s.current = 0; s.phase = .choosingVictim(candidates: [1, 2], returnTo: .main)
        #expect(decide(s) == .steal(from: 1))
    }
    @Test func freeRoadsHeadForTheTarget() {
        var s = TestGames.afterSetup(seed: 1); s.current = 0; s.phase = .placingFreeRoads(remaining: 2)
        let t = BoardFacts.bestTarget(for: 0, board: s.board, produces: BoardFacts.production(of: 0, board: s.board), roadsLeft: 13)!
        #expect(decide(s) == BoardFacts.roadToward(t.corner, legal: Engine.legalMoves(s), board: s.board, seat: 0))
    }
    @Test func endsTheTurnWithNothingToDo() {
        var s = TestGames.rolled(8); s.clearHands()
        #expect(decide(s) == .endTurn)
    }
    @Test func deckhandBlundersAboutAThirdOfTheTime() {
        var s = TestGames.rolled(8); s.set(hand: Cost.city + Cost.settlement + Cost.road, for: 0)
        let v = Engine.view(s, for: 0), legal = Engine.legalMoves(s)
        func run(_ level: EffortLevel) -> [Move] {
            var memory = TurnMemory(), rng = SeededRNG(seed: 7)
            return (0..<300).map { _ in HeuristicPolicy.choose(view: v, legal: legal, profile: .forLevel(level), memory: &memory, rng: &rng) }
        }
        let mate = run(.mate), deckhand = run(.deckhand)
        #expect(Set(mate).count == 1)
        let differs = deckhand.filter { $0 != mate[0] }.count
        #expect((60...140).contains(differs))
        #expect(deckhand.allSatisfy { Engine.isLegal($0, in: s) })
    }
}
