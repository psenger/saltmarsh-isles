import Testing
import SaltmarshEngine
import SaltmarshAI
import SaltmarshTestSupport
@testable import SaltmarshGame

@MainActor @Suite struct InteractionTests {
    func humans() -> GameViewModel {
        let vm = GameViewModel(store: InMemoryGameStore(), pacing: NoPacing()) { _, _ in nil }
        vm.newGame(GameConfig(controllers: [.human, .human, .human], seed: 1)); return vm
    }
    @Test func buildModeTogglesAndClears() throws {
        let vm = humans(); var s = TestGames.rolled(8); s.clearBoard(); s.clearHands(); s.place(settlement: 0, owner: 0); s.set(hand: Cost.road, for: 0); vm.load(s)
        vm.toggleBuildMode(.road); #expect(vm.ui.buildMode == .road); vm.toggleBuildMode(.road); #expect(vm.ui.buildMode == nil)
        vm.toggleBuildMode(.road); let e = vm.state!.board.corners[0].edges[0]; vm.tapEdge(e)
        #expect(vm.state!.board.edges[e].owner == 0); #expect(vm.ui.buildMode == nil)
    }
    @Test func discardPickerClamps() {                                    // Review Focus 4
        let vm = humans(); var s = TestGames.afterSetup(); s.clearHands(); s.set(hand: [.timber: 8], for: 1)
        s.current = 0; s.phase = .awaitingRoll; s.force(roll: 7); try! Engine.apply(.roll, to: &s); vm.load(s)
        #expect(vm.discardRequired == 4)
        for _ in 0..<6 { vm.discardAdjust(.timber, by: 1) }; #expect(vm.ui.discardPicks == [.timber: 4]); #expect(vm.canConfirmDiscard)
        vm.discardAdjust(.timber, by: -1); #expect(!vm.canConfirmDiscard); vm.discardAdjust(.clay, by: -1); #expect(vm.ui.discardPicks[.clay] == 0)
        vm.discardAdjust(.timber, by: 1); vm.confirmDiscard(); #expect(vm.state!.players[1].hand == [.timber: 4]); #expect(vm.ui.discardPicks.isEmpty)
    }
    @Test func offerBuilderAndHumanResponse() {                           // Review Focus 3
        let vm = humans(); var s = TestGames.rolled(8); s.clearBoard(); s.clearHands()
        s.set(hand: [.timber: 2], for: 0); s.set(hand: [.ore: 1], for: 1); s.set(hand: [.grain: 1], for: 2); vm.load(s)
        vm.offerAdjust(give: .timber, by: 2); #expect(vm.offerProblem() == "want side is empty")
        vm.offerAdjust(want: .ore, by: 1); #expect(vm.offerProblem() == nil); vm.proposeOffer()
        #expect(Engine.actingPlayer(vm.state!) == 1)
        vm.respondToOffer(accept: true); #expect(Engine.actingPlayer(vm.state!) == 2)
        vm.respondToOffer(accept: true)                                   // Amber cannot pay: ignored, stays pending
        #expect(Engine.actingPlayer(vm.state!) == 2); vm.respondToOffer(accept: false)
        #expect(Engine.actingPlayer(vm.state!) == 0); vm.executeTrade(with: 1)
        #expect(vm.state!.players[0].hand == [.ore: 1]); #expect(vm.ui.offerGive.isEmpty)
    }
    @Test func winOpensTheOverlayAndPreviewDoesNot() throws {
        let vm = humans(); var s = TestGames.rolled(8); s.clearBoard(); s.clearHands()
        let spots = s.spreadCorners(6); for c in spots.prefix(3) { s.place(settlement: c, owner: 0) }; for c in spots.dropFirst(3) { s.place(city: c, owner: 0) }
        let reach = s.addReach(from: spots[0], owner: 0); s.set(hand: Cost.settlement, for: 0); vm.load(s)
        vm.showPreviewWin(); #expect(vm.ui.overlay == .preview(seat: 0)); vm.dismissOverlay(); #expect(vm.ui.overlay == nil)
        vm.toggleBuildMode(.settlement); vm.tapCorner(reach)
        #expect(vm.ui.overlay == .victory(winner: 0)); vm.dismissOverlay(); #expect(vm.ui.overlay == nil)
        vm.tapCorner(reach); #expect(vm.state!.phase == .gameOver(winner: 0))  // locked, no crash
    }
    @Test func tapsFollowThePhase() throws {
        let vm = humans(); var f = TestGames.fresh(); f.forcedRolls = [[6, 6], [1, 1], [1, 1]]; vm.load(f)
        for _ in 0..<3 { vm.rollForFirst() }
        guard case .setup = vm.state!.phase else { Issue.record("not in setup: \(vm.state!.phase)"); return }
        let corner = Engine.legalMoves(vm.state!).compactMap { if case .placeSettlement(let c) = $0 { c } else { nil } }.first!
        vm.tapCorner(corner); #expect(vm.state!.board.corners[corner].owner == vm.state!.current)
        let edge = vm.state!.board.corners[corner].edges[0]; vm.tapEdge(edge); #expect(vm.state!.board.edges[edge].owner != nil)
        var s = TestGames.afterSetup(); s.clearHands(); s.current = 0; s.phase = .awaitingRoll; s.force(roll: 7); vm.load(s)
        vm.rollDice(); #expect(vm.state!.phase == .movingRobber(returnTo: .main))
        let tile = (vm.state!.robberTile + 1) % 19; vm.tapTile(tile); #expect(vm.state!.robberTile == tile)
    }
}
