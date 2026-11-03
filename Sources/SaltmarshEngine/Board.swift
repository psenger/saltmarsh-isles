public struct Point: Codable, Hashable, Sendable {
    public var x: Double
    public var y: Double
}

public struct Tile: Codable, Hashable, Sendable {
    public var center: Point
    public var terrain: Terrain
    public var number: Int?
    /// Six corner indices; corner i sits at angle 60·i − 30°.
    public var corners: [Int]
    /// Six edge indices; edge i joins corners i and i+1.
    public var edges: [Int]
    public var neighbours: [Int]
    public var resource: Resource? { terrain.resource }
    public var pips: Int { number.map(Board.pips) ?? 0 }
}

public struct Corner: Codable, Hashable, Sendable {
    public var point: Point
    public var tiles: [Int]
    public var adjacent: [Int]
    public var edges: [Int]
    public var owner: Int?
    public var isCity: Bool
}

public struct Edge: Codable, Hashable, Sendable {
    public var a: Int
    public var b: Int
    public var tiles: [Int]
    public var owner: Int?
    public var isCoastal: Bool { tiles.count == 1 }
    public func other(_ corner: Int) -> Int { corner == a ? b : a }
}

public struct Harbour: Codable, Hashable, Sendable {
    public enum Kind: Codable, Hashable, Sendable { case any, specific(Resource) }
    public var kind: Kind
    public var ratio: Int
    public var a: Int
    public var b: Int
    public var edge: Int
    public var position: Point
}

public struct Board: Codable, Hashable, Sendable {
    public var tiles: [Tile]
    public var corners: [Corner]
    public var edges: [Edge]
    public var harbours: [Harbour]
    public var desertTile: Int

    public static let hexSize = 58.0
    public static let size = (width: 680.0, height: 600.0)
    public static let seaRadius = 335.0

    public static func pips(_ n: Int) -> Int { 6 - abs(7 - n) }

    public func edgeIndex(between a: Int, _ b: Int) -> Int? {
        corners[a].edges.first { edges[$0].other(a) == b }
    }

    public func edges(at corner: Int) -> [Int] { corners[corner].edges }
}
