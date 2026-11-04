import Testing
import SaltmarshEngine
import SaltmarshAI
import SaltmarshTestSupport
@testable import SaltmarshGame

@MainActor @Suite struct ScreenStateTests {
    func humans(_ s: GameState? = nil) -> GameViewModel {
        let vm = GameViewModel(store: InMemoryGameStore(), pacing: NoPacing()) { _, _ in nil }
        if let s { vm.load(s) } else { vm.newGame(GameConfig(controllers: [.human, .human, .human], seed: 1)) }
        return vm
    }
    func on(_ labels: [String], _ screen: ScreenState) -> [String] { labels.filter { screen.buttons[$0] == true } }
    let turnButtons = ["Roll dice", "Road", "Settlement", "City", "Buy a card", "Trade 4 for 1", "Offer", "End turn"]

    @Test func freshGameRollsForFirst() {
        let sc = humans().screen
        #expect(sc.header == "Crimson · first roll"); #expect(sc.headerSeat == .crimson)
        #expect(sc.status == "Roll for first player."); #expect(sc.buttons["Roll for first"] == true)
        #expect(on(turnButtons, sc).isEmpty); #expect(sc.orderStrip == [.crimson, .cobalt, .amber]); #expect(sc.log.last == "New game with 3 players. Everyone rolls for first player.")
    }
    @Test func setupStrings() throws {
        var f = TestGames.fresh(); f.forcedRolls = [[1, 1], [1, 1], [6, 6]]; for _ in 0..<3 { try Engine.apply(.rollForFirst, to: &f) }
        let vm = humans(f); var sc = vm.screen
        #expect(sc.header == "Amber · setup"); #expect(sc.headerSeat == .amber); #expect(sc.status == "Tap a glowing corner to place a settlement.")
        #expect(sc.orderStrip == [.amber, .crimson, .cobalt, .cobalt, .crimson, .amber]); #expect(sc.orderStripNote == nil); #expect(on(turnButtons, sc).isEmpty)
        vm.tapCorner(Engine.legalMoves(vm.state!).compactMap { if case .placeSettlement(let c) = $0 { c } else { nil } }.first!)
        sc = vm.screen; #expect(sc.status == "Tap a dashed edge next to it to lay a road.")
        for _ in 0..<3 { try vm.apply(Engine.legalMoves(vm.state!).first!) }   // road, then Crimson's settlement + road
        for _ in 0..<2 { try vm.apply(Engine.legalMoves(vm.state!).first!) }   // Cobalt's first pair
        #expect(vm.screen.orderStripNote == "Round 2: reverse order")
    }
    @Test func awaitingRollAndMain() throws {
        let vm = humans(TestGames.afterSetup()); var sc = vm.screen
        #expect(sc.header == "Crimson"); #expect(sc.status == "Roll the dice to start your turn."); #expect(sc.dice == ["–", "–"])
        #expect(on(turnButtons, sc) == ["Roll dice"]); #expect(sc.holdTitle == "Crimson's hold"); #expect(sc.handCounts == vm.state!.players[0].hand)
        var s = vm.state!; s.force(roll: 8); vm.load(s); vm.rollDice(); sc = vm.screen
        #expect(sc.status == "Build, trade, or end your turn."); #expect(sc.dice == ["6", "2"]); #expect(sc.buttons["Roll dice"] == false); #expect(sc.buttons["End turn"] == true)
        vm.toggleBuildMode(.road); #expect(vm.screen.status == "Tap a dashed edge to build a road."); #expect(vm.screen.activeBuildMode == .road)
        vm.toggleBuildMode(.settlement); #expect(vm.screen.status == "Tap a glowing corner to build a settlement.")
        vm.toggleBuildMode(.city); #expect(vm.screen.status == "Tap one of your settlements to upgrade it.")
        #expect(vm.screen.bank == vm.state!.bank); #expect(vm.screen.deckCount == 25); #expect(vm.screen.buildLeft[.road] == 15 - vm.state!.roads(of: 0))
    }
    func sevenRolled() -> GameState {
        var s = TestGames.afterSetup(); s.clearBoard(); s.clearHands()
        func hand(_ n: Int) -> ResourceCounts { var h = ResourceCounts(); for i in 0..<n { h[Resource.allCases[i % 5]] += 1 }; return h }
        s.set(hand: hand(4), for: 0); s.set(hand: hand(9), for: 1); s.set(hand: hand(10), for: 2)
        s.current = 0; s.phase = .awaitingRoll; s.force(roll: 7); try! Engine.apply(.roll, to: &s); return s
    }
    @Test func discardingPanelBelongsToTheDiscarder() {
        let vm = humans(sevenRolled()); let sc = vm.screen
        #expect(sc.header == "Cobalt · discarding"); #expect(sc.headerSeat == .cobalt)
        #expect(sc.status == "Crimson rolled 7. Cobalt has more than 7 cards and must give up half. Pass the device to Cobalt.")
        #expect(sc.holdTitle == "Cobalt's hold"); #expect(sc.handCounts == vm.state!.players[1].hand)
        #expect(on(turnButtons, sc).isEmpty); #expect(sc.buttons["Discard 4 cards"] == false)
        vm.discardAdjust(.timber, by: 2); vm.discardAdjust(.clay, by: 2); #expect(vm.screen.buttons["Discard 4 cards"] == true)
    }
    @Test func robberVictimAndFreeRoadStrings() throws {
        var s = sevenRolled(); s.set(hand: [:], for: 1); s.set(hand: [:], for: 2); s.phase = .movingRobber(returnTo: .main)
        let vm = humans(s); #expect(vm.screen.status == "Tap a tile to move the robber there."); #expect(vm.screen.header == "Crimson")
        var t = vm.state!; t.set(hand: [.ore: 2], for: 1); let tile = t.tile(numbered: 8); t.place(settlement: t.board.tiles[tile].corners[0], owner: 1); vm.load(t)
        vm.tapTile(tile); #expect(vm.screen.status == "Steal a card: tap a glowing building on the robber's tile, or a name below.")
        var u = TestGames.rolled(8); u.clearBoard(); u.clearHands(); u.place(settlement: 0, owner: 0); u.players[0].devCards = [DevCard(type: .roadCrew, boughtOnTurn: -1)]; vm.load(u)
        vm.playCard(0); #expect(vm.screen.status == "Road crew: tap a dashed edge for a free road (2 left)."); #expect(on(turnButtons, vm.screen).isEmpty)
    }
    @Test func tradeOfferPanels() throws {
        var s = TestGames.rolled(8); s.clearBoard(); s.clearHands(); s.set(hand: [.timber: 2], for: 0); s.set(hand: [.grain: 1], for: 1); s.set(hand: [.ore: 1], for: 2)
        let vm = humans(s); vm.offerAdjust(give: .timber, by: 2); vm.offerAdjust(want: .ore, by: 1); vm.proposeOffer()
        var sc = vm.screen
        #expect(sc.header == "Cobalt · trade offer"); #expect(sc.headerSeat == .cobalt); #expect(sc.status == "Crimson offers 2 timber for 1 ore.")
        #expect(sc.buttons["Accept"] == false); #expect(sc.acceptProblem == "You don't have 1 ore"); #expect(sc.buttons["Decline"] == true); #expect(sc.holdTitle == "Cobalt's hold"); #expect(sc.handCounts == [.grain: 1])
        vm.respondToOffer(accept: false); sc = vm.screen
        #expect(sc.header == "Amber · trade offer"); #expect(sc.buttons["Accept"] == true); #expect(sc.acceptProblem == nil)
        vm.respondToOffer(accept: true); sc = vm.screen
        #expect(sc.header == "Crimson"); #expect(sc.status == "Answers are in. Trade with someone or withdraw."); #expect(sc.buttons["Withdraw"] == true)
        var waiting = vm.state!; waiting.phase = .tradeOffered(offer: TradeOffer(proposer: 0, give: [.timber: 2], want: [.ore: 1], to: nil), responses: [1: .declined, 2: .pending]); vm.load(waiting)
        #expect(vm.screen.header == "Amber · trade offer")
    }
    @Test func gameOverLocksEverything() throws {
        var s = TestGames.rolled(8); s.clearBoard(); s.clearHands()
        let spots = s.spreadCorners(6); for c in spots.prefix(3) { s.place(settlement: c, owner: 0) }; for c in spots.dropFirst(3) { s.place(city: c, owner: 0) }
        let reach = s.addReach(from: spots[0], owner: 0); s.set(hand: Cost.settlement, for: 0)
        let vm = humans(s); vm.toggleBuildMode(.settlement); vm.tapCorner(reach); let sc = vm.screen
        #expect(sc.status == "Game over."); #expect(on(turnButtons + ["Roll for first", "Discard 4 cards"], sc).isEmpty); #expect(sc.buttons["New game"] == true)
    }
    @Test func aiThinkingHidesControlsAndShowsTheSingleHumanHand() {
        var s = TestGames.rolled(8); s.players[1].controller = .ai(.mate); s.players[2].controller = .ai(.mate); s.current = 1; s.phase = .awaitingRoll
        let one = ScreenState.derive(state: s, ui: UIState(), aiThinking: true, reduceMotion: false)
        #expect(one.status == "Cobalt is thinking…"); #expect(one.header == "Cobalt"); #expect(on(turnButtons, one).isEmpty)
        #expect(one.handCounts == s.players[0].hand); #expect(one.holdTitle == "Crimson's hold")
        s.players[2].controller = .human
        let two = ScreenState.derive(state: s, ui: UIState(), aiThinking: true, reduceMotion: false)
        #expect(two.handCounts.isEmpty); #expect(two.holdTitle == "")
    }
    @Test func anAIsHandIsNeverShown() {
        var s = TestGames.rolled(8); s.clearHands(); s.set(hand: [.ore: 2], for: 0); s.set(hand: [.wool: 3], for: 1)
        s.players[1].controller = .ai(.mate); s.players[2].controller = .ai(.mate); s.current = 1; s.phase = .gameOver(winner: 1)
        let one = ScreenState.derive(state: s, ui: UIState(), aiThinking: false, reduceMotion: false)
        #expect(one.holdTitle == "Crimson's hold"); #expect(one.handCounts == [.ore: 2])
        s.players[2].controller = .human
        let two = ScreenState.derive(state: s, ui: UIState(), aiThinking: false, reduceMotion: false)
        #expect(two.holdTitle == ""); #expect(two.handCounts.isEmpty)
    }
    @Test func scoreboardRows() {
        var s = TestGames.rolled(8); s.players[0].devCards = [DevCard(type: .victoryPoint, boughtOnTurn: 0)]; s.players[1].controller = .ai(.mate)
        s.players[1].devCards = [DevCard(type: .victoryPoint, boughtOnTurn: 0)]; s.players[2].knightsPlayed = 3; s.largestArmyHolder = 2
        let sc = ScreenState.derive(state: s, ui: UIState(), aiThinking: false, reduceMotion: false)
        #expect(sc.scoreboard.map(\.name) == ["Crimson", "Cobalt", "Amber"]); #expect(sc.scoreboard[0].colorHex == "#c0392b")
        #expect(sc.scoreboard[0].score == "2 / 10"); #expect(sc.scoreboard[0].hidden == "+1"); #expect(sc.scoreboard[0].isCurrent)
        #expect(sc.scoreboard[1].hidden == nil); #expect(sc.scoreboard[1].devCards == 1)
        #expect(sc.scoreboard[2].score == "4 / 10"); #expect(sc.scoreboard[2].knights == 3); #expect(sc.scoreboard[2].knightsHighlighted); #expect(!sc.scoreboard[2].roadHighlighted)
        #expect(sc.scoreboard[0].cards == s.players[0].hand.total); #expect(sc.scoreboard[0].road == Engine.roadLength(s, player: 0))
    }
}
