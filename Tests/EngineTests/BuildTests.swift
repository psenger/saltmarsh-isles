import Testing
@testable import SaltmarshEngine
import SaltmarshTestSupport

@Suite struct BuildTests {
    /// Crimson has rolled; one Crimson settlement at corner 0 with a road along its first edge; empty hands.
    func base() -> GameState {
        var s = TestGames.rolled(8); s.clearBoard(); s.clearHands()
        s.place(settlement: 0, owner: 0); s.place(road: s.board.corners[0].edges[0], owner: 0); return s
    }
    func has(_ s: GameState, _ test: (Move) -> Bool) -> Bool { Engine.legalMoves(s).contains(where: test) }
    @Test func buildsFollowCost() {
        var s = base()
        #expect(!has(s) { if case .placeRoad = $0 { true } else { false } })
        s.set(hand: Cost.road, for: 0); #expect(has(s) { if case .placeRoad = $0 { true } else { false } })
        s.set(hand: Cost.city, for: 0); #expect(has(s) { $0 == .upgradeCity(corner: 0) })
        #expect(!has(s) { if case .placeSettlement = $0 { true } else { false } })
    }
    @Test func roadPaysAndLogs() throws {
        var s = base(); s.set(hand: Cost.road, for: 0)
        let e = Engine.legalMoves(s).compactMap { if case .placeRoad(let e) = $0 { e } else { nil } }.first!
        try Engine.apply(.placeRoad(edge: e), to: &s)
        #expect(s.board.edges[e].owner == 0); #expect(s.players[0].hand.isEmpty); #expect(s.bank == .uniform(19))
        #expect(s.log.last == "Crimson built a road.")
    }
    @Test func roadsMustConnect() {
        var s = base(); s.set(hand: Cost.road, for: 0)
        for m in Engine.legalMoves(s) { if case .placeRoad(let e) = m {
            let ed = s.board.edges[e]
            #expect([ed.a, ed.b].contains { c in s.board.corners[c].owner == 0 || s.board.corners[c].edges.contains { $0 != e && s.board.edges[$0].owner == 0 } }) } }
    }
    @Test func roadCannotPassOpponentBuilding() {
        var s = base(); s.set(hand: Cost.road, for: 0)
        let e = s.board.corners[0].edges[0], far = s.board.edges[e].other(0)
        s.place(settlement: far, owner: 1)
        for m in Engine.legalMoves(s) { if case .placeRoad(let x) = m { #expect(s.board.edges[x].a != far && s.board.edges[x].b != far) } }
    }
    @Test func opponentRoadsDoNotBlock() {
        var s = base(); s.set(hand: Cost.road, for: 0)
        let e = s.board.corners[0].edges[0], far = s.board.edges[e].other(0)
        let other = s.board.corners[far].edges.first { $0 != e }!; s.place(road: other, owner: 1)
        #expect(has(s) { if case .placeRoad(let x) = $0 { s.board.edges[x].a == far || s.board.edges[x].b == far } else { false } })
    }
    @Test func settlementRulesAndLog() throws {
        var s = base(); s.set(hand: Cost.settlement, for: 0)
        let e = s.board.corners[0].edges[0], mid = s.board.edges[e].other(0)
        let e2 = s.board.corners[mid].edges.first { $0 != e }!; s.place(road: e2, owner: 0)
        let far = s.board.edges[e2].other(mid)
        let spots = Engine.legalMoves(s).compactMap { if case .placeSettlement(let c) = $0 { c } else { nil } }
        #expect(spots == [far])                                       // mid is adjacent to corner 0, far is reachable
        try Engine.apply(.placeSettlement(corner: far), to: &s)
        #expect(s.board.corners[far].owner == 0); #expect(s.players[0].hand.isEmpty); #expect(s.log.last == "Crimson built a settlement.")
    }
    @Test func sharedCrossroadIsARace() throws {
        var s = base(); s.set(hand: Cost.settlement, for: 0); s.set(hand: Cost.settlement, for: 1)
        // Crimson: 0 -e- mid -e2- far, where far has three edges. Cobalt: cob -e3- far.
        let e = s.board.corners[0].edges[0], mid = s.board.edges[e].other(0)
        let e2 = s.board.corners[mid].edges.first { $0 != e && s.board.corners[s.board.edges[$0].other(mid)].edges.count == 3 }!
        s.place(road: e2, owner: 0)
        let far = s.board.edges[e2].other(mid)
        let e3 = s.board.corners[far].edges.first { $0 != e2 }!, cob = s.board.edges[e3].other(far)
        s.place(road: e3, owner: 1); s.place(settlement: cob, owner: 1)
        // Cobalt's settlement is one segment from far, so far is blocked for everyone
        #expect(!Engine.canSettle(s, corner: far, player: 0, setup: false)); #expect(!Engine.canSettle(s, corner: far, player: 1, setup: false))
        // move Cobalt's settlement one segment further away: far becomes a shared crossroad
        s.board.corners[cob].owner = nil
        let e4 = s.board.corners[cob].edges.first { $0 != e3 }!; s.place(road: e4, owner: 1); s.place(settlement: s.board.edges[e4].other(cob), owner: 1)
        #expect(Engine.canSettle(s, corner: far, player: 0, setup: false)); #expect(Engine.canSettle(s, corner: far, player: 1, setup: false))
        try Engine.apply(.placeSettlement(corner: far), to: &s)
        #expect(!Engine.canSettle(s, corner: far, player: 1, setup: false))
        let third = s.board.corners[far].edges.first { $0 != e2 && $0 != e3 }!
        #expect(!Engine.canRoad(s, edge: third, player: 1))
    }
    @Test func cityUpgrade() throws {
        var s = base(); s.set(hand: Cost.city, for: 0)
        try Engine.apply(.upgradeCity(corner: 0), to: &s)
        #expect(s.board.corners[0].isCity); #expect(s.players[0].hand.isEmpty); #expect(s.log.last == "Crimson upgraded to a city.")
        #expect(!has(s) { $0 == .upgradeCity(corner: 0) })
    }
    @Test func pieceLimits() throws {
        var s = base(); s.set(hand: Cost.settlement + Cost.city + Cost.road, for: 0)
        #expect(Engine.piecesLeft(s, player: 0) == PiecesLeft(settlements: 4, cities: 4, roads: 14))
        for c in [10, 20, 30, 40] { s.place(settlement: c, owner: 0) }     // 5 settlements
        #expect(Engine.piecesLeft(s, player: 0).settlements == 0)
        #expect(!has(s) { if case .placeSettlement = $0 { true } else { false } })
        try Engine.apply(.upgradeCity(corner: 10), to: &s)
        #expect(Engine.piecesLeft(s, player: 0).settlements == 1)
        for e in 0..<72 where s.board.edges[e].owner == nil && s.roads(of: 0) < 15 { s.place(road: e, owner: 0) }
        #expect(Engine.piecesLeft(s, player: 0).roads == 0); #expect(!has(s) { if case .placeRoad = $0 { true } else { false } })
        for c in [20, 30, 40] { s.place(city: c, owner: 0) }
        #expect(Engine.piecesLeft(s, player: 0).cities == 0); #expect(!has(s) { if case .upgradeCity = $0 { true } else { false } })
    }
}
