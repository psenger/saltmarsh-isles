import Testing
@testable import SaltmarshEngine
import SaltmarshTestSupport
@testable import SaltmarshAI

@Suite struct TradePolicyTests {
    func main(hand: ResourceCounts, others: ResourceCounts = [.ore: 3]) -> GameState {
        var s = TestGames.rolled(8); s.clearHands(); s.set(hand: hand, for: 0); s.set(hand: others, for: 1); s.set(hand: others, for: 2); return s
    }
    func decide(_ s: GameState, level: EffortLevel = .mate, memory: inout TurnMemory) -> Move {
        var rng = SeededRNG(seed: 1)
        return HeuristicPolicy.choose(view: Engine.view(s, for: 0), legal: Engine.legalMoves(s), profile: .forLevel(level), memory: &memory, rng: &rng)
    }
    let oneOreShort: ResourceCounts = [.grain: 2, .ore: 2, .timber: 2]          // a city, one ore short; timber is surplus
    let oneForOne = TradeOffer(proposer: 0, give: [.timber: 1], want: [.ore: 1], to: nil)

    @Test func offersSurplusForTheMissingCardWhenItCompletesABuild() {
        var m = TurnMemory()
        #expect(decide(main(hand: oneOreShort), memory: &m) == .proposeTrade(oneForOne))
        #expect(m.proposed.contains(oneForOne))
    }
    @Test func neverRepeatsAnOfferInOneTurn() throws {                                            // Review Focus 1
        var m = TurnMemory(); var s = main(hand: oneOreShort, others: [:])                         // nobody can answer
        let first = decide(s, memory: &m); #expect(first == .proposeTrade(oneForOne))
        try Engine.apply(first, to: &s); #expect(s.phase == .main)
        let second = decide(s, memory: &m)
        #expect(second == .proposeTrade(TradeOffer(proposer: 0, give: [.timber: 2], want: [.ore: 1], to: nil)))
        try Engine.apply(second, to: &s)
        let third = decide(s, memory: &m)
        if case .proposeTrade = third { Issue.record("offered a third time: \(third)") }
    }
    @Test func memoryResetsWhenTheTurnChanges() {
        var m = TurnMemory(); m.turn = 3; m.proposed = [oneForOne]
        var s = main(hand: oneOreShort); s.turn = 4
        #expect(decide(s, memory: &m) == .proposeTrade(oneForOne)); #expect(m.turn == 4)
    }
    @Test func deckhandNeverOffersAndDeclinesEverything() {
        let s = main(hand: oneOreShort), v = Engine.view(s, for: 0)
        for seed in 0..<50 {
            var m = TurnMemory(), rng = SeededRNG(seed: UInt64(seed))
            let move = HeuristicPolicy.choose(view: v, legal: Engine.legalMoves(s), profile: .forLevel(.deckhand), memory: &m, rng: &rng)
            if case .proposeTrade = move { Issue.record("Deckhand offered \(move)") }
        }
        let gift = TradeOffer(proposer: 1, give: [.ore: 1], want: [.timber: 1], to: 0)
        #expect(HeuristicPolicy.respond(to: gift, view: v, profile: .forLevel(.deckhand)) == .declined)
    }
    @Test func harbourBeatsBankAndBothNeedACompletingTrade() {
        var m = TurnMemory(); m.turn = TestGames.rolled(8).turn
        m.proposed = [oneForOne, TradeOffer(proposer: 0, give: [.timber: 2], want: [.ore: 1], to: nil)]
        var s = main(hand: [.grain: 2, .ore: 2, .timber: 4])
        var m1 = m; #expect(decide(s, memory: &m1) == .bankTrade(give: .timber, get: .ore))
        let h = s.board.harbours.firstIndex { $0.kind == .any }!; s.place(settlement: s.board.harbours[h].a, owner: 0)
        var m2 = m; #expect(decide(s, memory: &m2) == .harbourTrade(harbour: h, give: .timber, get: .ore))
        var m3 = m; s.set(hand: [.ore: 2], for: 0)                                                  // every goal two or more short
        #expect(decide(s, memory: &m3) == .endTurn)
    }
    @Test func responsesFollowTheLevel() {
        let v = Engine.view(main(hand: oneOreShort), for: 0)
        let helpful = TradeOffer(proposer: 1, give: [.ore: 1], want: [.timber: 1], to: 0)         // gain 2
        let robbery = TradeOffer(proposer: 1, give: [.timber: 1], want: [.ore: 1], to: 0)         // gain −2, and no sane counter
        let unpayable = TradeOffer(proposer: 1, give: [.ore: 1], want: [.wool: 1], to: 0)
        #expect(HeuristicPolicy.respond(to: helpful, view: v, profile: .forLevel(.mate)) == .accepted)
        #expect(HeuristicPolicy.respond(to: helpful, view: v, profile: .forLevel(.sailor)) == .declined)
        #expect(HeuristicPolicy.respond(to: robbery, view: v, profile: .forLevel(.mate)) == .declined)
        #expect(HeuristicPolicy.respond(to: unpayable, view: v, profile: .forLevel(.mate)) == .declined)
    }
    @Test func mateCountersForOneMoreCard() {
        let v = Engine.view(main(hand: oneOreShort), for: 0)
        let stingy = TradeOffer(proposer: 1, give: [.wool: 1], want: [.timber: 1], to: 0)         // gain 0
        #expect(HeuristicPolicy.respond(to: stingy, view: v, profile: .forLevel(.mate)) == .countered(TradeOffer(proposer: 1, give: [.wool: 1, .ore: 1], want: [.timber: 1], to: 0)))
        #expect(HeuristicPolicy.respond(to: stingy, view: v, profile: .forLevel(.sailor)) == .declined)
    }
    @Test func proposerExecutesTheBestAnswerOrWithdraws() throws {
        var m = TurnMemory()
        var s = main(hand: oneOreShort); try Engine.apply(.proposeTrade(oneForOne), to: &s)
        try Engine.apply(.respondToTrade(seat: 1, .declined), to: &s); try Engine.apply(.respondToTrade(seat: 2, .accepted), to: &s)
        #expect(decide(s, memory: &m) == .executeTrade(with: 2))
        var t = main(hand: oneOreShort); try Engine.apply(.proposeTrade(oneForOne), to: &t)
        try Engine.apply(.respondToTrade(seat: 1, .countered(TradeOffer(proposer: 0, give: [.timber: 2], want: [.ore: 1], to: 1))), to: &t)
        try Engine.apply(.respondToTrade(seat: 2, .declined), to: &t)
        #expect(decide(t, memory: &m) == .executeTrade(with: 1))                                    // gain 1 still clears Mate's bar
        var u = main(hand: oneOreShort); try Engine.apply(.proposeTrade(oneForOne), to: &u)
        try Engine.apply(.respondToTrade(seat: 1, .declined), to: &u); try Engine.apply(.respondToTrade(seat: 2, .declined), to: &u)
        #expect(decide(u, memory: &m) == .withdrawTrade)
    }
}
