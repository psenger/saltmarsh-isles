import Testing
@testable import SaltmarshEngine

@Suite struct BoardGeneratorTests {
    @Test func thousandBoardsAreFair() {
        for seed in 0..<1000 {
            var rng = SeededRNG(seed: UInt64(seed))
            let b = BoardGenerator.generate(using: &rng)
            #expect(BoardGenerator.violations(b).isEmpty, "seed \(seed): \(BoardGenerator.violations(b))")
        }
    }
    @Test func resourceAndNumberMix() {
        var rng = SeededRNG(seed: 11); let b = BoardGenerator.generate(using: &rng)
        let res = b.tiles.compactMap(\.resource)
        #expect(res.filter { $0 == .timber }.count == 4 && res.filter { $0 == .clay }.count == 3 && res.filter { $0 == .wool }.count == 4 && res.filter { $0 == .grain }.count == 4 && res.filter { $0 == .ore }.count == 3)
        #expect(b.tiles.compactMap(\.number).sorted() == [2,3,3,4,4,5,5,6,6,8,8,9,9,10,10,11,11,12])
        #expect(b.tiles[b.desertTile].number == nil && b.tiles[b.desertTile].terrain == .desert)
    }
    @Test func harbourLayout() {
        for seed in 0..<500 {
            var rng = SeededRNG(seed: UInt64(seed)); let b = BoardGenerator.generate(using: &rng)
            #expect(b.harbours.count == 9)
            #expect(b.harbours.filter { $0.kind == .any }.count == 4)
            for r in Resource.allCases { #expect(b.harbours.filter { $0.kind == .specific(r) && $0.ratio == 2 }.count == 1) }
            for h in b.harbours { #expect(b.edges[h.edge].isCoastal); #expect(Set([h.a, h.b]) == Set([b.edges[h.edge].a, b.edges[h.edge].b])) }
        }
    }
    @Test func violationsDetectsClusteredNumbers() {
        var rng = SeededRNG(seed: 1); var b = BoardGenerator.generate(using: &rng)
        let i = b.tiles.firstIndex { $0.number == 6 }!, j = b.tiles[i].neighbours.first { b.tiles[$0].number != nil }!
        b.tiles[j].number = 8
        #expect(!BoardGenerator.violations(b).isEmpty)
    }
    @Test func deterministicForSeed() {
        var r1 = SeededRNG(seed: 5), r2 = SeededRNG(seed: 5)
        #expect(BoardGenerator.generate(using: &r1) == BoardGenerator.generate(using: &r2))
    }
}
