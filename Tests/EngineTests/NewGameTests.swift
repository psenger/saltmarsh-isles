import Foundation
import Testing
@testable import SaltmarshEngine

@Suite struct NewGameTests {
    let s = Engine.newGame(GameConfig(controllers: [.human, .ai(.mate), .ai(.admiral)], seed: 9))
    @Test func initialFacts() {
        #expect(s.players.map(\.seat) == [.crimson, .cobalt, .amber])
        #expect(s.players.allSatisfy { $0.hand.isEmpty && $0.devCards.isEmpty && $0.knightsPlayed == 0 })
        #expect(s.devDeck.count == 25); #expect(s.devDeck.filter { $0 == .knight }.count == 14)
        #expect(s.bank == .uniform(19)); #expect(s.robberTile == s.board.desertTile)
        #expect(s.phase == .rollingForFirst(rolls: [nil, nil, nil], contenders: [0, 1, 2]))
        #expect(s.log.first == "New game with 3 players. Everyone rolls for first player.")
        #expect(Engine.legalMoves(s) == [.rollForFirst]); #expect(Engine.actingPlayer(s) == 0)
    }
    @Test func sameSeedSameGame() {
        let c = GameConfig(controllers: [.human, .human], seed: 123)
        #expect(Engine.newGame(c) == Engine.newGame(c))
    }
    @Test func codableRoundTrip() throws {
        let data = try JSONEncoder().encode(s)
        #expect(try JSONDecoder().decode(GameState.self, from: data) == s)
    }
    @Test func illegalMoveThrows() {
        var t = s
        #expect(throws: EngineError.illegalMove(.roll)) { try Engine.apply(.roll, to: &t) }
    }
    @Test func offerDescription() {
        #expect(TradeOffer(proposer: 0, give: [.timber: 2], want: [.ore: 1], to: nil).description == "2 timber for 1 ore")
    }
    @Test func newGameNamesEachSeatsController() {
        let s = Engine.newGame(GameConfig(controllers: [.human, .ai(.mate), .ai(.admiral)], seed: 1))
        #expect(Array(s.log.prefix(4)) == ["New game with 3 players. Everyone rolls for first player.",
                                          "Crimson is human.", "Cobalt is an AI Mate.", "Amber is an AI Admiral."])
        let two = Engine.newGame(GameConfig(controllers: [.ai(.deckhand), .human], seed: 2))
        #expect(two.log.count == 3); #expect(two.log[1] == "Crimson is an AI Deckhand."); #expect(two.log[2] == "Cobalt is human.")
    }
}
