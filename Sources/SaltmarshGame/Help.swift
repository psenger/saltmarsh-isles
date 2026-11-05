import SaltmarshEngine

public struct HelpSection: Equatable, Sendable {
    public var title: String
    public var lines: [String]
}

/// The rules as the help screen tells them. Costs, limits and card names come from the engine.
public enum Help {
    /// "14 Knight, 5 Victory point, ...", in the order the cards are listed everywhere else.
    private static var deckList: String {
        DevCardType.allCases.map { "\(DevCardType.deckComposition[$0] ?? 0) \($0.displayName)" }.joined(separator: ", ")
    }

    public static let sections: [HelpSection] = [
        HelpSection(title: "The goal", lines: [
            "First to 10 points on their own turn takes the isles.",
            "A settlement is worth 1 point and a city 2. Longest road and largest army are worth 2 each.",
            "Each \(DevCardType.victoryPoint.displayName) card is worth 1, and stays hidden until you win.",
        ]),
        HelpSection(title: "Getting started", lines: [
            "Everyone rolls to see who goes first. Ties roll again.",
            "Each player places two settlements, with a road beside each, going round the table and then back the other way.",
            "Your second settlement pays you a card from every tile touching it.",
        ]),
        HelpSection(title: "Your turn", lines: [
            "Roll the dice. Every tile showing that number pays the buildings on its corners: 1 card per settlement, 2 per city.",
            "Then build, trade and buy cards as much as you can afford, in any order.",
            "End your turn when you're done. A Knight can be played before you roll. Everything else waits for the dice.",
        ]),
        HelpSection(title: "Reading the board", lines: [
            "The dots under a number show how often it rolls. More dots, more cards.",
            "The red 6s and 8s roll most of all.",
        ]),
        HelpSection(title: "Building", lines: [
            "Road: \(Cost.road.description). It must touch your own road or building, and can't run through an opponent's building.",
            "Settlement: \(Cost.settlement.description). It must touch your own road, and no building can sit on a corner next door.",
            "City: \(Cost.city.description). It upgrades one of your settlements and gives you that settlement piece back.",
            "You only get \(PieceLimit.roads) roads, \(PieceLimit.settlements) settlements and \(PieceLimit.cities) cities. When a button says 0 left, you're out.",
        ]),
        HelpSection(title: "Oh NO! A 7", lines: [
            "Nobody gets paid when a 7 is rolled.",
            "Anyone holding more than 7 cards gives up half, rounded down, and picks which ones.",
            "The roller then moves the robber to another tile and steals a random card from someone with a building there.",
            "The robber's tile pays nothing until the robber moves on.",
        ]),
        HelpSection(title: "Trading", lines: [
            "You can trade on your own turn, after you roll.",
            "Bank: 4 of one resource for 1 of any other. The bank holds 19 of each, and a shortage can stop it paying out.",
            "Harbours: put a building on a corner joined to a harbour by a jetty. A 3:1 harbour trades any resource at 3 for 1, and a 2:1 harbour trades its own resource at 2 for 1.",
            "Players: offer any mix of cards to everyone or to one player, and see who bites.",
        ]),
        HelpSection(title: "Development cards", lines: [
            "Buy one with the Card button, after you roll. It costs \(Cost.devCard.description), you draw it at random, and the game tells you what you got.",
            "The deck holds \(DevCardType.deckComposition.values.reduce(0, +)) cards: \(deckList). When it runs out, there's nothing left to buy.",
            "To play a card, open the Cards tab and tap Play beside it.",
        ]),
        HelpSection(title: "The cards", lines: [
            "\(DevCardType.knight.displayName): tap Play, tap another tile to move the robber there, then steal a card from someone with a building on it. It counts toward largest army.",
            "\(DevCardType.victoryPoint.displayName): nothing to play. It's worth 1 point from the moment you draw it, and stays hidden until you win.",
            "\(DevCardType.roadCrew.displayName): tap Play, then tap 2 dashed edges for free roads. The usual road rules apply, and it ends early if you run out of road pieces or edges.",
            "\(DevCardType.bumperHarvest.displayName): tap Play and choose 2 cards to take from the bank. The same resource twice is fine, and only what the bank can pay is offered.",
            "\(DevCardType.cornerMarket.displayName): tap Play and name a resource. Every other player hands over all of theirs.",
        ]),
        HelpSection(title: "Card restrictions", lines: [
            "You can play only 1 card per turn.",
            "You can't play a card on the turn you bought it.",
            "A \(DevCardType.knight.displayName) can be played before or after you roll. Every other card has to wait for the roll.",
            "\(DevCardType.victoryPoint.displayName) cards are never played, so they don't use up your 1 card.",
            "If a Play button is grey, the note beside the card usually says why.",
        ]),
        HelpSection(title: "Awards", lines: [
            "Longest road: the first connected road of 5 or more earns 2 points. Someone else has to beat it, not tie it, to take the award.",
            "A branch only counts one path, and a road stops counting at an opponent's building.",
            "Largest army: the first to play 3 Knights earns 2 points. Someone else has to play more to take it.",
        ]),
    ]
}
