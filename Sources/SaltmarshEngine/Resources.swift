public enum Resource: String, CaseIterable, Codable, Hashable, Sendable, Comparable {
    case timber, clay, wool, grain, ore

    public static func < (a: Resource, b: Resource) -> Bool {
        allCases.firstIndex(of: a)! < allCases.firstIndex(of: b)!
    }
}

public struct ResourceCounts: Codable, Equatable, Hashable, Sendable, CustomStringConvertible, ExpressibleByDictionaryLiteral {
    private var counts: [Int]

    public init() { counts = Array(repeating: 0, count: Resource.allCases.count) }

    public init(_ dict: [Resource: Int]) {
        self.init()
        for (r, n) in dict { self[r] = n }
    }

    public init(dictionaryLiteral elements: (Resource, Int)...) {
        self.init()
        for (r, n) in elements { self[r] += n }
    }

    public static func uniform(_ n: Int) -> ResourceCounts {
        var c = ResourceCounts()
        for r in Resource.allCases { c[r] = n }
        return c
    }

    public subscript(_ r: Resource) -> Int {
        get { counts[Resource.allCases.firstIndex(of: r)!] }
        set { counts[Resource.allCases.firstIndex(of: r)!] = newValue }
    }

    public var total: Int { counts.reduce(0, +) }
    public var isEmpty: Bool { total == 0 }
    public var hasNegative: Bool { counts.contains { $0 < 0 } }

    public func contains(_ other: ResourceCounts) -> Bool {
        Resource.allCases.allSatisfy { self[$0] >= other[$0] }
    }

    public static func + (a: ResourceCounts, b: ResourceCounts) -> ResourceCounts {
        var c = a
        for r in Resource.allCases { c[r] += b[r] }
        return c
    }

    public static func - (a: ResourceCounts, b: ResourceCounts) -> ResourceCounts {
        var c = a
        for r in Resource.allCases { c[r] -= b[r] }
        return c
    }

    public var nonZero: [(Resource, Int)] {
        Resource.allCases.compactMap { self[$0] != 0 ? ($0, self[$0]) : nil }
    }

    public var description: String {
        isEmpty ? "nothing" : nonZero.map { "\($0.1) \($0.0.rawValue)" }.joined(separator: ", ")
    }
}

public enum Terrain: Codable, Hashable, Sendable {
    case land(Resource), desert

    public var resource: Resource? {
        if case .land(let r) = self { return r }
        return nil
    }
}

public enum DevCardType: String, CaseIterable, Codable, Hashable, Sendable {
    case knight, victoryPoint, roadCrew, bumperHarvest, cornerMarket

    public var displayName: String {
        switch self {
        case .knight: "Knight"
        case .victoryPoint: "Victory point"
        case .roadCrew: "Road crew"
        case .bumperHarvest: "Bumper harvest"
        case .cornerMarket: "Corner the market"
        }
    }

    public static let deckComposition: [DevCardType: Int] = [.knight: 14, .victoryPoint: 5, .roadCrew: 2, .bumperHarvest: 2, .cornerMarket: 2]
}

public struct DevCard: Codable, Hashable, Sendable {
    public var type: DevCardType
    public var boughtOnTurn: Int

    public init(type: DevCardType, boughtOnTurn: Int) {
        self.type = type
        self.boughtOnTurn = boughtOnTurn
    }
}

public enum Cost {
    public static let road: ResourceCounts = [.timber: 1, .clay: 1]
    public static let settlement: ResourceCounts = [.timber: 1, .clay: 1, .wool: 1, .grain: 1]
    public static let city: ResourceCounts = [.grain: 2, .ore: 3]
    public static let devCard: ResourceCounts = [.wool: 1, .grain: 1, .ore: 1]
}

public enum PieceLimit {
    public static let settlements = 5, cities = 4, roads = 15
}
