import SwiftUI
import SaltmarshEngine

/// First visible piece of the app: a generated board with a button for another one.
struct BoardPreviewScreen: View {
    @State private var seed: UInt64 = 1
    @State private var board: Board = BoardPreviewScreen.generate(seed: 1)

    var body: some View {
        VStack(spacing: 12) {
            BoardView(board: board, robberTile: board.desertTile)
                .padding(8)
            HStack(spacing: 16) {
                Text("Board \(seed)")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                Button("New board") {
                    seed = UInt64.random(in: 1..<1_000_000)
                    board = Self.generate(seed: seed)
                }
                .keyboardShortcut("n", modifiers: .command)
                .accessibilityIdentifier("New board")
            }
            .padding(.bottom, 12)
        }
        .frame(minWidth: 360, minHeight: 360)
        .background(Color(hex: 0x24414b).opacity(0.08))
    }

    private static func generate(seed: UInt64) -> Board {
        var rng = SeededRNG(seed: seed)
        return BoardGenerator.generate(using: &rng)
    }
}
