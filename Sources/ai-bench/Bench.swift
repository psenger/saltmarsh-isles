import Foundation
import SaltmarshEngine
import SaltmarshAI

/// ai-bench: the effort dial at shipped budgets. Plays every pair of levels in seeded two-player games with
/// the seats alternating, prints the win table as Markdown and judges the design's two criteria: Admiral
/// beats Deckhand in at least 70% of games, and each level beats the one below more often than not.
///
///     swift run -c release ai-bench [--games N] [--levels a,b,c] [--fast] [--max-moves N]
///
/// `--fast` gives the searching levels a tenth of their playouts and no clock: a smoke run, reproducible from
/// the seeds. Exit 0 when both criteria pass, 1 when one fails, 2 on bad arguments.
@main
struct Bench {
    static func main() async {
        var games = 20, maxMoves = 4000, fast = false
        var levels: [EffortLevel] = EffortLevel.allCases
        var args = Array(CommandLine.arguments.dropFirst())
        func fail(_ message: String) -> Never { FileHandle.standardError.write(Data((message + "\n").utf8)); exit(2) }
        func number(after flag: String) -> Int {
            guard let n = args.first.flatMap({ Int($0) }), n > 0 else { fail("\(flag) needs a positive number") }
            args.removeFirst(); return n
        }
        while !args.isEmpty {
            let flag = args.removeFirst()
            switch flag {
            case "--games": games = number(after: flag)
            case "--max-moves": maxMoves = number(after: flag)
            case "--levels":
                guard let list = args.first else { fail("--levels needs a comma-separated list") }
                args.removeFirst()
                levels = list.split(separator: ",").map { name in
                    guard let level = EffortLevel.allCases.first(where: { $0.name.lowercased() == name.lowercased() }) else { fail("unknown level \(name)") }
                    return level
                }
                guard levels.count >= 2 else { fail("--levels needs at least two levels") }
            case "--fast": fast = true
            case "--help", "-h": print("usage: ai-bench [--games N] [--levels a,b,c] [--fast] [--max-moves N]"); exit(0)
            default: fail("unknown argument \(flag)")
            }
        }

        let started = Date()
        var wins = [[Int]](repeating: [Int](repeating: 0, count: levels.count), count: levels.count)
        var played = [[Int]](repeating: [Int](repeating: 0, count: levels.count), count: levels.count)
        for i in levels.indices {
            for j in levels.indices where j > i {
                let pairStarted = Date()
                for g in 0..<games {
                    let firstSeat = g % 2 == 0 ? i : j, secondSeat = firstSeat == i ? j : i
                    let outcome = await Arena.play([levels[firstSeat], levels[secondSeat]], seed: UInt64(5000 + g), maxMoves: maxMoves, fast: fast)
                    played[i][j] += 1; played[j][i] += 1
                    if let w = outcome.winner {
                        let winner = w == 0 ? firstSeat : secondSeat, loser = winner == i ? j : i
                        wins[winner][loser] += 1
                    }
                }
                let seconds = Int(Date().timeIntervalSince(pairStarted).rounded())
                FileHandle.standardError.write(Data("\(levels[i].name) v \(levels[j].name): \(games) games in \(seconds)s\n".utf8))
            }
        }

        func rate(_ i: Int, _ j: Int) -> Int? { played[i][j] > 0 ? Int((100.0 * Double(wins[i][j]) / Double(played[i][j])).rounded()) : nil }
        print("| beats → | " + levels.map(\.name).joined(separator: " | ") + " |")
        print("|---|" + levels.map { _ in "---|" }.joined())
        for i in levels.indices {
            let cells = levels.indices.map { j in i == j ? "–" : rate(i, j).map { "\($0)%" } ?? "n/a" }
            print("| **\(levels[i].name)** | " + cells.joined(separator: " | ") + " |")
        }
        print("")
        var pass = true
        if let a = levels.firstIndex(of: .admiral), let d = levels.firstIndex(of: .deckhand), let r = rate(a, d) {
            let ok = r >= 70; pass = pass && ok
            print("Admiral vs Deckhand: \(r)% (criterion 70%): \(ok ? "PASS" : "FAIL")")
        }
        var failing: [String] = []
        for k in levels.indices.dropFirst() where levels[k].rawValue == levels[k - 1].rawValue + 1 {
            if let r = rate(k, k - 1), r <= 50 { failing.append("\(levels[k].name) v \(levels[k - 1].name) \(r)%") }
        }
        let ok = failing.isEmpty; pass = pass && ok
        print("Each level beats the one below: " + (ok ? "PASS" : "FAIL (" + failing.joined(separator: ", ") + ")"))
        print("\(games) games per pair, \(fast ? "fast budgets" : "shipped budgets"), \(Int(Date().timeIntervalSince(started).rounded()))s")
        exit(pass ? 0 : 1)
    }
}
