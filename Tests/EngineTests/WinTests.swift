import Testing
@testable import SaltmarshEngine
import SaltmarshTestSupport

@Suite struct WinTests {
    /// Crimson has rolled; board and hands empty; Crimson owns `settlements` + `cities` buildings on spread corners and a two-road reach to `reach`.
    func crimson(settlements: Int, cities: Int) -> (s: GameState, reach: Int) {
        var s = TestGames.rolled(8); s.clearBoard(); s.clearHands()
        let spots = s.spreadCorners(settlements + cities)
        for c in spots.prefix(settlements) { s.place(settlement: c, owner: 0) }
        for c in spots.dropFirst(settlements) { s.place(city: c, owner: 0) }
        let reach = s.addReach(from: spots[0], owner: 0); return (s, reach)
    }
    @Test func pointsAreCounted() {
        var (s, _) = crimson(settlements: 3, cities: 3)
        #expect(Engine.publicPoints(s, player: 0) == 9); #expect(Engine.totalPoints(s, player: 0) == 9)
        s.players[0].devCards = [DevCard(type: .victoryPoint, boughtOnTurn: 0)]
        #expect(Engine.publicPoints(s, player: 0) == 9); #expect(Engine.hiddenPoints(s, player: 0) == 1); #expect(Engine.totalPoints(s, player: 0) == 10)
    }
    @Test func settlementAtNineWins() throws {
        var (s, reach) = crimson(settlements: 3, cities: 3); s.set(hand: Cost.settlement, for: 0)
        try Engine.apply(.placeSettlement(corner: reach), to: &s)
        #expect(s.phase == .gameOver(winner: 0)); #expect(s.log.last == "Crimson wins with 10 points!")
    }
    @Test func cityAtNineWins() throws {
        // A city replaces a settlement's 1 point with 2, so it adds one point. The feature file's
        // "| 8 | builds a city |" row is wrong and is corrected to 9 in Plan 3.
        var (s, _) = crimson(settlements: 3, cities: 3); s.set(hand: Cost.city, for: 0)
        let c = s.board.corners.indices.first { s.board.corners[$0].owner == 0 && !s.board.corners[$0].isCity }!
        try Engine.apply(.upgradeCity(corner: c), to: &s); #expect(s.phase == .gameOver(winner: 0))
    }
    @Test func longestRoadAtEightWins() throws {
        // The two-road reach plus three more edges makes a five-road trail; the fifth road is the paid build.
        var (s, reach) = crimson(settlements: 4, cities: 2); s.set(hand: Cost.road, for: 0)
        var used: Set<Int> = Set(s.board.corners.indices.filter { s.board.corners[$0].owner != nil }.flatMap { [$0] + s.board.corners[$0].adjacent })
        let chain = s.chain(from: reach, length: 3, avoiding: &used); s.placeChain(Array(chain.prefix(2)), owner: 0)
        #expect(Engine.roadLength(s, player: 0) == 4)
        try Engine.apply(.placeRoad(edge: chain[2]), to: &s)
        #expect(s.longestRoadHolder == 0); #expect(s.phase == .gameOver(winner: 0))
    }
    @Test func thirdKnightAtEightWins() throws {
        var (s, _) = crimson(settlements: 4, cities: 2); s.players[0].knightsPlayed = 2; s.players[0].devCards = [DevCard(type: .knight, boughtOnTurn: -1)]
        try Engine.apply(.playKnight, to: &s)
        #expect(s.largestArmyHolder == 0); #expect(s.phase == .gameOver(winner: 0))
    }
    @Test func victoryPointCardAtNineWins() throws {
        var (s, _) = crimson(settlements: 3, cities: 3); s.set(hand: Cost.devCard, for: 0); s.devDeck[s.devDeck.count - 1] = .victoryPoint
        try Engine.apply(.buyDevCard, to: &s)
        #expect(s.phase == .gameOver(winner: 0)); #expect(s.log.last == "Crimson wins with 10 points, including 1 hidden victory point card!")
    }
    @Test func hiddenCardsCountAtStartOfTurn() throws {
        var (s, _) = crimson(settlements: 4, cities: 2); s.players[0].devCards = [DevCard(type: .victoryPoint, boughtOnTurn: 0), DevCard(type: .victoryPoint, boughtOnTurn: 0)]
        s.current = 2; s.phase = .main
        try Engine.apply(.endTurn, to: &s)
        #expect(s.phase == .gameOver(winner: 0)); #expect(s.log.last == "Crimson wins with 10 points, including 2 hidden victory point cards!")
    }
    @Test func passiveWinIsCaughtAtStartOfTurn() throws {
        var (s, _) = crimson(settlements: 4, cities: 2)
        var used: Set<Int> = Set(s.board.corners.indices.filter { s.board.corners[$0].owner != nil }.flatMap { [$0] + s.board.corners[$0].adjacent })
        s.placeChain(s.firstChain(length: 6, avoiding: &used), owner: 0)
        let amber = s.firstChain(length: 7, avoiding: &used) { s.board.corners[$0].edges.count == 3 }
        s.placeChain(amber, owner: 2); Engine.updateAwards(&s)
        #expect(s.longestRoadHolder == 2); #expect(Engine.totalPoints(s, player: 0) == 8)
        // a corner inside Amber's chain with a third, free edge
        // corners between edges 1-2 … 4-5 of Amber's chain: cutting there leaves pieces of at most 5
        let inner = (1..<5).map { Set([s.board.edges[amber[$0]].a, s.board.edges[amber[$0]].b]).intersection([s.board.edges[amber[$0 + 1]].a, s.board.edges[amber[$0 + 1]].b]).first! }
        let m = inner.first { s.board.corners[$0].edges.count == 3 }!
        let spur = s.board.corners[m].edges.first { s.board.edges[$0].owner == nil }!
        s.place(road: spur, owner: 1); s.set(hand: Cost.settlement, for: 1); s.current = 1; s.phase = .main
        try Engine.apply(.placeSettlement(corner: m), to: &s)
        #expect(s.longestRoadHolder == 0); #expect(Engine.totalPoints(s, player: 0) == 10)
        if case .gameOver = s.phase { Issue.record("won on someone else's turn") }
        try Engine.apply(.endTurn, to: &s); #expect(s.current == 2); if case .gameOver = s.phase { Issue.record("Amber's turn should not end the game") }
        s.phase = .main; try Engine.apply(.endTurn, to: &s)
        #expect(s.phase == .gameOver(winner: 0))
    }
    @Test func gameLocksAfterWin() throws {
        var (s, reach) = crimson(settlements: 3, cities: 3); s.set(hand: Cost.settlement, for: 0)
        try Engine.apply(.placeSettlement(corner: reach), to: &s)
        #expect(Engine.legalMoves(s).isEmpty)
        #expect(throws: EngineError.illegalMove(.endTurn)) { try Engine.apply(.endTurn, to: &s) }
    }
    @Test func endTurnResets() throws {
        var s = TestGames.rolled(8); s.devCardPlayedThisTurn = true; let turn = s.turn, cur = s.current
        try Engine.apply(.endTurn, to: &s)
        #expect(s.current == (cur + 1) % 3); #expect(s.dice == nil); #expect(!s.devCardPlayedThisTurn); #expect(s.turn == turn + 1); #expect(s.phase == .awaitingRoll)
    }
    @Test func endTurnLockedUntilRoll() { #expect(!Engine.legalMoves(TestGames.afterSetup()).contains(.endTurn)) }
}
