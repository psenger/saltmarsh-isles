import SwiftUI
import SaltmarshEngine
import SaltmarshGame

/// The win screen and its preview. Nothing here depends on animation: under Reduce Motion there is no confetti schedule.
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
            if let schedule = card.confetti {
                Confetti(schedule: schedule, seat: card.seat)
            }
        }
    }
}

/// Pieces thrown from the schedule's bursts, falling under gravity with drag and a sideways flutter.
/// Each position is worked out from the time alone. A full-screen layer that ignores touches, gone after six seconds.
private struct Confetti: View {
    let schedule: ConfettiSchedule
    let seat: Seat

    private enum Shape: CaseIterable { case rectangle, streamer, dot }

    private struct Piece {
        var delay: Double, x: Double, y: Double, vx: Double, vy: Double
        var spin: Double, tumble: Double, phase: Double, flutter: Double
        var color: Color, shape: Shape
    }

    private static let lifetime = 6.0, drag = 1.8, gravity = 700.0

    @State private var pieces: [Piece] = []
    @State private var start = Date()
    @State private var finished = false

    private func makePieces() -> [Piece] {
        let colors = [Color(seat: seat), Color(hex: 0xf2c94c), .white] + Resource.allCases.map(BoardView.fill(for:))
        return schedule.bursts.flatMap { burst in
            (0..<burst.pieces).map { _ in
                // Angles in degrees, where -90 is straight up. The corners fire up and inward.
                let (x, y, angle, speed): (Double, Double, Double, Double) = switch burst.origin {
                case "bottom-left": (0, 1, .random(in: -80 ... -45), .random(in: 700...1500))
                case "bottom-right": (1, 1, .random(in: -135 ... -100), .random(in: 700...1500))
                default: (0.5, 0.45, .random(in: -180...0), .random(in: 200...950))
                }
                let radians = angle * .pi / 180
                return Piece(delay: burst.delay, x: x, y: y, vx: speed * cos(radians), vy: speed * sin(radians),
                             spin: .random(in: -6...6), tumble: .random(in: 3...9), phase: .random(in: 0...(2 * .pi)), flutter: .random(in: 10...30),
                             color: colors.randomElement()!, shape: Shape.allCases.randomElement()!)
            }
        }
    }

    private func draw(_ piece: Piece, at elapsed: Double, in context: GraphicsContext, size: CGSize) {
        let t = elapsed - piece.delay
        guard t > 0 else { return }
        let slowed = (1 - exp(-Self.drag * t)) / Self.drag
        let x = piece.x * size.width + piece.vx * slowed + sin(piece.phase + t * 4) * piece.flutter * min(t, 1)
        let fall = Self.gravity / Self.drag
        let y = piece.y * size.height + (piece.vy - fall) * slowed + fall * t
        guard y < size.height + 20 else { return }
        var c = context
        c.translateBy(x: x, y: y)
        c.rotate(by: .radians(piece.spin * t))
        switch piece.shape {
        case .rectangle:
            c.scaleBy(x: cos(piece.tumble * t), y: 1)
            c.fill(Path(CGRect(x: -3, y: -5, width: 6, height: 10)), with: .color(piece.color))
        case .streamer:
            c.fill(Path(CGRect(x: -1.25, y: -9, width: 2.5, height: 18)), with: .color(piece.color))
        case .dot:
            c.fill(Path(ellipseIn: CGRect(x: -3, y: -3, width: 6, height: 6)), with: .color(piece.color))
        }
    }

    var body: some View {
        // Read here, not only in the Canvas, so that setting them in onAppear redraws this view.
        let thrown = pieces, began = start
        if !finished {
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    let elapsed = timeline.date.timeIntervalSince(began)
                    context.opacity = min(1, max(0, Self.lifetime - elapsed))
                    for piece in thrown { draw(piece, at: elapsed, in: context, size: size) }
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear {
                pieces = makePieces()
                start = .now
            }
            .task {
                try? await Task.sleep(for: .seconds(Self.lifetime))
                if !Task.isCancelled { finished = true }
            }
        }
    }
}
