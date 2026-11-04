import Foundation
import Testing
import SaltmarshEngine
import SaltmarshTestSupport
@testable import SaltmarshGame

@MainActor @Suite struct FileGameStoreTests {
    let directory = FileManager.default.temporaryDirectory.appending(path: "saltmarsh-\(UUID().uuidString)")

    @Test func nothingSavedLoadsNil() throws {
        #expect(try FileGameStore(directory: directory).load() == nil)
    }
    @Test func aMidGameRoundTrips() throws {
        let store = FileGameStore(directory: directory), s = TestGames.midGame(seed: 4)
        try store.save(s)
        #expect(try store.load() == s)
    }
    @Test func aTradeOfferRoundTrips() throws {                             // Review Focus 4
        let store = FileGameStore(directory: directory)
        var s = TestGames.rolled(8)
        let offer = TradeOffer(proposer: 0, give: [.timber: 1], want: [.ore: 1], to: nil)
        s.phase = .tradeOffered(offer: offer, responses: [1: .pending, 2: .countered(offer)])
        try store.save(s)
        #expect(try store.load() == s)
    }
    @Test func choosingAVictimRoundTrips() throws {                         // Review Focus 4
        let store = FileGameStore(directory: directory)
        var s = TestGames.rolled(8)
        s.phase = .choosingVictim(candidates: [1, 2], returnTo: .awaitingRoll)
        try store.save(s)
        #expect(try store.load() == s)
    }
    @Test func clearRemovesTheSaveAndIsSafeWithoutOne() throws {
        let store = FileGameStore(directory: directory)
        try store.clear()
        try store.save(TestGames.fresh())
        try store.clear()
        #expect(try store.load() == nil)
    }
    @Test func aCorruptSaveThrowsAndResumeDeclines() throws {               // Review Focus 3
        let store = FileGameStore(directory: directory)
        try store.save(TestGames.fresh())
        try Data("not a game".utf8).write(to: directory.appending(path: "game.json"))
        #expect(throws: (any Error).self) { try store.load() }
        let vm = GameViewModel(store: store, pacing: NoPacing()) { _, _ in nil }
        #expect(!vm.resume())
        #expect(vm.state == nil)
    }
}
