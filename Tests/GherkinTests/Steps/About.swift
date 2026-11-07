import Foundation
@testable import SaltmarshGame

/// Rule: About the game
@MainActor
func registerAbout(_ r: StepRegistry) {
    var info: [String: Any] = [:]
    r.given(#"the app is version "([^"]*)", build "([^"]*)", built "([^"]*)""#) { _, c, _ in
        info = ["CFBundleShortVersionString": c[0], "CFBundleVersion": c[1], About.builtKey: c[2]]
    }
    r.given(#"the app is version "([^"]*)", build "([^"]*)", with no build date"#) { _, c, _ in
        info = ["CFBundleShortVersionString": c[0], "CFBundleVersion": c[1]]
    }
    r.then(#"About reads "([^"]*)""#) { _, c, _ in
        try expectEqual(About.lines(info: info), c[0].components(separatedBy: "; "), "About lines")
    }
}
