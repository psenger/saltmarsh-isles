import Testing
import SaltmarshEngine
@testable import SaltmarshGame

/// The help quotes the real rules, so it cannot drift from them.
@Suite struct HelpTests {
    var text: String { Help.sections.flatMap { [$0.title] + $0.lines }.joined(separator: "\n") }

    @Test func everySectionSaysSomething() {
        #expect(!Help.sections.isEmpty)
        #expect(Help.sections.allSatisfy { !$0.title.isEmpty && !$0.lines.isEmpty })
    }
    @Test func itQuotesEveryCost() {
        for cost in [Cost.road, Cost.settlement, Cost.city, Cost.devCard] { #expect(text.contains(cost.description)) }
    }
    @Test func itQuotesThePieceLimits() {
        #expect(text.contains("\(PieceLimit.settlements) settlements"))
        #expect(text.contains("\(PieceLimit.cities) cities"))
        #expect(text.contains("\(PieceLimit.roads) roads"))
    }
    @Test func itNamesEveryDevelopmentCard() {
        for card in DevCardType.allCases { #expect(text.contains(card.displayName)) }
    }
    @Test func itSaysHowManyOfEachCardAreInTheDeck() {
        for card in DevCardType.allCases { #expect(text.contains("\(DevCardType.deckComposition[card]!) \(card.displayName)")) }
    }
    @Test func itStatesTheCardRestrictions() {
        #expect(text.contains("only 1 card per turn"))
        #expect(text.contains("on the turn you bought it"))
        #expect(text.contains("before or after you roll"))
    }
}
