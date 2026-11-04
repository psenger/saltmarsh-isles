import SaltmarshEngine

/// One scoreboard row.
public struct ScoreRow: Equatable, Sendable {
    public var seat: Seat
    public var name: String
    public var colorHex: String
    public var cards: Int
    public var devCards: Int
    public var road: Int
    public var roadHighlighted: Bool
    public var knights: Int
    public var knightsHighlighted: Bool
    /// "N / 10", buildings and awards only.
    public var score: String
    /// "+N" hidden victory points, shown for the current human seat only.
    public var hidden: String?
    public var isCurrent: Bool
}

/// The render model: every string and enabled flag the panel shows and every piece of intent the
/// board draws from. Views only turn this into pixels; the feature file's steps assert on it.
public struct ScreenState: Equatable, Sendable {
    public var header: String
    /// Whose colour the panel takes.
    public var headerSeat: Seat
    public var status: String
    /// Two dice faces, "–" before the roll.
    public var dice: [String]
    /// The hand shown in the hold, empty when no hand should be visible.
    public var handCounts: ResourceCounts
    /// "Cobalt's hold", or "" when no hand is shown.
    public var holdTitle: String
    public var bank: ResourceCounts
    public var log: [String]
    /// Placement order during the first roll and setup, nil otherwise.
    public var orderStrip: [Seat]?
    public var orderStripNote: String?
    /// Button label → enabled.
    public var buttons: [String: Bool]
    public var buildLeft: [BuildMode: Int]
    public var activeBuildMode: BuildMode?
    public var deckCount: Int
    /// Why the acting trade responder cannot accept, when they cannot.
    public var acceptProblem: String?
    public var scoreboard: [ScoreRow]
    public var aiThinking: Bool
    public var board: Board
    public var robberTile: Int

    /// Before any game exists.
    static func empty(board: Board) -> ScreenState {
        ScreenState(header: "", headerSeat: .crimson, status: "", dice: [Strings.dash, Strings.dash], handCounts: ResourceCounts(),
                    holdTitle: "", bank: .uniform(19), log: [], orderStrip: nil, orderStripNote: nil,
                    buttons: [Strings.newGame: true], buildLeft: [:], activeBuildMode: nil, deckCount: 25, acceptProblem: nil,
                    scoreboard: [], aiThinking: false, board: board, robberTile: board.desertTile)
    }
}
