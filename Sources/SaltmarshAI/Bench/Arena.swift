import SaltmarshEngine

/// One whole game between opponents: the loop the game layer runs, without the game layer. The acting seat
/// gets its view, answers an offer or chooses a move, the safety net replaces an illegal choice, the engine
/// applies it. The tests and `ai-bench` share it. The live game it drives is its own; nothing here is stored.
public enum Arena {
    public struct Outcome: Sendable {
        public var winner: Int?
        public var moves: Int
        /// `chooseMove` results the engine would have refused; the net replaced them.
        public var illegalChoices: Int
        /// Trade answers the engine refused (a counter the proposer could not pay); they became declines.
        public var refusedAnswers: Int
    }

    /// The game between factory opponents, each seeded from the game's seed and its seat. `fast` gives the
    /// searching levels a tenth of their playouts and no clock, for a smoke run that still replays from its seed.
    public static func play(_ levels: [EffortLevel], seed: UInt64, maxMoves: Int = 4000, fast: Bool = false) async -> Outcome {
        let d = await play(levels: levels, seed: seed, maxMoves: maxMoves, make: fast ? { level, seed in
            guard let b = LevelProfile.forLevel(level).search else { return OpponentFactory.make(level: level, seed: seed) }
            return SearchOpponent(level: level, seed: seed, budget: SearchBudget(samples: max(2, b.samples / 10), rounds: b.rounds, playouts: max(4, b.playouts / 10), timeCap: nil))
        } : nil)
        return Outcome(winner: d.winner, moves: d.moves.count, illegalChoices: d.illegalChoices, refusedAnswers: d.refusedAnswers)
    }

    // MARK: The loop itself, for the tests

    struct Detail {
        var winner: Int?
        var moves: [Move]
        var illegalChoices: Int
        /// The first few illegal choices, with the phase they were made in.
        var illegalSamples: [(move: Move, phase: Phase)]
        var refusedAnswers: Int
    }

    /// `make` builds each seat's opponent from its level and derived seed (nil: the factory); `check` runs after
    /// every applied move. Stops at game over or `maxMoves`.
    static func play(levels: [EffortLevel], seed: UInt64, maxMoves: Int,
                     make: ((EffortLevel, UInt64) -> any Opponent)? = nil,
                     check: (@Sendable (GameState) -> Void)? = nil) async -> Detail {
        var s = Engine.newGame(GameConfig(controllers: levels.map { .ai($0) }, seed: seed))
        let bots = levels.enumerated().map { seat, level in
            let derived = seed &* 31 &+ UInt64(seat)
            return make?(level, derived) ?? OpponentFactory.make(level: level, seed: derived)
        }
        var moves: [Move] = [], illegal = 0, refused = 0, samples: [(move: Move, phase: Phase)] = []
        for _ in 0..<maxMoves {
            if case .gameOver = s.phase { break }
            let p = Engine.actingPlayer(s), legal = Engine.legalMoves(s)
            guard !legal.isEmpty else { break }
            let view = Engine.view(s, for: p)
            let state = s
            let isLegal = { Engine.isLegal($0, in: state) }
            let move: Move
            if case .tradeOffered(let offer, let responses) = s.phase, responses[p] == .pending {
                let answer = Move.respondToTrade(seat: p, await bots[p].respondToTrade(offer, view: view))
                if isLegal(answer) { move = answer } else { refused += 1; move = .respondToTrade(seat: p, .declined) }
            } else {
                let proposed = await bots[p].chooseMove(view: view, legal: legal)
                if !isLegal(proposed) { illegal += 1; if samples.count < 5 { samples.append((proposed, s.phase)) } }
                move = MoveResolver.resolve(proposed, isLegal: isLegal, legal: legal) {
                    let steady = HeuristicPolicy.fallback(view: view, legal: legal)
                    return isLegal(steady) ? steady : [Move.endTurn, .withdrawTrade, .roll].first { legal.contains($0) }
                }
            }
            do { try Engine.apply(move, to: &s) } catch { preconditionFailure("a resolved move was refused: \(move): \(error)") }
            moves.append(move)
            check?(s)
        }
        var winner: Int?
        if case .gameOver(let w) = s.phase { winner = w }
        return Detail(winner: winner, moves: moves, illegalChoices: illegal, illegalSamples: samples, refusedAnswers: refused)
    }
}
