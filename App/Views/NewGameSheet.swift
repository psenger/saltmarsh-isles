import SwiftUI
import SaltmarshEngine

/// Choose the player count and who plays each seat. Defaults: 3 players, Crimson human, the rest Mate.
struct NewGameSheet: View {
    /// Shown under the title, for example when the last game was set aside after a crash.
    var note: String? = nil
    let onStart: (GameConfig) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var count = 3
    @State private var isAI = [false, true, true, true]
    @State private var levels = [EffortLevel](repeating: .mate, count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Saltmarsh Isles").font(.title2.bold())
            if let note { Text(note).font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
            Picker("Players", selection: $count) {
                ForEach(2...4, id: \.self) { Text("\($0)").tag($0) }
            }
            .pickerStyle(.segmented)
            ForEach(Array(Seat.allCases.prefix(count)), id: \.self) { seat in
                seatRow(seat)
            }
            HStack {
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Start game", action: start)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("Start game")
            }
        }
        .padding(20)
        #if os(macOS)
        .frame(width: 460)
        #endif
    }

    private func seatRow(_ seat: Seat) -> some View {
        let i = seat.rawValue
        return HStack {
            SeatDot(seat: seat)
            Text(seat.name).frame(width: 64, alignment: .leading)
            Picker(seat.name, selection: $isAI[i]) {
                Text("Human").tag(false)
                Text("AI").tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            Picker("Effort", selection: $levels[i]) {
                ForEach(EffortLevel.allCases, id: \.self) { Text($0.name).tag($0) }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .fixedSize()
            .disabled(!isAI[i])
        }
    }

    private func start() {
        let controllers = Seat.allCases.prefix(count).map { seat -> Controller in
            isAI[seat.rawValue] ? .ai(levels[seat.rawValue]) : .human
        }
        onStart(GameConfig(controllers: controllers, seed: UInt64.random(in: 1...UInt64.max)))
    }
}
