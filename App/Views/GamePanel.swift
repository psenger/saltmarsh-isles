import SwiftUI
import SaltmarshEngine
import SaltmarshGame

/// The panel beside or below the board: who acts, what they hold, and what they can do now.
struct GamePanel: View {
    let vm: GameViewModel
    let screen: ScreenState
    let onNewGame: () -> Void

    private var isResponding: Bool { screen.buttons[Strings.decline] == true }
    private var isChoosingVictim: Bool { !screen.stealTargets.isEmpty }

    /// Trading and cards belong to the current player's own turn, after setup.
    private var showsTradeAndCards: Bool {
        !screen.aiThinking && !isResponding && !isChoosingVictim && screen.discardBox == nil
            && screen.orderStrip == nil && !screen.header.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Who acts and what is asked of them never scrolls away.
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    header
                    Spacer(minLength: 0)
                    dice
                }
                Text(screen.status)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("status")
                if !screen.holdTitle.isEmpty { ResourceRow(title: screen.holdTitle, id: "hold", counts: screen.handCounts) }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    moment
                    orderStrip
                    ResourceRow(title: "Bank", id: "bank", counts: screen.bank)
                    if showsTradeAndCards { TradeAndCards(vm: vm, screen: screen) }
                    scoreboard
                    log
                    footer
                    Text("Saltmarsh Isles").font(.caption).foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func button(_ label: String, perform: @escaping () -> Void) -> some View {
        Button(label, action: perform)
            .buttonStyle(.bordered)
            .disabled(screen.buttons[label] != true)
            .accessibilityIdentifier(label)
    }

    @ViewBuilder private var header: some View {
        if !screen.header.isEmpty {
            Text(screen.header)
                .font(.title3.bold())
                .foregroundStyle(screen.headerSeat == .ivory ? Color(hex: 0x1d2a30) : .white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(seat: screen.headerSeat), in: RoundedRectangle(cornerRadius: 6))
                .accessibilityIdentifier("header")
        }
    }

    @ViewBuilder private var orderStrip: some View {
        if let strip = screen.orderStrip {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    ForEach(Array(strip.enumerated()), id: \.offset) { _, seat in
                        SeatDot(seat: seat)
                            .overlay(Circle().stroke(.primary, lineWidth: seat == screen.headerSeat ? 2 : 0))
                    }
                }
                if let note = screen.orderStripNote { Text(note).font(.caption) }
            }
        }
    }

    private var dice: some View {
        HStack(spacing: 4) {
            ForEach(Array(screen.dice.enumerated()), id: \.offset) { _, face in
                Text(face)
                    .font(.title3.monospacedDigit().bold())
                    .frame(width: 32, height: 32)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    // MARK: What this moment asks for

    @ViewBuilder private var moment: some View {
        if isResponding {
            HStack {
                button(Strings.accept) { vm.respondToOffer(accept: true) }
                button(Strings.decline) { vm.respondToOffer(accept: false) }
            }
            if let problem = screen.acceptProblem { Text(problem).font(.callout).foregroundStyle(.secondary) }
        } else if let box = screen.discardBox {
            discard(box)
        } else if isChoosingVictim {
            ForEach(screen.stealTargets, id: \.name) { target in
                Button("\(Strings.stealFrom(target.name)), \(Strings.cardCount(target.cards))") { vm.steal(from: target.seat.rawValue) }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier(Strings.stealFrom(target.name))
            }
        } else if screen.buttons[Strings.rollForFirstButton] == true {
            button(Strings.rollForFirstButton) { vm.rollForFirst() }
        } else {
            turnButtons
        }
    }

    private func discard(_ box: DiscardBox) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(box.title).font(.subheadline.bold())
            Text(box.counter).font(.callout.monospacedDigit())
            ForEach(box.rows, id: \.resource) { row in
                HStack {
                    Text(row.resource.rawValue).frame(width: 60, alignment: .leading)
                    Button("−") { vm.discardAdjust(row.resource, by: -1) }.disabled(!row.minusEnabled)
                    Text(row.label).font(.callout.monospacedDigit())
                    Button("+") { vm.discardAdjust(row.resource, by: 1) }.disabled(!row.plusEnabled)
                }
                .buttonStyle(.bordered)
            }
            if let next = box.next { Text(next).font(.caption) }
            Button(box.confirmLabel) { vm.confirmDiscard() }
                .buttonStyle(.bordered)
                .disabled(!box.confirmEnabled)
                .accessibilityIdentifier(box.confirmLabel)
        }
        .padding(8)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(seat: box.outlineSeat), lineWidth: 2))
    }

    private var turnButtons: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                button(Strings.rollDice) { vm.rollDice() }
                button(Strings.endTurn) { vm.endTurn() }
            }
            HStack {
                buildButton(Strings.road, .road)
                buildButton(Strings.settlement, .settlement)
                buildButton(Strings.city, .city)
            }
        }
    }

    private func buildButton(_ label: String, _ mode: BuildMode) -> some View {
        Button { vm.toggleBuildMode(mode) } label: {
            VStack(spacing: 0) {
                Text(label)
                Text(Strings.piecesLeft(screen.buildLeft[mode] ?? 0)).font(.caption2)
            }
        }
        .buttonStyle(.bordered)
        .tint(screen.activeBuildMode == mode ? Color(hex: 0xd68910) : nil)
        .disabled(screen.buttons[label] != true)
        .accessibilityIdentifier(label)
    }

    // MARK: Always on show

    @ViewBuilder private var scoreboard: some View {
        if !screen.scoreboard.isEmpty {
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
                GridRow {
                    Text("Player"); Text("Cards"); Text("Dev"); Text("Road"); Text("Army"); Text("Points")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                ForEach(screen.scoreboard, id: \.name) { row in
                    GridRow {
                        HStack(spacing: 4) {
                            SeatDot(seat: row.seat)
                            Text(row.name).fontWeight(row.isCurrent ? .bold : .regular)
                        }
                        Text("\(row.cards)")
                        Text("\(row.devCards)")
                        Text("\(row.road)").fontWeight(row.roadHighlighted ? .bold : .regular)
                        Text("\(row.knights)").fontWeight(row.knightsHighlighted ? .bold : .regular)
                        Text(row.score + (row.hidden.map { " \($0)" } ?? ""))
                    }
                }
            }
            .font(.callout.monospacedDigit())
        }
    }

    @ViewBuilder private var log: some View {
        if !screen.log.isEmpty {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(screen.log.reversed().enumerated()), id: \.offset) { _, line in
                        Text(line).font(.caption).fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 140)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 6))
            .accessibilityIdentifier("log")
        }
    }

    private var footer: some View {
        HStack {
            button(Strings.newGame, perform: onNewGame)
            #if DEBUG
            button(Strings.previewWin) { vm.showPreviewWin() }
            #endif
        }
    }
}

struct SeatDot: View {
    let seat: Seat

    var body: some View {
        Circle()
            .fill(Color(seat: seat))
            .overlay(Circle().stroke(.black.opacity(0.3), lineWidth: 0.5))
            .frame(width: 12, height: 12)
    }
}

/// A square box in the resource's board colour: the amount above its name, centred both ways.
struct ResourceBox: View {
    let resource: Resource
    let amount: Int
    /// Accessibility identifier prefix, such as "hold".
    let id: String

    private var ink: Color {
        resource == .grain || resource == .wool ? Color(hex: 0x1d2a30) : .white
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(BoardView.fill(for: resource))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(.black.opacity(0.35), lineWidth: 1))
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                VStack(spacing: 0) {
                    Text("\(amount)").font(.callout.monospacedDigit().bold())
                    Text(resource.rawValue).font(.caption2).minimumScaleFactor(0.7).lineLimit(1)
                }
                .foregroundStyle(ink)
                .padding(2)
            }
            .frame(maxWidth: 64)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(amount) \(resource.rawValue)")
            .accessibilityIdentifier("\(id) \(resource.rawValue)")
    }
}

/// Five resource boxes under a title: the hold and the bank.
struct ResourceRow: View {
    let title: String
    let id: String
    let counts: ResourceCounts

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                ForEach(Resource.allCases, id: \.self) { resource in
                    ResourceBox(resource: resource, amount: counts[resource], id: id)
                }
            }
        }
    }
}
