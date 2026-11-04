import SwiftUI
import SaltmarshGame

/// The whole game: owns the view model, resumes on launch, and lays out board and panel.
struct GameScreen: View {
    @State private var vm = GameViewModel(
        store: FileGameStore(directory: URL.applicationSupportDirectory.appending(path: "SaltmarshIsles")),
        pacing: RealPacing())
    @State private var showNewGame = false

    var body: some View {
        let screen = vm.screen
        GeometryReader { geometry in
            let board = BoardView(screen: screen) { x, y in vm.tapBoard(x: x, y: y) }.padding(6)
            let panel = GamePanel(vm: vm, screen: screen) { showNewGame = true }
            if geometry.size.width > geometry.size.height {
                HStack(spacing: 0) {
                    board.frame(maxWidth: .infinity, maxHeight: .infinity)
                    panel.frame(width: min(420, geometry.size.width * 0.45))
                }
            } else {
                VStack(spacing: 0) {
                    board
                    panel
                }
            }
        }
        .overlay {
            if let card = screen.victory {
                VictoryOverlay(card: card, onClose: vm.dismissOverlay) { showNewGame = true }
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
        #if os(macOS)
        .frame(minWidth: 760, minHeight: 520)
        #endif
    }
}
