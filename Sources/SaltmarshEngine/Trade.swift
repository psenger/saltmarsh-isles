public struct TradeOffer: Codable, Hashable, Sendable {
    public var proposer: Int
    public var give: ResourceCounts
    public var want: ResourceCounts
    public var to: Int?

    public init(proposer: Int, give: ResourceCounts, want: ResourceCounts, to: Int?) {
        self.proposer = proposer
        self.give = give
        self.want = want
        self.to = to
    }

    public var description: String { "\(give) for \(want)" }
}

public enum TradeResponse: Codable, Hashable, Sendable {
    case pending, accepted, declined, countered(TradeOffer)
}
