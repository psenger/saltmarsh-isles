/// Assembles every step group into one registry.
@MainActor
enum StepLibrary {
    static func make() -> StepRegistry {
        let r = StepRegistry()
        for register in groups { register(r) }
        return r
    }

    /// One entry per `Steps/*.swift` file.
    static let groups: [@MainActor (StepRegistry) -> Void] = [
        registerCommon, registerStarting, registerFirstRoll, registerBoard, registerSetup,
        registerTurn, registerSevens, registerRobber, registerBuilding,
        registerTrading, registerDevCards,
    ]

    /// Rules whose steps exist. The runner skips the others until Plan 3 Task 13 covers every rule.
    nonisolated static let coveredRules: Set<String> = [
        "Starting a new game", "Choosing who goes first", "The board is generated fairly", "Setup uses snake order",
        "Rolling and production", "Rolling a 7 makes players over 7 cards discard half, chosen by them",
        "Moving the robber and stealing", "Building", "Ending the turn",
        "Trading with the bank at 4 for 1", "Trading at captured harbours", "Trading with other players",
        "The bank can run out", "Development cards",
    ]
}
