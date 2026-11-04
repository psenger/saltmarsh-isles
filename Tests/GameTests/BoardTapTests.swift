import Testing
import SaltmarshEngine
import SaltmarshTestSupport
@testable import SaltmarshGame

@MainActor @Suite struct BoardTapTests {
    func humans(_ s: GameState) -> GameViewModel {
        let vm = GameViewModel(store: InMemoryGameStore(), pacing: NoPacing()) { _, _ in nil }
        vm.load(s); return vm
    }
    /// A fresh game with the first roll done, on the first settlement of setup.
    func inSetup() throws -> GameViewModel {
        var f = TestGames.fresh(); f.forcedRolls = [[6, 6], [1, 1], [1, 1]]
        for _ in 0..<3 { try Engine.apply(.rollForFirst, to: &f) }
        return humans(f)
    }
    func robberPhase() -> GameState {
        var s = TestGames.rolled(8); s.phase = .movingRobber(returnTo: .main); return s
    }

    @Test func aTapNearAGlowingCornerPicksIt() throws {
        let sc = try inSetup().screen
        let c = sc.glowingCorners.sorted()[0], p = sc.board.corners[c].point
        #expect(sc.boardTap(x: p.x + 5, y: p.y + 5) == .corner(c))
    }
    @Test func aTapBetweenTwoCornersPicksTheNearer() throws {
        let sc = try inSetup().screen
        let c = sc.glowingCorners.sorted()[0]
        let other = sc.board.corners[c].adjacent.first { sc.glowingCorners.contains($0) }!
        let a = sc.board.corners[c].point, b = sc.board.corners[other].point
        #expect(sc.boardTap(x: a.x + (b.x - a.x) * 0.4, y: a.y + (b.y - a.y) * 0.4) == .corner(c))
        #expect(sc.boardTap(x: a.x + (b.x - a.x) * 0.6, y: a.y + (b.y - a.y) * 0.6) == .corner(other))
    }
    @Test func aTapOnADashedEdgeMidpointPicksIt() throws {
        let vm = try inSetup()
        vm.tapCorner(vm.screen.glowingCorners.sorted()[0])
        let sc = vm.screen, e = sc.dashedEdges.sorted()[0], edge = sc.board.edges[e]
        let a = sc.board.corners[edge.a].point, b = sc.board.corners[edge.b].point
        #expect(sc.boardTap(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2) == .edge(e))
    }
    @Test func aTapOnASelectableTilePicksIt() {
        let sc = humans(robberPhase()).screen
        let t = sc.selectableTiles.sorted()[0], p = sc.board.tiles[t].center
        #expect(sc.boardTap(x: p.x, y: p.y) == .tile(t))
    }
    @Test func theRobbersOwnTileAndFarAwayPointsPickNothing() {
        let sc = humans(robberPhase()).screen
        let p = sc.board.tiles[sc.robberTile].center
        #expect(!sc.selectableTiles.contains(sc.robberTile))
        #expect(sc.boardTap(x: p.x, y: p.y) == nil)
        #expect(sc.boardTap(x: 1000, y: 1000) == nil)
    }
    @Test func aTapOnAStealTargetPicksItsCorner() {
        var s = TestGames.rolled(8); s.clearBoard(); s.clearHands()
        let tile = s.tile(numbered: 8), corner = s.board.tiles[tile].corners[0]
        s.place(settlement: corner, owner: 1); s.set(hand: [.ore: 2], for: 1)
        s.robberTile = tile; s.phase = .choosingVictim(candidates: [1], returnTo: .main)
        let sc = humans(s).screen, p = sc.board.corners[corner].point
        #expect(sc.boardTap(x: p.x, y: p.y) == .corner(corner))
    }
    @Test func nothingIsTappableWhileAnAIActs() throws {
        let vm = try inSetup()
        let sc = ScreenState.derive(state: vm.state!, ui: vm.ui, aiThinking: true, reduceMotion: false)
        let p = sc.board.corners[0].point
        #expect(sc.boardTap(x: p.x, y: p.y) == nil)
    }
    @Test func tapBoardPlacesTheSettlement() throws {
        let vm = try inSetup()
        let c = vm.screen.glowingCorners.sorted()[0], p = vm.state!.board.corners[c].point
        vm.tapBoard(x: p.x, y: p.y)
        #expect(vm.state!.board.corners[c].owner == vm.state!.current)
    }
    @Test func sharedLabels() {
        #expect(Strings.stealFrom("Cobalt") == "Steal from Cobalt")
        #expect(Strings.tradeWith("Cobalt") == "Trade with Cobalt")
        #expect(Strings.cardCount(5) == "5 cards")
        #expect(Strings.piecesLeft(3) == "3 left")
    }
}
