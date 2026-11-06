import Testing
@testable import SaltmarshEngine
import SaltmarshTestSupport
@testable import SaltmarshAI

@Suite struct BoardFactsTests {
    func bare() -> GameState { var s = TestGames.afterSetup(seed: 1); s.clearBoard(); return s }
    func kinds(_ c: Int, _ s: GameState) -> Set<Resource> { Set(s.board.corners[c].tiles.compactMap { s.board.tiles[$0].resource }) }

    @Test func productionCountsPipsAndDoublesCities() {
        var s = bare(); let c = s.corner(onTileNumbered: 8), tile = s.tile(numbered: 8), r = s.board.tiles[tile].resource!
        s.place(settlement: c, owner: 0)
        let expected = s.board.corners[c].tiles.reduce(into: ResourceCounts()) { acc, t in if let res = s.board.tiles[t].resource { acc[res] += s.board.tiles[t].pips } }
        #expect(BoardFacts.production(of: 0, board: s.board) == expected); #expect(expected[r] >= 5)
        s.place(city: c, owner: 0)
        #expect(BoardFacts.production(of: 0, board: s.board) == expected + expected)
        #expect(BoardFacts.production(of: 0, board: s.board, robber: tile)[r] == 2 * (expected[r] - 5))
        #expect(BoardFacts.pieces(of: 0, board: s.board) == (0, 1, 0)); #expect(BoardFacts.piecesLeft(of: 0, board: s.board) == (5, 3, 15))
    }
    @Test func spotScoreAddsTheLackBonusForResourcesNotYetProduced() {
        let s = bare(); let c = s.corner(onTileNumbered: 6), pips = BoardFacts.cornerPips(c, board: s.board)
        let inland = s.board.harbours.allSatisfy { $0.a != c && $0.b != c }
        let bonus = inland ? 0 : BoardFacts.spotScore(c, board: s.board, produces: .uniform(1)) - pips   // 1 for a 3:1 end; a 2:1 needs 4 pips of its resource
        #expect(BoardFacts.spotScore(c, board: s.board, produces: ResourceCounts()) == pips + 2 * kinds(c, s).count + bonus)
        #expect(BoardFacts.spotScore(c, board: s.board, produces: .uniform(1)) == pips + bonus)
    }
    @Test func harbourBonusNeedsMatchingProduction() {
        let s = bare()
        let h = s.board.harbours.first { if case .specific = $0.kind { true } else { false } }!
        guard case .specific(let r) = h.kind else { return }
        let c = h.a, pips = BoardFacts.cornerPips(c, board: s.board), lack = 2 * kinds(c, s).subtracting([r]).count
        #expect(BoardFacts.spotScore(c, board: s.board, produces: [r: 4]) == pips + lack + 3)
        #expect(BoardFacts.spotScore(c, board: s.board, produces: [r: 3]) == pips + lack)
        let any = s.board.harbours.first { $0.kind == .any }!
        #expect(BoardFacts.spotScore(any.a, board: s.board, produces: .uniform(1)) == BoardFacts.cornerPips(any.a, board: s.board) + 1)
    }
    @Test func settleableRespectsTheDistanceRule() {
        var s = bare(); let c = s.corner(onTileNumbered: 5)
        #expect(BoardFacts.settleable(c, board: s.board))
        s.place(settlement: s.board.corners[c].adjacent[0], owner: 1)
        #expect(!BoardFacts.settleable(c, board: s.board))
    }
    @Test func distancesCountRoadsToBuildAndStopAtOpponents() {
        var s = bare(); let start = s.corner(onTileNumbered: 5); s.place(settlement: start, owner: 0)
        let e = s.board.corners[start].edges[0], mid = s.board.edges[e].other(start)
        let e2 = s.board.corners[mid].edges.first { $0 != e }!, far = s.board.edges[e2].other(mid)
        func d() -> [Int?] { BoardFacts.distances(from: BoardFacts.network(of: 0, board: s.board), board: s.board, seat: 0) }
        #expect(d()[start] == 0); #expect(d()[mid] == 1); #expect(d()[far] == 2)
        s.place(road: e, owner: 0)
        #expect(d()[mid] == 0); #expect(d()[far] == 1)
        s.place(settlement: mid, owner: 1)
        #expect((d()[far] ?? 99) >= 2)
    }
    @Test func bestTargetTradesScoreAgainstDistance() throws {
        var s = bare(); let start = s.corner(onTileNumbered: 5); s.place(settlement: start, owner: 0)
        let produces = BoardFacts.production(of: 0, board: s.board)
        let t = try #require(BoardFacts.bestTarget(for: 0, board: s.board, produces: produces, roadsLeft: 13))
        let d = BoardFacts.distances(from: BoardFacts.network(of: 0, board: s.board), board: s.board, seat: 0)
        #expect(BoardFacts.settleable(t.corner, board: s.board)); #expect(d[t.corner] == t.distance); #expect(t.distance >= 1)
        let value = { (c: Int, dist: Int) in BoardFacts.spotScore(c, board: s.board, produces: produces) - 2 * dist }
        for c in s.board.corners.indices where BoardFacts.settleable(c, board: s.board) {
            if let dc = d[c], dc <= 13 { #expect(value(t.corner, t.distance) >= value(c, dc)) }
        }
        #expect(BoardFacts.bestTarget(for: 0, board: s.board, produces: produces, roadsLeft: 0) == nil)
    }
    @Test func roadTowardShortensTheDistance() throws {
        var s = bare(); let start = s.corner(onTileNumbered: 5); s.place(settlement: start, owner: 0)
        s.current = 0; s.phase = .main; s.set(hand: Cost.road, for: 0)
        let legal = Engine.legalMoves(s)
        let t = try #require(BoardFacts.bestTarget(for: 0, board: s.board, produces: ResourceCounts(), roadsLeft: 13))
        guard case .placeRoad(let e)? = BoardFacts.roadToward(t.corner, legal: legal, board: s.board, seat: 0) else { Issue.record("no road"); return }
        #expect(legal.contains(.placeRoad(edge: e)))
        var after = s; after.place(road: e, owner: 0)
        let d = BoardFacts.distances(from: BoardFacts.network(of: 0, board: after.board), board: after.board, seat: 0)
        #expect(d[t.corner] == t.distance - 1)
    }
}
