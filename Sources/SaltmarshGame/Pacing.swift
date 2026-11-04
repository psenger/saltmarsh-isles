/// The pause between AI actions so a human can follow the board and the log.
/// The app injects a real delay; tests inject none.
public protocol Pacing: Sendable {
    func pause() async
}

public struct NoPacing: Pacing {
    public init() {}
    public func pause() async {}
}

public struct RealPacing: Pacing {
    public var seconds: Double

    public init(seconds: Double = 0.5) {
        self.seconds = seconds
    }

    public func pause() async {
        try? await Task.sleep(for: .seconds(seconds))
    }
}
