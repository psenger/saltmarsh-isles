import Foundation
import Testing
@testable import SaltmarshEngine

@Suite struct BoardGeometryTests {
    let b = BoardGenerator.layout()
    @Test func counts() {
        #expect(b.tiles.count == 19); #expect(b.corners.count == 54); #expect(b.edges.count == 72)
        #expect(b.edges.filter(\.isCoastal).count == 30)
    }
    @Test func desertAtCentre() {
        let d = b.tiles[b.desertTile]
        #expect(abs(d.center.x) < 0.001 && abs(d.center.y) < 0.001)
    }
    @Test func cornersTouchOneToThreeTiles() { for c in b.corners { #expect((1...3).contains(c.tiles.count)) } }
    @Test func edgesTouchOneOrTwoTiles() { for e in b.edges { #expect((1...2).contains(e.tiles.count)) } }
    @Test func neighboursShareTwoCorners() {
        for (i, t) in b.tiles.enumerated() { for j in t.neighbours {
            #expect(Set(t.corners).intersection(b.tiles[j].corners).count == 2); #expect(b.tiles[j].neighbours.contains(i)) } }
        #expect(b.tiles[b.desertTile].neighbours.count == 6)
    }
    @Test func cornerAdjacencyMatchesEdges() {
        for (ci, c) in b.corners.enumerated() {
            #expect(Set(c.adjacent) == Set(c.edges.map { b.edges[$0].other(ci) }))
        }
    }
    @Test func pips() { #expect(Board.pips(6) == 5); #expect(Board.pips(2) == 1); #expect(Board.pips(12) == 1); #expect(Board.pips(7) == 6) }
    @Test func hexSizeGeometry() {
        let t = b.tiles[b.desertTile], c0 = b.corners[t.corners[0]]
        #expect(abs(hypot(c0.point.x, c0.point.y) - 58) < 0.01)
    }
}
