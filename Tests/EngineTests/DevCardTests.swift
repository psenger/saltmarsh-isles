import Testing
@testable import SaltmarshEngine
import SaltmarshTestSupport

@Suite struct DevCardTests {
    func base() -> GameState { var s = TestGames.rolled(8); s.clearBoard(); s.clearHands(); s.place(settlement: 0, owner: 0); s.place(road: s.board.corners[0].edges[0], owner: 0); return s }
    func give(_ s: inout GameState, _ type: DevCardType, turn: Int? = nil) { s.players[0].devCards.append(DevCard(type: type, boughtOnTurn: turn ?? (s.turn - 1))) }
    @Test func buyingACard() throws {
        var s = base(); s.set(hand: Cost.devCard, for: 0); let top = s.devDeck.last!
        try Engine.apply(.buyDevCard, to: &s)
        #expect(s.players[0].hand.isEmpty); #expect(s.players[0].devCards == [DevCard(type: top, boughtOnTurn: s.turn)]); #expect(s.devDeck.count == 24)
        #expect(s.log.last == "Crimson bought a development card.")
    }
    @Test func buyingNotAllowed() {
        var s = base(); #expect(!Engine.legalMoves(s).contains(.buyDevCard))
        s.set(hand: Cost.devCard, for: 0); s.devDeck = []; #expect(!Engine.legalMoves(s).contains(.buyDevCard))
        var t = TestGames.afterSetup(); t.set(hand: Cost.devCard, for: t.current); #expect(!Engine.legalMoves(t).contains(.buyDevCard))
    }
    @Test func cannotPlayCardBoughtThisTurn() { var s = base(); give(&s, .knight, turn: s.turn); #expect(!Engine.legalMoves(s).contains(.playKnight)) }
    @Test func oneCardPerTurn() throws {
        var s = base(); give(&s, .bumperHarvest); give(&s, .cornerMarket)
        try Engine.apply(.playCornerMarket(.ore), to: &s)
        #expect(!Engine.legalMoves(s).contains { if case .playBumperHarvest = $0 { true } else { false } })
    }
    @Test func knightBeforeRollOthersAfter() {
        var s = TestGames.afterSetup(); s.players[s.current].devCards = [DevCard(type: .knight, boughtOnTurn: -1), DevCard(type: .bumperHarvest, boughtOnTurn: -1)]
        #expect(Engine.legalMoves(s).contains(.playKnight)); #expect(!Engine.legalMoves(s).contains { if case .playBumperHarvest = $0 { true } else { false } })
    }
    @Test func knightBeforeRollFlow() throws {
        var s = TestGames.afterSetup(); s.clearBoard(); s.clearHands(); s.current = 0; s.players[0].devCards = [DevCard(type: .knight, boughtOnTurn: -1)]
        let t = s.tile(numbered: 8); s.place(settlement: s.board.tiles[t].corners[0], owner: 1); s.set(hand: [.ore: 2], for: 1)
        try Engine.apply(.playKnight, to: &s)
        #expect(s.players[0].knightsPlayed == 1); #expect(s.log.last == "Crimson played a Knight."); #expect(s.phase == .movingRobber(returnTo: .awaitingRoll))
        #expect(!Engine.legalMoves(s).contains(.roll))
        try Engine.apply(.moveRobber(tile: t), to: &s); try Engine.apply(.steal(from: 1), to: &s)
        #expect(s.phase == .awaitingRoll); #expect(Engine.legalMoves(s).contains(.roll)); #expect(s.players[0].hand == [.ore: 1])
    }
    @Test func knightAfterRollReturnsToMain() throws {
        var s = base(); give(&s, .knight); try Engine.apply(.playKnight, to: &s)
        #expect(s.phase == .movingRobber(returnTo: .main))
    }
    @Test func knightWithNoVictimsReturnsToAwaitingRoll() throws {          // Review Focus 4
        var s = TestGames.afterSetup(); s.clearBoard(); s.clearHands(); s.current = 0; s.players[0].devCards = [DevCard(type: .knight, boughtOnTurn: -1)]
        let t = s.tile(numbered: 8); s.place(settlement: s.board.tiles[t].corners[0], owner: 0)
        try Engine.apply(.playKnight, to: &s); try Engine.apply(.moveRobber(tile: t), to: &s)
        #expect(s.phase == .awaitingRoll); #expect(Engine.legalMoves(s) == [.roll])
    }
    @Test func victoryPointIsNeverPlayable() { var s = base(); give(&s, .victoryPoint); #expect(Engine.legalMoves(s).allSatisfy { !"\($0)".hasPrefix("play") }) }
    @Test func roadCrewTwoFreeRoads() throws {
        var s = base(); give(&s, .roadCrew)
        try Engine.apply(.playRoadCrew, to: &s); #expect(s.phase == .placingFreeRoads(remaining: 2)); #expect(s.log.last == "Crimson played Road crew.")
        for _ in 0..<2 { try Engine.apply(Engine.legalMoves(s).first!, to: &s) }
        #expect(s.roads(of: 0) == 3); #expect(s.bank == .uniform(19)); #expect(Array(s.log.suffix(2)) == ["Crimson built a free road.", "Crimson built a free road."]); #expect(s.phase == .main)
    }
    @Test func roadCrewNoRoom() throws {
        var s = TestGames.rolled(8); s.clearBoard(); s.clearHands(); s.place(settlement: 0, owner: 0)
        for e in s.board.corners[0].edges { s.place(road: e, owner: 1) }
        give(&s, .roadCrew); try Engine.apply(.playRoadCrew, to: &s)
        #expect(s.log.last == "No room for new roads."); #expect(s.phase == .main)
    }
    @Test func roadCrewWithOneLegalEdgeStopsEarly() throws {                 // Review Focus 2
        var s = TestGames.rolled(8); s.clearBoard(); s.clearHands(); s.place(settlement: 0, owner: 0)
        let open = s.board.corners[0].edges[0]; for e in s.board.corners[0].edges.dropFirst() { s.place(road: e, owner: 1) }
        let far = s.board.edges[open].other(0); for e in s.board.corners[far].edges where e != open { s.place(road: e, owner: 1) }
        give(&s, .roadCrew); try Engine.apply(.playRoadCrew, to: &s); try Engine.apply(.placeRoad(edge: open), to: &s)
        #expect(s.phase == .main); #expect(s.log.last == "No room for new roads."); #expect(s.roads(of: 0) == 1)
    }
    @Test func roadCrewWithOneRoadPieceLeft() throws {                        // Review Focus 2
        var s = base(); for e in 0..<72 where s.board.edges[e].owner == nil && s.roads(of: 0) < 14 { s.place(road: e, owner: 0) }
        give(&s, .roadCrew); try Engine.apply(.playRoadCrew, to: &s); try Engine.apply(Engine.legalMoves(s).first!, to: &s)
        #expect(s.roads(of: 0) == 15); #expect(s.phase == .main); #expect(s.log.last == "No roads left to build.")
        var t = s; t.players[0].devCards = [DevCard(type: .roadCrew, boughtOnTurn: -1)]; t.devCardPlayedThisTurn = false
        try Engine.apply(.playRoadCrew, to: &t); #expect(t.log.last == "No roads left to build."); #expect(t.phase == .main)
    }
    @Test func bumperHarvest() throws {
        var s = base(); give(&s, .bumperHarvest); try Engine.apply(.playBumperHarvest(.ore, .ore), to: &s)
        #expect(s.players[0].hand == [.ore: 2]); #expect(s.bank[.ore] == 17); #expect(s.log.last == "Crimson played Bumper harvest: ore and ore.")
    }
    @Test func bumperHarvestRespectsBank() {                                   // Review Focus 3
        var s = base(); give(&s, .bumperHarvest); s.set(hand: [.ore: 18], for: 1)
        #expect(!Engine.legalMoves(s).contains(.playBumperHarvest(.ore, .ore))); #expect(Engine.legalMoves(s).contains(.playBumperHarvest(.grain, .ore)))
    }
    @Test func cornerTheMarket() throws {
        var s = base(); give(&s, .cornerMarket); s.set(hand: [.ore: 3], for: 1); s.set(hand: [.ore: 2], for: 2)
        try Engine.apply(.playCornerMarket(.ore), to: &s)
        #expect(s.players[0].hand[.ore] == 5); #expect(s.players[1].hand[.ore] == 0); #expect(s.players[2].hand[.ore] == 0)
        #expect(s.log.last == "Crimson cornered the ore market and took 5.")
    }
}
