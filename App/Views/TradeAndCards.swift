import SwiftUI
import SaltmarshEngine
import SaltmarshGame

/// The Trade tab: the bank's supply, the bank and harbour rows, and the way into an offer to other players.
struct TradeTab: View {
    @Bindable var vm: GameViewModel
    let screen: ScreenState

    @State private var buildingOffer = false
    /// One width for every resource name, so the Trade button beside it stays put whatever is picked.
    private static let pickerWidth: CGFloat = 96

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if buildingOffer {
                offerBuilder(screen.tradeSection)
            } else {
                bankSupply
                bankTrade
                harbours
                Button { buildingOffer = true } label: {
                    Text(Strings.offerToPlayers).frame(maxWidth: .infinity)
                }
                .accessibilityIdentifier(Strings.offerToPlayers)
            }
        }
        .buttonStyle(GameButtonStyle())
    }

    private var bankSupply: some View {
        HStack(spacing: 4) {
            Text("Bank").font(.caption.bold())
            ForEach(Resource.allCases, id: \.self) { resource in
                Text("\(screen.bank[resource])")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(ResourceBox.ink(for: resource))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 2)
                    .background(BoardView.fill(for: resource), in: RoundedRectangle(cornerRadius: 3))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(screen.bank[resource]) \(resource.rawValue)")
                    .accessibilityIdentifier("bank \(resource.rawValue)")
            }
        }
    }

    private func resourcePicker(_ title: String, id: String, options: [Resource] = Resource.allCases, _ selection: Binding<Resource>) -> some View {
        Picker(title, selection: selection) {
            ForEach(options, id: \.self) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .frame(width: Self.pickerWidth, alignment: .leading)
        .accessibilityIdentifier(id)
    }

    /// The arrow between a row's give and get sides, grey when the whole row is disabled.
    private func arrow(enabled: Bool) -> some View {
        Image(systemName: "arrow.right")
            .foregroundStyle(enabled ? .primary : .secondary)
            .accessibilityHidden(true)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text).font(.subheadline.bold())
    }

    // MARK: Bank and harbours

    private var bankTrade: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle(screen.bankTitle)
            HStack {
                resourcePicker("Give", id: "bank give", options: screen.bankGiveOptions, Binding(get: { screen.bankChoice.give }, set: { vm.ui.bankChoice = TradeChoice(give: $0, get: screen.bankChoice.get) }))
                arrow(enabled: screen.bankRowEnabled)
                resourcePicker("Get", id: "bank get", Binding(get: { screen.bankChoice.get }, set: { vm.ui.bankChoice = TradeChoice(give: screen.bankChoice.give, get: $0) }))
                Button(Strings.bankTrade) { vm.bankTrade(give: screen.bankChoice.give, get: screen.bankChoice.get) }
                    .disabled(screen.buttons[Strings.bankTrade] != true)
                    .accessibilityIdentifier(Strings.bankTrade)
            }
            .disabled(!screen.bankRowEnabled)
        }
    }

    private var harbours: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("Harbours")
            if let empty = screen.harbours.emptyText {
                Text(empty).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            ForEach(screen.harbours.rows, id: \.index) { row in
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(row.title), \(row.heldBy)").font(.caption)
                    HStack {
                        if let fixed = row.giveFixed {
                            Text(fixed).font(.callout).foregroundStyle(row.rowEnabled ? .primary : .secondary)
                                .frame(width: Self.pickerWidth, alignment: .leading)
                        } else {
                            resourcePicker("Give", id: "harbour \(row.index) give", options: row.giveOptions, Binding(get: { row.give }, set: { vm.ui.harbourChoice[row.index] = TradeChoice(give: $0, get: row.get) }))
                        }
                        arrow(enabled: row.rowEnabled)
                        resourcePicker("Get", id: "harbour \(row.index) get", Binding(get: { row.get }, set: { vm.ui.harbourChoice[row.index] = TradeChoice(give: row.give, get: $0) }))
                        Button(row.tradeLabel) { vm.harbourTrade(row.index, give: row.give, get: row.get) }
                            .disabled(!row.tradeEnabled)
                    }
                    .disabled(!row.rowEnabled)
                }
            }
        }
    }

    // MARK: Offer to other players

    private func offerSide(_ title: String, counts: ResourceCounts, adjust: @escaping (Resource, Int) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 6) {
                ForEach(Resource.allCases, id: \.self) { resource in
                    VStack(spacing: 4) {
                        ResourceBox(resource: resource, amount: counts[resource], id: title.lowercased())
                        HStack(spacing: 2) {
                            Button("−") { adjust(resource, -1) }.accessibilityLabel("\(title) one less \(resource.rawValue)")
                            Button("+") { adjust(resource, 1) }.accessibilityLabel("\(title) one more \(resource.rawValue)")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .frame(maxWidth: 64)
                }
            }
        }
    }

    private func offerBuilder(_ section: TradeSection) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Above the boxes, so sending the offer stays in view when they need scrolling.
            HStack {
                Button(Strings.back) { buildingOffer = false }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier(Strings.back)
                Spacer(minLength: 0)
                Picker("To", selection: Binding(get: { section.target }, set: { vm.offerTarget($0) })) {
                    Text("Everyone").tag(Int?.none)
                    ForEach(section.targets, id: \.self) { Text($0.name).tag(Int?.some($0.rawValue)) }
                }
                .pickerStyle(.menu)
                .fixedSize()
                Button(Strings.offerButton) { vm.proposeOffer() }
                    .disabled(!section.offerEnabled)
                    .accessibilityIdentifier(Strings.offerButton)
            }
            if let problem = section.offerProblem {
                Text(problem).font(.caption).foregroundStyle(.secondary)
            }
            offerSide("Give", counts: section.offerGive) { vm.offerAdjust(give: $0, by: $1) }
            offerSide("Want", counts: section.offerWant) { vm.offerAdjust(want: $0, by: $1) }
        }
    }
}

/// The Cards tab: the cards still to play, and where the player's points come from.
struct CardsTab: View {
    let vm: GameViewModel
    let screen: ScreenState

    /// Victory point cards are never played, so they count under Victory points instead.
    private var cardsToPlay: [DevCardRow] {
        screen.devCards.filter { $0.note != Strings.countsAutomatically }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if cardsToPlay.isEmpty {
                Text(Strings.noCardsYet).font(.callout).foregroundStyle(.secondary)
            }
            ForEach(cardsToPlay, id: \.index) { row in
                HStack {
                    Text(row.name)
                    if let note = row.note { Text(note).font(.caption).foregroundStyle(.secondary) }
                    Spacer()
                    play(row)
                }
            }
            if let me = screen.scoreboard.first(where: \.isCurrent), me.knights > 0 {
                Text(Strings.knightsPlayed(me.knights)).font(.callout).accessibilityIdentifier("knights played")
            }
            Divider()
            victoryPoints
        }
        .buttonStyle(GameButtonStyle())
    }

    private var victoryPoints: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(Strings.victoryPoints).font(.subheadline.bold())
                Spacer()
                Text(Strings.pointsOfTen(screen.totalPoints)).font(.subheadline.monospacedDigit().bold())
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("victory points")
            ForEach(screen.pointsBreakdown.filter { $0.label != Strings.longestRoad && $0.label != Strings.largestArmy }, id: \.label) { row in
                HStack {
                    Text(row.label)
                    Spacer()
                    Text("\(row.points)").monospacedDigit()
                }
                .font(.callout)
            }
            awards
        }
    }

    @ViewBuilder private var awards: some View {
        if let me = screen.scoreboard.first(where: \.isCurrent) {
            HStack(spacing: 6) {
                if me.roadHighlighted { AwardPill(name: Strings.longestRoad, count: me.road) }
                if me.knightsHighlighted { AwardPill(name: Strings.largestArmy, count: me.knights) }
            }
        }
    }

    @ViewBuilder private func play(_ row: DevCardRow) -> some View {
        if row.name == DevCardType.bumperHarvest.displayName {
            Menu("Play") {
                Section("Take 2 free cards from the bank") {
                    ForEach(bumperPairs, id: \.0) { label, pair in
                        Button(label) { vm.playCard(row.index, bumper: pair) }
                    }
                }
            }
            .fixedSize()
            .disabled(!row.playEnabled)
        } else if row.name == DevCardType.cornerMarket.displayName {
            Menu("Play") {
                ForEach(Resource.allCases, id: \.self) { resource in
                    Button(resource.rawValue) { vm.playCard(row.index, market: resource) }
                }
            }
            .fixedSize()
            .disabled(!row.playEnabled)
        } else {
            Button("Play") { vm.playCard(row.index) }.disabled(!row.playEnabled)
        }
    }

    /// The Bumper harvest pairs the bank can pay right now.
    private var bumperPairs: [(String, (Resource, Resource))] {
        guard let state = vm.state else { return [] }
        let all = Resource.allCases
        return all.indices.flatMap { i in
            all[i...].compactMap { other -> (String, (Resource, Resource))? in
                let move = Move.playBumperHarvest(all[i], other)
                guard Engine.isLegal(move, in: state) else { return nil }
                return (all[i] == other ? "2 \(other.rawValue)" : "\(all[i].rawValue) and \(other.rawValue)", (all[i], other))
            }
        }
    }
}

/// An award the player holds, with its road length or knight count and the 2 points it is worth.
struct AwardPill: View {
    let name: String
    let count: Int

    var body: some View {
        Text("\(name) \(count) +2")
            .font(.caption.monospacedDigit().bold())
            .foregroundStyle(GameButtonStyle.ink)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(GameButtonStyle.amber, in: Capsule())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(name), \(count), 2 points")
            .accessibilityIdentifier("award \(name)")
    }
}

/// The proposer's list of answers, with the buttons that close the offer.
struct OfferAnswers: View {
    let vm: GameViewModel
    let screen: ScreenState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(screen.tradeSection.responses, id: \.seat) { response in
                HStack {
                    SeatDot(seat: response.seat)
                    Text(response.text).font(.callout)
                    Spacer()
                    if response.canTrade {
                        Button(Strings.tradeWith(response.seat.name)) { vm.executeTrade(with: response.seat.rawValue) }
                    }
                }
            }
            Button(Strings.withdraw) { vm.withdrawOffer() }
                .disabled(screen.buttons[Strings.withdraw] != true)
        }
        .buttonStyle(GameButtonStyle())
    }
}
