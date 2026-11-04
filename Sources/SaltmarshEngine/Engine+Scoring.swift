public struct PiecesLeft: Equatable, Sendable {
    public var settlements: Int
    public var cities: Int
    public var roads: Int
}

extension Engine {
    public static func piecesLeft(_ s: GameState, player p: Int) -> PiecesLeft {
        PiecesLeft(settlements: PieceLimit.settlements - s.settlements(of: p),
                   cities: PieceLimit.cities - s.cities(of: p),
                   roads: PieceLimit.roads - s.roads(of: p))
    }
}
