import SaltmarshEngine

public enum TestGames {
    /// A new game of all-human seats, still rolling for first player.
    public static func fresh(players: Int = 3, seed: UInt64 = 1) -> GameState {
        Engine.newGame(GameConfig(controllers: Array(repeating: .human, count: players), seed: seed))
    }

    /// First roll forced so `first` wins, setup completed with the first legal corner and edge at every step.
    public static func afterSetup(players: Int = 3, seed: UInt64 = 1, first: Int = 0) -> GameState {
        var s = fresh(players: players, seed: seed)
        s.forcedRolls = (0..<players).map { $0 == first ? [6, 6] : [1, 1] }
        for _ in 0..<players { try! Engine.apply(.rollForFirst, to: &s) }
        while case .setup = s.phase { try! Engine.apply(Engine.legalMoves(s).first!, to: &s) }
        return s
    }

    /// `afterSetup`, then the first player rolls `roll`.
    public static func rolled(_ roll: Int, players: Int = 3, seed: UInt64 = 1) -> GameState {
        var s = afterSetup(players: players, seed: seed)
        s.force(roll: roll)
        try! Engine.apply(.roll, to: &s)
        return s
    }

    /// A fresh 3-player game driven by random legal moves from `SeededRNG(seed:)`, calling `check` after
    /// every move, until the game ends or `maxMoves` is reached. Each pick chooses a move kind uniformly,
    /// then a move of that kind uniformly, so the dozens of trade offers do not drown out builds and
    /// games can actually finish. The same seed feeds the game config, so `Engine.replay` reproduces it.
    public static func randomGame(seed: UInt64, maxMoves: Int = 6000, check: ((GameState) -> Void)? = nil) -> (final: GameState, moves: [Move]) {
        var s = Engine.newGame(GameConfig(controllers: [.human, .human, .human], seed: seed))
        var rng = SeededRNG(seed: seed)
        var moves: [Move] = []
        for _ in 0..<maxMoves {
            if case .gameOver = s.phase { break }
            let legal = Engine.legalMoves(s)
            guard !legal.isEmpty else { break }
            let kinds = Array(Set(legal.map(kind))).sorted()
            let chosenKind = kinds[Int(rng.next() % UInt64(kinds.count))]
            let ofKind = legal.filter { kind($0) == chosenKind }
            let move = ofKind[Int(rng.next() % UInt64(ofKind.count))]
            try! Engine.apply(move, to: &s)
            moves.append(move)
            check?(s)
        }
        return (s, moves)
    }

    /// The enum case name of a move, without its payload.
    private static func kind(_ m: Move) -> String { String("\(m)".prefix { $0 != "(" }) }

    /// `afterSetup(seed:)`, then `moves` uniformly random legal moves drawn from `SeededRNG(seed:)`,
    /// stopping early when the game ends.
    public static func midGame(seed: UInt64, moves: Int = 60) -> GameState {
        var s = afterSetup(seed: seed)
        var rng = SeededRNG(seed: seed)
        for _ in 0..<moves {
            if case .gameOver = s.phase { break }
            let legal = Engine.legalMoves(s)
            guard !legal.isEmpty else { break }
            try! Engine.apply(legal[Int(rng.next() % UInt64(legal.count))], to: &s)
        }
        return s
    }
}
