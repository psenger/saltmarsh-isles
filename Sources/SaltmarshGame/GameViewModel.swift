import Foundation
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
    /// Goes up once per dice roll, human or AI, so the dice can tumble. Loading or resuming a game leaves it alone.
    public private(set) var rollCount = 0
    /// The tiles the latest roll paid out from, so the board can celebrate them. Empty after a roll for first.
    public private(set) var payingTiles: [Int] = []

    private let store: GameStore
    private let pacing: Pacing
    private let saves: SaveSlots
    private let makeOpponent: (Controller, Int) -> (any Opponent)?
    private var opponents: [Int: any Opponent] = [:]
    private var aiTask: Task<Void, Never>?
    /// Guard against an AI loop that never hands control back (for example two stubborn bots trading forever).
    static let aiMoveCap = 20_000

    public init(store: GameStore, pacing: Pacing, saves: SaveSlots = InMemorySaveSlots(),
                opponents: @escaping (Controller, Int) -> (any Opponent)? = { controller, seat in
                    if case .ai(let level) = controller { return OpponentFactory.make(level: level, seed: UInt64(seat)) }
                    return nil
                }) {
        self.store = store
        self.pacing = pacing
        self.saves = saves
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
        payingTiles = []
        noteSetupHolder()
        opponents = Dictionary(uniqueKeysWithValues: s.players.enumerated().compactMap { i, p in
            makeOpponent(p.controller, i).map { (i, $0) }
        })
        save()
        runAI()
    }

    // MARK: Named saves

    public func savedGames() -> [SavedGameSummary] { saves.list() }

    public var suggestedSaveName: String { Strings.suggestedSaveName(turn: (state?.turn ?? 0) + 1) }

    /// Keeps a copy of the current game. The game carries on unchanged.
    @discardableResult
    public func saveGame(named name: String, replacing: UUID? = nil) throws -> SavedGameSummary {
        guard let s = state, !Self.isOver(s) else { throw SaveError.noGame }
        return try saves.write(name: name, state: s, replacing: replacing)
    }

    /// Removes a named save. The game in progress and the automatic save are untouched.
    public func deleteSavedGame(id: UUID) throws {
        try saves.remove(id: id)
    }

    /// Replaces the current game with a save, as if the app had just reopened on it.
    public func loadGame(id: UUID) throws {
        install(try saves.load(id: id).state)
    }

    // MARK: Moves

    /// A human move. Ignored while an AI is acting or the game is over; throws for an illegal move.
    public func apply(_ move: Move) throws {
        guard var s = state, !aiThinking, !Self.isOver(s) else { return }
        let previous = s
        try Engine.apply(move, to: &s)
        state = s
        afterMove(move, from: previous)
        runAI()
    }

    private static func rollsDice(_ move: Move) -> Bool {
        move == .roll || move == .rollForFirst
    }

    /// Tiles numbered with the roll that hold a building, are free of the robber, and whose resource left the bank.
    private static func payingTiles(before: GameState, after: GameState) -> [Int] {
        let total = after.dice?.reduce(0, +)
        return after.board.tiles.indices.filter { index in
            let tile = after.board.tiles[index]
            guard tile.number == total, index != after.robberTile, let resource = tile.resource else { return false }
            return after.bank[resource] < before.bank[resource] && tile.corners.contains { after.board.corners[$0].owner != nil }
        }
    }

    private func afterMove(_ move: Move, from previous: GameState) {
        if Self.rollsDice(move), let s = state {
            payingTiles = move == .roll ? Self.payingTiles(before: previous, after: s) : []
            rollCount += 1
        }
        ui.buildMode = nil
        ui.drawnCard = nil
        ui.discardPicks = ResourceCounts()
        if let s = state, case .gameOver(let winner) = s.phase, ui.overlay == nil {
            ui.overlay = .victory(winner: winner)
        }
        noteSetupHolder()
        save()
    }

    /// The device passes without a handover during the first roll and setup, so the human who places
    /// last and takes the first turn is not asked to hand it to themselves.
    private func noteSetupHolder() {
        guard let s = state, s.phase.skipsHandover else { return }
        let acting = Engine.actingPlayer(s)
        if !s.players[acting].controller.isAI { ui.revealedTo = acting }
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
                // A new game cancelled this turn while the opponent was deciding; the move is for the old game.
                if Task.isCancelled { return }
                var next = current
                do { try Engine.apply(move, to: &next) } catch { break }
                self.state = next
                self.afterMove(move, from: current)
                moves += 1
                await self.pacing.pause()
                // The dice tumble for most of one pause; these two let them land and be read before the seat moves on.
                if Self.rollsDice(move) {
                    await self.pacing.pause()
                    await self.pacing.pause()
                }
            }
            // These flags now belong to whatever replaced a cancelled turn.
            if Task.isCancelled { return }
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
