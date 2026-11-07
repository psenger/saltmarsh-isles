import Testing
@testable import SaltmarshEngine

@Suite struct FirstRollTests {
    func game() -> GameState { Engine.newGame(GameConfig(controllers: [.human, .human, .human], seed: 1)) }
    @Test func highestGoesFirstAndOrderRotates() throws {
        var s = game(); s.forcedRolls = [[1, 2], [6, 6], [3, 3]]
        for _ in 0..<3 { try Engine.apply(.rollForFirst, to: &s) }
        #expect(s.firstPlayer == 1); #expect(s.current == 1)
        #expect(s.phase == .setup(step: 0, placingRoad: false, lastSettlement: nil))
        #expect(s.log.last == "Cobalt goes first. Place your first settlement.")
        #expect(Engine.setupOrder(players: 3, first: 1) == [1, 2, 0, 0, 2, 1])
    }
    @Test func tieRerollsAmongTiedOnly() throws {
        var s = game(); s.forcedRolls = [[6, 6], [1, 1], [6, 6], [2, 2], [5, 5]]
        for _ in 0..<3 { try Engine.apply(.rollForFirst, to: &s) }
        #expect(s.phase == .rollingForFirst(rolls: [nil, nil, nil], contenders: [0, 2]))
        #expect(s.log.last == "Tie between Crimson and Amber. Roll again.")
        #expect(Engine.actingPlayer(s) == 0)
        try Engine.apply(.rollForFirst, to: &s); #expect(Engine.actingPlayer(s) == 2)
        try Engine.apply(.rollForFirst, to: &s)
        #expect(s.firstPlayer == 2)
    }
    @Test func rollLogged() throws {
        var s = game(); s.forcedRolls = [[4, 5]]
        try Engine.apply(.rollForFirst, to: &s)
        #expect(s.log.last == "Crimson rolled 9 (4+5) for first player.")
    }
    @Test func onlyRollForFirstIsLegal() { #expect(Engine.legalMoves(game()) == [.rollForFirst]) }
}
