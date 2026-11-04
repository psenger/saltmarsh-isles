extension Engine {
    /// A corner can take a settlement when it is unowned, no neighbouring corner has a building,
    /// and (outside setup) one of the player's roads touches it.
    public static func canSettle(_ s: GameState, corner c: Int, player p: Int, setup: Bool) -> Bool {
        let corner = s.board.corners[c]
        guard corner.owner == nil else { return false }
        guard corner.adjacent.allSatisfy({ s.board.corners[$0].owner == nil }) else { return false }
        if setup { return true }
        return corner.edges.contains { s.board.edges[$0].owner == p }
    }

    /// An edge can take a road when it is unowned and connects to the player's network:
    /// during setup it must touch the settlement just placed; in play one end holds the player's
    /// building, or is an empty corner where another of the player's roads ends. An opponent's
    /// building at an end blocks continuing from that end.
    public static func canRoad(_ s: GameState, edge e: Int, player p: Int) -> Bool {
        let edge = s.board.edges[e]
        guard edge.owner == nil else { return false }
        if case .setup(_, true, let last?) = s.phase {
            return edge.a == last || edge.b == last
        }
        return [edge.a, edge.b].contains { end in
            let corner = s.board.corners[end]
            if corner.owner == p { return true }
            if corner.owner != nil { return false }
            return corner.edges.contains { $0 != e && s.board.edges[$0].owner == p }
        }
    }
}
