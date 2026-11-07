import Testing
@testable import SaltmarshEngine
import SaltmarshTestSupport

/// The log is the record a game is replayed from: every placement names its vertex or edge, every random
/// outcome is written as a fact, and the board is recorded before the first turn. See docs/game-log.md.
@Suite struct LogFormatTests {
    @Test func aNewGameRecordsSeedBoardPortsAndRobber() {
        let s = Engine.newGame(GameConfig(controllers: [.human, .ai(.mate), .human], seed: 42))
        let b = s.board
        #expect(s.log.contains("SEED 42"))
        let hexLines = s.log.filter { $0.hasPrefix("H") && $0.dropFirst().first?.isNumber == true }
        #expect(hexLines.count == 19)
        for (i, tile) in b.tiles.enumerated() {
            let terrain = tile.resource?.rawValue ?? "desert", number = tile.number.map(String.init) ?? "-"
            #expect(hexLines[i] == "H\(i) \(terrain) \(number)")
        }
        #expect(hexLines[b.desertTile] == "H\(b.desertTile) desert -"); #expect(b.desertTile == 9)
        let portLines = s.log.filter { $0.hasPrefix("PORT ") }
        #expect(portLines.count == 9)
        for (i, h) in b.harbours.enumerated() {
            let kind: String = { if case .specific(let r) = h.kind { return "\(r.rawValue) 2:1" } else { return "3:1" } }()
            #expect(portLines[i] == "PORT \(min(h.a, h.b))-\(max(h.a, h.b)) \(kind)")
        }
        #expect(s.log.contains("ROBBER H9"))
        let order = ["SEED 42", hexLines[0], portLines[0], "ROBBER H9"].map { line in s.log.firstIndex(of: line)! }
        #expect(order == order.sorted(), "seed, hexes, ports, robber, in that order")
        #expect(s.log.firstIndex(of: "SEED 42")! > s.log.firstIndex(of: "Amber is human.")!)
    }
    @Test func idsFollowTheModelsNumbering() {
        let b = BoardGenerator.layout()
        #expect(b.vertexID(12) == "V12"); #expect(b.hexID(7) == "H7")
        let e = b.edges.indices.first { b.edges[$0].a > b.edges[$0].b } ?? 0
        #expect(b.edgeID(e) == "E\(min(b.edges[e].a, b.edges[e].b))-\(max(b.edges[e].a, b.edges[e].b))")
        #expect(b.edgeIndex(ofID: b.edgeID(5)) == 5); #expect(b.edgeIndex(ofID: "E99-100") == nil)
    }
    @Test func setupPlacementsNameTheirSpotAndTheCardsCollected() throws {
        var s = TestGames.fresh(seed: 1); s.forcedRolls = [[6, 6], [1, 1], [1, 1]]
        for _ in 0..<3 { try Engine.apply(.rollForFirst, to: &s) }
        #expect(s.log.contains("Crimson rolled 12 (6+6) for first player."))
        let corner = Engine.legalMoves(s).compactMap { if case .placeSettlement(let c) = $0 { c } else { nil } }.first!
        try Engine.apply(.placeSettlement(corner: corner), to: &s)
        #expect(s.log.last == "Crimson founded a settlement at V\(corner).")
        let edge = Engine.legalMoves(s).compactMap { if case .placeRoad(let e) = $0 { e } else { nil } }.first!
        try Engine.apply(.placeRoad(edge: edge), to: &s)
        #expect(s.log.last == "Crimson laid a road \(s.board.edgeID(edge)).")
        // Play the other seats' placements until Crimson's second settlement is due.
        while true {
            guard case .setup(let step, let placingRoad, _) = s.phase else { break }
            if step >= s.playerCount && s.current == 0 && !placingRoad { break }
            try Engine.apply(Engine.legalMoves(s).first!, to: &s)
        }
        let second = Engine.legalMoves(s).compactMap { if case .placeSettlement(let c) = $0 { c } else { nil } }.first!
        let before = s.players[0].hand
        try Engine.apply(.placeSettlement(corner: second), to: &s)
        let gained = s.players[0].hand - before
        if gained.total > 0 {
            #expect(s.log.last == "Crimson collected \(gained).")
            #expect(s.log.dropLast().last == "Crimson founded a settlement at V\(second).")
        } else {
            #expect(s.log.last == "Crimson founded a settlement at V\(second).")
        }
    }
    @Test func rollsWriteBothDice() throws {
        var s = TestGames.afterSetup(seed: 1); s.clearBoard(); s.clearHands(); s.current = 0; s.phase = .awaitingRoll
        s.forcedRolls = [[3, 5]]; try Engine.apply(.roll, to: &s)
        #expect(s.log.last == "Crimson rolled 8 (3+5). Nobody harvested.")
        s.phase = .awaitingRoll; s.forcedRolls = [[3, 4]]; try Engine.apply(.roll, to: &s)
        #expect(s.log.last == "Crimson rolled 7 (3+4).")
    }
    @Test func buildsNameTheirSpot() throws {
        var s = TestGames.rolled(8); s.set(hand: Cost.road + Cost.city, for: 0)
        let edge = Engine.legalMoves(s).compactMap { if case .placeRoad(let e) = $0 { e } else { nil } }.first!
        try Engine.apply(.placeRoad(edge: edge), to: &s)
        #expect(s.log.last == "Crimson built a road \(s.board.edgeID(edge)).")
        let city = s.board.corners.indices.first { s.board.corners[$0].owner == 0 && !s.board.corners[$0].isCity }!
        try Engine.apply(.upgradeCity(corner: city), to: &s)
        #expect(s.log.last == "Crimson upgraded to a city at V\(city).")
    }
    @Test func endingTheTurnIsWritten() throws {
        var s = TestGames.rolled(8); try Engine.apply(.endTurn, to: &s)
        #expect(s.log.last == "Crimson ended the turn.")
    }
    @Test func robberMovesNameTheHexAndStealsNameTheCard() throws {
        var s = TestGames.afterSetup(seed: 1); s.clearHands(); s.set(hand: [.ore: 1], for: 1)
        let victimCorner = s.board.corners.indices.first { s.board.corners[$0].owner == 1 }!
        let tile = s.board.corners[victimCorner].tiles.first { $0 != s.robberTile }!
        s.current = 0; s.phase = .movingRobber(returnTo: .main)
        try Engine.apply(.moveRobber(tile: tile), to: &s)
        #expect(s.log.last == "Crimson moved the robber to H\(tile).")
        try Engine.apply(.steal(from: 1), to: &s)
        #expect(s.log.last == "Crimson stole 1 ore from Cobalt.")
    }
    @Test func buyingACardNamesIt() throws {
        var s = TestGames.rolled(8); s.set(hand: Cost.devCard, for: 0); s.devDeck.append(.roadCrew)
        try Engine.apply(.buyDevCard, to: &s)
        #expect(s.log.last == "Crimson bought a development card: Road crew.")
    }
    @Test func corneringTheMarketSaysWhoPaid() throws {
        var s = TestGames.rolled(8); s.clearHands(); s.set(hand: [.ore: 2], for: 1); s.set(hand: [.ore: 1, .wool: 3], for: 2)
        s.players[0].devCards = [DevCard(type: .cornerMarket, boughtOnTurn: -1)]
        try Engine.apply(.playCornerMarket(.ore), to: &s)
        #expect(s.log.last == "Crimson cornered the ore market and took 3 (Cobalt 2, Amber 1).")
        var t = TestGames.rolled(8); t.clearHands(); t.players[0].devCards = [DevCard(type: .cornerMarket, boughtOnTurn: -1)]
        try Engine.apply(.playCornerMarket(.ore), to: &t)
        #expect(t.log.last == "Crimson cornered the ore market and took 0.")
    }
    @Test func harbourTradesNameThePort() throws {
        var s = TestGames.rolled(8); s.clearBoard(); s.clearHands()
        let h = s.board.harbours.firstIndex { $0.kind == .any }!
        s.place(settlement: s.board.harbours[h].a, owner: 0); s.set(hand: [.timber: 3], for: 0)
        try Engine.apply(.harbourTrade(harbour: h, give: .timber, get: .ore), to: &s)
        #expect(s.log.last == "Crimson traded 3 timber for 1 ore at the 3:1 harbour (\(s.board.portID(h))).")
    }
}
