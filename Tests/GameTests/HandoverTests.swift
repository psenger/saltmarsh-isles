import Testing
import SaltmarshEngine
import SaltmarshTestSupport
@testable import SaltmarshGame

/// The game hides itself whenever the private view would pass from one human to a different human.
@MainActor @Suite struct HandoverTests {
    /// No opponents are built, so tests play AI seats' moves themselves and no AI task runs.
    func model(_ s: GameState) -> GameViewModel {
        let vm = GameViewModel(store: InMemoryGameStore(), pacing: NoPacing()) { _, _ in nil }
        vm.load(s)
        return vm
    }
    func seats(_ s: GameState, _ controllers: [Controller]) -> GameState {
        var s = s
        for i in s.players.indices { s.players[i].controller = controllers[i] }
        return s
    }
    func passTo(_ player: Int, _ seat: Seat, button: String) -> Handover {
        Handover(player: player, seat: seat, message: "Pass the device to \(seat.name)", button: button)
    }

    @Test func endTurnBlanksForTheNextHuman() {
        let vm = model(TestGames.rolled(8))
        vm.revealHand()
        vm.endTurn()
        #expect(vm.screen.handover == passTo(1, .cobalt, button: "Start turn, Cobalt"))
    }
    @Test func revealClearsIt() {
        let vm = model(TestGames.rolled(8))
        vm.revealHand()
        #expect(vm.screen.handover == nil)
        vm.endTurn()
        vm.revealHand()
        #expect(vm.screen.handover == nil)
        #expect(vm.screen.holdTitle == "Cobalt's hold")
    }
    @Test func oneHumanNeverSeesIt() {
        let vm = model(seats(TestGames.rolled(8), [.human, .ai(.mate), .ai(.mate)]))
        #expect(vm.screen.handover == nil)
        vm.endTurn()
        #expect(vm.screen.handover == nil)
    }
    @Test func aiBetweenHumansBlanksOnlyWhenTheHumanIsDue() {
        var s = seats(TestGames.rolled(8), [.human, .ai(.mate), .human])
        s.force(roll: 8)
        let vm = model(s)
        vm.revealHand()
        vm.endTurn()
        #expect(vm.screen.handover == nil, "the AI's seat is next")
        vm.rollDice()
        vm.endTurn()
        #expect(vm.screen.handover == passTo(2, .amber, button: "Start turn, Amber"))
    }
    @Test func noBlankWhileAnAIActs() {
        var s = seats(TestGames.afterSetup(), [.human, .human, .ai(.mate)])
        s.current = 2; s.phase = .awaitingRoll
        let sc = ScreenState.derive(state: s, ui: UIState(), aiThinking: true, reduceMotion: false)
        #expect(sc.handover == nil)
    }
    @Test func discardQueueBlanksOnlyOnAChangeOfHuman() {
        var s = TestGames.afterSetup()
        s.clearHands()
        s.set(hand: [.timber: 8], for: 0)
        s.set(hand: [.clay: 8], for: 1)
        s.force(roll: 7)
        let vm = model(s)
        vm.revealHand()
        vm.rollDice()
        #expect(vm.screen.handover == nil, "the roller discards first and already holds the device")
        for _ in 0..<4 { vm.discardAdjust(.timber, by: 1) }
        vm.confirmDiscard()
        #expect(vm.screen.handover == passTo(1, .cobalt, button: "Discard, Cobalt"))
        vm.revealHand()
        for _ in 0..<4 { vm.discardAdjust(.clay, by: 1) }
        vm.confirmDiscard()
        #expect(vm.screen.handover == passTo(0, .crimson, button: "Continue, Crimson"))
    }
    @Test func offerBlanksForTheResponderAndBackForTheProposer() {
        var s = TestGames.rolled(8)
        s.clearHands()
        s.set(hand: [.timber: 2], for: 0)
        s.set(hand: [.ore: 1], for: 1)
        s.set(hand: [.grain: 1], for: 2)
        let vm = model(s)
        vm.revealHand()
        vm.ui.offerGive = [.timber: 2]
        vm.ui.offerWant = [.ore: 1]
        vm.proposeOffer()
        #expect(vm.screen.handover == passTo(1, .cobalt, button: "See the offer, Cobalt"))
        vm.revealHand()
        vm.respondToOffer(accept: false)
        #expect(vm.screen.handover == passTo(2, .amber, button: "See the offer, Amber"))
        vm.revealHand()
        vm.respondToOffer(accept: false)
        #expect(vm.screen.handover == passTo(0, .crimson, button: "Continue, Crimson"))
    }
    @Test(arguments: [1, 2]) func setupHandsOverSilently(first: Int) throws {
        // First player 1: the same human places last and takes the first turn.
        // First player 2: an AI places last and takes the first turn; the next human placed last among humans.
        var s = seats(TestGames.fresh(), [.human, .human, .ai(.mate)])
        s.forcedRolls = (0..<3).map { $0 == first ? [6, 6] : [1, 1] }
        let vm = model(s)
        var inSetup = true
        while inSetup {
            #expect(vm.screen.handover == nil)
            try vm.apply(Engine.legalMoves(vm.state!).first!)
            switch vm.state!.phase {
            case .rollingForFirst, .setup: break
            default: inSetup = false
            }
        }
        #expect(vm.screen.handover == nil, "the first turn after setup")
    }
    @Test func noBlankAtGameOver() {
        var s = TestGames.rolled(8)
        s.phase = .gameOver(winner: 1)
        #expect(model(s).screen.handover == nil)
    }
    @Test func reopeningBlanksForWhoeverMustAct() {
        #expect(model(TestGames.rolled(8)).screen.handover == passTo(0, .crimson, button: "Continue, Crimson"))
    }
    @Test func reopeningDuringSetupDoesNotBlank() {
        #expect(model(TestGames.fresh()).screen.handover == nil)
    }
    @Test func backgroundBlanksAgain() {
        let vm = model(TestGames.rolled(8))
        vm.revealHand()
        vm.concealHand()
        #expect(vm.screen.handover == passTo(0, .crimson, button: "Continue, Crimson"))
    }
    @Test func backgroundDuringSetupDoesNotBlank() {
        let vm = model(TestGames.fresh())
        vm.concealHand()
        #expect(vm.screen.handover == nil)
    }
    @Test func backgroundWithOneHumanDoesNotBlank() {
        let vm = model(seats(TestGames.rolled(8), [.human, .ai(.mate), .ai(.mate)]))
        vm.concealHand()
        #expect(vm.screen.handover == nil)
    }

    // Nothing private of one player may reach another, whoever holds the device.

    func withHiddenPoint(_ s: GameState, for seat: Int) -> GameState {
        var s = s
        s.players[seat].devCards.append(DevCard(type: .victoryPoint, boughtOnTurn: 0))
        return s
    }
    @Test func hiddenPointsShowToTheirOwnerOnTheirTurn() {
        let vm = model(withHiddenPoint(TestGames.rolled(8), for: 0))
        vm.revealHand()
        #expect(vm.screen.scoreboard[0].hidden == "+1")
    }
    @Test func aResponderDoesNotSeeTheProposersHiddenPoints() {
        var s = withHiddenPoint(TestGames.rolled(8), for: 0)
        s.clearHands()
        s.set(hand: [.timber: 2], for: 0)
        s.set(hand: [.ore: 1], for: 1)
        let vm = model(s)
        vm.ui.offerGive = [.timber: 2]
        vm.ui.offerWant = [.ore: 1]
        vm.proposeOffer()
        vm.revealHand()
        #expect(vm.screen.holdTitle == "Cobalt's hold")
        #expect(vm.screen.scoreboard[0].hidden == nil)
    }
    @Test func hiddenPointsStayHiddenWhileAnAIActs() {
        var s = seats(withHiddenPoint(TestGames.rolled(8), for: 0), [.human, .human, .ai(.mate)])
        s.phase = .tradeOffered(offer: TradeOffer(proposer: 0, give: [.timber: 1], want: [.ore: 1], to: nil), responses: [1: .declined, 2: .pending])
        let sc = ScreenState.derive(state: s, ui: UIState(), aiThinking: true, reduceMotion: false)
        #expect(sc.scoreboard[0].hidden == nil)
    }
    @Test func previewWinIsOffWhileAnotherPlayerHoldsTheDevice() {
        var s = TestGames.rolled(8)
        s.clearHands()
        s.set(hand: [.timber: 2], for: 0)
        s.set(hand: [.ore: 1], for: 1)
        let vm = model(s)
        vm.revealHand()
        #expect(vm.screen.buttons[Strings.previewWin] == true)
        vm.ui.offerGive = [.timber: 2]
        vm.ui.offerWant = [.ore: 1]
        vm.proposeOffer()
        vm.revealHand()
        #expect(vm.screen.buttons[Strings.previewWin] == false)
    }
    @Test func aHalfBuiltTradeDoesNotCarryToTheNextPlayer() {
        var s = TestGames.rolled(8)
        s.clearHands()
        s.set(hand: [.ore: 4], for: 0)
        s.set(hand: [.ore: 4], for: 1)
        let vm = model(s)
        vm.revealHand()
        vm.ui.offerGive = [.ore: 2]
        vm.ui.offerWant = [.clay: 1]
        vm.ui.offerTarget = 1
        vm.ui.bankChoice = TradeChoice(give: .ore, get: .wool)
        vm.ui.harbourChoice[0] = TradeChoice(give: .ore, get: .wool)
        vm.endTurn()
        #expect(vm.ui.offerGive.isEmpty)
        #expect(vm.ui.offerWant.isEmpty)
        #expect(vm.ui.offerTarget == nil)
        #expect(vm.ui.bankChoice == nil)
        #expect(vm.ui.harbourChoice.isEmpty)
    }
}
