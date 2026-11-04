import Foundation
import Testing
import SaltmarshEngine
import SaltmarshAI
import SaltmarshTestSupport
@testable import SaltmarshGame

/// One scenario's state: the view model under test plus whatever a step remembers for a later one.
@MainActor
final class World {
    let store = InMemoryGameStore()
    private(set) var vm: GameViewModel
    /// A screen captured by a step ("When Cobalt is thinking") that later steps read instead of the live one.
    var frozenScreen: ScreenState?
    var rememberedCorner: Int?
    var rememberedEdge: Int?
    var rememberedTile: Int?
    var rememberedBoard: Board?
    var rememberedHands: [ResourceCounts] = []
    var rememberedDeckCount = 0
    var rememberedPoints = 0
    var boards: [Board] = []

    init() {
        vm = GameViewModel(store: store, pacing: NoPacing())
        vm.newGame(GameConfig(controllers: [.human, .human, .human], seed: 1))
    }

    var screen: ScreenState { frozenScreen ?? vm.screen }
    var state: GameState { vm.state! }

    func load(_ s: GameState) { frozenScreen = nil; vm.load(s) }

    /// A fresh view model for a game with the given seats.
    func newGame(_ controllers: [Controller], seed: UInt64 = 1) {
        frozenScreen = nil
        vm = GameViewModel(store: store, pacing: NoPacing())
        vm.newGame(GameConfig(controllers: controllers, seed: seed))
    }

    // MARK: Names and lists

    func seat(_ name: String) -> Int {
        guard let i = state.players.firstIndex(where: { $0.name == name }) else { fatalError("no seat called \(name)") }
        return i
    }

    /// "Crimson, Cobalt and Amber" / "Crimson, Cobalt, Amber" → ["Crimson", "Cobalt", "Amber"]
    static func names(_ list: String) -> [String] {
        list.replacingOccurrences(of: " and ", with: ", ").components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    /// "1 timber, 1 clay and 1 wool" / "4 timber" → counts
    static func resources(_ list: String) -> ResourceCounts {
        var counts = ResourceCounts()
        for item in names(list) {
            let parts = item.split(separator: " ")
            guard parts.count == 2, let n = Int(parts[0]), let r = Resource(rawValue: String(parts[1])) else { fatalError("bad resource list: \(list)") }
            counts[r] += n
        }
        return counts
    }

    // MARK: Game phases

    /// Forces the first roll so `winner` wins and applies every seat's roll through the view model.
    func forceFirstRoll(winner: Int) {
        var s = state
        s.forcedRolls = (0..<s.playerCount).map { $0 == winner ? [6, 6] : [1, 1] }
        load(s)
        for _ in 0..<state.playerCount { vm.rollForFirst() }
        precondition({ if case .setup = state.phase { return true } else { return false } }(), "first roll did not end in setup")
    }

    /// Plays every remaining setup placement with the first legal corner and edge.
    func completeSetup() {
        while case .setup = state.phase { try! vm.apply(Engine.legalMoves(state).first!) }
    }

    /// Setup complete with `first` (default Crimson) rolling first, board and hands cleared unless `keepBoard`.
    func afterSetup(first: Int = 0, clear: Bool = true) {
        var s = TestGames.afterSetup(players: state.playerCount, seed: state.seed, first: first)
        if clear { s.clearBoard(); s.clearHands() }
        load(s)
    }

    /// Forces the next roll to total `n`.
    func forceRoll(_ n: Int) {
        var s = state
        s.force(roll: n)
        load(s)
    }

    func set(hand: ResourceCounts, for player: Int) {
        var s = state
        s.set(hand: hand, for: player)
        load(s)
    }

    func mutate(_ change: (inout GameState) -> Void) {
        var s = state
        change(&s)
        load(s)
    }

    /// A Crimson settlement at corner 0 with a road along its first edge, when Crimson owns nothing yet.
    func ensureCrimsonBase() {
        guard !state.board.corners.contains(where: { $0.owner == 0 }) else { return }
        mutate { s in
            s.place(settlement: 0, owner: 0)
            s.place(road: s.board.corners[0].edges[0], owner: 0)
        }
    }

    /// Crimson at 9 points with a settlement in hand and a reachable corner; returns the corner.
    func crimsonAtNine() -> Int {
        var s = TestGames.rolled(8); s.clearBoard(); s.clearHands()
        let spots = s.spreadCorners(6)
        for c in spots.prefix(3) { s.place(settlement: c, owner: 0) }
        for c in spots.dropFirst(3) { s.place(city: c, owner: 0) }
        let reach = s.addReach(from: spots[0], owner: 0)
        s.set(hand: Cost.settlement, for: 0)
        load(s)
        return reach
    }

    /// Crimson wins by building a settlement; the victory overlay opens.
    func crimsonWins() {
        let reach = crimsonAtNine()
        vm.toggleBuildMode(.settlement)
        vm.tapCorner(reach)
        precondition(vm.ui.overlay == .victory(winner: 0), "the win did not open the overlay")
    }
}

/// Assertion helpers that read like the feature file.
@MainActor
func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ what: String) throws {
    guard actual == expected else { throw StepError.failed("\(what): expected \(expected), got \(actual)") }
}

@MainActor
func expectTrue(_ condition: Bool, _ what: String) throws {
    guard condition else { throw StepError.failed(what) }
}
