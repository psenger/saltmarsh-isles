import SwiftUI
import SaltmarshGame

/// The win screen and its preview. Confetti waits for Plan 5; nothing here depends on animation.
struct VictoryOverlay: View {
    let card: VictoryCard
    let onClose: () -> Void
    let onNewGame: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 10) {
                Text(card.title).font(.caption.bold()).textCase(.uppercase).foregroundStyle(.secondary)
                Text(card.winner).font(.title.bold()).foregroundStyle(Color(seat: card.seat))
                Text(card.subtitle).font(.callout).multilineTextAlignment(.center)
                VStack(spacing: 2) {
                    ForEach(card.breakdown, id: \.label) { row in
                        HStack {
                            Text(row.label)
                            Spacer()
                            Text("\(row.points)").monospacedDigit()
                        }
                    }
                    Divider()
                    HStack {
                        Text("Total").bold()
                        Spacer()
                        Text("\(card.total)").monospacedDigit().bold()
                    }
                }
                Text(card.banner).font(.callout).multilineTextAlignment(.center)
                HStack {
                    ForEach(card.buttons, id: \.self) { label in
                        if label == Strings.newGame {
                            Button(label, action: onNewGame)
                                .buttonStyle(.borderedProminent)
                                .accessibilityIdentifier("Victory \(label)")
                        } else {
                            Button(label, action: onClose)
                                .buttonStyle(.bordered)
                                .keyboardShortcut(.cancelAction)
                        }
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: 340)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding(16)
        }
    }
}
