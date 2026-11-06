import Testing
@testable import SaltmarshEngine
import SaltmarshTestSupport
@testable import SaltmarshAI

@Suite struct GoalsTests {
    func view(hand: ResourceCounts) -> PlayerView {
        var s = TestGames.afterSetup(seed: 1); s.clearHands(); s.set(hand: hand, for: 0); s.current = 0; s.phase = .main
        return Engine.view(s, for: 0)
    }
    @Test func nearestPrefersTheFewestMissingCardsThenPriority() {
        #expect(Goals.nearest(view: view(hand: [.grain: 2, .ore: 2]))?.goal == .city)                   // city 1 short; devCard 1 short; city first
        #expect(Goals.nearest(view: view(hand: [.grain: 2, .ore: 2]))?.missing == [.ore: 1])
        #expect(Goals.nearest(view: view(hand: [.timber: 1, .clay: 1, .wool: 1, .grain: 1]))?.goal == .road)   // after setup no spot is at distance 0
        #expect(Goals.nearest(view: view(hand: [.wool: 1, .grain: 1, .ore: 1]))?.goal == .devCard)
    }
    @Test func nearestIsNilWhenNothingCanBeBuilt() {
        var s = TestGames.afterSetup(seed: 1); s.clearBoard(); s.clearHands(); s.devDeck = []; s.current = 0; s.phase = .main
        #expect(Goals.nearest(view: Engine.view(s, for: 0)) == nil)
    }
    @Test func handValueRewardsNeededCardsAndPunishesBigHands() {
        let plan = GoalPlan(goal: .city, missing: [.ore: 1])
        #expect(Goals.handValue([.grain: 2, .ore: 2], toward: plan) == 12)
        #expect(Goals.handValue([.grain: 2, .ore: 3], toward: plan) == 15)
        #expect(Goals.handValue([.grain: 2, .ore: 3, .timber: 1], toward: plan) == 16)
        #expect(Goals.handValue([.grain: 2, .ore: 3, .timber: 3], toward: plan) == 16)   // 18, less 2 for the eighth card
        #expect(Goals.handValue([.timber: 9], toward: nil) == 5)
        #expect(Goals.surplus(of: [.grain: 3, .ore: 1, .wool: 2], over: plan) == [.grain: 1, .wool: 2])
    }
    @Test func discardKeepsTheGoalAndDropsTheBiggestSurplus() {                                  // Review Focus 3
        let plan = GoalPlan(goal: .settlement, missing: ResourceCounts())
        #expect(Goals.discard(from: [.timber: 3, .clay: 1, .wool: 1, .grain: 1, .ore: 2], count: 4, keeping: plan) == [.timber: 2, .ore: 2])
        #expect(Goals.discard(from: [.timber: 9], count: 4, keeping: plan) == [.timber: 4])
        #expect(Goals.discard(from: [.timber: 2, .clay: 2, .wool: 2, .grain: 2], count: 4, keeping: plan) == [.timber: 1, .clay: 1, .wool: 1, .grain: 1])
        #expect(Goals.discard(from: [.timber: 1, .clay: 1, .wool: 1, .grain: 1], count: 2, keeping: plan) == [.timber: 1, .clay: 1])
        #expect(Goals.discard(from: [.ore: 5, .grain: 3], count: 4, keeping: nil) == [.ore: 3, .grain: 1])
    }
}
