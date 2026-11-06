import SaltmarshEngine

/// How much thinking a decision gets: guessed states to try, how deep to play each, a hard count of
/// playouts, and an optional wall-clock cap. Tests set no cap, so a result replays from its seed.
struct SearchBudget: Sendable, Equatable {
    var samples: Int
    var rounds: Int
    var playouts: Int
    var timeCap: Duration?
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
    /// fallback policy for every seat, and the candidate with the best mean margin over its completed playouts
    /// wins. A candidate the engine refuses in a sample is skipped for that sample. The cap is checked between
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
            let sample = Engine.sampleFullState(from: view, using: &rng)
            let stopTurn = sample.turn + budget.rounds * sample.playerCount
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
