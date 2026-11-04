import Observation
import SaltmarshEngine
import SaltmarshAI

/// Owns the current game: applies human moves, runs AI seats through `TurnRunner`, saves after
/// every move, and resumes a saved game on launch. Views read `screen` and call the entry points.
@MainActor @Observable
public final class GameViewModel {
    public private(set) var state: GameState?
    public var ui = UIState()
    public private(set) var aiThinking = false
    /// Set by the app from the accessibility environment; drives the victory animation mode.
    public var reduceMotion = false

    private let store: GameStore
    private let pacing: Pacing
    private let makeOpponent: (Controller, Int) -> (any Opponent)?
    private var opponents: [Int: any Opponent] = [:]
    private var aiTask: Task<Void, Never>?
    /// Guard against an AI loop that never hands control back (for example two stubborn bots trading forever).
    static let aiMoveCap = 20_000

    public init(store: GameStore, pacing: Pacing,
                opponents: @escaping (Controller, Int) -> (any Opponent)? = { controller, seat in
                    if case .ai(let level) = controller { return OpponentFactory.make(level: level, seed: UInt64(seat)) }
                    return nil
                }) {
        self.store = store
        self.pacing = pacing
        self.makeOpponent = opponents
    }

    // MARK: Lifecycle

    public func newGame(_ config: GameConfig) {
        install(Engine.newGame(config))
    }

    /// Loads the saved game, if any, and restarts an AI turn when one was in progress.
    @discardableResult
    public func resume() -> Bool {
        guard let saved = try? store.load() else { return false }
        install(saved)
        return true
    }

    /// Replaces the game with a prepared state (tests and the debug menu).
    public func load(_ prepared: GameState) {
        install(prepared)
    }

    private func install(_ s: GameState) {
        cancelAI()
        state = s
        ui = UIState()
        opponents = Dictionary(uniqueKeysWithValues: s.players.enumerated().compactMap { i, p in
            makeOpponent(p.controller, i).map { (i, $0) }
        })
        save()
        runAI()
    }

    // MARK: Moves

    /// A human move. Ignored while an AI is acting or the game is over; throws for an illegal move.
    public func apply(_ move: Move) throws {
        guard var s = state, !aiThinking, !Self.isOver(s) else { return }
        try Engine.apply(move, to: &s)
        state = s
        afterMove()
        runAI()
    }

    private func afterMove() {
        ui.buildMode = nil
        ui.discardPicks = ResourceCounts()
        if let s = state, case .gameOver(let winner) = s.phase, ui.overlay == nil {
            ui.overlay = .victory(winner: winner)
        }
        save()
    }

    private func save() {
        if let s = state { try? store.save(s) }
    }

    nonisolated static func isOver(_ s: GameState) -> Bool {
        if case .gameOver = s.phase { return true }
        return false
    }

    // MARK: AI turns

    private func runAI() {
        guard aiTask == nil, let s = state, !Self.isOver(s), opponents[Engine.actingPlayer(s)] != nil else { return }
        aiThinking = true
        aiTask = Task { [weak self] in
            guard let self else { return }
            var moves = 0
            while !Task.isCancelled, moves < Self.aiMoveCap, let current = self.state,
                  let move = await TurnRunner.step(state: current, opponents: self.opponents) {
                var next = current
                do { try Engine.apply(move, to: &next) } catch { break }
                self.state = next
                self.afterMove()
                moves += 1
                await self.pacing.pause()
            }
            self.aiThinking = false
            self.aiTask = nil
        }
    }

    private func cancelAI() {
        aiTask?.cancel()
        aiTask = nil
        aiThinking = false
    }

    /// Tests: waits until the AI loop has handed control back.
    public func waitForAI() async {
        while let task = aiTask { await task.value }
    }
}
