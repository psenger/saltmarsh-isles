import Testing
@testable import SaltmarshEngine
import SaltmarshTestSupport

@Suite struct SetupTests {
    @Test(arguments: [(2, [0, 1, 1, 0]), (3, [0, 1, 2, 2, 1, 0]), (4, [0, 1, 2, 3, 3, 2, 1, 0])])
    func placementOrder(players: Int, order: [Int]) throws {
        var s = TestGames.fresh(players: players)
        s.forcedRolls = (0..<players).map { $0 == 0 ? [6, 6] : [1, 1] }
        for _ in 0..<players { try Engine.apply(.rollForFirst, to: &s) }
        var seen: [Int] = []
        while case .setup = s.phase {
            seen.append(s.current)
            try Engine.apply(Engine.legalMoves(s).first!, to: &s)   // settlement
            try Engine.apply(Engine.legalMoves(s).first!, to: &s)   // road
        }
        #expect(seen == order); #expect(s.phase == .awaitingRoll); #expect(s.current == 0)
        #expect(s.log.last == "Setup done. Crimson rolls first.")
    }
    @Test func orderStartsFromFirstPlayer() {
        let s = TestGames.afterSetup(players: 3, first: 2)
        #expect(s.current == 2); #expect(s.log.last == "Setup done. Amber rolls first.")
    }
    @Test func onlySecondSettlementPays() throws {
        var s = TestGames.fresh(); s.forcedRolls = [[6, 6], [1, 1], [1, 1]]
        for _ in 0..<3 { try Engine.apply(.rollForFirst, to: &s) }
        try Engine.apply(Engine.legalMoves(s).first!, to: &s)
        #expect(s.players[0].hand.isEmpty)
        // run to Crimson's second placement (step 5 of 6)
        while case .setup(let step, _, _) = s.phase, step < 5 { try Engine.apply(Engine.legalMoves(s).first!, to: &s) }
        let corner = Engine.legalMoves(s).compactMap { if case .placeSettlement(let c) = $0 { c } else { nil } }.first!
        let expected = s.board.corners[corner].tiles.compactMap { s.board.tiles[$0].resource }
        try Engine.apply(.placeSettlement(corner: corner), to: &s)
        #expect(s.players[0].hand.total == expected.count)
        for r in expected { #expect(s.players[0].hand[r] >= 1) }
        #expect(s.bank.total == 19 * 5 - s.players.map(\.hand.total).reduce(0, +))
    }
    @Test func setupRoadMustTouchNewSettlement() throws {
        var s = TestGames.fresh(); s.forcedRolls = [[6, 6], [1, 1], [1, 1]]
        for _ in 0..<3 { try Engine.apply(.rollForFirst, to: &s) }
        let c = 10
        try Engine.apply(.placeSettlement(corner: c), to: &s)
        let legal = Engine.legalMoves(s)
        #expect(legal.count == s.board.corners[c].edges.count)
        for m in legal { if case .placeRoad(let e) = m { #expect(s.board.edges[e].a == c || s.board.edges[e].b == c) } else { Issue.record("non-road move in setup road step") } }
        #expect(s.log.last == "Crimson founded a settlement.")
    }
    @Test func distanceRuleDuringSetup() throws {
        var s = TestGames.fresh(); s.forcedRolls = [[6, 6], [1, 1], [1, 1]]
        for _ in 0..<3 { try Engine.apply(.rollForFirst, to: &s) }
        try Engine.apply(.placeSettlement(corner: 10), to: &s)
        try Engine.apply(Engine.legalMoves(s).first!, to: &s)
        let legal = Engine.legalMoves(s).compactMap { if case .placeSettlement(let c) = $0 { c } else { nil } }
        #expect(!legal.contains(10)); for a in s.board.corners[10].adjacent { #expect(!legal.contains(a)) }
    }
}
