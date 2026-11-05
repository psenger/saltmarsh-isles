import SwiftUI

/// One die with pips. Any face other than 1 to 6 means not rolled: an empty dashed outline in the same place.
struct DieView: View {
    let face: String

    private static let ink = Color(hex: 0x1d2a30)
    private static let (low, mid, high): (CGFloat, CGFloat, CGFloat) = (0.3, 0.5, 0.7)

    private static func pips(_ n: Int) -> [CGPoint] {
        let (l, m, h) = (low, mid, high)
        switch n {
        case 1: return [CGPoint(x: m, y: m)]
        case 2: return [CGPoint(x: l, y: l), CGPoint(x: h, y: h)]
        case 3: return [CGPoint(x: l, y: l), CGPoint(x: m, y: m), CGPoint(x: h, y: h)]
        case 4: return [CGPoint(x: l, y: l), CGPoint(x: h, y: l), CGPoint(x: l, y: h), CGPoint(x: h, y: h)]
        case 5: return pips(4) + [CGPoint(x: m, y: m)]
        default: return pips(4) + [CGPoint(x: l, y: m), CGPoint(x: h, y: m)]
        }
    }

    var body: some View {
        let value = Int(face)
        let shape = RoundedRectangle(cornerRadius: 6)
        Group {
            if let value {
                shape.fill(Color(hex: 0xfbf8f0))
                    .overlay(shape.stroke(Self.ink, lineWidth: 1.5))
                    .overlay {
                        Canvas { context, size in
                            for pip in Self.pips(value) {
                                let r = size.width * 0.09
                                let rect = CGRect(x: pip.x * size.width - r, y: pip.y * size.height - r, width: 2 * r, height: 2 * r)
                                context.fill(Path(ellipseIn: rect), with: .color(Self.ink))
                            }
                        }
                    }
            } else {
                shape.stroke(.secondary, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
            }
        }
        .frame(width: 28, height: 28)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.label(face))
    }

    static func label(_ face: String) -> String {
        Int(face).map { "Die showing \($0)" } ?? "Die not rolled"
    }
}

/// A die that tumbles each time `rolls` changes, then lands on `face`. Only visual transforms move, so
/// nothing around it shifts. The roll is already decided: this changes what is drawn and nothing else.
struct RollingDie: View {
    let face: String
    /// The die's place in the pair. The second tumbles the other way and lands a moment after the first.
    let index: Int
    let rolls: Int

    /// Seconds from the roll until the slower die lands. Payout animations wait this long.
    static let landingTime = 0.72

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Tumble {
        var flip = 0.0, spin = 0.0, lift = 0.0, scale = 1.0
    }

    private static let halfTurns = 6.0

    /// The real face shows for the last half turn. Before that, each half turn shows another face, changing while the die is edge-on.
    private func drawnFace(flip: Double) -> String {
        let halfTurn = Int((-flip + 90) / 180)
        return halfTurn == 0 ? face : String(((rolls + index) * 7 + halfTurn * 5) % 6 + 1)
    }

    var body: some View {
        Group {
            if reduceMotion {
                DieView(face: face)
            } else {
                tumbling
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(DieView.label(face))
    }

    private var tumbling: some View {
        let duration = 0.6 + 0.12 * Double(index)
        let direction = index == 0 ? 1.0 : -1.0
        let flips = 180 * Self.halfTurns
        return KeyframeAnimator(initialValue: Tumble(), trigger: rolls) { tumble in
            DieView(face: drawnFace(flip: tumble.flip))
                .rotation3DEffect(.degrees(tumble.flip), axis: (x: 1, y: 0.6 * direction, z: 0))
                .rotationEffect(.degrees(tumble.spin))
                .scaleEffect(tumble.scale)
                .offset(y: tumble.lift)
        } keyframes: { _ in
            // Starting at twice the average speed makes the die slow down as it lands.
            KeyframeTrack(\.flip) {
                MoveKeyframe(-flips)
                CubicKeyframe(0, duration: duration, startVelocity: 2 * flips / duration)
            }
            KeyframeTrack(\.spin) {
                MoveKeyframe(-360 * direction)
                CubicKeyframe(0, duration: duration, startVelocity: 2 * 360 * direction / duration)
            }
            KeyframeTrack(\.lift) {
                CubicKeyframe(-10, duration: 0.18)
                CubicKeyframe(0, duration: 0.18)
                CubicKeyframe(-4, duration: 0.1)
                CubicKeyframe(0, duration: duration - 0.46)
            }
            KeyframeTrack(\.scale) {
                CubicKeyframe(1.35, duration: 0.18)
                CubicKeyframe(1, duration: duration - 0.18)
            }
        }
    }
}
