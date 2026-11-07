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
        // During an AI's turn the trade rows carry nothing of its hand: no legal pairs, no hand behind the defaults.
        let currentIsAI = s.players[current].controller.isAI
        let tradeLegal = currentIsAI ? [] : legal
        func name(_ i: Int) -> String { s.players[i].name }
        func has(_ test: (Move) -> Bool) -> Bool { legal.contains(where: test) }
        let settleCorners = Set(legal.compactMap { if case .placeSettlement(let c) = $0 { c } else { nil } })
        let roadEdges = Set(legal.compactMap { if case .placeRoad(let e) = $0 { e } else { nil } })
        let cityCorners = Set(legal.compactMap { if case .upgradeCity(let c) = $0 { c } else { nil } })
        let inMain: Bool = { if case .main = s.phase { return true } else { return false } }()

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
        let humans = s.players.indices.filter { !s.players[$0].controller.isAI }
        // The human the panel belongs to; with an AI acting, the only human if there is just one. Never an AI.
        let handOwner = !aiThinking && !s.players[panelOwner].controller.isAI ? panelOwner : (humans.count == 1 ? humans[0] : nil)
        if let handOwner {
            handCounts = s.players[handOwner].hand
            holdTitle = Strings.hold(name(handOwner))
        }

        // The device passes privately whenever the private view would change to a different human.
        var handover: Handover?
        if humans.count >= 2, !aiThinking, !s.players[panelOwner].controller.isAI, !s.phase.skipsHandover, ui.revealedTo != panelOwner {
            let who = name(panelOwner)
            let button: String
            switch s.phase {
            case .discarding: button = Strings.handoverDiscard(who)
            case .awaitingRoll: button = Strings.startTurn(who)
            default: button = responderPending ? Strings.seeOffer(who) : Strings.continueTurn(who)
            }
            handover = Handover(player: panelOwner, seat: s.players[panelOwner].seat, message: Strings.passDevice(who), button: button)
        }

        let bankPairs = tradeLegal.compactMap { move -> TradeChoice? in
            if case .bankTrade(let give, let get) = move { TradeChoice(give: give, get: get) } else { nil }
        }
        let bankChoice = TradeChoice.shown(picked: ui.bankChoice, legal: bankPairs, fallback: .bankFallback)

        // Buttons.
        let builtOffer = TradeOffer(proposer: current, give: ui.offerGive, want: ui.offerWant, to: ui.offerTarget)
        let offerProblem = Engine.validate(builtOffer, in: s)
        let canPreview = !over && !aiThinking && panelOwner == current && !s.players[current].controller.isAI
        var buttons: [String: Bool] = [
            Strings.rollForFirstButton: legal.contains(.rollForFirst),
            Strings.rollDice: legal.contains(.roll),
            Strings.road: inMain && !roadEdges.isEmpty,
            Strings.settlement: inMain && !settleCorners.isEmpty,
            Strings.city: inMain && !cityCorners.isEmpty,
            Strings.endTurn: legal.contains(.endTurn),
            Strings.buyCard: legal.contains(.buyDevCard),
            Strings.bankTrade: legal.contains(.bankTrade(give: bankChoice.give, get: bankChoice.get)),
            Strings.offerButton: inMain && !aiThinking && offerProblem == nil,
            Strings.withdraw: acting == current && legal.contains(.withdrawTrade),
            Strings.accept: responderPending && legal.contains(.respondToTrade(seat: acting, .accepted)),
            Strings.decline: responderPending && legal.contains(.respondToTrade(seat: acting, .declined)),
            Strings.newGame: true,
            Strings.saveGame: !over,
            Strings.previewWin: canPreview,
            Strings.previewLose: canPreview,
            Strings.seeTheBoard: { if case .victory = ui.overlay { return true } else { return false } }(),
            Strings.backToTheGame: {
                switch ui.overlay {
                case .preview, .previewDefeat: true
                default: false
                }
            }(),
        ]
        var acceptProblem: String?, offerTerms: String?
        if case .tradeOffered(let offer, _) = s.phase, responderPending {
            offerTerms = Strings.offerTerms(offer)
            if buttons[Strings.accept] == false { acceptProblem = Strings.cannotPay(offer.want) }
        }

        // Discard box.
        var discardBox: DiscardBox?
        if case .discarding(let queue) = s.phase, let p = queue.first, !aiThinking {
            let required = s.players[p].hand.total / 2
            let picked = ui.discardPicks.total
            buttons[Strings.discard(required)] = picked == required
            let rows = s.players[p].hand.nonZero.map { r, held in
                DiscardRow(resource: r, picked: ui.discardPicks[r], held: held, label: Strings.discardRow(ui.discardPicks[r], held),
                           plusEnabled: ui.discardPicks[r] < held && picked < required, minusEnabled: ui.discardPicks[r] > 0)
            }
            discardBox = DiscardBox(title: Strings.discardTitle(name(p), required), counter: Strings.discardCounter(picked, required), rows: rows,
                                    next: queue.count > 1 ? Strings.next(name(queue[1])) : nil,
                                    confirmLabel: Strings.discard(required), confirmEnabled: picked == required, outlineSeat: s.players[p].seat)
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

        // Board intent.
        var glowing = Set<Int>(), dashed = Set<Int>(), pulsing = Set<Int>()
        switch s.phase {
        case .setup(_, let placingRoad, _):
            if placingRoad { dashed = roadEdges } else { glowing = settleCorners }
        case .placingFreeRoads:
            dashed = roadEdges
        case .main:
            switch ui.buildMode {
            case .road: dashed = roadEdges
            case .settlement: glowing = settleCorners
            case .city: pulsing = cityCorners
            case nil: break
            }
        default:
            break
        }
        let selectable = Set(legal.compactMap { if case .moveRobber(let t) = $0 { t } else { nil } })
        let robberTile = s.board.tiles[s.robberTile]
        var stealTargets: [StealTarget] = []
        if case .choosingVictim(let candidates, _) = s.phase, !aiThinking {
            stealTargets = candidates.map { seat in
                StealTarget(seat: s.players[seat].seat, name: name(seat), cards: s.players[seat].hand.total,
                            corners: Set(robberTile.corners.filter { s.board.corners[$0].owner == seat }))
            }
        }
        var rings: [Int: [Seat]] = [:]
        for (i, h) in s.board.harbours.enumerated() {
            var owners: [Int] = []
            for c in [h.a, h.b] { if let o = s.board.corners[c].owner, !owners.contains(o) { owners.append(o) } }
            if !owners.isEmpty { rings[i] = owners.sorted().map { s.players[$0].seat } }
        }
        var champion = Set<Int>()
        if case .gameOver(let winner) = s.phase {
            champion = Set(s.board.corners.indices.filter { s.board.corners[$0].owner == winner })
        }

        // Harbours, bank, cards and the trade section belong to the current player.
        let captured = Engine.capturedHarbours(s, player: current)
        let hand = currentIsAI ? ResourceCounts() : s.players[current].hand
        let harbourRows = captured.map { ch -> HarbourRow in
            let h = ch.harbour
            let pairs = tradeLegal.compactMap { move -> TradeChoice? in
                if case .harbourTrade(ch.index, let give, let get) = move { TradeChoice(give: give, get: get) } else { nil }
            }
            let choice = TradeChoice.shown(picked: ui.harbourChoice[ch.index], legal: pairs,
                                           fallback: HarbourRow.defaultChoice(for: h, hand: hand, bank: s.bank))
            let fixed: String? = { if case .specific(let r) = h.kind { return "\(h.ratio) \(r.rawValue)" } else { return nil } }()
            return HarbourRow(index: ch.index, title: Strings.harbourTitle(h), heldBy: ch.heldByDescription, giveFixed: fixed,
                              give: choice.give, get: choice.get, giveOptions: TradeChoice.giveOptions(legal: pairs, shown: choice),
                              tradeLabel: Strings.harbourTrade(h.ratio),
                              tradeEnabled: tradeLegal.contains(.harbourTrade(harbour: ch.index, give: choice.give, get: choice.get)),
                              rowEnabled: !pairs.isEmpty)
        }
        let devRows = aiThinking ? [] : s.players[current].devCards.enumerated().map { i, card -> DevCardRow in
            let note: String?
            if card.type == .victoryPoint { note = Strings.countsAutomatically }
            else if card.boughtOnTurn == s.turn { note = Strings.boughtThisTurn }
            else if card.type != .knight, legal.contains(.roll) { note = Strings.rollFirst }
            else if s.devCardPlayedThisTurn { note = Strings.oneCardPerTurn }
            else { note = nil }
            let playable: Bool
            switch card.type {
            case .knight: playable = legal.contains(.playKnight)
            case .roadCrew: playable = legal.contains(.playRoadCrew)
            case .bumperHarvest: playable = has { if case .playBumperHarvest = $0 { true } else { false } }
            case .cornerMarket: playable = has { if case .playCornerMarket = $0 { true } else { false } }
            case .victoryPoint: playable = false
            }
            return DevCardRow(index: i, name: card.type.displayName, note: note, playEnabled: note == nil && playable,
                              needsChoices: card.type == .bumperHarvest || card.type == .cornerMarket)
        }
        var responses: [ResponseRow] = []
        if case .tradeOffered(_, let answers) = s.phase {
            responses = answers.keys.sorted().map { seat in
                let text: String
                switch answers[seat] {
                case .accepted: text = Strings.accepted
                case .declined: text = Strings.declined
                case .countered(let counter): text = Strings.countered(counter)
                default: text = Strings.pending
                }
                return ResponseRow(seat: s.players[seat].seat, text: text, canTrade: legal.contains(.executeTrade(with: seat)))
            }
        }
        let tradeSection = TradeSection(offerGive: ui.offerGive, offerWant: ui.offerWant, target: ui.offerTarget,
                                        targets: s.players.indices.filter { $0 != current }.map { s.players[$0].seat },
                                        offerEnabled: buttons[Strings.offerButton] == true, offerProblem: legal.contains(.roll) ? Strings.rollBeforeOffering : offerProblem, responses: responses)

        // Trade and Cards belong to the current player, so they close while an AI is that player.
        let hasRequest = responderPending || discardBox != nil || !stealTargets.isEmpty || buttons[Strings.withdraw] == true
        let enabledTabs: Set<PanelTab> = hasRequest ? [] : (aiThinking || orderStrip != nil ? [.players, .log] : Set(PanelTab.allCases))

        // Victory card.
        var victory: VictoryCard?
        func breakdown(_ p: Int) -> [BreakdownRow] {
            let rows: [(String, Int)] = [
                (Strings.settlements, s.settlements(of: p)), (Strings.cities, 2 * s.cities(of: p)),
                (Strings.longestRoad, s.longestRoadHolder == p ? 2 : 0), (Strings.largestArmy, s.largestArmyHolder == p ? 2 : 0),
                (Strings.victoryPointCards, Engine.hiddenPoints(s, player: p)),
            ]
            return rows.filter { $0.1 > 0 }.map { BreakdownRow(label: $0.0, points: $0.1) }
        }
        let confetti: ConfettiSchedule? = reduceMotion ? nil : ConfettiSchedule(bursts: [
            ConfettiBurst(delay: 0, origin: "centre", pieces: 170), ConfettiBurst(delay: 0, origin: "bottom-left", pieces: 90),
            ConfettiBurst(delay: 0, origin: "bottom-right", pieces: 90), ConfettiBurst(delay: 0.55, origin: "bottom-left", pieces: 60),
            ConfettiBurst(delay: 0.55, origin: "bottom-right", pieces: 60),
        ])
        switch ui.overlay {
        case .victory(let w):
            let total = Engine.totalPoints(s, player: w)
            let rounds = s.turn / s.playerCount + 1
            // An AI beat every human at the table. An all-AI game has nobody to commiserate with, so it still celebrates.
            let lost = s.players[w].controller.isAI && !humans.isEmpty
            victory = VictoryCard(title: lost ? Strings.defeat : Strings.victory, winner: Strings.wins(name(w)), seat: s.players[w].seat,
                                  subtitle: lost ? Strings.defeated(name(w), rounds: rounds) : Strings.rounds(rounds), breakdown: breakdown(w), total: total,
                                  banner: lost ? Strings.betterLuck : Strings.banner(name(w), total), buttons: [Strings.seeTheBoard, Strings.newGame], confetti: lost ? nil : confetti)
        case .preview(let p):
            let total = Engine.totalPoints(s, player: p)
            victory = VictoryCard(title: Strings.preview, winner: Strings.wins(name(p)), seat: s.players[p].seat,
                                  subtitle: Strings.previewNote, breakdown: breakdown(p), total: total,
                                  banner: Strings.banner(name(p), total), buttons: [Strings.backToTheGame], confetti: confetti)
        case .previewDefeat(let w):
            victory = VictoryCard(title: Strings.defeat, winner: Strings.wins(name(w)), seat: s.players[w].seat,
                                  subtitle: Strings.previewDefeatNote, breakdown: breakdown(w), total: Engine.totalPoints(s, player: w),
                                  banner: Strings.betterLuck, buttons: [Strings.backToTheGame], confetti: nil)
        case nil:
            break
        }

        let left = Engine.piecesLeft(s, player: current)
        let scoreboard = s.players.indices.map { i -> ScoreRow in
            let p = s.players[i]
            let hidden = Engine.hiddenPoints(s, player: i)
            return ScoreRow(seat: p.seat, name: p.name, colorHex: p.seat.colorHex, cards: p.hand.total, devCards: p.devCards.count,
                            road: Engine.roadLength(s, player: i), roadHighlighted: s.longestRoadHolder == i,
                            knights: p.knightsPlayed, knightsHighlighted: s.largestArmyHolder == i,
                            score: "\(Engine.publicPoints(s, player: i)) / 10", points: Engine.publicPoints(s, player: i),
                            hidden: i == panelOwner && !aiThinking && !p.controller.isAI && hidden > 0 ? "+\(hidden)" : nil,
                            isCurrent: i == current)
        }

        return ScreenState(
            header: Strings.header(name(panelOwner), suffix), headerSeat: s.players[panelOwner].seat, status: status,
            dice: s.dice.map { $0.map(String.init) } ?? [Strings.dash, Strings.dash],
            handCounts: handCounts, holdTitle: holdTitle, bank: s.bank, log: s.log,
            orderStrip: orderStrip, orderStripNote: orderStripNote, buttons: buttons,
            buildLeft: [.road: left.roads, .settlement: left.settlements, .city: left.cities],
            buildCost: ScreenState.buildCosts, cardCost: Cost.devCard,
            activeBuildMode: ui.buildMode, deckCount: s.devDeck.count, acceptProblem: acceptProblem, offerTerms: offerTerms,
            scoreboard: scoreboard, aiThinking: aiThinking, board: s.board, robberTile: s.robberTile,
            glowingCorners: glowing, dashedEdges: dashed, selectableTiles: selectable, pulsingSettlements: pulsing,
            hotNumbers: [6, 8], hitNumber: s.dice.map { $0.reduce(0, +) }.flatMap { $0 == 7 ? nil : $0 },
            stealTargets: stealTargets, numberDiscBelowRobber: robberTile.number != nil, desertLabelBelowRobber: robberTile.number == nil,
            harbourRings: rings, championCorners: champion,
            discardBox: discardBox, harbours: HarboursPanel(emptyText: captured.isEmpty ? Strings.noHarbours : nil, rows: harbourRows),
            bankTitle: Strings.bankTitle, bankChoice: bankChoice, bankGiveOptions: TradeChoice.giveOptions(legal: bankPairs, shown: bankChoice),
            bankRowEnabled: !bankPairs.isEmpty,
            devCards: devRows, tradeSection: tradeSection,
            victory: victory, victoryAnimation: reduceMotion ? .reduced : .full, enabledTabs: enabledTabs, handover: handover,
            drawnCard: ui.drawnCard.map { DrawnCard(title: Strings.youDrew($0.displayName), text: Strings.drawnCardText($0)) },
            pointsBreakdown: aiThinking ? [] : breakdown(current), totalPoints: aiThinking ? 0 : Engine.totalPoints(s, player: current))
    }
}

extension Phase {
    /// The first roll and setup hold nothing secret, and the end of the game has nothing left to hide.
    var skipsHandover: Bool {
        switch self {
        case .rollingForFirst, .setup, .gameOver: true
        default: false
        }
    }
}

extension TradeChoice {
    /// What the bank row shows when it has no pick and no legal trade.
    static let bankFallback = TradeChoice(give: .timber, get: .ore)

    /// The pair a row shows: the pick while its give side can still be traded, otherwise the first
    /// legal pair, keeping the picked get side if it can. With nothing legal, the pick or the fallback.
    static func shown(picked: TradeChoice?, legal: [TradeChoice], fallback: TradeChoice) -> TradeChoice {
        if let picked, legal.contains(where: { $0.give == picked.give }) { return picked }
        return legal.first { $0.get == picked?.get } ?? legal.first ?? picked ?? fallback
    }

    /// The resources a row's Give dropdown lists. A row with no legal trade lists only what it shows,
    /// so the disabled dropdown still has a valid selection.
    static func giveOptions(legal: [TradeChoice], shown: TradeChoice) -> [Resource] {
        let gives = Resource.allCases.filter { give in legal.contains { $0.give == give } }
        return gives.isEmpty ? [shown.give] : gives
    }
}

extension HarbourRow {
    /// A 2:1 harbour gives its own resource; a 3:1 harbour gives the first resource held three times.
    /// The get side is the first other resource the bank still holds.
    static func defaultChoice(for h: Harbour, hand: ResourceCounts, bank: ResourceCounts) -> TradeChoice {
        let give: Resource
        switch h.kind {
        case .specific(let r): give = r
        case .any: give = Resource.allCases.first { hand[$0] >= 3 } ?? .timber
        }
        let get = Resource.allCases.first { $0 != give && bank[$0] >= 1 } ?? (give == .ore ? .timber : .ore)
        return TradeChoice(give: give, get: get)
    }
}
