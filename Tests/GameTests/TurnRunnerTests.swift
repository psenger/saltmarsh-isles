import Testing
@testable import SaltmarshEngine
import SaltmarshAI
import SaltmarshTestSupport
@testable import SaltmarshGame

/// The safety net between an opponent and the engine must judge a move by the engine's legality
/// check, not by whether it appears in the enumerated `legalMoves` sample.
@Suite struct TurnRunnerTests {
    /// Proposes one fixed move whatever the position.
    struct Fixed: Opponent {
        let move: Move
        func chooseMove(view: PlayerView, legal: [Move]) async -> Move { move }
        func respondToTrade(_ o: TradeOffer, view: PlayerView) async -> TradeResponse { .declined }
    }
    func crimsonToTrade() -> GameState {
        var s = TestGames.rolled(8); s.clearBoard(); s.clearHands()
        s.set(hand: [.timber: 3, .wool: 1], for: 0); s.set(hand: [.ore: 2], for: 1); return s
    }
    @Test func legalButUnlistedOfferIsKept() async {                             // Review 2026-11-06, finding 1
        let s = crimsonToTrade()
        let offer = Move.proposeTrade(TradeOffer(proposer: 0, give: [.timber: 3], want: [.ore: 1], to: nil))
        #expect(!Engine.legalMoves(s).contains(offer)); #expect(Engine.isLegal(offer, in: s))
        let move = await TurnRunner.step(state: s, opponents: [0: Fixed(move: offer)])
        #expect(move == offer)
    }
    @Test func illegalChoiceIsReplaced() async {
        let s = crimsonToTrade()
        let tooMuch = Move.proposeTrade(TradeOffer(proposer: 0, give: [.timber: 4], want: [.ore: 1], to: nil))
        let move = await TurnRunner.step(state: s, opponents: [0: Fixed(move: tooMuch)])
        #expect(move == .endTurn)
    }
}
