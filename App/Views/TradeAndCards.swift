import SwiftUI
import SaltmarshEngine
import SaltmarshGame

/// Development cards and the three kinds of trade, for the current player's own turn.
struct TradeAndCards: View {
    @Bindable var vm: GameViewModel
    let screen: ScreenState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            cards
            bankTrade
            harbours
            playerTrade
        }
        .buttonStyle(.bordered)
    }

    private func resourcePicker(_ title: String, _ selection: Binding<Resource>) -> some View {
        Picker(title, selection: selection) {
            ForEach(Resource.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.menu)
        .fixedSize()
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text).font(.subheadline.bold())
    }

    // MARK: Development cards

    private var cards: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("Development cards")
            Button(screen.buyLabel) { vm.buyCard() }
                .disabled(screen.buttons[Strings.buyCard] != true)
                .accessibilityIdentifier(Strings.buyCard)
            ForEach(screen.devCards, id: \.index) { row in
                HStack {
                    Text(row.name)
                    if let note = row.note { Text(note).font(.caption).foregroundStyle(.secondary) }
                    Spacer()
                    if row.note != Strings.countsAutomatically { play(row) }
                }
            }
        }
    }

    @ViewBuilder private func play(_ row: DevCardRow) -> some View {
        if row.name == DevCardType.bumperHarvest.displayName {
            Menu("Play") {
                ForEach(bumperPairs, id: \.0) { label, pair in
                    Button(label) { vm.playCard(row.index, bumper: pair) }
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

    // MARK: Bank and harbours

    private var bankTrade: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle(screen.bankTitle)
            HStack {
                resourcePicker("Give", $vm.ui.bankChoice.give)
                Image(systemName: "arrow.right").accessibilityHidden(true)
                resourcePicker("Get", $vm.ui.bankChoice.get)
                Button(Strings.bankTrade) { vm.bankTrade(give: vm.ui.bankChoice.give, get: vm.ui.bankChoice.get) }
                    .disabled(screen.buttons[Strings.bankTrade] != true)
                    .accessibilityIdentifier(Strings.bankTrade)
            }
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
                            Text(fixed).font(.callout)
                        } else {
                            resourcePicker("Give", Binding(get: { row.give }, set: { vm.ui.harbourChoice[row.index] = TradeChoice(give: $0, get: row.get) }))
                        }
                        Image(systemName: "arrow.right").accessibilityHidden(true)
                        resourcePicker("Get", Binding(get: { row.get }, set: { vm.ui.harbourChoice[row.index] = TradeChoice(give: row.give, get: $0) }))
                        Button(row.tradeLabel) { vm.harbourTrade(row.index, give: row.give, get: row.get) }
                            .disabled(!row.tradeEnabled)
                    }
                }
            }
        }
    }

    // MARK: Other players

    @ViewBuilder private var playerTrade: some View {
        let section = screen.tradeSection
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("Trade with players")
            if section.responses.isEmpty {
                offerBuilder(section)
            } else {
                ForEach(section.responses, id: \.seat) { response in
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
        }
    }

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
                        .controlSize(.small)
                    }
                    .frame(maxWidth: 64)
                }
            }
        }
    }

    private func offerBuilder(_ section: TradeSection) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            offerSide("Give", counts: section.offerGive) { vm.offerAdjust(give: $0, by: $1) }
            offerSide("Want", counts: section.offerWant) { vm.offerAdjust(want: $0, by: $1) }
            HStack {
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
        }
    }
}
