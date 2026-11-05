import SwiftUI
import SaltmarshEngine
import SaltmarshGame

/// The blank screen between two humans. Nothing of the game is drawn with it.
struct HandoverView: View {
    let handover: Handover
    let onReveal: () -> Void

    var body: some View {
        ZStack {
            Color(hex: 0x1d2a30).ignoresSafeArea()
            VStack(spacing: 16) {
                Text(handover.message).foregroundStyle(.white.opacity(0.8))
                Button(action: onReveal) {
                    Text(handover.button)
                        .bold()
                        .foregroundStyle(handover.seat == .ivory ? Color(hex: 0x1d2a30) : .white)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(Color(seat: handover.seat))
                .accessibilityIdentifier("handover")
            }
        }
    }
}
