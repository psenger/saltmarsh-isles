extension Engine {
    // MARK: Bank and harbour trades

    static func tradeMoves(_ s: GameState) -> [Move] {
        let p = s.current, hand = s.players[p].hand
        var moves: [Move] = []
        for give in Resource.allCases where hand[give] >= 4 {
            for get in Resource.allCases where get != give && s.bank[get] >= 1 {
                moves.append(.bankTrade(give: give, get: get))
            }
        }
        for captured in capturedHarbours(s, player: p) {
            let harbour = captured.harbour
            for give in Resource.allCases where hand[give] >= harbour.ratio {
                if case .specific(let only) = harbour.kind, only != give { continue }
                for get in Resource.allCases where get != give && s.bank[get] >= 1 {
                    moves.append(.harbourTrade(harbour: captured.index, give: give, get: get))
                }
            }
        }
        return moves
    }

    /// Gives `count` of one resource to the bank for one of another.
    static func exchange(_ s: inout GameState, give: Resource, count: Int, get: Resource) {
        s.players[s.current].hand[give] -= count
        s.bank[give] += count
        s.bank[get] -= 1
        s.players[s.current].hand[get] += 1
    }

    static func applyBankTrade(_ s: inout GameState, give: Resource, get: Resource) {
        exchange(&s, give: give, count: 4, get: get)
        s.log("\(s.players[s.current].name) traded 4 \(give.rawValue) for 1 \(get.rawValue) with the bank.")
    }

    static func applyHarbourTrade(_ s: inout GameState, harbour h: Int, give: Resource, get: Resource) {
        let harbour = s.board.harbours[h]
        exchange(&s, give: give, count: harbour.ratio, get: get)
        let place = harbour.kind == .any ? "the 3:1 harbour" : "the 2:1 \(give.rawValue) harbour"
        s.log("\(s.players[s.current].name) traded \(harbour.ratio) \(give.rawValue) for 1 \(get.rawValue) at \(place) (\(s.board.portID(h))).")
    }

    // MARK: Trading between players

    /// nil when the offer is well formed and the proposer can pay; otherwise the reason.
    public static func validate(_ offer: TradeOffer, in s: GameState) -> String? {
        if offer.give.hasNegative || offer.want.hasNegative { return "negative count" }
        if offer.give.isEmpty { return "give side is empty" }
        if offer.want.isEmpty { return "want side is empty" }
        if Resource.allCases.contains(where: { offer.give[$0] > 0 && offer.want[$0] > 0 }) { return "same resource on both sides" }
        guard s.players.indices.contains(offer.proposer), s.players[offer.proposer].hand.contains(offer.give) else { return "proposer cannot pay" }
        if let to = offer.to {
            if to == offer.proposer { return "target is the proposer" }
            if !s.players.indices.contains(to) { return "target out of range" }
        }
        return nil
    }

    /// The canonical offers listed in `legalMoves`: one resource each side, 1 or 2 cards, to everyone.
    static func playerTradeMoves(_ s: GameState) -> [Move] {
        let p = s.current, hand = s.players[p].hand
        var moves: [Move] = []
        for give in Resource.allCases {
            for giveCount in 1...2 where hand[give] >= giveCount {
                for want in Resource.allCases where want != give {
                    for wantCount in 1...2 {
                        moves.append(.proposeTrade(TradeOffer(proposer: p, give: [give: giveCount], want: [want: wantCount], to: nil)))
                    }
                }
            }
        }
        return moves
    }

    static func tradeResponseMoves(_ s: GameState, offer: TradeOffer, responses: [Int: TradeResponse]) -> [Move] {
        var moves: [Move] = []
        let pending = responses.filter { $0.value == .pending }.keys.sorted()
        for seat in pending {
            moves.append(.respondToTrade(seat: seat, .declined))
            if s.players[seat].hand.contains(offer.want) { moves.append(.respondToTrade(seat: seat, .accepted)) }
        }
        if pending.isEmpty {
            for seat in responses.keys.sorted() {
                switch responses[seat] {
                case .accepted, .countered: moves.append(.executeTrade(with: seat))
                default: break
                }
            }
        }
        moves.append(.withdrawTrade)
        return moves
    }

    /// Why a counter-offer from `seat` cannot be accepted, or nil when it can.
    static func counterProblem(_ counter: TradeOffer, from seat: Int, to offer: TradeOffer, in s: GameState) -> String? {
        if counter.proposer != offer.proposer { return "counter must keep the original proposer" }
        if counter.to != seat { return "counter must be addressed to the responder" }
        if let reason = validate(counter, in: s) { return reason }
        if !s.players[seat].hand.contains(counter.want) { return "responder cannot pay" }
        return nil
    }

    static func applyProposeTrade(_ s: inout GameState, _ offer: TradeOffer) {
        let targets = offer.to.map { [$0] } ?? s.players.indices.filter { $0 != offer.proposer }
        let responders = targets.filter { s.players[$0].hand.total > 0 }
        guard !responders.isEmpty else {
            s.log("Nobody can answer that offer.")
            return
        }
        var line = "\(s.players[offer.proposer].name) offers \(offer.description)"
        if let to = offer.to { line += " to \(s.players[to].name)" }
        s.log(line + ".")
        s.phase = .tradeOffered(offer: offer, responses: Dictionary(uniqueKeysWithValues: responders.map { ($0, TradeResponse.pending) }))
    }

    static func applyRespondToTrade(_ s: inout GameState, seat: Int, _ response: TradeResponse) {
        guard case .tradeOffered(let offer, var responses) = s.phase else { return }
        responses[seat] = response
        let name = s.players[seat].name
        switch response {
        case .accepted: s.log("\(name) accepted the offer.")
        case .declined: s.log("\(name) declined the offer.")
        case .countered(let counter): s.log("\(name) countered: \(counter.description).")
        case .pending: break
        }
        s.phase = .tradeOffered(offer: offer, responses: responses)
    }

    static func applyExecuteTrade(_ s: inout GameState, with seat: Int) {
        guard case .tradeOffered(let offer, let responses) = s.phase else { return }
        let terms: TradeOffer
        if case .countered(let counter) = responses[seat] { terms = counter } else { terms = offer }
        let p = offer.proposer
        s.players[p].hand = s.players[p].hand - terms.give + terms.want
        s.players[seat].hand = s.players[seat].hand + terms.give - terms.want
        s.log("\(s.players[p].name) traded \(terms.give) with \(s.players[seat].name) for \(terms.want).")
        s.phase = .main
    }

    static func applyWithdrawTrade(_ s: inout GameState) {
        s.log("\(s.players[s.current].name) withdrew the offer.")
        s.phase = .main
    }
}
