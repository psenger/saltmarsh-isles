public struct PiecesLeft: Equatable, Sendable {
    public var settlements: Int
    public var cities: Int
    public var roads: Int
}

/// A harbour the player sits on, with the buildings holding it (corner a first, then b).
public struct CapturedHarbour: Equatable, Sendable {
    public var index: Int
    public var harbour: Harbour
    /// "settlement" or "city" for each of the harbour's two corners the player owns.
    public var buildings: [String]
    /// "your settlement", "your settlement and city".
    public var heldByDescription: String
}

extension Engine {
    public static func piecesLeft(_ s: GameState, player p: Int) -> PiecesLeft {
        PiecesLeft(settlements: PieceLimit.settlements - s.settlements(of: p),
                   cities: PieceLimit.cities - s.cities(of: p),
                   roads: PieceLimit.roads - s.roads(of: p))
    }

    public static func capturedHarbours(_ s: GameState, player p: Int) -> [CapturedHarbour] {
        s.board.harbours.enumerated().compactMap { index, harbour in
            let buildings = [harbour.a, harbour.b].compactMap { c -> String? in
                guard s.board.corners[c].owner == p else { return nil }
                return s.board.corners[c].isCity ? "city" : "settlement"
            }
            guard !buildings.isEmpty else { return nil }
            return CapturedHarbour(index: index, harbour: harbour, buildings: buildings,
                                   heldByDescription: "your " + buildings.joined(separator: " and "))
        }
    }

    // MARK: Points and winning

    /// Settlements, cities (2 each) and the two awards (2 each). Visible to everyone.
    public static func publicPoints(_ s: GameState, player p: Int) -> Int {
        s.settlements(of: p) + 2 * s.cities(of: p)
            + (s.longestRoadHolder == p ? 2 : 0) + (s.largestArmyHolder == p ? 2 : 0)
    }

    /// Victory point cards in hand.
    public static func hiddenPoints(_ s: GameState, player p: Int) -> Int {
        s.players[p].devCards.filter { $0.type == .victoryPoint }.count
    }

    public static func totalPoints(_ s: GameState, player p: Int) -> Int {
        publicPoints(s, player: p) + hiddenPoints(s, player: p)
    }

    /// Ends the game when the current player has reached 10 points. Only the current player can win.
    @discardableResult
    static func checkWin(_ s: inout GameState) -> Bool {
        if case .gameOver = s.phase { return false }
        let p = s.current
        let total = totalPoints(s, player: p)
        guard total >= 10 else { return false }
        s.phase = .gameOver(winner: p)
        let hidden = hiddenPoints(s, player: p)
        if hidden == 0 {
            s.log("\(s.players[p].name) wins with \(total) points!")
        } else {
            s.log("\(s.players[p].name) wins with \(total) points, including \(hidden) hidden victory point card\(hidden > 1 ? "s" : "")!")
        }
        return true
    }

    /// 2 at a matching 2:1 harbour, 3 at a 3:1 harbour, otherwise the bank's 4.
    public static func bestRate(_ s: GameState, player p: Int, giving r: Resource) -> Int {
        var rate = 4
        for captured in capturedHarbours(s, player: p) {
            switch captured.harbour.kind {
            case .any: rate = min(rate, 3)
            case .specific(let x): if x == r { rate = min(rate, 2) }
            }
        }
        return rate
    }
}
