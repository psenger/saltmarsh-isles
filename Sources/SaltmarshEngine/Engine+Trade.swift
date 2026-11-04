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
        s.log("\(s.players[s.current].name) traded \(harbour.ratio) \(give.rawValue) for 1 \(get.rawValue) at \(place).")
    }
}
