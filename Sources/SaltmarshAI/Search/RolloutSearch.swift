import SaltmarshEngine

/// How much thinking a decision gets: guessed states to try, how deep to play each, a hard count of
/// playouts, and an optional wall-clock cap. Tests set no cap, so a result replays from its seed.
struct SearchBudget: Sendable, Equatable {
    var samples: Int
    var rounds: Int
    var playouts: Int
    var timeCap: Duration?
    /// How much better an alternative's mean margin must be than the heuristic's own choice to displace it;
    /// a guard against a noisy estimate overruling a sound default.
    var holdBack: Int = 0
}

/// Design section 6.3: determinize, play out, evaluate, pick. Every state here is a guess from
/// `Engine.sampleFullState`, or that guess moved on by `Engine.apply`.
enum RolloutSearch {
    struct Decision: Equatable {
        var move: Move
        /// Playouts that ran to an evaluation.
        var playouts: Int
    }

    /// `candidates[0]` is the heuristic's own choice: the answer with fewer than two candidates, when the budget
    /// allows no playout, or on a tie. Otherwise each sample is played out once per candidate with the Plan 2
    /// fallback policy for every seat, through `rounds` rounds and the seat's next turn, and the candidate with
    /// the best mean margin over its completed playouts wins. A candidate the engine refuses in a sample is skipped for that sample. The cap is checked between
    /// playouts; what was measured so far decides.
    static func choose(view: PlayerView, candidates: [Move], budget: SearchBudget, rng: inout SeededRNG,
                       clock: ContinuousClock = .continuous) -> Decision {
        guard candidates.count >= 2 else { return Decision(move: candidates.first ?? .endTurn, playouts: 0) }
        let start = clock.now
        func overCap() -> Bool { budget.timeCap.map { clock.now - start >= $0 } ?? false }
        var total = [Int](repeating: 0, count: candidates.count), runs = [Int](repeating: 0, count: candidates.count)
        var played = 0
        samples: for _ in 0..<budget.samples {
            if played >= budget.playouts || overCap() { break }
            var sample = Engine.sampleFullState(from: view, using: &rng)
            // One turn past a full round, so the seat's own next turn, where this turn's cards get spent, is played.
            let stopTurn = sample.turn + budget.rounds * sample.playerCount + 1
            // Every candidate meets the same dice in this sample, so their playouts differ only by the move.
            sample.forcedRolls = (0..<(budget.rounds * sample.playerCount + 2)).map { _ in [rng.d6(), rng.d6()] }
            for (i, candidate) in candidates.enumerated() {
                if played >= budget.playouts || overCap() { break samples }
                var state = sample
                do { try Engine.apply(candidate, to: &state) } catch { continue }
                playOut(&state, until: stopTurn, moveCap: 40 * budget.rounds * sample.playerCount)
                total[i] += Evaluator.margin(state, for: view.me)
                runs[i] += 1
                played += 1
            }
        }
        var best = 0, bestMean: Double?
        for i in candidates.indices where runs[i] > 0 {
            let mean = Double(total[i]) / Double(runs[i])
            if bestMean == nil || mean > bestMean! { best = i; bestMean = mean }
        }
        if best != 0, runs[0] > 0, let bestMean, bestMean - Double(total[0]) / Double(runs[0]) < Double(budget.holdBack) { best = 0 }
        return Decision(move: candidates[best], playouts: played)
    }

    /// Every seat plays the fallback policy until the turn counter reaches `stopTurn`, the game ends, or the
    /// move cap guards against a stall.
    static func playOut(_ s: inout GameState, until stopTurn: Int, moveCap: Int) {
        var moves = 0
        while moves < moveCap {
            if case .gameOver = s.phase { return }
            if s.turn >= stopTurn { return }
            let p = Engine.actingPlayer(s), legal = Engine.legalMoves(s)
            guard !legal.isEmpty else { return }
            let view = Engine.view(s, for: p)
            var move: Move
            if case .tradeOffered(let offer, let responses) = s.phase, responses[p] == .pending {
                move = .respondToTrade(seat: p, HeuristicPolicy.respond(to: offer, view: view, profile: .fallback))
                if !Engine.isLegal(move, in: s) { move = .respondToTrade(seat: p, .declined) }
            } else {
                move = HeuristicPolicy.fallback(view: view, legal: legal)
                if !Engine.isLegal(move, in: s) { move = legal[0] }
            }
            do { try Engine.apply(move, to: &s) } catch { return }
            moves += 1
        }
    }
}
