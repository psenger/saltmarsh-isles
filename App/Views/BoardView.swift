import SwiftUI
import SaltmarshEngine

/// Draws a board in the prototype's style: sea hexagon, terrain tiles, number discs with pips,
/// harbour jetties and discs, and the robber. Scales the 680 × 600 board space to fit.
struct BoardView: View {
    let board: Board
    let robberTile: Int

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width / Board.size.width, size.height / Board.size.height)
            context.translateBy(x: size.width / 2, y: size.height / 2)
            context.scaleBy(x: scale, y: scale)
            drawSea(&context)
            drawHarbours(&context)
            drawTiles(&context)
            drawRobber(&context)
        }
        .aspectRatio(Board.size.width / Board.size.height, contentMode: .fit)
        .accessibilityIdentifier("board")
    }

    // MARK: Palette (from the prototype's stylesheet)

    private static let sea = Color(hex: 0x4f7f8f), seaDeep = Color(hex: 0x3b6573)
    private static let token = Color(hex: 0xf4efe2), ink = Color(hex: 0x1d2a30)
    private static let hot = Color(hex: 0xb3261e), jetty = Color(hex: 0xc9b79a), dunes = Color(hex: 0x6b5a33)

    private static func fill(for terrain: Terrain) -> Color {
        switch terrain {
        case .desert: Color(hex: 0xd9c79e)
        case .land(let r): fill(for: r)
        }
    }

    private static func fill(for resource: Resource) -> Color {
        switch resource {
        case .timber: Color(hex: 0x3f6b3a)
        case .clay: Color(hex: 0xb5643c)
        case .wool: Color(hex: 0x9cc46a)
        case .grain: Color(hex: 0xe0b84a)
        case .ore: Color(hex: 0x7d8794)
        }
    }

    // MARK: Layers

    private func point(_ corner: Int) -> CGPoint {
        CGPoint(x: board.corners[corner].point.x, y: board.corners[corner].point.y)
    }

    private func drawSea(_ context: inout GraphicsContext) {
        var path = Path()
        for i in 0..<6 {
            let a = Double(60 * i) * .pi / 180
            let p = CGPoint(x: Board.seaRadius * cos(a), y: Board.seaRadius * sin(a))
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        context.fill(path, with: .color(Self.sea))
        context.stroke(path, with: .color(Self.seaDeep), style: StrokeStyle(lineWidth: 6, lineJoin: .round))
    }

    private func drawHarbours(_ context: inout GraphicsContext) {
        for harbour in board.harbours {
            let centre = CGPoint(x: harbour.position.x, y: harbour.position.y)
            for corner in [harbour.a, harbour.b] {
                var jetty = Path()
                jetty.move(to: centre)
                jetty.addLine(to: point(corner))
                context.stroke(jetty, with: .color(Self.jetty), style: StrokeStyle(lineWidth: 5, lineCap: .round))
            }
            let disc = Path(ellipseIn: CGRect(x: centre.x - 17, y: centre.y - 17, width: 34, height: 34))
            let fill: Color, darkText: Bool, label: String?
            switch harbour.kind {
            case .any:
                fill = Self.token; darkText = true; label = nil
            case .specific(let r):
                fill = Self.fill(for: r); darkText = r == .grain || r == .wool; label = r.rawValue.uppercased()
            }
            context.fill(disc, with: .color(fill))
            context.stroke(disc, with: .color(Self.ink), lineWidth: 1.5)
            let textColor = darkText ? Self.ink : Color.white
            let ratio = Text("\(harbour.ratio):1").font(.system(size: label == nil ? 13 : 12, weight: .heavy, design: .serif)).foregroundStyle(textColor)
            context.draw(ratio, at: CGPoint(x: centre.x, y: centre.y + (label == nil ? 0 : -3)))
            if let label {
                let name = Text(label).font(.system(size: 6.5, weight: .semibold)).foregroundStyle(textColor)
                context.draw(name, at: CGPoint(x: centre.x, y: centre.y + 8))
            }
        }
    }

    private func drawTiles(_ context: inout GraphicsContext) {
        for (index, tile) in board.tiles.enumerated() {
            var hex = Path()
            for (i, corner) in tile.corners.enumerated() {
                if i == 0 { hex.move(to: point(corner)) } else { hex.addLine(to: point(corner)) }
            }
            hex.closeSubpath()
            context.fill(hex, with: .color(Self.fill(for: tile.terrain)))
            context.stroke(hex, with: .color(Self.seaDeep), lineWidth: 2)

            let centre = CGPoint(x: tile.center.x, y: tile.center.y)
            let hasRobber = index == robberTile
            if let number = tile.number {
                // The robber takes the centre, so the disc shrinks and slides down out of its way.
                var disc = context
                disc.translateBy(x: centre.x, y: hasRobber ? centre.y + 31 : centre.y)
                if hasRobber { disc.scaleBy(x: 0.72, y: 0.72); disc.opacity = 0.85 }
                let hot = number == 6 || number == 8
                let circle = Path(ellipseIn: CGRect(x: -19, y: -19, width: 38, height: 38))
                disc.fill(circle, with: .color(Self.token))
                disc.stroke(circle, with: .color(.black.opacity(0.25)), lineWidth: 1)
                let colour = hot ? Self.hot : Self.ink
                disc.draw(Text("\(number)").font(.system(size: 17, weight: .heavy, design: .serif)).foregroundStyle(colour), at: CGPoint(x: 0, y: -1))
                let pips = Board.pips(number)
                for i in 0..<pips {
                    let x = (Double(i) - Double(pips - 1) / 2) * 4
                    disc.fill(Path(ellipseIn: CGRect(x: x - 1.4, y: 12 - 1.4, width: 2.8, height: 2.8)), with: .color(colour))
                }
            } else {
                let label = Text("DUNES").font(.system(size: 11, weight: .semibold)).foregroundStyle(Self.dunes)
                context.draw(label, at: CGPoint(x: centre.x, y: centre.y + (hasRobber ? 28 : 0)))
            }
        }
    }

    private func drawRobber(_ context: inout GraphicsContext) {
        guard board.tiles.indices.contains(robberTile) else { return }
        let t = board.tiles[robberTile]
        let x = t.center.x, y = t.center.y - 0.68
        context.fill(Path(ellipseIn: CGRect(x: x - 10, y: y + 8.5, width: 20, height: 7)), with: .color(.black.opacity(0.35)))
        var body = Path()
        body.move(to: CGPoint(x: x - 8, y: y + 12))
        body.addQuadCurve(to: CGPoint(x: x - 4, y: y - 3), control: CGPoint(x: x - 7, y: y))
        body.addArc(center: CGPoint(x: x, y: y - 7.5), radius: 6, startAngle: .degrees(143), endAngle: .degrees(37), clockwise: false)
        body.addQuadCurve(to: CGPoint(x: x + 8, y: y + 12), control: CGPoint(x: x + 7, y: y))
        body.closeSubpath()
        context.fill(body, with: .color(Color(hex: 0x22272b)))
        context.stroke(body, with: .color(Color(hex: 0xf4efe2)), lineWidth: 1.5)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xff) / 255, green: Double((hex >> 8) & 0xff) / 255, blue: Double(hex & 0xff) / 255)
    }
}
