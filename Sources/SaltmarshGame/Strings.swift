import SaltmarshEngine

/// Every status, header and button string the panel shows, in one place. The wording is the
/// feature file's, word for word.
enum Strings {
    // Status line
    static let rollForFirst = "Roll for first player."
    static let setupCorner = "Tap a glowing corner to place a settlement."
    static let setupRoad = "Tap a dashed edge next to it to lay a road."
    static let awaitingRoll = "Roll the dice to start your turn."
    static let main = "Build, trade, or end your turn."
    static let roadMode = "Tap a dashed edge to build a road."
    static let settlementMode = "Tap a glowing corner to build a settlement."
    static let cityMode = "Tap one of your settlements to upgrade it."
    static let robber = "Tap a tile to move the robber there."
    static let victim = "Steal a card: tap a glowing building on the robber's tile, or a name below."
    static let answersIn = "Answers are in. Trade with someone or withdraw."
    static let gameOver = "Game over."
    static func discarding(roller: String, name: String) -> String {
        "\(roller) rolled 7. \(name) has more than 7 cards and must give up half. Pass the device to \(name)."
    }
    static func freeRoads(_ left: Int) -> String { "Road crew: tap a dashed edge for a free road (\(left) left)." }
    static func offer(from proposer: String, _ offer: TradeOffer) -> String { "\(proposer) offers \(offer.description)." }
    static func thinking(_ name: String) -> String { "\(name) is thinking…" }
    static func cannotPay(_ want: ResourceCounts) -> String { "You don't have \(want)" }

    // Header suffixes
    static func header(_ name: String, _ suffix: String?) -> String { suffix.map { "\(name) · \($0)" } ?? name }
    static let firstRoll = "first roll", setup = "setup", discardingSuffix = "discarding", tradeOffer = "trade offer"

    // Buttons
    static let rollForFirstButton = "Roll for first", rollDice = "Roll dice", road = "Road", settlement = "Settlement", city = "City"
    static let endTurn = "End turn", buyCard = "Buy a card", bankTrade = "Trade 4 for 1", offerButton = "Offer", withdraw = "Withdraw"
    static let accept = "Accept", decline = "Decline", newGame = "New game", previewWin = "Preview win"
    static let seeTheBoard = "See the board", backToTheGame = "Back to the game"
    static func discard(_ n: Int) -> String { "Discard \(n) cards" }

    // Panel labels
    static func hold(_ name: String) -> String { "\(name)'s hold" }
    static let reverseOrder = "Round 2: reverse order"
    static let dash = "–"
    static let noHarbours = "None yet. Build a settlement on a corner joined to a harbour by a jetty."
    static let bankTitle = "Trade with bank, 4 for 1"
    static func buyCard(_ left: Int) -> String { "Buy a card (\(left) left)" }
    static func harbourTitle(_ h: Harbour) -> String {
        switch h.kind {
        case .any: "3:1 any"
        case .specific(let r): "2:1 \(r.rawValue)"
        }
    }
    static func harbourTrade(_ ratio: Int) -> String { "Trade \(ratio) for 1" }

    // Discard box
    static func discardTitle(_ name: String, _ n: Int) -> String { "\(name), pick \(n) cards to give up" }
    static func discardCounter(_ picked: Int, _ n: Int) -> String { "\(picked) / \(n)" }
    static func discardRow(_ picked: Int, _ held: Int) -> String { "\(picked) of \(held)" }
    static func next(_ name: String) -> String { "Next: \(name)" }

    // Development card notes
    static let boughtThisTurn = "bought this turn", oneCardPerTurn = "one card per turn", countsAutomatically = "counts automatically"

    // Trade responses
    static let pending = "pending", accepted = "accepted", declined = "declined"
    static func countered(_ counter: TradeOffer) -> String { "countered: \(counter.description)" }

    // Victory card
    static let victory = "Victory", preview = "Preview"
    static func wins(_ name: String) -> String { "\(name) wins" }
    static func rounds(_ n: Int) -> String { "Rules the isles after \(n) rounds." }
    static let previewNote = "This is what the win screen looks like. The game carries on."
    static func banner(_ name: String, _ points: Int) -> String { "\(name) rules the isles with \(points) points." }
    static let settlements = "Settlements", cities = "Cities", longestRoad = "Longest road", largestArmy = "Largest army", victoryPointCards = "Victory point cards"
}
