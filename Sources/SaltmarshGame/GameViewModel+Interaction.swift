import SaltmarshEngine

/// Human entry points. Each one maps a tap or button to the engine move the current phase allows
/// and does nothing when it is not the human's moment (AI acting, game over, wrong phase).
extension GameViewModel {
    private var humanCanAct: Bool {
        guard let s = state else { return false }
        return !aiThinking && !Self.isOver(s)
    }

    private func attempt(_ move: Move) {
        guard humanCanAct else { return }
        try? apply(move)
    }

    // MARK: Board taps (by index; the view does the hit-testing)

    public func tapCorner(_ c: Int) {
        guard let s = state, humanCanAct, s.board.corners.indices.contains(c) else { return }
        switch s.phase {
        case .setup(_, false, _):
            attempt(.placeSettlement(corner: c))
        case .choosingVictim(let candidates, _):
            if let owner = s.board.corners[c].owner, candidates.contains(owner), s.board.tiles[s.robberTile].corners.contains(c) {
                attempt(.steal(from: owner))
            }
        case .main:
            switch ui.buildMode {
            case .settlement: attempt(.placeSettlement(corner: c))
            case .city: attempt(.upgradeCity(corner: c))
            default: break
            }
        default:
            break
        }
    }

    public func tapEdge(_ e: Int) {
        guard let s = state, humanCanAct, s.board.edges.indices.contains(e) else { return }
        switch s.phase {
        case .setup(_, true, _), .placingFreeRoads:
            attempt(.placeRoad(edge: e))
        case .main where ui.buildMode == .road:
            attempt(.placeRoad(edge: e))
        default:
            break
        }
    }

    public func tapTile(_ t: Int) {
        guard let s = state, case .movingRobber = s.phase else { return }
        attempt(.moveRobber(tile: t))
    }

    // MARK: Buttons

    public func toggleBuildMode(_ mode: BuildMode) {
        guard humanCanAct else { return }
        ui.buildMode = ui.buildMode == mode ? nil : mode
    }

    public func rollForFirst() { attempt(.rollForFirst) }
    public func rollDice() { attempt(.roll) }
    public func endTurn() { attempt(.endTurn) }
    public func bankTrade(give: Resource, get: Resource) { attempt(.bankTrade(give: give, get: get)) }
    public func harbourTrade(_ harbour: Int, give: Resource, get: Resource) { attempt(.harbourTrade(harbour: harbour, give: give, get: get)) }
    public func buyCard() { attempt(.buyDevCard) }
    public func steal(from seat: Int) { attempt(.steal(from: seat)) }

    /// Plays the current player's held card at `index`; Bumper harvest and Corner the market need their choices.
    public func playCard(_ index: Int, bumper: (Resource, Resource)? = nil, market: Resource? = nil) {
        guard let s = state, humanCanAct, s.players[s.current].devCards.indices.contains(index) else { return }
        switch s.players[s.current].devCards[index].type {
        case .knight: attempt(.playKnight)
        case .roadCrew: attempt(.playRoadCrew)
        case .bumperHarvest: if let (a, b) = bumper { attempt(.playBumperHarvest(min(a, b), max(a, b))) }
        case .cornerMarket: if let r = market { attempt(.playCornerMarket(r)) }
        case .victoryPoint: break
        }
    }

    // MARK: Discard picker

    /// Cards the acting discarder must give up, 0 outside the discard phase.
    public var discardRequired: Int {
        guard let s = state, case .discarding(let queue) = s.phase, let p = queue.first else { return 0 }
        return s.players[p].hand.total / 2
    }

    public var canConfirmDiscard: Bool { discardRequired > 0 && ui.discardPicks.total == discardRequired }

    /// Moves one pick up or down, never below zero, above what is held, or past the required total.
    public func discardAdjust(_ r: Resource, by delta: Int) {
        guard let s = state, case .discarding(let queue) = s.phase, let p = queue.first else { return }
        let held = s.players[p].hand[r]
        let room = discardRequired - ui.discardPicks.total
        let current = ui.discardPicks[r]
        ui.discardPicks[r] = max(0, min(held, current + delta, current + room))
    }

    public func confirmDiscard() {
        guard canConfirmDiscard else { return }
        attempt(.discard(ui.discardPicks))
    }

    // MARK: Offer builder and responses

    public func offerAdjust(give r: Resource, by delta: Int) {
        guard let s = state else { return }
        ui.offerGive[r] = max(0, min(s.players[s.current].hand[r], ui.offerGive[r] + delta))
    }

    public func offerAdjust(want r: Resource, by delta: Int) {
        ui.offerWant[r] = max(0, ui.offerWant[r] + delta)
    }

    public func offerTarget(_ seat: Int?) { ui.offerTarget = seat }

    private var builtOffer: TradeOffer? {
        state.map { TradeOffer(proposer: $0.current, give: ui.offerGive, want: ui.offerWant, to: ui.offerTarget) }
    }

    /// Why the built offer cannot be sent, or nil when it can.
    public func offerProblem() -> String? {
        guard let s = state, let offer = builtOffer else { return nil }
        return Engine.validate(offer, in: s)
    }

    public func proposeOffer() {
        guard let s = state, humanCanAct, case .main = s.phase, let offer = builtOffer, Engine.validate(offer, in: s) == nil else { return }
        attempt(.proposeTrade(offer))
        ui.offerGive = ResourceCounts()
        ui.offerWant = ResourceCounts()
        ui.offerTarget = nil
    }

    /// The acting human responder accepts or declines. Accepting without the cards is ignored.
    public func respondToOffer(accept: Bool) {
        guard let s = state, humanCanAct, case .tradeOffered = s.phase else { return }
        attempt(.respondToTrade(seat: Engine.actingPlayer(s), accept ? .accepted : .declined))
    }

    public func executeTrade(with seat: Int) { attempt(.executeTrade(with: seat)) }
    public func withdrawOffer() { attempt(.withdrawTrade) }

    // MARK: Overlay

    public func showPreviewWin() {
        guard let s = state else { return }
        ui.overlay = .preview(seat: s.current)
    }

    public func dismissOverlay() { ui.overlay = nil }
}
