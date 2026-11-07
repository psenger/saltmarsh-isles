import Foundation
import SaltmarshEngine
import SaltmarshTestSupport
@testable import SaltmarshGame

/// Rule: Turning on the log
@MainActor
func registerLogs(_ r: StepRegistry) {
    r.then(#"the new game sheet has a box "([^"]*)", unticked"#) { _, c, _ in
        try expectEqual(Strings.turnOnLogs, c[0], "box label")
        try expectTrue(!GameConfig(controllers: [.human, .human, .human], seed: 1).showsLog, "logs are on by default")
    }
    r.when(#"I start a 3-player game with logs turned on"#) { w, _, _ in w.newGame([.human, .human, .human], showsLog: true) }
    r.given(#"a 3-player game with logs turned on"#) { w, _, _ in w.newGame([.human, .human, .human], showsLog: true) }
    r.then(#"the tabs are "([^"]*)""#) { w, c, _ in try expectEqual(w.screen.tabs.map(\.rawValue), World.names(c[0]), "tabs") }
    r.then(#"under the order strip the panel shows the Players tab"#) { w, _, _ in
        try expectTrue(w.screen.orderStrip != nil, "no order strip")
        try expectEqual(w.screen.fallbackTab, .players, "tab under the order strip")
    }
    r.then(#"the game still writes its log"#) { w, _, _ in try expectTrue(!w.state.log.isEmpty, "the log is empty") }
    r.given(#"a game saved before the log setting existed"#) { w, _, _ in
        w.newGame([.human, .human, .human])
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(w.state)) as! [String: Any]
        try expectTrue(json.removeValue(forKey: "showsLog") != nil, "the save has no showsLog to remove")
        let old = try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: json))
        try w.store.save(old)
    }
    // Real dice, not forced ones: a replay rebuilds rolls from the seed, so only an unforced game replays.
    r.when(#"everyone rolls for first player"#) { w, _, _ in
        for _ in w.state.players { w.vm.rollForFirst() }
    }
    r.then(#"the Log tab offers "([^"]*)""#) { w, c, _ in
        try expectEqual(Strings.copyLog, c[0], "button label")
        try expectTrue(w.screen.tabs.contains(.log), "no Log tab")
    }
    r.then(#"the copied log is every log line, oldest first, one to a line"#) { w, _, _ in
        try expectEqual(w.screen.logText, w.state.log.map { $0 + "\n" }.joined(), "copied log")
        // Pasted into a file, the copy is a log the replay reads back line for line and rebuilds the game from.
        let file = FileManager.default.temporaryDirectory.appending(path: "copied-log-\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: file) }
        try w.screen.logText.write(to: file, atomically: true, encoding: .utf8)
        let lines = try LogReplay.lines(ofFile: file.path)
        try expectEqual(lines, w.state.log, "lines read back")
        try expectEqual(try LogReplay.replay(lines).phase, w.state.phase, "replayed phase")
    }
}
