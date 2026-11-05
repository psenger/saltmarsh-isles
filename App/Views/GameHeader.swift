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
    let actions: GameActions

    #if !os(macOS)
    @State private var showHelp = false
    #endif

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 6) {
                ForEach(screen.scoreboard, id: \.name) { chip($0) }
                if statusOnOwnRow { Spacer(minLength: 0) } else { status }
                dice
                #if !os(macOS)
                menu
                #endif
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

    #if !os(macOS)
    /// These devices have no menu bar, so this holds what the File and Help menus hold on a Mac.
    private var menu: some View {
        Menu {
            Button(Strings.newGameMenu, action: actions.newGame)
            Button(Strings.loadGame, action: actions.loadGame)
            Button(Strings.saveGame, action: actions.saveGame).disabled(!actions.canSave)
            Button(Strings.howToPlay) { showHelp = true }
            #if DEBUG
            Button(Strings.previewWin, action: actions.previewWin).disabled(!actions.canPreview)
            Button(Strings.previewLose, action: actions.previewLose).disabled(!actions.canPreview)
            #endif
        } label: {
            Text(Strings.gameMenu).font(.callout.weight(.semibold))
        }
        .fixedSize()
        .accessibilityIdentifier("menu")
        .sheet(isPresented: $showHelp) { HelpSheet() }
    }
    #endif
}

#if !os(macOS)
/// The rules on devices without Apple's Help Viewer: an index of topics with a search box.
private struct HelpSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List(Help.search(query), id: \.title) { section in
                NavigationLink(section.title) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(section.lines, id: \.self) { Text($0).fixedSize(horizontal: false, vertical: true) }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                    }
                    .navigationTitle(section.title)
                }
            }
            .searchable(text: $query, prompt: "Search help")
            .navigationTitle("How to play")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("help done")
                }
            }
        }
    }
}
#endif
