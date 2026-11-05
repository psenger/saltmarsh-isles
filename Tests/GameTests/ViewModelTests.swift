import Testing
import SaltmarshEngine
import SaltmarshAI
import SaltmarshTestSupport
@testable import SaltmarshGame

/// Holds opponents inside their decision until the test lets them go, in arrival order.
private actor Gate {
    private var waiting: [CheckedContinuation<Void, Never>] = []
    private(set) var arrivals = 0
    func wait() async {
        arrivals += 1
        await withCheckedContinuation { waiting.append($0) }
    }
    func releaseOldest() { if !waiting.isEmpty { waiting.removeFirst().resume() } }
    func releaseAll() { waiting.forEach { $0.resume() }; waiting = [] }
    func untilArrivals(_ n: Int) async { while arrivals < n { await Task.yield() } }
}

private struct GatedOpponent: Opponent {
    let gate: Gate
    func chooseMove(view: PlayerView, legal: [Move]) async -> Move { await gate.wait(); return legal[0] }
    func respondToTrade(_ o: TradeOffer, view: PlayerView) async -> TradeResponse { .declined }
}

private actor CountingPacing: Pacing {
    private(set) var count = 0
    func pause() async { count += 1 }
}

private struct RollThenEnd: Opponent {
    func chooseMove(view: PlayerView, legal: [Move]) async -> Move { legal.contains(.roll) ? .roll : .endTurn }
    func respondToTrade(_ o: TradeOffer, view: PlayerView) async -> TradeResponse { .declined }
}

@MainActor @Suite struct ViewModelTests {
    @Test func aCancelledAITurnDoesNotOverwriteTheNewGame() async throws {
        let gate = Gate()
        let vm = GameViewModel(store: InMemoryGameStore(), pacing: NoPacing()) { c, _ in c.isAI ? GatedOpponent(gate: gate) : nil }
        vm.newGame(GameConfig(controllers: [.ai(.mate), .ai(.mate)], seed: 1))
        await gate.untilArrivals(1)
        vm.newGame(GameConfig(controllers: [.human, .human, .human], seed: 2))
        let fresh = vm.state
        await gate.releaseAll()
        try await Task.sleep(for: .milliseconds(50))
        #expect(vm.state == fresh)
    }
    @Test func aCancelledAITurnLeavesTheNewAITurnRunning() async throws {
        let gate = Gate()
        let vm = GameViewModel(store: InMemoryGameStore(), pacing: NoPacing()) { c, _ in c.isAI ? GatedOpponent(gate: gate) : nil }
        vm.newGame(GameConfig(controllers: [.ai(.mate), .ai(.mate)], seed: 1))
        await gate.untilArrivals(1)
        vm.newGame(GameConfig(controllers: [.ai(.mate), .ai(.mate)], seed: 2))
        await gate.untilArrivals(2)
        await gate.releaseOldest()
        try await Task.sleep(for: .milliseconds(50))
        #expect(vm.aiThinking)
        vm.newGame(GameConfig(controllers: [.human, .human], seed: 3))
        await gate.releaseAll()
    }
    func model(_ controllers: [Controller], seed: UInt64 = 1, store: InMemoryGameStore = InMemoryGameStore()) -> GameViewModel {
        let vm = GameViewModel(store: store, pacing: NoPacing()) { c, seat in c.isAI ? RandomOpponent(seed: seed &* 31 &+ UInt64(seat)) : nil }
        vm.newGame(GameConfig(controllers: controllers, seed: seed)); return vm
    }
    func isOver(_ s: GameState) -> Bool { if case .gameOver = s.phase { return true } else { return false } }

    @Test func everyRollIsCounted() throws {
        let vm = GameViewModel(store: InMemoryGameStore(), pacing: NoPacing()) { _, _ in nil }
        vm.load(TestGames.fresh())
        #expect(vm.rollCount == 0)
        try vm.apply(.rollForFirst)
        #expect(vm.rollCount == 1)
        vm.load(TestGames.afterSetup())
        try vm.apply(.roll)
        #expect(vm.rollCount == 2)
        try vm.apply(.endTurn)
        #expect(vm.rollCount == 2)
    }
    @Test func reopeningASavedRollDoesNotCountAsARoll() throws {
        let store = InMemoryGameStore()
        try store.save(TestGames.rolled(8))
        let vm = GameViewModel(store: store, pacing: NoPacing()) { _, _ in nil }
        #expect(vm.resume())
        #expect(vm.state?.dice != nil)
        #expect(vm.rollCount == 0)
    }
    @Test func anAISeatWaitsForItsDiceToLandBeforeMovingOn() async {
        var s = TestGames.afterSetup()
        s.players[0].controller = .ai(.mate)
        s.forcedRolls = [[2, 3]]
        let pacing = CountingPacing()
        let vm = GameViewModel(store: InMemoryGameStore(), pacing: pacing) { c, _ in c.isAI ? RollThenEnd() : nil }
        vm.load(s)
        await vm.waitForAI()
        #expect(vm.rollCount == 1)
        #expect(await pacing.count == 4)                                   // three after the roll, one after ending the turn
    }

    /// A game after setup, with the first tile that has a building and a number, ready to roll that number.
    func readyToPay() -> (state: GameState, tile: Int, resource: Resource) {
        var s = TestGames.afterSetup()
        let tile = s.board.tiles.indices.first { i in
            s.board.tiles[i].number != nil && s.board.tiles[i].corners.contains { s.board.corners[$0].owner != nil }
        }!
        s.force(roll: s.board.tiles[tile].number!)
        return (s, tile, s.board.tiles[tile].resource!)
    }
    func payingTiles(after s: GameState) throws -> [Int] {
        let vm = GameViewModel(store: InMemoryGameStore(), pacing: NoPacing()) { _, _ in nil }
        vm.load(s)
        try vm.apply(.roll)
        return vm.payingTiles
    }

    @Test func aTileWithABuildingPaysWhenItsNumberIsRolled() throws {
        let (s, tile, _) = readyToPay()
        #expect(try payingTiles(after: s).contains(tile))
    }
    @Test func aTileWithNoBuildingDoesNotPay() throws {
        var (s, tile, _) = readyToPay()
        for corner in s.board.tiles[tile].corners { s.board.corners[corner].owner = nil }
        #expect(try !payingTiles(after: s).contains(tile))
    }
    @Test func theRobbersTileDoesNotPay() throws {
        var (s, tile, _) = readyToPay()
        s.robberTile = tile
        #expect(try !payingTiles(after: s).contains(tile))
    }
    @Test func aTileDoesNotPayWhenTheBankCannotCoverIt() throws {
        var (s, tile, resource) = readyToPay()
        s.bank[resource] = 0
        #expect(try !payingTiles(after: s).contains(tile))
    }
    @Test func rollingForFirstClearsTheLastPayout() throws {
        let (s, tile, _) = readyToPay()
        let vm = GameViewModel(store: InMemoryGameStore(), pacing: NoPacing()) { _, _ in nil }
        vm.load(s)
        try vm.apply(.roll)
        #expect(vm.payingTiles.contains(tile))
        vm.load(TestGames.fresh())
        try vm.apply(.rollForFirst)
        #expect(vm.payingTiles.isEmpty)
    }

    @Test func aiOnlyGameRunsToTheEnd() async {
        let vm = model([.ai(.mate), .ai(.mate), .ai(.mate)], seed: 3); await vm.waitForAI()
        #expect(isOver(vm.state!), "AI-only game did not finish: \(vm.state!.phase)")
        #expect(vm.state!.log.last!.contains("wins with"))
    }
    @Test func controlReturnsToTheHuman() async throws {
        let vm = model([.human, .ai(.mate), .ai(.mate)], seed: 2); await vm.waitForAI()
        #expect(Engine.actingPlayer(vm.state!) == 0)                       // the human's first roll is waited for
        while case .rollingForFirst = vm.state!.phase, Engine.actingPlayer(vm.state!) == 0 { try vm.apply(.rollForFirst); await vm.waitForAI() }
        while case .setup = vm.state!.phase { try vm.apply(Engine.legalMoves(vm.state!).first!); await vm.waitForAI() }
        #expect(vm.state!.current == vm.state!.firstPlayer)
        if vm.state!.current == 0 {
            try vm.apply(.roll); await vm.waitForAI()
            if case .main = vm.state!.phase { try vm.apply(.endTurn) }
            await vm.waitForAI()
        }
        #expect(Engine.actingPlayer(vm.state!) == 0 || isOver(vm.state!))
        #expect(!vm.aiThinking)
    }
    @Test func savesAfterEveryMoveAndResumes() async throws {
        let store = InMemoryGameStore(); let vm = model([.human, .human, .human], store: store)
        try vm.apply(.rollForFirst); #expect(store.saveCount == 2)          // newGame saves once, the move again
        let again = GameViewModel(store: store, pacing: NoPacing()) { _, _ in nil }
        #expect(again.resume()); #expect(again.state == vm.state)
    }
    @Test func resumeRestartsAnAITurn() async throws {
        let store = InMemoryGameStore(); let vm = model([.ai(.mate), .human, .human], seed: 5, store: store); await vm.waitForAI()
        let saved = try store.load()!; #expect(Engine.actingPlayer(saved) == 1)
        var mid = saved; mid.current = 0; mid.phase = .awaitingRoll; try store.save(mid)   // as if we quit on the AI's turn
        let again = GameViewModel(store: store, pacing: NoPacing()) { c, _ in c.isAI ? RandomOpponent(seed: 9) : nil }
        #expect(again.resume()); await again.waitForAI()
        #expect(again.state!.turn > mid.turn || Engine.actingPlayer(again.state!) != 0 || isOver(again.state!))
    }
    @Test func illegalAIMovesAreResolved() async {                         // Review Focus 1
        struct Stubborn: Opponent {
            func chooseMove(view: PlayerView, legal: [Move]) async -> Move { .withdrawTrade }
            func respondToTrade(_ o: TradeOffer, view: PlayerView) async -> TradeResponse { .declined }
        }
        let vm = GameViewModel(store: InMemoryGameStore(), pacing: NoPacing()) { _, _ in Stubborn() }
        vm.newGame(GameConfig(controllers: [.ai(.deckhand), .ai(.deckhand)], seed: 1)); await vm.waitForAI()
        #expect(vm.state!.turn > 0 || isOver(vm.state!))
    }
}
