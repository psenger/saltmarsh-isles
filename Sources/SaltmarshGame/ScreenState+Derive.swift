import SaltmarshEngine

extension GameViewModel {
    /// What the views draw. Derived on every read from the game, the UI state and the AI flag.
    public var screen: ScreenState {
        guard let s = state else { return .empty(board: BoardGenerator.layout()) }
        return ScreenState.derive(state: s, ui: ui, aiThinking: aiThinking, reduceMotion: reduceMotion)
    }
}

extension ScreenState {
    static func derive(state s: GameState, ui: UIState, aiThinking: Bool, reduceMotion: Bool) -> ScreenState {
        let acting = Engine.actingPlayer(s)
        let current = s.current
        let over = GameViewModel.isOver(s)
        let legal = aiThinking ? [] : Engine.legalMoves(s)
        func name(_ i: Int) -> String { s.players[i].name }

        // Whose panel this is: the discarder, a human trade responder, otherwise the current player.
        var panelOwner = current
        var suffix: String?
        var responderPending = false
        switch s.phase {
        case .rollingForFirst:
            panelOwner = acting; suffix = Strings.firstRoll
        case .setup:
            suffix = Strings.setup
        case .discarding:
            panelOwner = acting; suffix = Strings.discardingSuffix
        case .tradeOffered(_, let responses):
            if acting != current, responses[acting] == .pending {
                panelOwner = acting; suffix = Strings.tradeOffer; responderPending = true
            }
        default:
            break
        }

        // Status line.
        var status: String
        if aiThinking {
            status = Strings.thinking(name(acting))
        } else {
            switch s.phase {
            case .rollingForFirst: status = Strings.rollForFirst
            case .setup(_, let placingRoad, _): status = placingRoad ? Strings.setupRoad : Strings.setupCorner
            case .awaitingRoll: status = Strings.awaitingRoll
            case .main:
                switch ui.buildMode {
                case .road: status = Strings.roadMode
                case .settlement: status = Strings.settlementMode
                case .city: status = Strings.cityMode
                case nil: status = Strings.main
                }
            case .discarding: status = Strings.discarding(roller: name(current), name: name(acting))
            case .movingRobber: status = Strings.robber
            case .choosingVictim: status = Strings.victim
            case .placingFreeRoads(let remaining): status = Strings.freeRoads(remaining)
            case .tradeOffered(let offer, _): status = responderPending ? Strings.offer(from: name(offer.proposer), offer) : Strings.answersIn
            case .gameOver: status = Strings.gameOver
            }
        }

        // The hand on show.
        var handCounts = ResourceCounts()
        var holdTitle = ""
        if aiThinking {
            let humans = s.players.indices.filter { !s.players[$0].controller.isAI }
            if humans.count == 1 { handCounts = s.players[humans[0]].hand; holdTitle = Strings.hold(name(humans[0])) }
        } else if !responderPending {
            handCounts = s.players[panelOwner].hand
            holdTitle = Strings.hold(name(panelOwner))
        }

        // Buttons.
        func has(_ test: (Move) -> Bool) -> Bool { legal.contains(where: test) }
        let inMain: Bool = { if case .main = s.phase { return true } else { return false } }()
        var buttons: [String: Bool] = [
            Strings.rollForFirstButton: legal.contains(.rollForFirst),
            Strings.rollDice: legal.contains(.roll),
            Strings.road: inMain && has { if case .placeRoad = $0 { true } else { false } },
            Strings.settlement: inMain && has { if case .placeSettlement = $0 { true } else { false } },
            Strings.city: inMain && has { if case .upgradeCity = $0 { true } else { false } },
            Strings.endTurn: legal.contains(.endTurn),
            Strings.buyCard: legal.contains(.buyDevCard),
            Strings.bankTrade: legal.contains(.bankTrade(give: ui.bankChoice.give, get: ui.bankChoice.get)),
            Strings.offerButton: inMain && !aiThinking
                && Engine.validate(TradeOffer(proposer: current, give: ui.offerGive, want: ui.offerWant, to: ui.offerTarget), in: s) == nil,
            Strings.withdraw: acting == current && legal.contains(.withdrawTrade),
            Strings.accept: responderPending && legal.contains(.respondToTrade(seat: acting, .accepted)),
            Strings.decline: responderPending && legal.contains(.respondToTrade(seat: acting, .declined)),
            Strings.newGame: true,
            Strings.previewWin: !over && !aiThinking,
            Strings.seeTheBoard: { if case .victory = ui.overlay { return true } else { return false } }(),
            Strings.backToTheGame: { if case .preview = ui.overlay { return true } else { return false } }(),
        ]
        var acceptProblem: String?
        if case .tradeOffered(let offer, _) = s.phase, responderPending, buttons[Strings.accept] == false {
            acceptProblem = Strings.cannotPay(offer.want)
        }
        if case .discarding(let queue) = s.phase, let p = queue.first, !aiThinking {
            let required = s.players[p].hand.total / 2
            buttons[Strings.discard(required)] = ui.discardPicks.total == required
        }

        // Order strip.
        var orderStrip: [Seat]?
        var orderStripNote: String?
        switch s.phase {
        case .rollingForFirst:
            orderStrip = s.players.map(\.seat)
        case .setup(let step, _, _):
            orderStrip = Engine.setupOrder(players: s.playerCount, first: s.firstPlayer).map { s.players[$0].seat }
            if step >= s.playerCount { orderStripNote = Strings.reverseOrder }
        default:
            break
        }

        let left = Engine.piecesLeft(s, player: current)
        let scoreboard = s.players.indices.map { i -> ScoreRow in
            let p = s.players[i]
            let hidden = Engine.hiddenPoints(s, player: i)
            return ScoreRow(seat: p.seat, name: p.name, colorHex: p.seat.colorHex, cards: p.hand.total, devCards: p.devCards.count,
                            road: Engine.roadLength(s, player: i), roadHighlighted: s.longestRoadHolder == i,
                            knights: p.knightsPlayed, knightsHighlighted: s.largestArmyHolder == i,
                            score: "\(Engine.publicPoints(s, player: i)) / 10",
                            hidden: i == current && !p.controller.isAI && hidden > 0 ? "+\(hidden)" : nil,
                            isCurrent: i == current)
        }

        return ScreenState(
            header: Strings.header(name(panelOwner), suffix), headerSeat: s.players[panelOwner].seat, status: status,
            dice: s.dice.map { $0.map(String.init) } ?? [Strings.dash, Strings.dash],
            handCounts: handCounts, holdTitle: holdTitle, bank: s.bank, log: s.log,
            orderStrip: orderStrip, orderStripNote: orderStripNote, buttons: buttons,
            buildLeft: [.road: left.roads, .settlement: left.settlements, .city: left.cities],
            activeBuildMode: ui.buildMode, deckCount: s.devDeck.count, acceptProblem: acceptProblem,
            scoreboard: scoreboard, aiThinking: aiThinking, board: s.board, robberTile: s.robberTile)
    }
}
