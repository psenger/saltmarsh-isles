import SaltmarshEngine

public enum BuildMode: Equatable, Sendable {
    case road, settlement, city
}

public enum Overlay: Equatable, Sendable {
    case victory(winner: Int)
    case preview(seat: Int)
}

/// A give/get pair chosen in a bank or harbour trade row.
public struct TradeChoice: Equatable, Sendable {
    public var give: Resource
    public var get: Resource
    public init(give: Resource, get: Resource) {
        self.give = give
        self.get = get
    }
}

/// Everything the panel remembers that is not game state: modes, pickers and the overlay.
public struct UIState: Equatable, Sendable {
    public var buildMode: BuildMode?
    public var discardPicks = ResourceCounts()
    public var offerGive = ResourceCounts()
    public var offerWant = ResourceCounts()
    public var offerTarget: Int?
    public var overlay: Overlay?
    public var bankChoice = TradeChoice(give: .timber, get: .ore)
    public var harbourChoice: [Int: TradeChoice] = [:]

    public init() {}
}
