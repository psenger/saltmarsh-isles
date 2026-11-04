/// Assembles every step group into one registry.
@MainActor
enum StepLibrary {
    static func make() -> StepRegistry {
        let r = StepRegistry()
        for register in groups { register(r) }
        return r
    }

    /// One entry per `Steps/*.swift` file.
    static let groups: [@MainActor (StepRegistry) -> Void] = []
}
