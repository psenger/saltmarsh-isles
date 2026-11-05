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
    /// The N of `score`, for the compact header.
    public var points: Int
    /// "+N" hidden victory points, shown for the current human seat only.
    public var hidden: String?
    public var isCurrent: Bool
}

/// A player who can be robbed: their name button and their glowing buildings on the robber's tile.
public struct StealTarget: Equatable, Sendable {
    public var seat: Seat
    public var name: String
    public var cards: Int
    public var corners: Set<Int>
    public init(seat: Seat, name: String, cards: Int, corners: Set<Int>) {
        self.seat = seat; self.name = name; self.cards = cards; self.corners = corners
    }
}

public struct DiscardRow: Equatable, Sendable {
    public var resource: Resource
    public var picked: Int
    public var held: Int
    /// "0 of N"
    public var label: String
    public var plusEnabled: Bool
    public var minusEnabled: Bool
}

public struct DiscardBox: Equatable, Sendable {
    /// "Cobalt, pick 4 cards to give up"
    public var title: String
    /// "0 / 4"
    public var counter: String
    public var rows: [DiscardRow]
    /// "Next: Amber"
    public var next: String?
    /// "Discard 4 cards"
    public var confirmLabel: String
    public var confirmEnabled: Bool
    public var outlineSeat: Seat
}

public struct HarbourRow: Equatable, Sendable {
    public var index: Int
    /// "3:1 any" or "2:1 grain"
    public var title: String
    /// "your settlement", "your settlement and city"
    public var heldBy: String
    /// "2 wool" at a 2:1 harbour, nil at a 3:1 harbour
    public var giveFixed: String?
    public var give: Resource
    public var get: Resource
    /// What the Give dropdown lists: the resources this row can trade, or only `give` when it can trade none.
    public var giveOptions: [Resource]
    /// "Trade 2 for 1"
    public var tradeLabel: String
    public var tradeEnabled: Bool
    /// False when no trade on this row is legal, whatever is picked.
    public var rowEnabled: Bool
}

public struct HarboursPanel: Equatable, Sendable {
    public var emptyText: String?
    public var rows: [HarbourRow]
}

public struct DevCardRow: Equatable, Sendable {
    public var index: Int
    public var name: String
    /// "bought this turn", "one card per turn", "counts automatically"
    public var note: String?
    public var playEnabled: Bool
    public var needsChoices: Bool
}

public struct ResponseRow: Equatable, Sendable {
    public var seat: Seat
    /// "pending", "accepted", "declined", "countered: 3 timber for 1 ore"
    public var text: String
    public var canTrade: Bool
}

public struct TradeSection: Equatable, Sendable {
    public var offerGive: ResourceCounts
    public var offerWant: ResourceCounts
    public var target: Int?
    public var targets: [Seat]
    public var offerEnabled: Bool
    public var offerProblem: String?
    public var responses: [ResponseRow]
}

public struct BreakdownRow: Equatable, Sendable {
    public var label: String
    public var points: Int
}

public struct ConfettiBurst: Equatable, Sendable {
    public var delay: Double
    /// "centre", "bottom-left", "bottom-right"
    public var origin: String
    public var pieces: Int
}

public struct ConfettiSchedule: Equatable, Sendable {
    public var bursts: [ConfettiBurst]
}

public enum VictoryAnimation: Equatable, Sendable {
    case full, reduced
}

public struct VictoryCard: Equatable, Sendable {
    /// "Victory" or "Preview"
    public var title: String
    /// "Crimson wins"
    public var winner: String
    public var seat: Seat
    public var subtitle: String
    public var breakdown: [BreakdownRow]
    public var total: Int
    /// "Crimson rules the isles with 10 points."
    public var banner: String
    public var buttons: [String]
    public var confetti: ConfettiSchedule?
}

/// The tabs under the turn buttons, in the order they are shown.
public enum PanelTab: String, CaseIterable, Sendable {
    case trade = "Trade", cards = "Cards", players = "Players", log = "Log"
}

/// The blank screen shown while the device passes to a different human. Nothing else is drawn with it.
public struct Handover: Equatable, Sendable {
    public var player: Int
    public var seat: Seat
    /// "Pass the device to Cobalt"
    public var message: String
    /// "Start turn, Cobalt"
    public var button: String
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

    // Board intent
    public var glowingCorners: Set<Int>
    public var dashedEdges: Set<Int>
    public var selectableTiles: Set<Int>
    public var pulsingSettlements: Set<Int>
    public var hotNumbers: Set<Int>
    public var hitNumber: Int?
    public var stealTargets: [StealTarget]
    public var numberDiscBelowRobber: Bool
    public var desertLabelBelowRobber: Bool
    public var harbourRings: [Int: [Seat]]
    public var championCorners: Set<Int>

    // Sub-panels
    public var discardBox: DiscardBox?
    public var harbours: HarboursPanel
    public var bankTitle: String
    /// The give and get the bank row shows.
    public var bankChoice: TradeChoice
    /// What the bank's Give dropdown lists: the resources it can trade, or only the one shown when it can trade none.
    public var bankGiveOptions: [Resource]
    /// False when no bank trade is legal, whatever is picked.
    public var bankRowEnabled: Bool
    public var devCards: [DevCardRow]
    public var buyLabel: String
    public var tradeSection: TradeSection
    public var victory: VictoryCard?
    public var victoryAnimation: VictoryAnimation
    /// Empty while the game asks the player for something; that request takes the tab area.
    public var enabledTabs: Set<PanelTab>
    /// When set, the app draws only this. The other fields keep their values so the rules can still read them.
    public var handover: Handover?

    /// Before any game exists.
    static func empty(board: Board) -> ScreenState {
        ScreenState(header: "", headerSeat: .crimson, status: "", dice: [Strings.dash, Strings.dash], handCounts: ResourceCounts(),
                    holdTitle: "", bank: .uniform(19), log: [], orderStrip: nil, orderStripNote: nil,
                    buttons: [Strings.newGame: true], buildLeft: [:], activeBuildMode: nil, deckCount: 25, acceptProblem: nil,
                    scoreboard: [], aiThinking: false, board: board, robberTile: board.desertTile,
                    glowingCorners: [], dashedEdges: [], selectableTiles: [], pulsingSettlements: [], hotNumbers: [6, 8], hitNumber: nil,
                    stealTargets: [], numberDiscBelowRobber: false, desertLabelBelowRobber: true, harbourRings: [:], championCorners: [],
                    discardBox: nil, harbours: HarboursPanel(emptyText: Strings.noHarbours, rows: []), bankTitle: Strings.bankTitle, bankChoice: TradeChoice.bankFallback, bankGiveOptions: [TradeChoice.bankFallback.give], bankRowEnabled: false,
                    devCards: [], buyLabel: Strings.buyCard(25), tradeSection: TradeSection(offerGive: ResourceCounts(), offerWant: ResourceCounts(), target: nil, targets: [], offerEnabled: false, offerProblem: nil, responses: []),
                    victory: nil, victoryAnimation: .full, enabledTabs: [.players, .log], handover: nil)
    }
}
