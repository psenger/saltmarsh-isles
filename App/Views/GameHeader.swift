import SwiftUI
import SaltmarshEngine
import SaltmarshGame

/// The full-width row above the board: the scores, what is asked now, the dice and the menu. Its height never changes.
struct GameHeader: View {
    let vm: GameViewModel
    let screen: ScreenState
    /// Short or narrow screens shrink each chip to its dot and score.
    let compactChips: Bool
    /// Narrow screens give the status line its own row.
    let statusOnOwnRow: Bool
    let onNewGame: () -> Void

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 6) {
                ForEach(screen.scoreboard, id: \.name) { chip($0) }
                if statusOnOwnRow { Spacer(minLength: 0) } else { status }
                dice
                menu
            }
            if statusOnOwnRow { status }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private func chip(_ row: ScoreRow) -> some View {
        HStack(spacing: 4) {
            SeatDot(seat: row.seat)
            // Sized for bold in every state, so the turn passing does not change any chip's width.
            let label = compactChips ? "\(row.points)" : "\(row.name) \(row.score)"
            Text(label)
                .fontWeight(.bold)
                .opacity(0)
                .overlay(alignment: .leading) {
                    Text(label).fontWeight(row.isCurrent ? .bold : .regular)
                }
                .font(.callout.monospacedDigit())
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(.quaternary.opacity(0.5), in: Capsule())
        .overlay(Capsule().strokeBorder(row.isCurrent ? Color.primary : Color.clear, lineWidth: 2))
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(row.name), \(row.score)")
        .accessibilityIdentifier("chip \(row.name)")
    }

    /// A fixed-height slot: long text wraps and shrinks inside it and never pushes anything.
    private var status: some View {
        Text(screen.status)
            .font(.callout)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.75)
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .accessibilityIdentifier("status")
    }

    private var dice: some View {
        HStack(spacing: 4) {
            ForEach(Array(screen.dice.enumerated()), id: \.offset) { i, face in RollingDie(face: face, index: i, rolls: vm.rollCount) }
        }
    }

    private var menu: some View {
        Menu {
            Button(Strings.newGame, action: onNewGame)
            #if DEBUG
            Button(Strings.previewWin) { vm.showPreviewWin() }
                .disabled(screen.buttons[Strings.previewWin] != true)
            #endif
        } label: {
            Image(systemName: "ellipsis.circle").accessibilityLabel("Menu")
        }
        #if os(macOS)
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        #endif
        .fixedSize()
        .accessibilityIdentifier("menu")
    }
}
