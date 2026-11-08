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
    /// The noise guard: an alternative needs at least this many playouts paired with the heuristic's choice
    /// (same guessed hand, same dice), and a mean paired gain of `holdBack` plus `noiseMultiple` standard errors.
    /// With both at 0 the guard is off and the unpaired rule decides.
    var minPlayouts: Int = 0
    var noiseMultiple: Double = 0
}

/// Design section 6.3: determinize, play out, evaluate, pick. Every state here is a guess from
/// `Engine.sampleFullState`, or that guess moved on by `Engine.apply`.
enum RolloutSearch {
    struct Decision: Equatable {
        var move: Move
        /// Playouts that ran to an evaluation.
        var playouts: Int
        /// Guessed states drawn.
        var samples: Int
        var elapsed: Duration
        var outOfTime: Bool
        /// The search overruled candidates[0].
        var changedMind: Bool

        /// Two decisions are the same when they chose the same and measured the same; the clock does not count.
        static func == (a: Decision, b: Decision) -> Bool {
            a.move == b.move && a.playouts == b.playouts && a.samples == b.samples && a.outOfTime == b.outOfTime && a.changedMind == b.changedMind
        }
    }

    /// `candidates[0]` is the heuristic's own choice: the answer with fewer than two candidates, when the budget
    /// allows no playout, or on a tie. Otherwise each sample is played out once per candidate with the Plan 2
    /// fallback policy for every seat, through `rounds` rounds and the seat's next turn, and the candidate with
    /// the best mean margin over its completed playouts wins (see `pick`). A candidate the engine refuses in a sample is skipped for that sample. The cap is checked between
    /// playouts; what was measured so far decides.
    static func choose(view: PlayerView, candidates: [Move], budget: SearchBudget, rng: inout SeededRNG,
                       clock: ContinuousClock = .continuous) -> Decision {
        let start = clock.now
        guard candidates.count >= 2 else { return Decision(move: candidates.first ?? .endTurn, playouts: 0, samples: 0, elapsed: .zero, outOfTime: false, changedMind: false) }
        var outOfTime = false
        func overCap() -> Bool {
            guard let cap = budget.timeCap, clock.now - start >= cap else { return false }
            outOfTime = true; return true
        }
        // margins[i][k]: candidate i's margin in sample k, nil when it was refused or never reached there.
        var margins = [[Int?]](repeating: [], count: candidates.count)
        var played = 0, drawn = 0
        samples: for _ in 0..<budget.samples {
            if played >= budget.playouts || overCap() { break }
            drawn += 1
            for i in candidates.indices { margins[i].append(nil) }
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
                margins[i][drawn - 1] = Evaluator.margin(state, for: view.me)
                played += 1
            }
        }
        let best = pick(margins, budget: budget)
        return Decision(move: candidates[best], playouts: played, samples: drawn, elapsed: clock.now - start, outOfTime: outOfTime, changedMind: best != 0)
    }

    /// The index of the candidate to play, from each candidate's margin per sample.
    ///
    /// Guard off: the best mean over each candidate's own playouts, ties to the lower index, kept only when it
    /// beats candidates[0]'s mean by `holdBack`.
    ///
    /// Guard on: an alternative is paired with candidates[0] over the samples where both have a margin. With
    /// n pairs, mean gain d and standard error se (0 below two pairs), it is eligible when n >= 1,
    /// n >= `minPlayouts` and d >= `holdBack` + `noiseMultiple` * se. The eligible one with the largest d wins,
    /// ties to the lower index; with none eligible, candidates[0].
    static func pick(_ margins: [[Int?]], budget: SearchBudget) -> Int {
        guard budget.minPlayouts != 0 || budget.noiseMultiple != 0 else {
            func mean(_ i: Int) -> Double? {
                let done = margins[i].compactMap { $0 }
                return done.isEmpty ? nil : Double(done.reduce(0, +)) / Double(done.count)
            }
            var best = 0, bestMean: Double?
            for i in margins.indices { if let m = mean(i), bestMean == nil || m > bestMean! { best = i; bestMean = m } }
            if best != 0, let base = mean(0), let bestMean, bestMean - base < Double(budget.holdBack) { best = 0 }
            return best
        }
        var best = 0, bestGain = -Double.infinity
        for i in margins.indices.dropFirst() {
            let gains = zip(margins[i], margins[0]).compactMap { a, b in a.flatMap { a in b.map { Double(a - $0) } } }
            let n = Double(gains.count)
            guard gains.count >= max(1, budget.minPlayouts) else { continue }
            let gain = gains.reduce(0, +) / n
            let se = gains.count < 2 ? 0 : (gains.reduce(0) { $0 + ($1 - gain) * ($1 - gain) } / (n - 1)).squareRoot() / n.squareRoot()
            if gain >= Double(budget.holdBack) + budget.noiseMultiple * se, gain > bestGain { best = i; bestGain = gain }
        }
        return best
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
