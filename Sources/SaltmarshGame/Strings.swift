import SaltmarshEngine
import SaltmarshAI

/// Every status, header and button string the panel shows, in one place. The wording is the
/// feature file's, word for word.
public enum Strings {
    // Status line
    public static let rollForFirst = "Who sails first? Roll for it!"
    public static let setupCorner = "Stake your claim! Tap a glowing corner to settle."
    public static let setupRoad = "Now a road! Tap a dashed edge next to your settlement."
    public static let awaitingRoll = "Your move, captain. Roll the dice!"
    public static let main = "The isles are yours! Build, trade, or end your turn."
    public static let roadMode = "Pave the way! Tap a dashed edge to build a road."
    public static let settlementMode = "New home! Tap a glowing corner to build a settlement."
    public static let cityMode = "Go big! Tap one of your settlements to make it a city."
    public static let robber = "Send in the robber! Tap a tile to move it there."
    public static let victim = "Pick a pocket! Tap a glowing building on the robber's tile, or a name below."
    public static let answersIn = "The answers are in! Trade with someone or withdraw."
    public static let gameOver = "That's the game!"
    public static func discarding(roller: String, name: String) -> String {
        "\(roller) rolled a 7! \(name) has more than 7 cards and must give up half."
    }
    public static func freeRoads(_ left: Int) -> String { "Road crew on the job! Tap a dashed edge for a free road (\(left) left)." }
    /// The proposer's side, in the words of the offer builder's Give and Want: "Crimson gives 2 timber and wants 1 ore."
    public static func offer(from proposer: String, _ offer: TradeOffer) -> String { "\(proposer) gives \(offer.give) and wants \(offer.want)." }
    /// The same offer from the responder's side: "You give 1 ore and get 2 timber."
    public static func offerTerms(_ offer: TradeOffer) -> String { "You give \(offer.want) and get \(offer.give)." }
    public static func thinking(_ name: String) -> String { "\(name) is plotting…" }
    /// A searching seat's log line: "Amber weighed 4 moves over 32 guessed hands (128 playouts, 0.6 s) and stuck with its first instinct."
    public static func thought(_ name: String, _ t: Thought) -> String {
        let tenths = Int((t.seconds * 10).rounded())
        let time = "\(tenths / 10).\(tenths % 10) s" + (t.outOfTime ? ", out of time" : "")
        let verdict = t.changedMind ? "changed its mind" : "stuck with its first instinct"
        return "\(name) weighed \(t.moves) moves over \(t.hands) guessed hands (\(t.playouts) playouts, \(time)) and \(verdict)."
    }
    public static func cannotPay(_ want: ResourceCounts) -> String { "You don't have \(want)" }

    // Header suffixes
    public static func header(_ name: String, _ suffix: String?) -> String { suffix.map { "\(name) · \($0)" } ?? name }
    public static let firstRoll = "first roll", setup = "setup", discardingSuffix = "discarding", tradeOffer = "trade offer"

    // Buttons
    public static let rollForFirstButton = "Roll for first", rollDice = "Roll dice", road = "Road", settlement = "Settlement", city = "City"
    public static let endTurn = "End turn", buyCard = "Buy a card", bankTrade = "Trade 4 for 1", offerButton = "Offer", withdraw = "Withdraw"
    public static let accept = "Accept", decline = "Decline", newGame = "New game", previewWin = "Preview win", previewLose = "Preview lose"
    // The game menu, which is the File menu on Mac and the Game button on iPhone and iPad.
    public static let gameMenu = "Game", newGameMenu = "New Game…", loadGame = "Load Game…", saveGame = "Save Game…", howToPlay = "How to Play"
    // Saved games
    public static let saveTitle = "Save Game", loadTitle = "Load Game", saveName = "Name", saveButton = "Save", loadButton = "Load", replaceButton = "Replace", deleteButton = "Delete", cancel = "Cancel"
    public static let setAsideNote = "The last game was set aside after a crash. Its save is kept for a replay."
    public static let noSavedGames = "No saved games yet.", savesFull = "All 5 saves are used. Tap one to replace it, or delete one to make room."
    public static let savedGamesHeading = "Saved games", tapToReplace = "Tap a save to replace it."
    public static let loadWarning = "This replaces the game you're playing.", replaceWarning = "The saved game will be overwritten.", deleteWarning = "This can't be undone."
    public static func replacePrompt(_ name: String) -> String { "Replace \"\(name)\"?" }
    public static func deletePrompt(_ name: String) -> String { "Delete \"\(name)\"?" }
    public static func loadPrompt(_ name: String) -> String { "Load \"\(name)\"?" }
    public static func suggestedSaveName(turn: Int) -> String { "Turn \(turn)" }
    public static let seeTheBoard = "See the board", backToTheGame = "Back to the game"
    public static func discard(_ n: Int) -> String { "Discard \(n) cards" }
    public static func stealFrom(_ name: String) -> String { "Steal from \(name)" }
    public static func tradeWith(_ name: String) -> String { "Trade with \(name)" }

    // Handing the device to another human
    public static func passDevice(_ name: String) -> String { "Eyes off! Pass the device to \(name)" }
    public static func startTurn(_ name: String) -> String { "Start turn, \(name)" }
    public static func handoverDiscard(_ name: String) -> String { "Discard, \(name)" }
    public static func seeOffer(_ name: String) -> String { "See the offer, \(name)" }
    public static func continueTurn(_ name: String) -> String { "Continue, \(name)" }

    // Panel labels
    public static let offerToPlayers = "Offer a trade to players…", back = "Back"
    public static let rollBeforeOffering = "Not so fast! Roll the dice before offering a trade."
    public static func hold(_ name: String) -> String { "\(name)'s hold" }
    public static let reverseOrder = "Round 2: back the other way!"
    public static let dash = "–"
    public static func cardCount(_ n: Int) -> String { "\(n) cards" }
    public static func piecesLeft(_ n: Int) -> String { "\(n) left" }
    public static let noHarbours = "None yet. Build a settlement on a corner joined to a harbour by a jetty."
    public static let bankTitle = "Trade with bank, 4 for 1"
    public static func harbourTitle(_ h: Harbour) -> String {
        switch h.kind {
        case .any: "3:1 any"
        case .specific(let r): "2:1 \(r.rawValue)"
        }
    }
    public static func harbourTrade(_ ratio: Int) -> String { "Trade \(ratio) for 1" }

    // Discard box
    public static func discardTitle(_ name: String, _ n: Int) -> String { "Oh NO! \(name), the robber needs \(n) cards from your deck" }
    public static func discardCounter(_ picked: Int, _ n: Int) -> String { "\(picked) / \(n)" }
    public static func discardRow(_ picked: Int, _ held: Int) -> String { "\(picked) of \(held)" }
    public static func next(_ name: String) -> String { "Next: \(name)" }

    // The new game sheet and the Log tab
    public static let turnOnLogs = "Turn on logs", copyLog = "Copy log"

    // The Cards tab
    public static let played = "Played", oneCardPerTurnHint = "1 card per turn", plusOnePoint = "+1 point", ready = "ready"
    public static func inYourHand(_ n: Int) -> String { "In your hand (\(n))" }
    public static func playedPill(_ type: DevCardType, _ count: Int) -> String { count > 1 ? "\(type.displayName) \u{00D7}\(count)" : type.displayName }
    public static func cardText(_ type: DevCardType) -> String {
        switch type {
        case .knight: "Move the robber and steal a card from someone with a building there. Counts toward largest army."
        case .roadCrew: "Build 2 roads for free. The usual road rules apply."
        case .bumperHarvest: "Take any 2 cards from the bank. The same resource twice is fine."
        case .cornerMarket: "Name a resource. Every other player hands over all of theirs."
        case .victoryPoint: "Worth 1 point from the moment you drew it. Hidden from everyone until you win."
        }
    }

    // Development card notes
    public static let boughtThisTurn = "bought this turn", oneCardPerTurn = "one card per turn", countsAutomatically = "counts automatically", rollFirst = "roll first"
    public static func youDrew(_ card: String) -> String { "You drew: \(card)!" }
    public static func drawnCardText(_ type: DevCardType) -> String {
        switch type {
        case .knight: "Play it on a later turn to move the robber and steal a card. It counts toward largest army."
        case .victoryPoint: "Worth 1 point straight away, and hidden from everyone else until you win."
        case .roadCrew: "Play it on a later turn to build 2 roads for free."
        case .bumperHarvest: "Play it on a later turn to take any 2 cards from the bank."
        case .cornerMarket: "Play it on a later turn, name a resource, and every other player gives you all of theirs."
        }
    }

    // The Cards tab and the card button
    public static let card = "Card", noCardsYet = "Nothing up your sleeve yet.", victoryPoints = "Victory points"
    public static func pointsOfTen(_ n: Int) -> String { "\(n) / 10" }
    public static func knightsPlayed(_ n: Int) -> String { "Knights played: \(n)" }

    // Trade responses
    public static let pending = "pending", accepted = "accepted", declined = "declined"
    public static func countered(_ counter: TradeOffer) -> String { "countered: \(counter.description)" }

    // Victory card
    public static let victory = "Victory", preview = "Preview", defeat = "Defeat"
    public static func defeated(_ name: String, rounds n: Int) -> String { "\(name) takes the isles after \(n) rounds." }
    public static let betterLuck = "Better luck next time, captain."
    public static let previewDefeatNote = "This is what losing looks like. The game carries on."
    public static func wins(_ name: String) -> String { "\(name) wins" }
    public static func rounds(_ n: Int) -> String { "Rules the isles after \(n) rounds." }
    public static let previewNote = "This is what the win screen looks like. The game carries on."
    public static func banner(_ name: String, _ points: Int) -> String { "\(name) rules the isles with \(points) points." }
    public static let settlements = "Settlements", cities = "Cities", longestRoad = "Longest road", largestArmy = "Largest army", victoryPointCards = "Victory point cards"
}
