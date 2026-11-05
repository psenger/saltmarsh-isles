import Testing
import SaltmarshEngine
import SaltmarshTestSupport
@testable import SaltmarshGame

/// Which tabs can be opened. A request from the game greys them all; content that belongs to someone else greys its tab.
@MainActor @Suite struct PanelTabTests {
    func screen(_ s: GameState) -> ScreenState {
        let vm = GameViewModel(store: InMemoryGameStore(), pacing: NoPacing()) { _, _ in nil }
        vm.load(s)
        return vm.screen
    }
    let readOnly: Set<PanelTab> = [.players, .log]

    @Test func allTabsOnAPlayersOwnTurn() {
        #expect(screen(TestGames.rolled(8)).enabledTabs == Set(PanelTab.allCases))
    }
    @Test func onlyReadableTabsDuringFirstRollAndSetup() {
        #expect(screen(TestGames.fresh()).enabledTabs == readOnly)
    }
    @Test func onlyReadableTabsWhileAnAIActs() {
        let sc = ScreenState.derive(state: TestGames.rolled(8), ui: UIState(), aiThinking: true, reduceMotion: false)
        #expect(sc.enabledTabs == readOnly)
    }
    @Test func noTabsDuringADiscard() {
        var s = TestGames.afterSetup()
        s.clearHands()
        s.set(hand: [.timber: 8], for: 0)
        s.force(roll: 7)
        let vm = GameViewModel(store: InMemoryGameStore(), pacing: NoPacing()) { _, _ in nil }
        vm.load(s)
        vm.rollDice()
        #expect(vm.screen.discardBox != nil)
        #expect(vm.screen.enabledTabs.isEmpty)
    }
    @Test func noTabsWhileAnswersAreInOrAnOfferIsOpen() {
        var s = TestGames.rolled(8)
        s.clearHands()
        s.set(hand: [.timber: 2], for: 0)
        s.set(hand: [.ore: 1], for: 1)
        let vm = GameViewModel(store: InMemoryGameStore(), pacing: NoPacing()) { _, _ in nil }
        vm.load(s)
        vm.ui.offerGive = [.timber: 2]
        vm.ui.offerWant = [.ore: 1]
        vm.proposeOffer()
        #expect(vm.screen.enabledTabs.isEmpty, "the responder must answer")
        vm.respondToOffer(accept: false)
        #expect(vm.screen.buttons[Strings.withdraw] == true)
        #expect(vm.screen.enabledTabs.isEmpty, "the proposer must close the offer")
    }
    @Test func scoreRowCarriesThePointsAlone() {
        #expect(screen(TestGames.rolled(8)).scoreboard[0].points == 2)
    }
}
