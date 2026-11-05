import SwiftUI
import SaltmarshEngine
import SaltmarshGame

/// The panel beside or below the board. Everything above the tab area keeps its place in every
/// state; a control that cannot be used greys out where it is. Only the tab area scrolls.
struct GamePanel: View {
    let vm: GameViewModel
    let screen: ScreenState

    @State private var picked = PanelTab.trade

    private var isResponding: Bool { screen.buttons[Strings.decline] == true }
    /// The game wants something from this player, and that request takes the tab area.
    private var hasRequest: Bool { screen.enabledTabs.isEmpty }
    private var shownTab: PanelTab? {
        if hasRequest { return nil }
        return screen.enabledTabs.contains(picked) ? picked : screen.fallbackTab
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            whoLine
            hand
            turnButtons
            buildButtons
            tabBar
            tabArea
        }
        .padding(10)
    }

    // MARK: Always in place

    private var whoLine: some View {
        HStack(spacing: 6) {
            SeatDot(seat: screen.headerSeat)
            Text(screen.header)
                .font(.callout.bold())
                .lineLimit(1)
                .accessibilityIdentifier("header")
            Spacer(minLength: 4)
            Text(screen.holdTitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(height: 18)
    }

    private var hand: some View {
        HStack(spacing: 6) {
            ForEach(Resource.allCases, id: \.self) { resource in
                PulsingResourceBox(resource: resource, amount: screen.holdTitle.isEmpty ? nil : screen.handCounts[resource], holder: screen.holdTitle, rolls: vm.rollCount)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var turnButtons: some View {
        let roll = screen.buttons[Strings.rollForFirstButton] == true ? Strings.rollForFirstButton : Strings.rollDice
        return HStack {
            turnButton(roll, icon: "dice.fill", fill: GameButtonStyle.ink) {
                if roll == Strings.rollDice { vm.rollDice() } else { vm.rollForFirst() }
            }
            turnButton(Strings.endTurn, icon: "arrow.right.circle.fill", fill: GameButtonStyle.ink) { vm.endTurn() }
        }
    }

    private func turnButton(_ label: String, icon: String, fill: Color, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            HStack(spacing: 6) {
                Image(systemName: icon).accessibilityHidden(true)
                Text(label).fontWeight(.semibold).lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(GameButtonStyle(fill: fill))
        .disabled(screen.buttons[label] != true)
        .accessibilityIdentifier(label)
    }

    private var buildButtons: some View {
        HStack(spacing: 6) {
            buildButton(Strings.road, icon: "road.lanes", .road)
            buildButton(Strings.settlement, icon: "house.fill", .settlement)
            buildButton(Strings.city, icon: "building.2.fill", .city)
        }
    }

    private func buildButton(_ label: String, icon: String, _ mode: BuildMode) -> some View {
        Button { vm.toggleBuildMode(mode) } label: {
            VStack(spacing: 3) {
                HStack(spacing: 4) {
                    // A fixed box, because icons differ in height and would make the three buttons differ too.
                    Image(systemName: icon).font(.caption).frame(width: 16, height: 14).accessibilityHidden(true)
                    Text(label).fontWeight(.semibold).lineLimit(1).minimumScaleFactor(0.8)
                }
                CostChips(cost: screen.buildCost[mode] ?? ResourceCounts())
                Text(Strings.piecesLeft(screen.buildLeft[mode] ?? 0)).font(.caption2)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(GameButtonStyle(fill: screen.activeBuildMode == mode ? GameButtonStyle.amber : GameButtonStyle.sea))
        .disabled(screen.buttons[label] != true)
        .accessibilityIdentifier(label)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(PanelTab.allCases, id: \.self) { tab in
                let enabled = screen.enabledTabs.contains(tab), on = shownTab == tab
                Button { picked = tab } label: {
                    Text(tab.rawValue)
                        .font(.callout)
                        .fontWeight(on ? .bold : .regular)
                        .foregroundStyle(enabled ? .primary : .tertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .contentShape(Rectangle())
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(.primary).frame(height: 2).opacity(on ? 1 : 0)
                        }
                }
                .buttonStyle(.plain)
                .disabled(!enabled)
                .accessibilityIdentifier("tab \(tab.rawValue)")
            }
        }
        .overlay(alignment: .bottom) { Divider() }
    }

    // MARK: The tab area

    @ViewBuilder private var tabArea: some View {
        VStack(alignment: .leading, spacing: 6) {
            orderStrip
            switch shownTab {
            case .trade: scrolling { TradeTab(vm: vm, screen: screen) }
            case .cards: scrolling { CardsTab(vm: vm, screen: screen) }
            case .players: scrolling { scoreboard }
            case .log: log
            case nil: scrolling { request }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func scrolling(@ViewBuilder _ content: () -> some View) -> some View {
        ScrollView {
            content().frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder private var orderStrip: some View {
        if let strip = screen.orderStrip {
            HStack(spacing: 4) {
                ForEach(Array(strip.enumerated()), id: \.offset) { _, seat in
                    SeatDot(seat: seat)
                        .overlay(Circle().stroke(.primary, lineWidth: seat == screen.headerSeat ? 2 : 0))
                }
                if let note = screen.orderStripNote { Text(note).font(.caption).lineLimit(1) }
            }
            .frame(height: 16)
        }
    }

    // MARK: What the game is asking for

    @ViewBuilder private var request: some View {
        if isResponding {
            VStack(alignment: .leading, spacing: 8) {
                Text(screen.status).font(.callout.bold()).fixedSize(horizontal: false, vertical: true)
                HStack {
                    requestButton(Strings.accept) { vm.respondToOffer(accept: true) }
                    requestButton(Strings.decline) { vm.respondToOffer(accept: false) }
                }
                if let problem = screen.acceptProblem { Text(problem).font(.callout).foregroundStyle(.secondary) }
            }
        } else if let box = screen.discardBox {
            discard(box)
        } else if !screen.stealTargets.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(screen.stealTargets, id: \.name) { target in
                    Button("\(Strings.stealFrom(target.name)), \(Strings.cardCount(target.cards))") { vm.steal(from: target.seat.rawValue) }
                        .buttonStyle(GameButtonStyle())
                        .accessibilityIdentifier(Strings.stealFrom(target.name))
                }
            }
        } else {
            OfferAnswers(vm: vm, screen: screen)
        }
    }

    private func requestButton(_ label: String, perform: @escaping () -> Void) -> some View {
        Button(label, action: perform)
            .buttonStyle(GameButtonStyle())
            .disabled(screen.buttons[label] != true)
            .accessibilityIdentifier(label)
    }

    private func discard(_ box: DiscardBox) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(box.title).font(.subheadline.bold())
                Spacer()
                Text(box.counter).font(.callout.monospacedDigit())
            }
            // Above the rows, so it stays in view when the rows need scrolling.
            Button(box.confirmLabel) { vm.confirmDiscard() }
                .buttonStyle(GameButtonStyle())
                .disabled(!box.confirmEnabled)
                .accessibilityIdentifier(box.confirmLabel)
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
        }
        .padding(8)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(seat: box.outlineSeat), lineWidth: 2))
    }

    // MARK: Players and Log

    private var scoreboard: some View {
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

    private var log: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(Array(screen.log.reversed().enumerated()), id: \.offset) { _, line in
                    Text(line).font(.caption).fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier("log")
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
/// A box of the hand on show that swells when its count goes up. A change of holder is not an increase.
/// A payout from a roll waits for the dice to land; any other increase pulses at once.
struct PulsingResourceBox: View {
    let resource: Resource
    let amount: Int?
    let holder: String
    let rolls: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulses = 0
    @State private var hold = 0.0

    private struct Seen: Equatable {
        var amount: Int?, holder: String, rolls: Int
    }

    var body: some View {
        ResourceBox(resource: resource, amount: amount, id: "hold")
            .keyframeAnimator(initialValue: 1.0, trigger: pulses) { box, scale in
                box.scaleEffect(scale)
            } keyframes: { _ in
                KeyframeTrack {
                    LinearKeyframe(1, duration: hold)
                    CubicKeyframe(1.2, duration: 0.2)
                    CubicKeyframe(1, duration: 0.3)
                }
            }
            .onChange(of: Seen(amount: amount, holder: holder, rolls: rolls)) { old, new in
                guard !reduceMotion, old.holder == new.holder, let before = old.amount, let after = new.amount, after > before else { return }
                hold = old.rolls == new.rolls ? 0 : RollingDie.landingTime
                pulses += 1
            }
    }
}

struct ResourceBox: View {
    let resource: Resource
    /// Nil keeps the box in place with no number, when no hand may be shown.
    let amount: Int?
    /// Accessibility identifier prefix, such as "hold".
    let id: String

    static func ink(for resource: Resource) -> Color {
        resource == .grain || resource == .wool ? Color(hex: 0x1d2a30) : .white
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(BoardView.fill(for: resource))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(.black.opacity(0.35), lineWidth: 1))
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                VStack(spacing: 0) {
                    Text(amount.map(String.init) ?? " ").font(.callout.monospacedDigit().bold())
                    Text(resource.rawValue).font(.caption2).minimumScaleFactor(0.7).lineLimit(1)
                }
                .foregroundStyle(Self.ink(for: resource))
                .padding(2)
            }
            .frame(maxWidth: 64)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(amount.map { "\($0) \(resource.rawValue)" } ?? resource.rawValue)
            .accessibilityIdentifier("\(id) \(resource.rawValue)")
    }
}
