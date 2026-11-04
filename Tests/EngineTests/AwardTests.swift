import Testing
@testable import SaltmarshEngine
import SaltmarshTestSupport

@Suite struct AwardTests {
    func board() -> (GameState, Set<Int>) { var s = TestGames.afterSetup(); s.clearBoard(); return (s, []) }
    /// The single corner shared by two consecutive chain edges.
    func junction(_ s: GameState, _ e1: Int, _ e2: Int) -> Int {
        Set([s.board.edges[e1].a, s.board.edges[e1].b]).intersection([s.board.edges[e2].a, s.board.edges[e2].b]).first!
    }
    @Test func sixRoadsClaimLongestRoad() {
        var (s, used) = board(); s.placeChain(s.chain(from: 0, length: 6, avoiding: &used), owner: 0)
        #expect(Engine.roadLength(s, player: 0) == 6)
        Engine.updateAwards(&s)
        #expect(s.longestRoadHolder == 0); #expect(s.log.last == "Crimson takes longest road (6).")
    }
    @Test func yShapeMeasuresTwo() {
        var (s, _) = board(); for e in s.board.corners[20].edges { s.place(road: e, owner: 0) }
        #expect(s.board.corners[20].edges.count == 3); #expect(Engine.roadLength(s, player: 0) == 2)
    }
    @Test func tieKeepsHolderStrictlyLongerTakes() {
        var (s, used) = board()
        s.placeChain(s.chain(from: 0, length: 6, avoiding: &used), owner: 0); Engine.updateAwards(&s)
        let cobalt = s.chain(from: 30, length: 7, avoiding: &used)
        s.placeChain(Array(cobalt.prefix(6)), owner: 1); Engine.updateAwards(&s)
        #expect(s.longestRoadHolder == 0)
        s.place(road: cobalt[6], owner: 1); Engine.updateAwards(&s)
        #expect(s.longestRoadHolder == 1); #expect(s.log.last == "Cobalt takes longest road (7).")
    }
    @Test func settlementCutsRoad() {
        var (s, used) = board(); let edges = s.chain(from: 0, length: 6, avoiding: &used)
        s.placeChain(edges, owner: 0); Engine.updateAwards(&s)
        let middle = junction(s, edges[2], edges[3])
        s.place(settlement: middle, owner: 1); Engine.updateAwards(&s)
        #expect(Engine.roadLength(s, player: 0) == 3); #expect(s.longestRoadHolder == nil)
        #expect(s.log.last == "Nobody holds longest road now.")
    }
    @Test func cutHolderWithTwoOthersTiedLeavesNobody() {
        var (s, used) = board(); let crimson = s.chain(from: 0, length: 6, avoiding: &used)
        s.placeChain(crimson, owner: 0); Engine.updateAwards(&s)
        s.placeChain(s.chain(from: 25, length: 6, avoiding: &used), owner: 1)
        s.placeChain(s.chain(from: 45, length: 6, avoiding: &used), owner: 2); Engine.updateAwards(&s)
        #expect(s.longestRoadHolder == 0)
        let shared = junction(s, crimson[2], crimson[3])
        s.place(settlement: shared, owner: 1); Engine.updateAwards(&s)
        #expect(s.longestRoadHolder == nil)
    }
    @Test func trailStopsAtOpponentBuilding() {
        var (s, used) = board(); let edges = s.chain(from: 0, length: 4, avoiding: &used); s.placeChain(edges, owner: 0)
        let shared = junction(s, edges[1], edges[2])
        s.place(settlement: shared, owner: 1)
        #expect(Engine.roadLength(s, player: 0) == 2)
    }
    @Test func largestArmy() {
        var (s, _) = board()
        s.players[0].knightsPlayed = 3; Engine.updateAwards(&s)
        #expect(s.largestArmyHolder == 0); #expect(s.log.last == "Crimson takes largest army (3 knights).")
        s.players[1].knightsPlayed = 3; Engine.updateAwards(&s); #expect(s.largestArmyHolder == 0)
        s.players[1].knightsPlayed = 4; Engine.updateAwards(&s); #expect(s.largestArmyHolder == 1)
    }
}
