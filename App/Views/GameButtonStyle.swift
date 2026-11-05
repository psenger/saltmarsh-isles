import SwiftUI
import SaltmarshEngine

/// The game's solid button. Its size never depends on whether it is enabled, so nothing moves when it greys out.
struct GameButtonStyle: ButtonStyle {
    /// The sea from the board.
    static let sea = Color(hex: 0x3f6472)
    static let ink = Color(hex: 0x1d2a30)
    static let amber = Color(hex: 0xd68910)

    var fill = GameButtonStyle.sea
    var horizontalPadding: CGFloat = 10

    func makeBody(configuration: Configuration) -> some View {
        Face(configuration: configuration, fill: fill, horizontalPadding: horizontalPadding)
    }

    private struct Face: View {
        let configuration: Configuration
        let fill: Color
        let horizontalPadding: CGFloat
        @Environment(\.isEnabled) private var enabled

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: 8)
            configuration.label
                .foregroundStyle(enabled ? Color.white : Color.secondary)
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, 6)
                .background(enabled ? fill : Color.secondary.opacity(0.15), in: shape)
                .overlay(shape.stroke(.black.opacity(enabled ? 0.3 : 0.08), lineWidth: 1))
                .shadow(color: .black.opacity(enabled ? 0.25 : 0), radius: 1, y: 1)
                .opacity(configuration.isPressed ? 0.75 : 1)
        }
    }
}

/// What something costs: one small box per resource in its board colour, with the number inside.
/// Stays in full colour on a greyed button, because that is when the player needs to know.
struct CostChips: View {
    let cost: ResourceCounts

    var body: some View {
        HStack(spacing: 2) {
            ForEach(cost.nonZero, id: \.0) { resource, amount in
                Text("\(amount)")
                    .font(.caption2.monospacedDigit().bold())
                    .foregroundStyle(ResourceBox.ink(for: resource))
                    .frame(width: 16, height: 16)
                    .background(BoardView.fill(for: resource), in: RoundedRectangle(cornerRadius: 3))
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(.black.opacity(0.35), lineWidth: 0.5))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("costs \(cost.description)")
    }
}
