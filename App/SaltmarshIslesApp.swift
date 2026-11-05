import SwiftUI
#if os(macOS)
import SaltmarshGame
#endif

@main
struct SaltmarshIslesApp: App {
    var body: some Scene {
        WindowGroup("Saltmarsh Isles") {
            GameScreen()
        }
        #if os(macOS)
        .defaultSize(width: 1100, height: 720)
        .commands { GameCommands() }
        #endif
    }
}

#if os(macOS)
/// The File, Help and debug menus. Replacing the new item also removes New Window, so a second
/// window cannot write to the same automatic save.
private struct GameCommands: Commands {
    @FocusedValue(\.gameActions) private var actions

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button(Strings.newGameMenu) { actions?.newGame() }
                .keyboardShortcut("n")
                .disabled(actions == nil)
            Button(Strings.loadGame) { actions?.loadGame() }
                .keyboardShortcut("o")
                .disabled(actions == nil)
        }
        CommandGroup(replacing: .saveItem) {
            Button(Strings.saveGame) { actions?.saveGame() }
                .keyboardShortcut("s")
                .disabled(actions?.canSave != true)
        }
        // Opens the help book named in Info.plist, built by `make help`. Its pages stay blank unless
        // the app runs from an Applications folder, so use `make run` rather than Cmd-R to check it.
        CommandGroup(replacing: .help) {
            Button(Help.bookTitle) { NSApp.showHelp(nil) }
                .keyboardShortcut("?", modifiers: .command)
        }
        #if DEBUG
        CommandMenu("Debug") {
            Button(Strings.previewWin) { actions?.previewWin() }
                .disabled(actions?.canPreview != true)
            Button(Strings.previewLose) { actions?.previewLose() }
                .disabled(actions?.canPreview != true)
        }
        #endif
    }
}
#endif
