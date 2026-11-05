import SwiftUI
import SaltmarshGame

/// The whole game: owns the view model, resumes on launch, and lays out header, board and panel.
struct GameScreen: View {
    @State private var vm = GameViewModel(
        store: FileGameStore(directory: URL.applicationSupportDirectory.appending(path: "SaltmarshIsles")),
        pacing: RealPacing())
    @State private var showNewGame = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let screen = vm.screen
        Group {
            // Nothing of the game is drawn behind a handover, so it cannot show through.
            if let handover = screen.handover {
                HandoverView(handover: handover, onReveal: vm.revealHand)
            } else {
                game(screen)
                    .overlay {
                        if let card = screen.victory {
                            VictoryOverlay(card: card, onClose: vm.dismissOverlay) { showNewGame = true }
                        }
                    }
            }
        }
        .sheet(isPresented: $showNewGame) {
            NewGameSheet { config in
                vm.newGame(config)
                showNewGame = false
            }
        }
        .task {
            if vm.state == nil, !vm.resume() { showNewGame = true }
        }
        .onChange(of: scenePhase) { _, phase in
            #if os(macOS)
            if phase == .background { vm.concealHand() }
            #else
            // Inactive comes before the app switcher takes its snapshot.
            if phase != .active { vm.concealHand() }
            #endif
        }
        #if os(macOS)
        .frame(minWidth: 760, minHeight: 520)
        #endif
    }

    private func game(_ screen: ScreenState) -> some View {
        GeometryReader { geometry in
            let size = geometry.size
            let board = BoardView(screen: screen) { x, y in vm.tapBoard(x: x, y: y) }.padding(6)
            let panel = GamePanel(vm: vm, screen: screen)
            VStack(spacing: 0) {
                GameHeader(vm: vm, screen: screen, compactChips: size.width < 600 || size.height < 500, statusOnOwnRow: size.width < 600) { showNewGame = true }
                Divider()
                if size.width > size.height {
                    HStack(spacing: 0) {
                        board.frame(maxWidth: .infinity, maxHeight: .infinity)
                        Divider()
                        panel.frame(width: min(420, size.width * 0.45))
                    }
                } else {
                    board.frame(maxWidth: .infinity).frame(height: size.height * 0.36)
                    Divider()
                    panel
                }
            }
        }
    }
}
