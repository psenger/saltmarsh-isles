import Testing
import SaltmarshEngine
import SaltmarshTestSupport
@testable import SaltmarshAI

@Suite struct RandomOpponentTests {
    @Test func drivesSeededGamesToTheEnd() async throws {
        var ended = 0
        for seed in 0..<10 {
            var s = Engine.newGame(GameConfig(controllers: [.ai(.mate), .ai(.mate), .ai(.mate)], seed: UInt64(seed)))
            let bots = (0..<3).map { RandomOpponent(seed: UInt64(seed * 10 + $0)) }
            for _ in 0..<6000 {
                if case .gameOver = s.phase { ended += 1; break }
                let p = Engine.actingPlayer(s), legal = Engine.legalMoves(s)
                let m = await bots[p].chooseMove(view: Engine.view(s, for: p), legal: legal)
                #expect(legal.contains(m)); try Engine.apply(m, to: &s)
            }
        }
        #expect(ended > 0)
    }
    @Test func sameSeedSameChoice() async {
        let s = TestGames.rolled(8); let v = Engine.view(s, for: 0), legal = Engine.legalMoves(s)
        let a = await RandomOpponent(seed: 4).chooseMove(view: v, legal: legal), b = await RandomOpponent(seed: 4).chooseMove(view: v, legal: legal)
        #expect(a == b)
    }
    @Test func resolverFallsBack() {
        let legal: [Move] = [.roll, .playKnight]
        #expect(MoveResolver.resolve(.endTurn, isLegal: { $0 == .roll }, legal: [.roll]) == .roll)
        #expect(MoveResolver.resolve(.endTurn, isLegal: legal.contains, legal: legal, fallback: { .playKnight }) == .playKnight)
        #expect(MoveResolver.resolve(.roll, isLegal: legal.contains, legal: legal, fallback: { .playKnight }) == .roll)
        #expect(MoveResolver.resolve(.endTurn, isLegal: { $0 == .endTurn }, legal: legal) == .endTurn)   // legal but unlisted
    }
    @Test func factoryGivesAnOpponentForEveryLevel() async {
        let s = TestGames.rolled(8); let v = Engine.view(s, for: 0), legal = Engine.legalMoves(s)
        for level in EffortLevel.allCases {
            let m = await OpponentFactory.make(level: level, seed: 1).chooseMove(view: v, legal: legal)
            #expect(legal.contains(m))
        }
    }
}
