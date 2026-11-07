/// The names the game log uses for board elements. They are the model's own indices, which are the same in
/// every game because the geometry never changes; `BoardGenerator.layout()` documents how each index is
/// assigned, so an ID can be turned into a position, or a position into an ID, from that comment alone.
///
/// - `H7`: hex 7 (`tiles[7]`). The desert is always `H9`.
/// - `V12`: vertex 12 (`corners[12]`).
/// - `E14-15`: the edge joining vertices 14 and 15, smaller number first. Edges have indices too (`edges[e]`),
///   but the pair is self-describing, and `edgeIndex(ofID:)` maps it back.
/// - `PORT 14-15`: the harbour sitting on edge `E14-15`.
extension Board {
    public func hexID(_ tile: Int) -> String { "H\(tile)" }

    public func vertexID(_ corner: Int) -> String { "V\(corner)" }

    public func edgeID(_ edge: Int) -> String {
        let e = edges[edge]
        return "E\(min(e.a, e.b))-\(max(e.a, e.b))"
    }

    public func portID(_ harbour: Int) -> String {
        let h = harbours[harbour]
        return "PORT \(min(h.a, h.b))-\(max(h.a, h.b))"
    }

    /// The edge for "E14-15" or "14-15"; nil when the two vertices are not joined.
    public func edgeIndex(ofID id: String) -> Int? {
        let body = id.hasPrefix("E") ? String(id.dropFirst()) : id
        let ends = body.split(separator: "-").compactMap { Int($0) }
        guard ends.count == 2, ends.allSatisfy(corners.indices.contains) else { return nil }
        return edgeIndex(between: ends[0], ends[1])
    }

    /// The harbour for "PORT 14-15" or "14-15"; nil when no harbour sits on that edge.
    public func harbourIndex(ofID id: String) -> Int? {
        let body = id.hasPrefix("PORT ") ? String(id.dropFirst(5)) : id
        guard let edge = edgeIndex(ofID: body) else { return nil }
        return harbours.firstIndex { $0.edge == edge }
    }
}
