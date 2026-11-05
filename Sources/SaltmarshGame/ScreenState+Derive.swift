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

        // Buttons.
        let builtOffer = TradeOffer(proposer: current, give: ui.offerGive, want: ui.offerWant, to: ui.offerTarget)
        let offerProblem = Engine.validate(builtOffer, in: s)
        var buttons: [String: Bool] = [
            Strings.rollForFirstButton: legal.contains(.rollForFirst),
            Strings.rollDice: legal.contains(.roll),
            Strings.road: inMain && !roadEdges.isEmpty,
            Strings.settlement: inMain && !settleCorners.isEmpty,
            Strings.city: inMain && !cityCorners.isEmpty,
            Strings.endTurn: legal.contains(.endTurn),
            Strings.buyCard: legal.contains(.buyDevCard),
            Strings.bankTrade: legal.contains(.bankTrade(give: ui.bankChoice.give, get: ui.bankChoice.get)),
            Strings.offerButton: inMain && !aiThinking && offerProblem == nil,
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
        let hand = s.players[current].hand
        let harbourRows = captured.map { ch -> HarbourRow in
            let h = ch.harbour
            let choice = ui.harbourChoice[ch.index] ?? HarbourRow.defaultChoice(for: h, hand: hand, bank: s.bank)
            let fixed: String? = { if case .specific(let r) = h.kind { return "\(h.ratio) \(r.rawValue)" } else { return nil } }()
            return HarbourRow(index: ch.index, title: Strings.harbourTitle(h), heldBy: ch.heldByDescription, giveFixed: fixed,
                              give: choice.give, get: choice.get, tradeLabel: Strings.harbourTrade(h.ratio),
                              tradeEnabled: legal.contains(.harbourTrade(harbour: ch.index, give: choice.give, get: choice.get)),
                              rowEnabled: has { if case .harbourTrade(ch.index, _, _) = $0 { true } else { false } })
        }
        let devRows = aiThinking ? [] : s.players[current].devCards.enumerated().map { i, card -> DevCardRow in
            let note: String?
            if card.type == .victoryPoint { note = Strings.countsAutomatically }
            else if card.boughtOnTurn == s.turn { note = Strings.boughtThisTurn }
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
                                        offerEnabled: buttons[Strings.offerButton] == true, offerProblem: offerProblem, responses: responses)

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
            victory = VictoryCard(title: Strings.victory, winner: Strings.wins(name(w)), seat: s.players[w].seat,
                                  subtitle: Strings.rounds(s.turn / s.playerCount + 1), breakdown: breakdown(w), total: total,
                                  banner: Strings.banner(name(w), total), buttons: [Strings.seeTheBoard, Strings.newGame], confetti: confetti)
        case .preview(let p):
            let total = Engine.totalPoints(s, player: p)
            victory = VictoryCard(title: Strings.preview, winner: Strings.wins(name(p)), seat: s.players[p].seat,
                                  subtitle: Strings.previewNote, breakdown: breakdown(p), total: total,
                                  banner: Strings.banner(name(p), total), buttons: [Strings.backToTheGame], confetti: confetti)
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
            scoreboard: scoreboard, aiThinking: aiThinking, board: s.board, robberTile: s.robberTile,
            glowingCorners: glowing, dashedEdges: dashed, selectableTiles: selectable, pulsingSettlements: pulsing,
            hotNumbers: [6, 8], hitNumber: s.dice.map { $0.reduce(0, +) }.flatMap { $0 == 7 ? nil : $0 },
            stealTargets: stealTargets, numberDiscBelowRobber: robberTile.number != nil, desertLabelBelowRobber: robberTile.number == nil,
            harbourRings: rings, championCorners: champion,
            discardBox: discardBox, harbours: HarboursPanel(emptyText: captured.isEmpty ? Strings.noHarbours : nil, rows: harbourRows),
            bankTitle: Strings.bankTitle, bankRowEnabled: has { if case .bankTrade = $0 { true } else { false } },
            devCards: devRows, buyLabel: Strings.buyCard(s.devDeck.count), tradeSection: tradeSection,
            victory: victory, victoryAnimation: reduceMotion ? .reduced : .full)
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
