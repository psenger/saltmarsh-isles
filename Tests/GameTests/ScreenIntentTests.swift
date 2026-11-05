import Testing
import SaltmarshEngine
import SaltmarshAI
import SaltmarshTestSupport
@testable import SaltmarshGame

@MainActor @Suite struct ScreenIntentTests {
    func humans(_ s: GameState) -> GameViewModel {
        let vm = GameViewModel(store: InMemoryGameStore(), pacing: NoPacing()) { _, _ in nil }
        vm.load(s); return vm
    }
    func corners(_ s: GameState) -> Set<Int> { Set(Engine.legalMoves(s).compactMap { if case .placeSettlement(let c) = $0 { c } else { nil } }) }
    func edges(_ s: GameState) -> Set<Int> { Set(Engine.legalMoves(s).compactMap { if case .placeRoad(let e) = $0 { e } else { nil } }) }
    func sevenRolled(crimson: Int = 4, cobalt: Int = 9, amber: Int = 10) -> GameState {
        var s = TestGames.afterSetup(); s.clearBoard(); s.clearHands()
        func hand(_ n: Int) -> ResourceCounts { var h = ResourceCounts(); for i in 0..<n { h[Resource.allCases[i % 5]] += 1 }; return h }
        s.set(hand: hand(crimson), for: 0); s.set(hand: hand(cobalt), for: 1); s.set(hand: hand(amber), for: 2)
        s.current = 0; s.phase = .awaitingRoll; s.force(roll: 7); try! Engine.apply(.roll, to: &s); return s
    }
    func harbour(_ s: GameState, _ kind: Harbour.Kind) -> Int { s.board.harbours.firstIndex { $0.kind == kind }! }

    @Test func glowAndDashFollowLegalMoves() throws {
        var f = TestGames.fresh(); f.forcedRolls = [[6, 6], [1, 1], [1, 1]]; for _ in 0..<3 { try Engine.apply(.rollForFirst, to: &f) }
        let vm = humans(f)
        #expect(vm.screen.glowingCorners == corners(f)); #expect(vm.screen.dashedEdges.isEmpty)
        vm.tapCorner(corners(f).min()!)
        #expect(vm.screen.dashedEdges == edges(vm.state!)); #expect(vm.screen.glowingCorners.isEmpty)
        var s = TestGames.rolled(8); s.clearBoard(); s.clearHands(); s.place(settlement: 0, owner: 0); s.place(road: s.board.corners[0].edges[0], owner: 0)
        s.set(hand: Cost.road + Cost.settlement + Cost.city, for: 0); vm.load(s)
        #expect(vm.screen.dashedEdges.isEmpty); #expect(vm.screen.glowingCorners.isEmpty); #expect(vm.screen.pulsingSettlements.isEmpty)
        vm.toggleBuildMode(.road); #expect(vm.screen.dashedEdges == edges(vm.state!))
        vm.toggleBuildMode(.settlement); #expect(vm.screen.glowingCorners == corners(vm.state!)); #expect(vm.screen.dashedEdges.isEmpty)
        vm.toggleBuildMode(.city); #expect(vm.screen.pulsingSettlements == [0])
        var free = s; free.players[0].devCards = [DevCard(type: .roadCrew, boughtOnTurn: -1)]; vm.load(free); vm.playCard(0)
        #expect(vm.screen.dashedEdges == edges(vm.state!))
    }
    @Test func robberIntentAndStealTargets() {
        let vm = humans(sevenRolled(cobalt: 7, amber: 3))
        #expect(vm.screen.selectableTiles == Set(0..<19).subtracting([vm.state!.robberTile])); #expect(vm.screen.hitNumber == nil)
        #expect(vm.screen.desertLabelBelowRobber); #expect(!vm.screen.numberDiscBelowRobber)
        var s = vm.state!; let tile = s.tile(numbered: 8); let corner = s.board.tiles[tile].corners[0]
        s.place(settlement: corner, owner: 1); s.set(hand: .uniform(1), for: 1); vm.load(s); vm.tapTile(tile)
        #expect(vm.screen.robberTile == tile); #expect(vm.screen.numberDiscBelowRobber); #expect(!vm.screen.desertLabelBelowRobber)
        #expect(vm.screen.stealTargets == [StealTarget(seat: .cobalt, name: "Cobalt", cards: 5, corners: [corner])]); #expect(vm.screen.selectableTiles.isEmpty)
        vm.tapCorner(corner); #expect(vm.screen.stealTargets.isEmpty); #expect(vm.state!.players[1].hand.total == 4)
    }
    @Test func hitAndHotNumbers() {
        let vm = humans(TestGames.rolled(8)); #expect(vm.screen.hitNumber == 8); #expect(vm.screen.hotNumbers == [6, 8])
        var s = vm.state!; s.dice = nil; vm.load(s); #expect(vm.screen.hitNumber == nil)
    }
    @Test func discardBox() {
        let vm = humans(sevenRolled()); var box = vm.screen.discardBox!
        #expect(box.title == "Oh NO! Cobalt, the robber needs 4 cards from your deck"); #expect(box.counter == "0 / 4"); #expect(box.next == "Next: Amber")
        #expect(box.confirmLabel == "Discard 4 cards"); #expect(!box.confirmEnabled); #expect(box.outlineSeat == .cobalt)
        #expect(box.rows.map(\.resource) == [.timber, .clay, .wool, .grain, .ore]); #expect(box.rows[0].label == "0 of 2"); #expect(box.rows[4].label == "0 of 1")
        #expect(box.rows.allSatisfy { !$0.minusEnabled && $0.plusEnabled })
        vm.discardAdjust(.timber, by: 2); vm.discardAdjust(.clay, by: 2); box = vm.screen.discardBox!
        #expect(box.counter == "4 / 4"); #expect(box.rows.allSatisfy { !$0.plusEnabled }); #expect(box.rows[0].minusEnabled); #expect(box.confirmEnabled); #expect(box.rows[0].label == "2 of 2")
        vm.confirmDiscard(); #expect(vm.screen.discardBox?.title == "Oh NO! Amber, the robber needs 5 cards from your deck"); #expect(vm.screen.discardBox?.next == nil)
        let s = sevenRolled(cobalt: 7, amber: 3); #expect(humans(s).screen.discardBox == nil)
    }
    @Test func harbourRows() {
        var s = TestGames.rolled(8); s.clearBoard(); s.clearHands(); let vm = humans(s)
        #expect(vm.screen.harbours.rows.isEmpty); #expect(vm.screen.harbours.emptyText == "None yet. Build a settlement on a corner joined to a harbour by a jetty.")
        let any = harbour(s, .any), grain = harbour(s, .specific(.grain)), wool = harbour(s, .specific(.wool))
        s.place(settlement: s.board.harbours[any].a, owner: 0); vm.load(s); var rows = vm.screen.harbours.rows
        #expect(rows.map(\.title) == ["3:1 any"]); #expect(rows[0].heldBy == "your settlement"); #expect(rows[0].tradeLabel == "Trade 3 for 1"); #expect(rows[0].giveFixed == nil)
        #expect(vm.screen.harbourRings[any] == [.crimson]); #expect(vm.screen.harbours.emptyText == nil)
        s.place(settlement: s.board.harbours[grain].a, owner: 0); s.place(city: s.board.harbours[grain].b, owner: 0); vm.load(s); rows = vm.screen.harbours.rows
        #expect(rows.count == 2); let grainRow = rows.first { $0.title == "2:1 grain" }
        #expect(grainRow?.heldBy == "your settlement and city"); #expect(grainRow?.giveFixed == "2 grain")
        var t = s; t.clearBoard(); t.place(settlement: t.board.harbours[wool].a, owner: 0); t.place(settlement: t.board.harbours[wool].b, owner: 1); t.set(hand: [.wool: 2], for: 0); vm.load(t)
        #expect(vm.screen.harbourRings[wool] == [.crimson, .cobalt]); #expect(vm.screen.harbours.rows[0].tradeEnabled); #expect(vm.screen.harbours.rows[0].tradeLabel == "Trade 2 for 1")
        t.set(hand: [.wool: 1], for: 0); vm.load(t); #expect(!vm.screen.harbours.rows[0].tradeEnabled)
    }
    @Test func devCardRows() {
        var s = TestGames.rolled(8); s.clearHands(); s.players[0].devCards = [DevCard(type: .knight, boughtOnTurn: s.turn), DevCard(type: .victoryPoint, boughtOnTurn: -1), DevCard(type: .bumperHarvest, boughtOnTurn: -1)]
        let vm = humans(s); var rows = vm.screen.devCards
        #expect(rows.map(\.name) == ["Knight", "Victory point", "Bumper harvest"]); #expect(rows[0].note == "bought this turn"); #expect(!rows[0].playEnabled)
        #expect(rows[1].note == "counts automatically"); #expect(!rows[1].playEnabled); #expect(rows[2].note == nil); #expect(rows[2].playEnabled); #expect(rows[2].needsChoices)
        #expect(vm.screen.deckCount == 25)
        vm.playCard(2, bumper: (.ore, .ore)); rows = vm.screen.devCards
        #expect(rows.map(\.name) == ["Knight", "Victory point"]); #expect(rows[0].note == "bought this turn")
        var t = TestGames.afterSetup(); t.players[0].devCards = [DevCard(type: .knight, boughtOnTurn: -1), DevCard(type: .roadCrew, boughtOnTurn: -1)]; vm.load(t); rows = vm.screen.devCards
        #expect(rows[0].playEnabled); #expect(!rows[1].playEnabled); #expect(rows[1].note == Strings.rollFirst)
        var u = TestGames.rolled(8); u.players[0].devCards = [DevCard(type: .knight, boughtOnTurn: -1), DevCard(type: .roadCrew, boughtOnTurn: -1)]; u.devCardPlayedThisTurn = true; vm.load(u)
        #expect(vm.screen.devCards.map(\.note) == ["one card per turn", "one card per turn"])
    }
    @Test func tradeSection() {
        var s = TestGames.rolled(8); s.clearBoard(); s.clearHands(); s.set(hand: [.timber: 3], for: 0); s.set(hand: [.ore: 2], for: 1); s.set(hand: [.grain: 1], for: 2)
        let vm = humans(s); #expect(vm.screen.tradeSection.targets == [.cobalt, .amber]); #expect(!vm.screen.tradeSection.offerEnabled); #expect(vm.screen.tradeSection.offerProblem == "give side is empty")
        vm.offerAdjust(give: .timber, by: 2); vm.offerAdjust(want: .ore, by: 1); #expect(vm.screen.tradeSection.offerEnabled); #expect(vm.screen.tradeSection.offerGive == [.timber: 2])
        vm.proposeOffer(); vm.respondToOffer(accept: true); vm.respondToOffer(accept: false)
        let responses = vm.screen.tradeSection.responses
        #expect(responses.map(\.seat) == [.cobalt, .amber]); #expect(responses.map(\.text) == ["accepted", "declined"]); #expect(responses.map(\.canTrade) == [true, false])
        var c = vm.state!; c.phase = .tradeOffered(offer: TradeOffer(proposer: 0, give: [.timber: 2], want: [.ore: 1], to: nil), responses: [1: .countered(TradeOffer(proposer: 0, give: [.timber: 3], want: [.ore: 1], to: 1)), 2: .declined]); vm.load(c)
        #expect(vm.screen.tradeSection.responses[0].text == "countered: 3 timber for 1 ore"); #expect(vm.screen.tradeSection.responses[0].canTrade)
    }
    @Test func victoryCardAndConfetti() throws {
        var s = TestGames.rolled(8); s.clearBoard(); s.clearHands()
        let spots = s.spreadCorners(6); for c in spots.prefix(3) { s.place(settlement: c, owner: 0) }; for c in spots.dropFirst(3) { s.place(city: c, owner: 0) }
        let reach = s.addReach(from: spots[0], owner: 0); s.set(hand: Cost.settlement, for: 0)
        let vm = humans(s); #expect(vm.screen.victory == nil)
        vm.showPreviewWin(); var card = vm.screen.victory!
        #expect(card.title == "Preview"); #expect(card.winner == "Crimson wins"); #expect(card.subtitle == "This is what the win screen looks like. The game carries on.")
        #expect(card.buttons == ["Back to the game"]); #expect(card.total == 9); vm.dismissOverlay()
        vm.toggleBuildMode(.settlement); vm.tapCorner(reach); card = vm.screen.victory!
        #expect(card.title == "Victory"); #expect(card.seat == .crimson); #expect(card.subtitle == "Rules the isles after 1 rounds.")
        #expect(card.breakdown.map(\.label) == ["Settlements", "Cities"]); #expect(card.breakdown.map(\.points) == [4, 6]); #expect(card.total == 10)
        #expect(card.banner == "Crimson rules the isles with 10 points."); #expect(card.buttons == ["See the board", "New game"])
        #expect(card.confetti?.bursts.map(\.origin) == ["centre", "bottom-left", "bottom-right", "bottom-left", "bottom-right"])
        #expect(card.confetti?.bursts.map(\.delay) == [0, 0, 0, 0.55, 0.55]); #expect(card.confetti?.bursts.map(\.pieces) == [170, 90, 90, 60, 60])
        #expect(vm.screen.victoryAnimation == .full); #expect(vm.screen.championCorners == Set(spots) .union([reach]))
        vm.dismissOverlay(); #expect(vm.screen.victory == nil); #expect(vm.screen.championCorners.count == 7)
        vm.reduceMotion = true; vm.showPreviewWin(); #expect(vm.screen.victory?.confetti == nil); #expect(vm.screen.victoryAnimation == .reduced)
    }
}
