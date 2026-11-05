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
        .accessibilityLabel(value.map { "Die showing \($0)" } ?? "Die not rolled")
    }
}
