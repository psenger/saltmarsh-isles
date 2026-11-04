import Testing
@testable import SaltmarshEngine

@Suite struct PlayerTradeTests {
    func base() -> GameState { var s = TestGames.rolled(8); s.clearBoard(); s.clearHands(); s.set(hand: [.timber: 3, .wool: 1], for: 0); s.set(hand: [.ore: 2], for: 1); s.set(hand: [.grain: 2, .ore: 1], for: 2); return s }
    let offer = TradeOffer(proposer: 0, give: [.timber: 2], want: [.ore: 1], to: nil)
    @Test func validation() {
        let s = base()
        #expect(Engine.validate(offer, in: s) == nil)
        #expect(Engine.validate(TradeOffer(proposer: 0, give: [:], want: [.ore: 1], to: nil), in: s) == "give side is empty")
        #expect(Engine.validate(TradeOffer(proposer: 0, give: [.timber: 1], want: [:], to: nil), in: s) == "want side is empty")
        #expect(Engine.validate(TradeOffer(proposer: 0, give: [.timber: 1], want: [.timber: 1, .ore: 1], to: nil), in: s) == "same resource on both sides")
        #expect(Engine.validate(TradeOffer(proposer: 0, give: [.timber: 4], want: [.ore: 1], to: nil), in: s) == "proposer cannot pay")
        #expect(Engine.validate(TradeOffer(proposer: 0, give: [.timber: 1], want: [.ore: 1], to: 0), in: s) == "target is the proposer")
        #expect(Engine.validate(TradeOffer(proposer: 0, give: [.timber: 1], want: [.ore: 1], to: 3), in: s) == "target out of range")
    }
    @Test func proposeToEveryoneSkipsEmptyHands() throws {
        var s = base(); s.set(hand: [:], for: 2)
        try Engine.apply(.proposeTrade(offer), to: &s)
        #expect(s.phase == .tradeOffered(offer: offer, responses: [1: .pending])); #expect(s.log.last == "Crimson offers 2 timber for 1 ore."); #expect(Engine.actingPlayer(s) == 1)
    }
    @Test func unanswerableOfferStaysInMain() throws {                            // Review Focus 5
        var s = base(); s.set(hand: [:], for: 1); s.set(hand: [:], for: 2)
        try Engine.apply(.proposeTrade(offer), to: &s)
        #expect(s.phase == .main); #expect(s.log.last == "Nobody can answer that offer.")
    }
    @Test func acceptRequiresPayment() throws {
        var s = base(); try Engine.apply(.proposeTrade(TradeOffer(proposer: 0, give: [.timber: 1], want: [.grain: 1], to: nil)), to: &s)
        #expect(throws: EngineError.self) { try Engine.apply(.respondToTrade(seat: 1, .accepted), to: &s) }   // Cobalt has no grain
        #expect(Engine.legalMoves(s).contains(.respondToTrade(seat: 1, .declined))); #expect(!Engine.legalMoves(s).contains(.respondToTrade(seat: 1, .accepted)))
    }
    @Test func respondThenExecute() throws {
        var s = base(); try Engine.apply(.proposeTrade(offer), to: &s)
        #expect(!Engine.legalMoves(s).contains(.executeTrade(with: 1)))
        try Engine.apply(.respondToTrade(seat: 1, .accepted), to: &s); #expect(s.log.last == "Cobalt accepted the offer.")
        #expect(!Engine.legalMoves(s).contains(.executeTrade(with: 1)))              // Amber still pending
        try Engine.apply(.respondToTrade(seat: 2, .declined), to: &s); #expect(s.log.last == "Amber declined the offer.")
        #expect(Engine.actingPlayer(s) == 0); #expect(Engine.legalMoves(s).contains(.executeTrade(with: 1))); #expect(!Engine.legalMoves(s).contains(.executeTrade(with: 2)))
        let bank = s.bank
        try Engine.apply(.executeTrade(with: 1), to: &s)
        #expect(s.players[0].hand == [.timber: 1, .wool: 1, .ore: 1]); #expect(s.players[1].hand == [.timber: 2, .ore: 1]); #expect(s.bank == bank)
        #expect(s.log.last == "Crimson traded 2 timber with Cobalt for 1 ore."); #expect(s.phase == .main)
    }
    @Test func counterIsValidatedAndExecutesOnItsTerms() throws {
        var s = base(); try Engine.apply(.proposeTrade(offer), to: &s)
        let bad = TradeOffer(proposer: 0, give: [.timber: 5], want: [.ore: 1], to: 1)
        #expect(throws: EngineError.self) { try Engine.apply(.respondToTrade(seat: 1, .countered(bad)), to: &s) }
        let counter = TradeOffer(proposer: 0, give: [.timber: 3], want: [.ore: 1], to: 1)
        try Engine.apply(.respondToTrade(seat: 1, .countered(counter)), to: &s); #expect(s.log.last == "Cobalt countered: 3 timber for 1 ore.")
        try Engine.apply(.respondToTrade(seat: 2, .declined), to: &s)
        try Engine.apply(.executeTrade(with: 1), to: &s)
        #expect(s.players[0].hand == [.wool: 1, .ore: 1]); #expect(s.players[1].hand == [.timber: 3, .ore: 1])
    }
    @Test func withdrawLeavesHandsUnchanged() throws {
        var s = base(); let hands = s.players.map(\.hand); try Engine.apply(.proposeTrade(offer), to: &s)
        try Engine.apply(.withdrawTrade, to: &s)
        #expect(s.players.map(\.hand) == hands); #expect(s.phase == .main); #expect(s.log.last == "Crimson withdrew the offer.")
    }
    @Test func targetedOfferAsksOnlyThatSeat() throws {
        var s = base(); var o = offer; o.to = 2
        try Engine.apply(.proposeTrade(o), to: &s)
        #expect(s.phase == .tradeOffered(offer: o, responses: [2: .pending])); #expect(s.log.last == "Crimson offers 2 timber for 1 ore to Amber.")
    }
    @Test func canonicalOffersInLegalMoves() {
        let offers = Engine.legalMoves(base()).compactMap { if case .proposeTrade(let o) = $0 { o } else { nil } }
        #expect(!offers.isEmpty)
        for o in offers {
            #expect(o.to == nil); #expect(o.give.nonZero.count == 1 && o.want.nonZero.count == 1)
            #expect((1...2).contains(o.give.total) && (1...2).contains(o.want.total)); #expect(Engine.validate(o, in: base()) == nil)
        }
        #expect(offers.contains(TradeOffer(proposer: 0, give: [.timber: 2], want: [.ore: 2], to: nil))); #expect(!offers.contains { $0.give[.wool] == 2 })
    }
    @Test func proposingIsOnlyLegalAfterRolling() { #expect(!Engine.legalMoves(TestGames.afterSetup()).contains { if case .proposeTrade = $0 { true } else { false } }) }
}
