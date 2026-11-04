import SaltmarshEngine

/// Picks a move kind uniformly, then a move of that kind uniformly, from its own seeded generator,
/// so games with it finish and replay exactly. Accepts an offer it can pay on a coin flip; never counters.
public actor RandomOpponent: Opponent {
    private var rng: SeededRNG

    public init(seed: UInt64) {
        rng = SeededRNG(seed: seed)
    }

    public func chooseMove(view: PlayerView, legal: [Move]) async -> Move {
        precondition(!legal.isEmpty, "no legal moves to choose from")
        let kinds = Array(Set(legal.map(Self.kind))).sorted()
        let chosen = kinds[Int(rng.next() % UInt64(kinds.count))]
        let ofKind = legal.filter { Self.kind($0) == chosen }
        return ofKind[Int(rng.next() % UInt64(ofKind.count))]
    }

    public func respondToTrade(_ offer: TradeOffer, view: PlayerView) async -> TradeResponse {
        guard view.hand.contains(offer.want) else { return .declined }
        return rng.next() % 2 == 0 ? .accepted : .declined
    }

    /// The enum case name of a move, without its payload.
    private static func kind(_ m: Move) -> String { String("\(m)".prefix { $0 != "(" }) }
}
