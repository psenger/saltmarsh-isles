import Testing
import SaltmarshEngine
import SaltmarshTestSupport
@testable import SaltmarshGame

/// A bank or harbour row is enabled only when at least one trade on it is legal right now.
@MainActor @Suite struct TradeRowTests {
    func screen(_ s: GameState) -> ScreenState {
        let vm = GameViewModel(store: InMemoryGameStore(), pacing: NoPacing()) { _, _ in nil }
        vm.load(s)
        return vm.screen
    }
    func rolled(hand: ResourceCounts) -> GameState {
        var s = TestGames.rolled(8); s.clearBoard(); s.clearHands(); s.set(hand: hand, for: 0); return s
    }
    func withHarbour(_ kind: Harbour.Kind, hand: ResourceCounts) -> GameState {
        var s = rolled(hand: hand)
        let h = s.board.harbours.firstIndex { $0.kind == kind }!
        s.place(settlement: s.board.harbours[h].a, owner: 0)
        return s
    }

    @Test func bankRowNeedsFourOfOneResource() {
        #expect(!screen(rolled(hand: [.timber: 3, .ore: 3])).bankRowEnabled)
        #expect(screen(rolled(hand: [.timber: 4])).bankRowEnabled)
    }
    @Test func bankRowIsDisabledBeforeRolling() {
        var s = rolled(hand: [.timber: 4]); s.phase = .awaitingRoll
        #expect(!screen(s).bankRowEnabled)
    }
    @Test func bankRowIsDisabledWhenTheBankHasNothingToGive() {
        var s = rolled(hand: [.timber: 4]); s.bank = ResourceCounts()
        #expect(!screen(s).bankRowEnabled)
    }
    @Test func bankRowIsDisabledWhileAnAIActs() {
        let sc = ScreenState.derive(state: rolled(hand: [.timber: 4]), ui: UIState(), aiThinking: true, reduceMotion: false)
        #expect(!sc.bankRowEnabled)
    }
    @Test func twoToOneRowNeedsItsOwnResource() {
        #expect(screen(withHarbour(.specific(.wool), hand: [.wool: 2])).harbours.rows.first?.rowEnabled == true)
        #expect(screen(withHarbour(.specific(.wool), hand: [.wool: 1, .timber: 5])).harbours.rows.first?.rowEnabled == false)
    }
    @Test func threeToOneRowNeedsThreeOfOneResource() {
        #expect(screen(withHarbour(.any, hand: [.clay: 2, .ore: 2])).harbours.rows.first?.rowEnabled == false)
        #expect(screen(withHarbour(.any, hand: [.clay: 3])).harbours.rows.first?.rowEnabled == true)
    }
    @Test func harbourRowIsDisabledBeforeRollingAndWithAnEmptyBank() {
        var before = withHarbour(.any, hand: [.clay: 3]); before.phase = .awaitingRoll
        #expect(screen(before).harbours.rows.first?.rowEnabled == false)
        var empty = withHarbour(.any, hand: [.clay: 3]); empty.bank = ResourceCounts()
        #expect(screen(empty).harbours.rows.first?.rowEnabled == false)
    }
}
