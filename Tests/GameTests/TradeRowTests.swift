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

    // The Give list holds only what can be traded, and an untouched row is ready to trade.

    @Test func bankGiveListsOnlyWhatCanBeTraded() {
        let sc = screen(rolled(hand: [.timber: 2, .clay: 3, .grain: 5, .ore: 4]))
        #expect(sc.bankGiveOptions == [.grain, .ore])
    }
    @Test func bankRowStartsOnALegalTrade() {
        let sc = screen(rolled(hand: [.clay: 3, .grain: 5]))
        #expect(sc.bankChoice == TradeChoice(give: .grain, get: .timber))
        #expect(sc.buttons[Strings.bankTrade] == true)
    }
    @Test func bankRowStartsOnALegalTradeWhenOnlyOreCanBeGiven() {
        let sc = screen(rolled(hand: [.ore: 4]))
        #expect(sc.bankChoice == TradeChoice(give: .ore, get: .timber))
        #expect(sc.buttons[Strings.bankTrade] == true)
    }
    @Test func bankRowSkipsAResourceTheBankHasRunOutOf() {
        var s = rolled(hand: [.grain: 4]); s.bank[.timber] = 0
        #expect(screen(s).bankChoice == TradeChoice(give: .grain, get: .clay))
    }
    @Test func bankPickIsKeptWhileItsGiveCanStillBeTraded() {
        let vm = GameViewModel(store: InMemoryGameStore(), pacing: NoPacing()) { _, _ in nil }
        vm.load(rolled(hand: [.grain: 4, .ore: 4]))
        vm.ui.bankChoice = TradeChoice(give: .ore, get: .wool)
        #expect(vm.screen.bankChoice == TradeChoice(give: .ore, get: .wool))
    }
    @Test func bankPickMovesWhenItsGiveCanNoLongerBeTraded() {
        let vm = GameViewModel(store: InMemoryGameStore(), pacing: NoPacing()) { _, _ in nil }
        vm.load(rolled(hand: [.grain: 4, .ore: 3]))
        vm.ui.bankChoice = TradeChoice(give: .ore, get: .wool)
        #expect(vm.screen.bankChoice == TradeChoice(give: .grain, get: .wool))
        #expect(vm.screen.buttons[Strings.bankTrade] == true)
    }
    @Test func disabledBankRowListsOnlyTheResourceItShows() {
        let sc = screen(rolled(hand: [.timber: 1]))
        #expect(sc.bankGiveOptions == [sc.bankChoice.give])
        #expect(sc.buttons[Strings.bankTrade] == false)
    }
    @Test func threeToOneGiveListsOnlyWhatCanBeTraded() {
        let row = screen(withHarbour(.any, hand: [.timber: 2, .clay: 3, .grain: 5])).harbours.rows.first
        #expect(row?.giveOptions == [.clay, .grain])
        #expect(row?.give == .clay)
        #expect(row?.tradeEnabled == true)
    }
    @Test func threeToOnePickMovesWhenItsGiveCanNoLongerBeTraded() {
        let vm = GameViewModel(store: InMemoryGameStore(), pacing: NoPacing()) { _, _ in nil }
        let s = withHarbour(.any, hand: [.clay: 3, .grain: 2])
        vm.load(s)
        let index = vm.screen.harbours.rows.first!.index
        vm.ui.harbourChoice[index] = TradeChoice(give: .grain, get: .ore)
        let row = vm.screen.harbours.rows.first
        #expect(row?.give == .clay)
        #expect(row?.get == .ore)
        #expect(row?.tradeEnabled == true)
    }
    @Test func twoToOneGiveListsOnlyItsOwnResource() {
        let row = screen(withHarbour(.specific(.wool), hand: [.wool: 2, .timber: 5])).harbours.rows.first
        #expect(row?.giveOptions == [.wool])
        #expect(row?.give == .wool)
        #expect(row?.tradeEnabled == true)
    }
    @Test func disabledTwoToOneRowStillShowsItsOwnResource() {
        let row = screen(withHarbour(.specific(.wool), hand: [.wool: 1, .timber: 5])).harbours.rows.first
        #expect(row?.giveOptions == [.wool])
        #expect(row?.give == .wool)
    }
}
