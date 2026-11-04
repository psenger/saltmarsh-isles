import Testing
@testable import SaltmarshEngine
import SaltmarshTestSupport

@Suite struct RobberTests {
    func sevenRolled(crimson: Int = 4, cobalt: Int = 9, amber: Int = 10) -> GameState {
        var s = TestGames.afterSetup(); s.clearBoard(); s.clearHands()
        func hand(_ n: Int) -> ResourceCounts { var h = ResourceCounts(); for i in 0..<n { h[Resource.allCases[i % 5]] += 1 }; return h }
        s.set(hand: hand(crimson), for: 0); s.set(hand: hand(cobalt), for: 1); s.set(hand: hand(amber), for: 2)
        s.current = 0; s.phase = .awaitingRoll; s.force(roll: 7); try! Engine.apply(.roll, to: &s); return s
    }
    @Test func queueFormsInSeatOrder() {
        let s = sevenRolled()
        #expect(s.phase == .discarding(queue: [1, 2])); #expect(Engine.actingPlayer(s) == 1)
        #expect(Engine.legalMoves(s).allSatisfy { if case .discard(let c) = $0 { c.total == 4 } else { false } })
    }
    @Test func rollerDiscardsTooWhenOverSeven() {       // Review Focus 1
        let s = sevenRolled(crimson: 9)
        #expect(s.phase == .discarding(queue: [0, 1, 2]))
    }
    @Test func wrongCountIsIllegal() {
        var s = sevenRolled(); let c = Engine.legalMoves(s).first!
        #expect(throws: EngineError.self) { try Engine.apply(.discard([.timber: 1]), to: &s) }
        #expect(throws: Never.self) { try Engine.apply(c, to: &s) }
    }
    @Test func confirmingMovesQueueThenRobber() throws {
        var s = sevenRolled(); let before = s.players[1].hand, bank = s.bank
        let pick: ResourceCounts = [.timber: 2, .clay: 2]
        try Engine.apply(.discard(pick), to: &s)
        #expect(s.players[1].hand == before - pick); #expect(s.bank == bank + pick)
        #expect(s.log.last == "Cobalt discarded 2 timber, 2 clay."); #expect(Engine.actingPlayer(s) == 2)
        try Engine.apply(Engine.legalMoves(s).first!, to: &s)
        #expect(s.phase == .movingRobber(returnTo: .main)); #expect(s.log.last == "Crimson now moves the robber.")
    }
    @Test func nobodyOverSevenSkipsToRobber() {
        #expect(sevenRolled(cobalt: 7, amber: 3).phase == .movingRobber(returnTo: .main))
    }
    @Test func robberMustChangeTile() {
        var s = sevenRolled(cobalt: 7, amber: 3)
        #expect(Engine.legalMoves(s).count == 18)
        #expect(throws: EngineError.self) { try Engine.apply(.moveRobber(tile: s.robberTile), to: &s) }
    }
    @Test func stealIsAVisibleStepEvenWithOneVictim() throws {
        var s = sevenRolled(cobalt: 5, amber: 3)
        let t = s.tile(numbered: 8); s.place(settlement: s.board.tiles[t].corners[0], owner: 1)
        try Engine.apply(.moveRobber(tile: t), to: &s)
        #expect(s.robberTile == t); #expect(s.phase == .choosingVictim(candidates: [1], returnTo: .main))
        #expect(s.log.last == "Crimson moved the robber.")
        try Engine.apply(.steal(from: 1), to: &s)
        #expect(s.players[1].hand.total == 4); #expect(s.players[0].hand.total == 5)
        #expect(s.log.last == "Crimson stole a card from Cobalt."); #expect(s.phase == .main)
    }
    @Test func twoVictimsOffered() throws {
        var s = sevenRolled(cobalt: 5, amber: 5)
        let t = s.tile(numbered: 8)
        s.place(settlement: s.board.tiles[t].corners[0], owner: 1); s.place(settlement: s.board.tiles[t].corners[3], owner: 2)
        try Engine.apply(.moveRobber(tile: t), to: &s)
        #expect(s.phase == .choosingVictim(candidates: [1, 2], returnTo: .main))
    }
    @Test func noVictimsLogsAndContinues() throws {
        var s = sevenRolled(cobalt: 7, amber: 0)
        let t = s.tile(numbered: 8); s.place(settlement: s.board.tiles[t].corners[0], owner: 2)
        try Engine.apply(.moveRobber(tile: t), to: &s)
        #expect(s.log.last == "Nobody on that tile has cards to steal."); #expect(s.phase == .main)
    }
    @Test func discardOptionsEnumerateOrGreedy() {
        #expect(Set(Engine.discardOptions(hand: [.timber: 3, .clay: 1], count: 2)) == Set([[.timber: 2], [.timber: 1, .clay: 1]] as [ResourceCounts]))
        #expect(Engine.discardOptions(hand: .uniform(4), count: 10) == [.uniform(2)])
    }
}
