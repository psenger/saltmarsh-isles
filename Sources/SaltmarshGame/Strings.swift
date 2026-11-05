import SaltmarshEngine

/// Every status, header and button string the panel shows, in one place. The wording is the
/// feature file's, word for word.
public enum Strings {
    // Status line
    public static let rollForFirst = "Roll for first player."
    public static let setupCorner = "Tap a glowing corner to place a settlement."
    public static let setupRoad = "Tap a dashed edge next to it to lay a road."
    public static let awaitingRoll = "Roll the dice to start your turn."
    public static let main = "Build, trade, or end your turn."
    public static let roadMode = "Tap a dashed edge to build a road."
    public static let settlementMode = "Tap a glowing corner to build a settlement."
    public static let cityMode = "Tap one of your settlements to upgrade it."
    public static let robber = "Tap a tile to move the robber there."
    public static let victim = "Steal a card: tap a glowing building on the robber's tile, or a name below."
    public static let answersIn = "Answers are in. Trade with someone or withdraw."
    public static let gameOver = "Game over."
    public static func discarding(roller: String, name: String) -> String {
        "\(roller) rolled 7. \(name) has more than 7 cards and must give up half."
    }
    public static func freeRoads(_ left: Int) -> String { "Road crew: tap a dashed edge for a free road (\(left) left)." }
    public static func offer(from proposer: String, _ offer: TradeOffer) -> String { "\(proposer) offers \(offer.description)." }
    public static func thinking(_ name: String) -> String { "\(name) is thinking…" }
    public static func cannotPay(_ want: ResourceCounts) -> String { "You don't have \(want)" }

    // Header suffixes
    public static func header(_ name: String, _ suffix: String?) -> String { suffix.map { "\(name) · \($0)" } ?? name }
    public static let firstRoll = "first roll", setup = "setup", discardingSuffix = "discarding", tradeOffer = "trade offer"

    // Buttons
    public static let rollForFirstButton = "Roll for first", rollDice = "Roll dice", road = "Road", settlement = "Settlement", city = "City"
    public static let endTurn = "End turn", buyCard = "Buy a card", bankTrade = "Trade 4 for 1", offerButton = "Offer", withdraw = "Withdraw"
    public static let accept = "Accept", decline = "Decline", newGame = "New game", previewWin = "Preview win"
    public static let seeTheBoard = "See the board", backToTheGame = "Back to the game"
    public static func discard(_ n: Int) -> String { "Discard \(n) cards" }
    public static func stealFrom(_ name: String) -> String { "Steal from \(name)" }
    public static func tradeWith(_ name: String) -> String { "Trade with \(name)" }

    // Handing the device to another human
    public static func passDevice(_ name: String) -> String { "Pass the device to \(name)" }
    public static func startTurn(_ name: String) -> String { "Start turn, \(name)" }
    public static func handoverDiscard(_ name: String) -> String { "Discard, \(name)" }
    public static func seeOffer(_ name: String) -> String { "See the offer, \(name)" }
    public static func continueTurn(_ name: String) -> String { "Continue, \(name)" }

    // Panel labels
    public static let offerToPlayers = "Offer a trade to players…", back = "Back"
    public static let rollBeforeOffering = "Roll the dice before offering a trade."
    public static func hold(_ name: String) -> String { "\(name)'s hold" }
    public static let reverseOrder = "Round 2: reverse order"
    public static let dash = "–"
    public static func cardCount(_ n: Int) -> String { "\(n) cards" }
    public static func piecesLeft(_ n: Int) -> String { "\(n) left" }
    public static let noHarbours = "None yet. Build a settlement on a corner joined to a harbour by a jetty."
    public static let bankTitle = "Trade with bank, 4 for 1"
    public static func buyCard(_ left: Int) -> String { "Buy a card (\(left) left)" }
    public static func harbourTitle(_ h: Harbour) -> String {
        switch h.kind {
        case .any: "3:1 any"
        case .specific(let r): "2:1 \(r.rawValue)"
        }
    }
    public static func harbourTrade(_ ratio: Int) -> String { "Trade \(ratio) for 1" }

    // Discard box
    public static func discardTitle(_ name: String, _ n: Int) -> String { "\(name), pick \(n) cards to give up" }
    public static func discardCounter(_ picked: Int, _ n: Int) -> String { "\(picked) / \(n)" }
    public static func discardRow(_ picked: Int, _ held: Int) -> String { "\(picked) of \(held)" }
    public static func next(_ name: String) -> String { "Next: \(name)" }

    // Development card notes
    public static let boughtThisTurn = "bought this turn", oneCardPerTurn = "one card per turn", countsAutomatically = "counts automatically"

    // Trade responses
    public static let pending = "pending", accepted = "accepted", declined = "declined"
    public static func countered(_ counter: TradeOffer) -> String { "countered: \(counter.description)" }

    // Victory card
    public static let victory = "Victory", preview = "Preview"
    public static func wins(_ name: String) -> String { "\(name) wins" }
    public static func rounds(_ n: Int) -> String { "Rules the isles after \(n) rounds." }
    public static let previewNote = "This is what the win screen looks like. The game carries on."
    public static func banner(_ name: String, _ points: Int) -> String { "\(name) rules the isles with \(points) points." }
    public static let settlements = "Settlements", cities = "Cities", longestRoad = "Longest road", largestArmy = "Largest army", victoryPointCards = "Victory point cards"
}
