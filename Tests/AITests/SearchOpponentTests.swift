import Testing
@testable import SaltmarshEngine
import SaltmarshTestSupport
@testable import SaltmarshAI

@Suite struct SearchOpponentTests {
    let tiny = SearchBudget(samples: 2, rounds: 1, playouts: 8, timeCap: nil)

    @Test func factorySplitsTheLevels() {
        for level in [EffortLevel.deckhand, .sailor, .mate] { #expect(OpponentFactory.make(level: level, seed: 1) is HeuristicOpponent) }
        for level in [EffortLevel.captain, .admiral] { #expect(OpponentFactory.make(level: level, seed: 1) is SearchOpponent) }
        #expect(LevelProfile.forLevel(.captain).search?.timeCap == .milliseconds(750)); #expect(LevelProfile.forLevel(.admiral).search?.samples == 96)
        #expect(LevelProfile.forLevel(.mate).search == nil)
    }
    @Test func sameSeedSameGameWithSearch() async {
        func game() async -> Arena.Detail {
            await Arena.play(levels: [.captain, .mate], seed: 11, maxMoves: 150, make: { level, seed in
                level == .captain ? SearchOpponent(level: .captain, seed: seed, budget: tiny) : OpponentFactory.make(level: level, seed: seed) })
        }
        let a = await game(), b = await game()
        #expect(a.moves == b.moves); #expect(a.illegalChoices == 0); #expect(a.moves.count == 150 || a.winner != nil)
    }
    @Test func unpayableOfferIsDeclinedWithoutSearch() async {                       // Review Focus 5
        var s = TestGames.rolled(8); s.clearHands(); s.set(hand: [.timber: 1], for: 0); s.set(hand: [.ore: 2], for: 1); s.set(hand: [.wool: 1], for: 2)
        try! Engine.apply(.proposeTrade(TradeOffer(proposer: 0, give: [.timber: 1], want: [.ore: 1], to: 2)), to: &s)
        guard case .tradeOffered(let offer, _) = s.phase else { Issue.record("no trade phase"); return }
        let bot = SearchOpponent(level: .captain, seed: 1, budget: tiny)
        #expect(await bot.respondToTrade(offer, view: Engine.view(s, for: 2)) == .declined)
    }
    @Test func lastThoughtReportsASearchedDecision() async {
        var s = TestGames.rolled(8); s.set(hand: Cost.city + Cost.settlement + Cost.road + Cost.devCard, for: 0)
        let bot = SearchOpponent(level: .captain, seed: 1, budget: tiny)
        #expect(await bot.lastThought() == nil)
        _ = await bot.chooseMove(view: Engine.view(s, for: 0), legal: Engine.legalMoves(s))
        let thought = await bot.lastThought()
        #expect(thought != nil); #expect((thought?.moves ?? 0) >= 2); #expect(thought?.hands == 2)
        #expect((1...8).contains(thought?.playouts ?? 0)); #expect(thought?.outOfTime == false)
        #expect(await bot.lastThought() == nil, "a thought is reported once")
        var r = TestGames.afterSetup(seed: 1); r.current = 0; r.phase = .awaitingRoll
        _ = await bot.chooseMove(view: Engine.view(r, for: 0), legal: Engine.legalMoves(r))
        #expect(await bot.lastThought() == nil, "rolling is not a searched decision")
        let plain = HeuristicOpponent(level: .mate, seed: 1)
        #expect(await plain.lastThought() == nil)
    }
    @Test func answersAreSearchedWhenBothAreLegal() async {
        var s = TestGames.rolled(8); s.clearHands(); s.set(hand: [.timber: 1], for: 0); s.set(hand: [.ore: 2, .grain: 2], for: 2)
        try! Engine.apply(.proposeTrade(TradeOffer(proposer: 0, give: [.timber: 1], want: [.ore: 1], to: 2)), to: &s)
        guard case .tradeOffered(let offer, _) = s.phase else { Issue.record("no trade phase"); return }
        let bot = SearchOpponent(level: .captain, seed: 1, budget: tiny)
        let answer = await bot.respondToTrade(offer, view: Engine.view(s, for: 2))
        #expect(answer == .accepted || answer == .declined)
    }
}
