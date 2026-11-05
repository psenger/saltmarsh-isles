import SwiftUI
import SaltmarshEngine
import SaltmarshGame

/// The full-width row above the board: the scores, what is asked now, the dice and the menu. Its height never changes.
struct GameHeader: View {
    let vm: GameViewModel
    let screen: ScreenState
    /// Narrow screens shrink each chip to its dot and score, and give the status line its own row.
    let compact: Bool
    let onNewGame: () -> Void

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 6) {
                ForEach(screen.scoreboard, id: \.name) { chip($0) }
                if compact { Spacer(minLength: 0) } else { status }
                dice
                menu
            }
            if compact { status }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private func chip(_ row: ScoreRow) -> some View {
        HStack(spacing: 4) {
            SeatDot(seat: row.seat)
            Text(compact ? "\(row.points)" : "\(row.name) \(row.score)")
                .font(.callout.monospacedDigit())
                .fontWeight(row.isCurrent ? .bold : .regular)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(.quaternary.opacity(0.5), in: Capsule())
        .overlay(Capsule().stroke(.primary, lineWidth: row.isCurrent ? 2 : 0))
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(row.name), \(row.score)")
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
            ForEach(Array(screen.dice.enumerated()), id: \.offset) { _, face in DieView(face: face) }
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
