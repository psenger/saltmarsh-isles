import Testing
@testable import SaltmarshEngine

@Suite struct BankTradeTests {
    func base() -> GameState { var s = TestGames.rolled(8); s.clearBoard(); s.clearHands(); return s }
    func harbour(_ s: GameState, _ kind: Harbour.Kind) -> Int { s.board.harbours.firstIndex { $0.kind == kind }! }
    @Test func bankTradeFourForOne() throws {
        var s = base(); s.set(hand: [.timber: 4], for: 0)
        try Engine.apply(.bankTrade(give: .timber, get: .ore), to: &s)
        #expect(s.players[0].hand == [.ore: 1]); #expect(s.bank[.timber] == 19); #expect(s.bank[.ore] == 18)
        #expect(s.log.last == "Crimson traded 4 timber for 1 ore with the bank.")
    }
    @Test func bankTradeInvalidCases() {
        var s = base(); s.set(hand: [.timber: 3], for: 0)
        #expect(!Engine.legalMoves(s).contains(.bankTrade(give: .timber, get: .ore)))
        s.set(hand: [.timber: 4], for: 0)
        #expect(!Engine.legalMoves(s).contains(.bankTrade(give: .timber, get: .timber)))
        s.set(hand: [.ore: 19], for: 1)                                 // bank now has 0 ore
        #expect(!Engine.legalMoves(s).contains(.bankTrade(give: .timber, get: .ore)))
        var t = TestGames.afterSetup(); t.set(hand: [.timber: 4], for: t.current)
        #expect(!Engine.legalMoves(t).contains { if case .bankTrade = $0 { true } else { false } })
    }
    @Test func bankRateNeverChanges() {
        var s = base(); let h = harbour(s, .specific(.wool)); s.place(settlement: s.board.harbours[h].a, owner: 0); s.set(hand: [.wool: 4], for: 0)
        #expect(Engine.legalMoves(s).contains(.bankTrade(give: .wool, get: .ore))); #expect(Engine.bestRate(s, player: 0, giving: .wool) == 2); #expect(Engine.bestRate(s, player: 0, giving: .ore) == 4)
    }
    @Test func noHarboursCaptured() { #expect(Engine.capturedHarbours(base(), player: 0).isEmpty) }
    @Test func capturedHarbourAndHolding() {
        var s = base(); let h = harbour(s, .any)
        s.place(settlement: s.board.harbours[h].a, owner: 0)
        #expect(Engine.capturedHarbours(s, player: 0).map(\.heldByDescription) == ["your settlement"])
        s.place(city: s.board.harbours[h].b, owner: 0)
        #expect(Engine.capturedHarbours(s, player: 0).first?.heldByDescription == "your settlement and city")
    }
    @Test func severalHarboursSeveralRows() {
        var s = base(); s.place(settlement: s.board.harbours[harbour(s, .any)].a, owner: 0); s.place(settlement: s.board.harbours[harbour(s, .specific(.grain))].a, owner: 0)
        #expect(Engine.capturedHarbours(s, player: 0).count == 2)
    }
    @Test func twoForOneTakesTwo() throws {
        var s = base(); let h = harbour(s, .specific(.wool)); s.place(settlement: s.board.harbours[h].a, owner: 0); s.set(hand: [.wool: 2], for: 0)
        #expect(!Engine.legalMoves(s).contains(.harbourTrade(harbour: h, give: .grain, get: .ore)))
        try Engine.apply(.harbourTrade(harbour: h, give: .wool, get: .ore), to: &s)
        #expect(s.players[0].hand == [.ore: 1]); #expect(s.log.last == "Crimson traded 2 wool for 1 ore at the 2:1 wool harbour.")
    }
    @Test func threeForOne() throws {
        var s = base(); let h = harbour(s, .any); s.place(settlement: s.board.harbours[h].a, owner: 0); s.set(hand: [.clay: 3], for: 0)
        try Engine.apply(.harbourTrade(harbour: h, give: .clay, get: .grain), to: &s)
        #expect(s.players[0].hand == [.grain: 1]); #expect(s.log.last == "Crimson traded 3 clay for 1 grain at the 3:1 harbour.")
    }
    @Test func notEnoughCardsAndUnownedHarbour() {
        var s = base(); let h = harbour(s, .specific(.wool)); s.place(settlement: s.board.harbours[h].a, owner: 0); s.set(hand: [.wool: 1], for: 0)
        #expect(!Engine.legalMoves(s).contains(.harbourTrade(harbour: h, give: .wool, get: .ore)))
        s.set(hand: [.wool: 2], for: 0); let other = harbour(s, .specific(.ore)); s.set(hand: [.ore: 2], for: 0)
        #expect(!Engine.legalMoves(s).contains(.harbourTrade(harbour: other, give: .ore, get: .wool)))
    }
    @Test func sharedHarbour() {
        var s = base(); let h = harbour(s, .any); s.place(settlement: s.board.harbours[h].a, owner: 0); s.place(settlement: s.board.harbours[h].b, owner: 1)
        #expect(Engine.capturedHarbours(s, player: 0).count == 1); #expect(Engine.capturedHarbours(s, player: 1).count == 1)
    }
}
