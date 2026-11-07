import SwiftUI
import SaltmarshGame

/// What the game menu can do, from the File menu on Mac or the Game button on iPhone and iPad.
struct GameActions {
    var newGame: () -> Void, loadGame: () -> Void, saveGame: () -> Void
    var previewWin: () -> Void, previewLose: () -> Void
    var canSave: Bool, canPreview: Bool
}

struct GameActionsKey: FocusedValueKey {
    typealias Value = GameActions
}

extension FocusedValues {
    var gameActions: GameActions? {
        get { self[GameActionsKey.self] }
        set { self[GameActionsKey.self] = newValue }
    }
}

private enum GameSheet: String, Identifiable {
    case newGame, load, save
    var id: String { rawValue }
}

/// The whole game: owns the view model, resumes on launch, and lays out header, board and panel.
struct GameScreen: View {
    @State private var vm: GameViewModel = {
        let folder = URL.applicationSupportDirectory.appending(path: "SaltmarshIsles")
        return GameViewModel(store: FileGameStore(directory: folder), pacing: RealPacing(),
                             saves: FileSaveSlots(directory: folder.appending(path: "saves")))
    }()
    @State private var sheet: GameSheet?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                            VictoryOverlay(card: card, onClose: vm.dismissOverlay) { sheet = .newGame }
                        }
                    }
            }
        }
        .sheet(item: $sheet) { kind in
            switch kind {
            case .newGame:
                NewGameSheet(note: vm.setAsideSave == nil ? nil : Strings.setAsideNote) { config in
                    vm.newGame(config)
                    sheet = nil
                }
            case .load: LoadGameSheet(vm: vm)
            case .save: SaveGameSheet(vm: vm)
            }
        }
        .focusedSceneValue(\.gameActions, actions(screen))
        .task {
            if vm.state == nil, !vm.resume() { sheet = .newGame }
        }
        .onChange(of: reduceMotion, initial: true) { _, on in vm.reduceMotion = on }
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

    private func actions(_ screen: ScreenState) -> GameActions {
        GameActions(newGame: { sheet = .newGame }, loadGame: { sheet = .load }, saveGame: { sheet = .save },
                    previewWin: { vm.showPreviewWin() }, previewLose: { vm.showPreviewLose() },
                    canSave: vm.state != nil && screen.buttons[Strings.saveGame] == true,
                    canPreview: screen.buttons[Strings.previewWin] == true)
    }

    private func game(_ screen: ScreenState) -> some View {
        GeometryReader { geometry in
            let size = geometry.size
            let board = BoardView(screen: screen, payingTiles: vm.payingTiles, rolls: vm.rollCount) { x, y in vm.tapBoard(x: x, y: y) }.padding(6)
            let panel = GamePanel(vm: vm, screen: screen)
            VStack(spacing: 0) {
                GameHeader(vm: vm, screen: screen, compactChips: size.width < 600 || size.height < 500, statusOnOwnRow: size.width < 600, actions: actions(screen))
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
