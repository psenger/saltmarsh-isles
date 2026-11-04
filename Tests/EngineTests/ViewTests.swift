import Foundation
import Testing
@testable import SaltmarshEngine

@Suite struct ViewTests {
    @Test func viewHidesOpponentCardsAndKeepsCounts() {
        let s = TestGames.midGame(seed: 3), v = Engine.view(s, for: 0)
        #expect(v.me == 0); #expect(v.hand == s.players[0].hand); #expect(v.devCards == s.players[0].devCards)
        #expect(v.opponents.map(\.index) == [1, 2])
        for o in v.opponents { #expect(o.cardCount == s.players[o.index].hand.total); #expect(o.devCardCount == s.players[o.index].devCards.count); #expect(o.roadLength == Engine.roadLength(s, player: o.index)); #expect(o.publicPoints == Engine.publicPoints(s, player: o.index)) }
        let json = String(decoding: try! JSONEncoder().encode(v), as: UTF8.self)
        #expect(!json.contains("\"devDeck\"")); #expect(v.deckCount == s.devDeck.count)
    }
    @Test func viewCarriesPublicFacts() {
        let s = TestGames.midGame(seed: 4), v = Engine.view(s, for: 1)
        #expect(v.board == s.board && v.bank == s.bank && v.robberTile == s.robberTile && v.phase == s.phase && v.dice == s.dice && v.longestRoadHolder == s.longestRoadHolder && v.current == s.current && v.turn == s.turn)
    }
    @Test func sampledStateRespectsCounts() {
        let s = TestGames.midGame(seed: 5), v = Engine.view(s, for: 0); var rng = SeededRNG(seed: 99)
        let g = Engine.sampleFullState(from: v, using: &rng)
        #expect(g.players[0].hand == s.players[0].hand && g.players[0].devCards == s.players[0].devCards)
        for o in v.opponents { #expect(g.players[o.index].hand.total == o.cardCount); #expect(g.players[o.index].devCards.count == o.devCardCount); #expect(g.players[o.index].knightsPlayed == o.knightsPlayed) }
        #expect(g.devDeck.count == v.deckCount); #expect(g.bank == v.bank); #expect(g.board == v.board); #expect(g.phase == v.phase); #expect(g.current == v.current)
        #expect(g.devDeck.count + g.players.flatMap(\.devCards).count + g.players.map(\.knightsPlayed).reduce(0, +) <= 25)
    }
    @Test func sampledStateIsPlayable() throws {
        let s = TestGames.midGame(seed: 6), v = Engine.view(s, for: s.current); var rng = SeededRNG(seed: 1)
        var g = Engine.sampleFullState(from: v, using: &rng)
        for _ in 0..<50 { let legal = Engine.legalMoves(g); if legal.isEmpty { break }; try Engine.apply(legal[Int(rng.next() % UInt64(legal.count))], to: &g) }
    }
    @Test func samplingCannotReproduceHiddenHands() {
        var differs = false
        for seed in 1...20 {
            let s = TestGames.midGame(seed: UInt64(seed)); var rng = SeededRNG(seed: UInt64(seed))
            let g = Engine.sampleFullState(from: Engine.view(s, for: 0), using: &rng)
            if (1..<3).contains(where: { g.players[$0].hand != s.players[$0].hand }) { differs = true }
        }
        #expect(differs)
    }
    @Test func sampleIsDeterministicForSeed() {
        let v = Engine.view(TestGames.midGame(seed: 7), for: 0); var a = SeededRNG(seed: 2), b = SeededRNG(seed: 2)
        #expect(Engine.sampleFullState(from: v, using: &a) == Engine.sampleFullState(from: v, using: &b))
    }
}
