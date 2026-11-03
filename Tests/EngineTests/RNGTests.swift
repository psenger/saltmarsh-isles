import Foundation
import Testing
@testable import SaltmarshEngine

@Suite struct RNGTests {
    @Test func sameSeedSameSequence() {
        var a = SeededRNG(seed: 42), b = SeededRNG(seed: 42)
        #expect((0..<8).map { _ in a.next() } == (0..<8).map { _ in b.next() })
    }
    @Test func differentSeedsDiffer() {
        var a = SeededRNG(seed: 1), b = SeededRNG(seed: 2)
        #expect(a.next() != b.next())
    }
    @Test func codableRoundTripContinuesSequence() throws {
        var a = SeededRNG(seed: 7); _ = a.next()
        var b = try JSONDecoder().decode(SeededRNG.self, from: JSONEncoder().encode(a))
        #expect(a.next() == b.next())
    }
    @Test func d6InRange() {
        var r = SeededRNG(seed: 3)
        for _ in 0..<1000 { #expect((1...6).contains(r.d6())) }
    }
}
