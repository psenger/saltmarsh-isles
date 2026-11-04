import Testing
@testable import SaltmarshEngine

@Suite struct RollTests {
    func crimsonToRoll(_ roll: Int) -> GameState {
        var s = TestGames.afterSetup(); s.clearBoard(); s.clearHands()
        s.current = 0; s.phase = .awaitingRoll; s.force(roll: roll); return s
    }
    @Test func rollThatProduces() throws {
        var s = crimsonToRoll(8)
        s.place(settlement: s.corner(onTileNumbered: 8, index: 0), owner: 1)
        s.place(city: s.corner(onTileNumbered: 8, index: 3), owner: 2)
        let res = s.board.tiles[s.tile(numbered: 8)].resource!
        try Engine.apply(.roll, to: &s)
        #expect(s.players[1].hand[res] == 1); #expect(s.players[2].hand[res] == 2)
        #expect(s.log.last == "Crimson rolled 8. Cobalt +1, Amber +2")
        #expect(s.phase == .main); #expect(s.dice!.reduce(0, +) == 8)
    }
    @Test func rollThatProducesNothing() throws {
        var s = crimsonToRoll(8); try Engine.apply(.roll, to: &s)
        #expect(s.log.last == "Crimson rolled 8. Nobody harvested.")
    }
    @Test func robberBlocksProduction() throws {
        var s = crimsonToRoll(6)
        s.place(settlement: s.corner(onTileNumbered: 6), owner: 1); s.robberTile = s.tile(numbered: 6)
        try Engine.apply(.roll, to: &s)
        #expect(s.players[1].hand.isEmpty)
    }
    @Test func rollIsSingleUse() throws {
        var s = crimsonToRoll(5); try Engine.apply(.roll, to: &s)
        #expect(!Engine.legalMoves(s).contains(.roll))
        #expect(throws: EngineError.illegalMove(.roll)) { try Engine.apply(.roll, to: &s) }
    }
    @Test func singleOwedPlayerTakesRemainder() throws {
        var s = crimsonToRoll(8); let res = s.board.tiles[s.tile(numbered: 8)].resource!
        s.set(hand: [res: 18], for: 0)                       // bank now holds 1
        s.place(city: s.corner(onTileNumbered: 8), owner: 2)
        try Engine.apply(.roll, to: &s)
        #expect(s.players[2].hand[res] == 1); #expect(s.bank[res] == 0)
        #expect(s.log.last == "Bank is out of \(res.rawValue).")
    }
    @Test func twoOwedPlayersGetNothing() throws {
        var s = crimsonToRoll(8); let res = s.board.tiles[s.tile(numbered: 8)].resource!
        s.set(hand: [res: 18], for: 0)
        s.place(settlement: s.corner(onTileNumbered: 8, index: 0), owner: 1)
        s.place(settlement: s.corner(onTileNumbered: 8, index: 3), owner: 2)
        try Engine.apply(.roll, to: &s)
        #expect(s.players[1].hand[res] == 0); #expect(s.players[2].hand[res] == 0); #expect(s.bank[res] == 1)
        #expect(s.log.suffix(2).first == "Crimson rolled 8. Nobody harvested.")
    }
    @Test func sevenBuildsDiscardQueueOrGoesToRobber() throws {
        var s = crimsonToRoll(7)
        s.set(hand: .uniform(2), for: 1)                     // 10 cards
        try Engine.apply(.roll, to: &s)
        #expect(s.phase == .discarding(queue: [1])); #expect(s.log.last == "Crimson rolled 7.")
        var t = crimsonToRoll(7); try Engine.apply(.roll, to: &t)
        #expect(t.phase == .movingRobber(returnTo: .main))
    }
}
