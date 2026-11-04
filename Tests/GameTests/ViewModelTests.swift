import Testing
import SaltmarshEngine
import SaltmarshAI
import SaltmarshTestSupport
@testable import SaltmarshGame

@MainActor @Suite struct ViewModelTests {
    func model(_ controllers: [Controller], seed: UInt64 = 1, store: InMemoryGameStore = InMemoryGameStore()) -> GameViewModel {
        let vm = GameViewModel(store: store, pacing: NoPacing()) { c, seat in c.isAI ? RandomOpponent(seed: seed &* 31 &+ UInt64(seat)) : nil }
        vm.newGame(GameConfig(controllers: controllers, seed: seed)); return vm
    }
    func isOver(_ s: GameState) -> Bool { if case .gameOver = s.phase { return true } else { return false } }

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
