import Foundation
import Testing
@testable import SaltmarshEngine

@Suite struct ResourceTests {
    @Test func countsArithmetic() {
        let a: ResourceCounts = [.timber: 3, .clay: 1], b: ResourceCounts = [.timber: 1]
        #expect((a + b)[.timber] == 4)
        #expect((a - b) == [.timber: 2, .clay: 1])
        #expect(a.total == 4); #expect(a.contains(b)); #expect(!b.contains(a))
        #expect(ResourceCounts().isEmpty); #expect(ResourceCounts.uniform(19)[.ore] == 19)
    }
    @Test func zeroEqualsMissing() { #expect(ResourceCounts([.wool: 0]) == ResourceCounts()) }
    @Test func descriptionOrderAndFormat() {
        #expect(ResourceCounts([.clay: 1, .timber: 3]).description == "3 timber, 1 clay")
        #expect(ResourceCounts().description == "nothing")
    }
    @Test func codableRoundTrip() throws {
        let a: ResourceCounts = [.grain: 2, .ore: 3]
        #expect(try JSONDecoder().decode(ResourceCounts.self, from: JSONEncoder().encode(a)) == a)
    }
    @Test func deckComposition() { #expect(DevCardType.deckComposition.values.reduce(0, +) == 25) }
    @Test func seatsAndColours() {
        #expect(Seat.allCases.map(\.name) == ["Crimson", "Cobalt", "Amber", "Ivory"])
        #expect(Seat.cobalt.colorHex == "#2a5db0")
    }
    @Test func costs() { #expect(Cost.city == [.grain: 2, .ore: 3]); #expect(Cost.devCard.total == 3) }
}
