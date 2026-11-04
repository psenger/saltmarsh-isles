import SwiftUI

@main
struct SaltmarshIslesApp: App {
    var body: some Scene {
        WindowGroup("Saltmarsh Isles") {
            GameScreen()
        }
        #if os(macOS)
        .defaultSize(width: 1100, height: 720)
        #endif
    }
}
