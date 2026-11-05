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
        .commands {
            // Opens the help book named in Info.plist, built by `make help`. Its pages stay blank unless
            // the app runs from an Applications folder, so use `make run` rather than Cmd-R to check it.
            CommandGroup(replacing: .help) {
                Button(Help.bookTitle) { NSApp.showHelp(nil) }
                    .keyboardShortcut("?", modifiers: .command)
            }
        }
        #endif
    }
}
