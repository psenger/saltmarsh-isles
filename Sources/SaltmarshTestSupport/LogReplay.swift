import Foundation
import SaltmarshEngine

/// Rebuilds a game from its log alone (docs/game-log.md). The header gives the seats and the seed; a fresh
/// game is started from them, and every turn line that describes a move is applied in order. After each
/// move the lines the replay has just written must equal the lines it read, so a dice value, a stolen card,
/// a drawn card or a board line that disagrees with the real game fails at its line number.
public enum LogReplay {
    public enum Failure: Error, CustomStringConvertible {
        case header(String)
        /// A line that is neither a move nor a fact the engine writes.
        case unparsed(line: Int, text: String)
        case illegal(line: Int, move: Move, reason: String)
        /// The replay wrote `got` where the log says `expected`.
        case mismatch(line: Int, expected: String, got: String)

        public var description: String {
            switch self {
            case .header(let why): "bad header: \(why)"
            case .unparsed(let line, let text): "line \(line): cannot read \"\(text)\""
            case .illegal(let line, let move, let reason): "line \(line): \(move) is not legal here: \(reason)"
            case .mismatch(let line, let expected, let got): "line \(line): log says \"\(expected)\", replay says \"\(got)\""
            }
        }
    }

    /// The game the log describes, or the first line that cannot be reproduced. Line numbers are 1-based.
    public static func replay(_ log: [String]) throws -> GameState {
        var controllers: [Controller] = []
        var seed: UInt64?
        let levels = Dictionary(uniqueKeysWithValues: EffortLevel.allCases.map { ($0.name, $0) })
        for line in log.prefix { !$0.hasPrefix("ROBBER ") } {
            if let m = match(#"^(\w+) is human\.$"#, line) { _ = m; controllers.append(.human) }
            else if let m = match(#"^(\w+) is an AI (\w+)\.$"#, line) {
                guard let level = levels[m[2]] else { throw Failure.header("unknown level \(m[2])") }
                controllers.append(.ai(level))
            } else if let m = match(#"^SEED (\d+)$"#, line) { seed = UInt64(m[1]) }
        }
        guard (2...4).contains(controllers.count) else { throw Failure.header("\(controllers.count) seat lines; a game has 2 to 4") }
        guard let seed else { throw Failure.header("no SEED line") }

        var s = Engine.newGame(GameConfig(controllers: controllers, seed: seed))
        var i = 0
        try consume(log, from: &i, expecting: s.log[...])
        while i < log.count {
            let line = log[i]
            if isThought(line) { i += 1; continue }
            guard let move = move(for: line, in: s) else { throw Failure.unparsed(line: i + 1, text: line) }
            let before = s.log.count
            do { try Engine.apply(move, to: &s) } catch { throw Failure.illegal(line: i + 1, move: move, reason: "\(error)") }
            try consume(log, from: &i, expecting: s.log[before...])
        }
        return s
    }

    /// The lines of a log file, or the `log` array of a saved game's JSON.
    public static func lines(ofFile path: String) throws -> [String] {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        if path.hasSuffix(".json"), let object = try JSONSerialization.jsonObject(with: data) as? [String: Any], let log = object["log"] as? [String] {
            return log
        }
        return String(decoding: data, as: UTF8.self).split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            .reversed().drop { $0.isEmpty }.reversed()
    }

    /// A line the game layer adds about an AI's search; the engine never writes it, so a replay skips it.
    public static func isThought(_ line: String) -> Bool { line.contains(" weighed ") }

    // MARK: Lines to moves

    /// The move a line describes in the given position, or nil for a fact line (production, awards, the
    /// board record, the win) that follows from a move rather than being one.
    public static func move(for line: String, in s: GameState) -> Move? {
        func seat(_ name: String) -> Int? { s.players.firstIndex { $0.name == name } }
        func edge(_ a: String, _ b: String) -> Int? { s.board.edgeIndex(ofID: "E\(a)-\(b)") }
        if match(#"^(\w+) rolled \d+ \(\d\+\d\) for first player\.$"#, line) != nil { return .rollForFirst }
        if let m = match(#"^(\w+) founded a settlement at V(\d+)\.$"#, line) { return .placeSettlement(corner: Int(m[2])!) }
        if let m = match(#"^(\w+) laid a road E(\d+)-(\d+)\.$"#, line), let e = edge(m[2], m[3]) { return .placeRoad(edge: e) }
        if match(#"^(\w+) rolled \d+ \(\d\+\d\)\.( .*)?$"#, line) != nil { return .roll }
        if let m = match(#"^(\w+) discarded (.+)\.$"#, line), let c = counts(m[2]) { return .discard(c) }
        if let m = match(#"^(\w+) moved the robber to H(\d+)\.$"#, line) { return .moveRobber(tile: Int(m[2])!) }
        if let m = match(#"^(\w+) stole 1 \w+ from (\w+)\.$"#, line), let v = seat(m[2]) { return .steal(from: v) }
        if let m = match(#"^(\w+) traded 4 (\w+) for 1 (\w+) with the bank\.$"#, line), let g = Resource(rawValue: m[2]), let t = Resource(rawValue: m[3]) {
            return .bankTrade(give: g, get: t)
        }
        if let m = match(#"^(\w+) traded \d (\w+) for 1 (\w+) at the .+ \(PORT (\d+)-(\d+)\)\.$"#, line),
           let g = Resource(rawValue: m[2]), let t = Resource(rawValue: m[3]), let h = s.board.harbourIndex(ofID: "PORT \(m[4])-\(m[5])") {
            return .harbourTrade(harbour: h, give: g, get: t)
        }
        if let m = match(#"^(\w+) offers (.+) for (.+?)(?: to (\w+))?\.$"#, line), let p = seat(m[1]), let give = counts(m[2]), let want = counts(m[3]) {
            let to = m[4].isEmpty ? nil : seat(m[4])
            if !m[4].isEmpty && to == nil { return nil }
            return .proposeTrade(TradeOffer(proposer: p, give: give, want: want, to: to))
        }
        if let m = match(#"^(\w+) accepted the offer\.$"#, line), let r = seat(m[1]) { return .respondToTrade(seat: r, .accepted) }
        if let m = match(#"^(\w+) declined the offer\.$"#, line), let r = seat(m[1]) { return .respondToTrade(seat: r, .declined) }
        if let m = match(#"^(\w+) countered: (.+) for (.+)\.$"#, line), let r = seat(m[1]), let give = counts(m[2]), let want = counts(m[3]),
           case .tradeOffered(let offer, _) = s.phase {
            return .respondToTrade(seat: r, .countered(TradeOffer(proposer: offer.proposer, give: give, want: want, to: r)))
        }
        if let m = match(#"^(\w+) traded (.+) with (\w+) for (.+)\.$"#, line), let partner = seat(m[3]) { return .executeTrade(with: partner) }
        if match(#"^(\w+) withdrew the offer\.$"#, line) != nil { return .withdrawTrade }
        if match(#"^(\w+) bought a development card: .+\.$"#, line) != nil { return .buyDevCard }
        if match(#"^(\w+) played a Knight\.$"#, line) != nil { return .playKnight }
        if match(#"^(\w+) played Road crew\.$"#, line) != nil { return .playRoadCrew }
        if let m = match(#"^(\w+) built a free road E(\d+)-(\d+)\.$"#, line), let e = edge(m[2], m[3]) { return .placeRoad(edge: e) }
        if let m = match(#"^(\w+) played Bumper harvest: (\w+) and (\w+)\.$"#, line), let a = Resource(rawValue: m[2]), let b = Resource(rawValue: m[3]) {
            return .playBumperHarvest(a, b)
        }
        if let m = match(#"^(\w+) cornered the (\w+) market and took \d+"#, line), let r = Resource(rawValue: m[2]) { return .playCornerMarket(r) }
        if let m = match(#"^(\w+) built a road E(\d+)-(\d+)\.$"#, line), let e = edge(m[2], m[3]) { return .placeRoad(edge: e) }
        if let m = match(#"^(\w+) built a settlement at V(\d+)\.$"#, line) { return .placeSettlement(corner: Int(m[2])!) }
        if let m = match(#"^(\w+) upgraded to a city at V(\d+)\.$"#, line) { return .upgradeCity(corner: Int(m[2])!) }
        if match(#"^(\w+) ended the turn\.$"#, line) != nil { return .endTurn }
        return nil
    }

    /// "2 timber, 1 ore" as counts; nil when a word is not a resource.
    static func counts(_ text: String) -> ResourceCounts? {
        var c = ResourceCounts()
        for part in text.split(separator: ", ") {
            let words = part.split(separator: " ")
            guard words.count == 2, let n = Int(words[0]), let r = Resource(rawValue: String(words[1])) else { return nil }
            c[r] += n
        }
        return c
    }

    // MARK: Pieces

    /// Advances `i` over the lines the replay just wrote, which must match the log, thought lines aside.
    private static func consume(_ log: [String], from i: inout Int, expecting written: ArraySlice<String>) throws {
        for line in written {
            while i < log.count, isThought(log[i]) { i += 1 }
            guard i < log.count else { throw Failure.mismatch(line: i + 1, expected: "(end of log)", got: line) }
            guard log[i] == line else { throw Failure.mismatch(line: i + 1, expected: log[i], got: line) }
            i += 1
        }
    }

    /// The whole match and its capture groups (missing groups as ""), or nil.
    private static func match(_ pattern: String, _ line: String) -> [String]? {
        let regex = try! NSRegularExpression(pattern: pattern)
        guard let m = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else { return nil }
        return (0..<m.numberOfRanges).map { Range(m.range(at: $0), in: line).map { String(line[$0]) } ?? "" }
    }
}
