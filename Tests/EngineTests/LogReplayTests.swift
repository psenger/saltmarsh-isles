import Foundation
import Testing
@testable import SaltmarshEngine
import SaltmarshTestSupport

/// A game can be rebuilt from its log alone: seats and seed from the header, every move from the turn lines,
/// and every logged fact checked against what the replay produces. See docs/game-log.md.
@Suite struct LogReplayTests {
    @Test func randomGamesReplayExactly() throws {
        for seed in 1...6 {
            let played = TestGames.randomGame(seed: UInt64(seed)).final
            let replayed = try LogReplay.replay(played.log)
            #expect(replayed == played, "seed \(seed)")
        }
    }
    @Test func everyMoveKindIsCoveredByTheRandomGames() throws {
        var kinds = Set<String>()
        for seed in 1...6 {
            for m in TestGames.randomGame(seed: UInt64(seed)).moves { kinds.insert(String("\(m)".prefix { $0 != "(" })) }
        }
        for kind in ["rollForFirst", "placeSettlement", "placeRoad", "upgradeCity", "roll", "discard", "moveRobber", "steal", "bankTrade",
                     "harbourTrade", "proposeTrade", "respondToTrade", "executeTrade", "withdrawTrade", "buyDevCard", "playKnight",
                     "playRoadCrew", "playBumperHarvest", "playCornerMarket", "endTurn"] {
            #expect(kinds.contains(kind), "no random game played \(kind); the replay of it is untested")
        }
    }
    @Test func aChangedFactIsRefusedAtItsLine() throws {
        let played = TestGames.randomGame(seed: 2).final
        var log = played.log
        let i = log.firstIndex { $0.contains(" rolled ") && !$0.contains("for first player") }!
        log[i] = log[i].replacingOccurrences(of: "rolled ", with: "rolled 1")        // 8 becomes 18: not what the dice say
        #expect(throws: LogReplay.Failure.self) { try LogReplay.replay(log) }
        do { _ = try LogReplay.replay(log) } catch let LogReplay.Failure.mismatch(line, _, _) { #expect(line == i + 1) } catch { Issue.record("\(error)") }
        var junk = played.log; junk.insert("Crimson sneezed.", at: 40)
        do { _ = try LogReplay.replay(junk) } catch let LogReplay.Failure.unparsed(line, text) { #expect(line == 41); #expect(text == "Crimson sneezed.") } catch { Issue.record("\(error)") }
    }
    @Test func thoughtLinesFromTheGameLayerAreSkipped() throws {
        let played = TestGames.randomGame(seed: 3).final
        var log = played.log
        log.insert("Cobalt weighed 3 moves over 20 guessed hands (60 playouts, 0.4 s) and stuck with its first instinct.", at: 45)
        let replayed = try LogReplay.replay(log)
        var expected = played; expected.log = played.log
        #expect(replayed == expected)
    }
    @Test func parsesEveryLineShapeTheEngineWrites() {
        let s = TestGames.rolled(8)
        #expect(LogReplay.move(for: "Crimson rolled 9 (4+5) for first player.", in: s) == .rollForFirst)
        #expect(LogReplay.move(for: "Crimson founded a settlement at V12.", in: s) == .placeSettlement(corner: 12))
        #expect(LogReplay.move(for: "Crimson laid a road \(s.board.edgeID(7)).", in: s) == .placeRoad(edge: 7))
        #expect(LogReplay.move(for: "Crimson rolled 8 (6+2). Cobalt +1 ore", in: s) == .roll)
        #expect(LogReplay.move(for: "Crimson rolled 7 (3+4).", in: s) == .roll)
        #expect(LogReplay.move(for: "Cobalt discarded 2 timber, 1 ore.", in: s) == .discard([.timber: 2, .ore: 1]))
        #expect(LogReplay.move(for: "Crimson moved the robber to H8.", in: s) == .moveRobber(tile: 8))
        #expect(LogReplay.move(for: "Crimson stole 1 ore from Amber.", in: s) == .steal(from: 2))
        #expect(LogReplay.move(for: "Crimson traded 4 timber for 1 ore with the bank.", in: s) == .bankTrade(give: .timber, get: .ore))
        let h = 3
        #expect(LogReplay.move(for: "Crimson traded 3 clay for 1 grain at the 3:1 harbour (\(s.board.portID(h))).", in: s) == .harbourTrade(harbour: h, give: .clay, get: .grain))
        #expect(LogReplay.move(for: "Crimson offers 2 timber for 1 ore.", in: s) == .proposeTrade(TradeOffer(proposer: 0, give: [.timber: 2], want: [.ore: 1], to: nil)))
        #expect(LogReplay.move(for: "Crimson offers 1 timber, 1 clay for 1 ore to Amber.", in: s) == .proposeTrade(TradeOffer(proposer: 0, give: [.timber: 1, .clay: 1], want: [.ore: 1], to: 2)))
        #expect(LogReplay.move(for: "Crimson bought a development card: Knight.", in: s) == .buyDevCard)
        #expect(LogReplay.move(for: "Crimson played a Knight.", in: s) == .playKnight)
        #expect(LogReplay.move(for: "Crimson played Road crew.", in: s) == .playRoadCrew)
        #expect(LogReplay.move(for: "Crimson built a free road \(s.board.edgeID(2)).", in: s) == .placeRoad(edge: 2))
        #expect(LogReplay.move(for: "Crimson played Bumper harvest: ore and ore.", in: s) == .playBumperHarvest(.ore, .ore))
        #expect(LogReplay.move(for: "Crimson cornered the ore market and took 5 (Cobalt 3, Amber 2).", in: s) == .playCornerMarket(.ore))
        #expect(LogReplay.move(for: "Crimson built a road \(s.board.edgeID(9)).", in: s) == .placeRoad(edge: 9))
        #expect(LogReplay.move(for: "Crimson built a settlement at V3.", in: s) == .placeSettlement(corner: 3))
        #expect(LogReplay.move(for: "Crimson upgraded to a city at V3.", in: s) == .upgradeCity(corner: 3))
        #expect(LogReplay.move(for: "Crimson ended the turn.", in: s) == .endTurn)
        #expect(LogReplay.move(for: "Cobalt accepted the offer.", in: s) == .respondToTrade(seat: 1, .accepted))
        #expect(LogReplay.move(for: "Amber declined the offer.", in: s) == .respondToTrade(seat: 2, .declined))
        #expect(LogReplay.move(for: "Crimson withdrew the offer.", in: s) == .withdrawTrade)
        #expect(LogReplay.move(for: "Crimson traded 2 timber with Cobalt for 1 ore.", in: s) == .executeTrade(with: 1))
        for fact in ["Crimson collected 1 grain, 1 ore.", "Bank is out of ore.", "Cobalt now moves the robber.", "Setup done. Crimson rolls first.",
                     "Crimson takes longest road (5).", "Cobalt wins with 10 points!", "Nobody can answer that offer.", "SEED 1", "H0 ore 10", "PORT 1-2 3:1", "ROBBER H9"] {
            #expect(LogReplay.move(for: fact, in: s) == nil, Comment(rawValue: fact))
        }
    }
    @Test func aCounterIsRebuiltFromTheOpenOffer() throws {
        var s = TestGames.rolled(8); s.clearHands(); s.set(hand: [.timber: 3], for: 0); s.set(hand: [.ore: 2], for: 1)
        try Engine.apply(.proposeTrade(TradeOffer(proposer: 0, give: [.timber: 2], want: [.ore: 1], to: nil)), to: &s)
        let counter = TradeOffer(proposer: 0, give: [.timber: 3], want: [.ore: 1], to: 1)
        #expect(LogReplay.move(for: "Cobalt countered: 3 timber for 1 ore.", in: s) == .respondToTrade(seat: 1, .countered(counter)))
    }
    /// `SALTMARSH_LOG=/path/to/log.txt swift test --filter replaysTheLogFileFromTheEnvironment` replays a saved log, or
    /// the `log` array of a saved game's JSON, and prints where it stands. The way to analyse a real game.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["SALTMARSH_LOG"] != nil))
    func replaysTheLogFileFromTheEnvironment() throws {
        let path = ProcessInfo.processInfo.environment["SALTMARSH_LOG"]!
        let lines = try LogReplay.lines(ofFile: path)
        let s = try LogReplay.replay(lines)
        print("REPLAY \(path): \(lines.count) lines, \(s.players.count) players, turn \(s.turn), phase \(s.phase)")
        for (i, p) in s.players.enumerated() { print("REPLAY \(p.name): \(Engine.totalPoints(s, player: i)) points, hand \(p.hand), \(p.devCards.count) cards") }
    }
}
