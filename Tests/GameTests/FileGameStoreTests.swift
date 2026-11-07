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
    @Test func theResumeMarkSurvivesUntilCleared() throws {
        let store = FileGameStore(directory: directory)
        try store.save(TestGames.fresh())
        #expect(!store.resumeWasInterrupted)
        try store.markResuming(); #expect(store.resumeWasInterrupted)
        #expect(FileGameStore(directory: directory).resumeWasInterrupted)              // the next launch sees it
        try store.resumeSucceeded(); #expect(!store.resumeWasInterrupted)
    }
    @Test func settingAsideKeepsTheGameForAReplay() throws {
        let store = FileGameStore(directory: directory), game = TestGames.midGame(seed: 6)
        try store.save(game); try store.markResuming()
        let kept = try #require(try store.setAside())
        #expect(kept.lastPathComponent.hasPrefix("game-crashed-")); #expect(kept.pathExtension == "json")
        #expect(try JSONDecoder().decode(GameState.self, from: Data(contentsOf: kept)) == game)
        #expect(try store.load() == nil); #expect(!store.resumeWasInterrupted)
        #expect(try store.setAside() == nil)                                               // nothing left to move
    }
    @Test func anInterruptedResumeStartsCleanAndKeepsTheSave() throws {
        let store = FileGameStore(directory: directory)
        try store.save(TestGames.midGame(seed: 7)); try store.markResuming()               // the last launch died here
        let vm = GameViewModel(store: store, pacing: NoPacing()) { _, _ in nil }
        #expect(!vm.resume()); #expect(vm.state == nil)
        #expect(vm.setAsideSave?.lastPathComponent.hasPrefix("game-crashed-") == true)
        #expect(try store.load() == nil)
        #expect(FileGameStore(directory: directory).resumeWasInterrupted == false)
    }
}
