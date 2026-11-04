# Plan 3: Game layer and Gherkin runner Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (this repo's subagent dispatches hang on permission prompts; see the master plan's Execution notes) to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Everything between the rules engine and the views: a view model that owns a game, drives AI seats, autosaves and resumes; a render model (`ScreenState`) that exposes every string and piece of render intent the feature file names; and a Gherkin runner that executes `saltmarsh-isles.feature` directly under `swift test`.

**Architecture:** `SaltmarshGame` (library) holds `GameViewModel` (`@MainActor @Observable`), `ScreenState`, `TurnRunner`, `GameStore`/`Pacing`. `SaltmarshAI` gets its `Opponent` protocol now with a seeded `RandomOpponent` stand-in so AI seats work end to end before Plan 2 replaces the brain. A new non-test library `SaltmarshTestSupport` exposes the engine's test-only state mutators to every test target without touching the app. `GherkinTests` parses the feature file, expands outlines, and runs each scenario as a parameterised Swift Testing case through step closures that drive the view model and assert on `ScreenState`.

**Tech Stack:** Swift 6, Swift Testing, Foundation (`NSRegularExpression`), no third-party packages.

**Spec:** `docs/superpowers/specs/2026-11-02-saltmarsh-native-design.md` (sections 4, 5.1 to 5.4, 6.1, 6.5, 6.6, 7, 8, 9) and `docs/superpowers/plans/2026-11-02-saltmarsh-native-plan.md` (Global Constraints, Corrections for the feature file).

## Global Constraints

- Swift 6 language mode; minimum iOS 17.0 and macOS 14.0; one multiplatform app target.
- No network calls, no API keys, no third-party dependencies.
- Seats are fixed: Crimson `#c0392b`, Cobalt `#2a5db0`, Amber `#d68910`, Ivory `#ece6d6`, in that order; player index equals seat index.
- Costs: road 1 timber 1 clay; settlement 1 timber 1 clay 1 wool 1 grain; city 2 grain 3 ore; dev card 1 wool 1 grain 1 ore. Points: settlement 1, city 2, longest road 2, largest army 2, victory point card 1. Win at 10 on your own turn.
- Piece limits 5 settlements, 4 cities, 15 roads. Bank 19 of each resource. Dev deck 14 Knight, 5 Victory point, 2 Road crew, 2 Bumper harvest, 2 Corner the market.
- Log lines and screen strings are exact copies of the feature file's quoted text. Resource lists are written "3 timber, 1 clay" in the order timber, clay, wool, grain, ore.
- The AI receives only `PlayerView`; the live `GameState` never enters `SaltmarshAI`.
- Every randomness source is a `SeededRNG` stored in state; a game is reproducible from its seed and move list.
- Reduce Motion is respected; no animation is load-bearing.
- `saltmarsh.html`, `prototype-tests/*.py` and `media/` are never modified.
- Commit messages carry no `Co-Authored-By` trailer.

## Review Focus

1. An AI seat whose opponent returns a move that is not legal: the view model substitutes a legal move and the game still ends. (Task 4)
2. Relaunching with a saved game whose acting player is an AI: the AI turn restarts from the saved phase without a human tap. (Task 4)
3. A human trade responder who cannot pay the want side: Accept is disabled with the reason, Decline works, and the device passes to the next responder in seat order. (Task 5, Task 7)
4. The discard picker when the player holds exactly 8 cards of one resource: the counter reaches "4 / 4", every "+" is disabled, and confirm applies a legal discard. (Task 5)
5. A scenario step the registry does not know: the scenario fails naming the step text, and never passes silently. (Task 8)

---

## File structure

```
Package.swift                               + SaltmarshTestSupport target; test targets depend on it
Sources/SaltmarshTestSupport/
  GameState+TestSupport.swift               public mutators moved from Tests/EngineTests/Helpers.swift
  TestGames.swift                           public fresh/afterSetup/rolled/midGame/randomGame
Sources/SaltmarshAI/
  Opponent.swift                            protocol Opponent, OpponentFactory
  RandomOpponent.swift                      actor RandomOpponent (seeded, kind-uniform)
  MoveResolver.swift                        safety net
Sources/SaltmarshGame/
  GameStore.swift                           protocol + InMemoryGameStore
  Pacing.swift                              protocol + NoPacing + RealPacing
  UIState.swift                             BuildMode, discard picks, offer builder, overlay
  GameViewModel.swift                       @MainActor @Observable
  TurnRunner.swift                          AI driving loop (used by the view model)
  ScreenState.swift                         the render model
  ScreenState+Derive.swift                  GameViewModel.screen
  Strings.swift                             every status/header/button string in one place
Tests/EngineTests/Helpers.swift             now only `@testable import` shims, or deleted
Tests/AITests/                              RandomOpponentTests, BoundaryTests
Tests/GameTests/                            new test target: ViewModelTests, ScreenStateTests, StoreTests
Tests/GherkinTests/
  GherkinParser.swift, StepRegistry.swift, World.swift, FeatureTests.swift, ParserTests.swift
  Steps/Starting.swift, Board.swift, Setup.swift, Turn.swift, Sevens.swift, Building.swift,
        Trading.swift, DevCards.swift, Awards.swift, Winning.swift, Victory.swift, NewRules.swift
saltmarsh-isles.feature                     updated per design section 9
```

---

### Task 1: Shared test support library

**Files:**
- Modify: `Package.swift`
- Create: `Sources/SaltmarshTestSupport/GameState+TestSupport.swift`, `Sources/SaltmarshTestSupport/TestGames.swift`
- Modify: `Tests/EngineTests/Helpers.swift` (delete; every test file adds `import SaltmarshTestSupport`)

**Interfaces:**
- Produces: library target `SaltmarshTestSupport` (depends on `SaltmarshEngine`, not a product the app links). `public extension GameState` with the mutators now in `Tests/EngineTests/Helpers.swift`: `force(roll:)`, `set(hand:for:)`, `clearHands()`, `clearBoard()`, `place(settlement:owner:)`, `place(city:owner:)`, `place(road:owner:)`, `tile(numbered:)`, `corner(onTileNumbered:index:)`, `chain(from:length:avoiding:)`, `firstChain(length:avoiding:startWhere:)`, `placeChain(_:owner:)`, `spreadCorners(_:avoiding:)`, `addReach(from:owner:)`. `public enum TestGames` with `fresh`, `afterSetup`, `rolled`, `midGame`, `randomGame` unchanged in behaviour. Test targets `EngineTests`, `AITests`, `GameTests` (new), `GherkinTests` depend on it.

- [ ] **Step 1: Move the code**, make every helper `public`, add the target and dependencies, replace `@testable import SaltmarshEngine` plus the deleted file with `import SaltmarshTestSupport` where helpers are used (keep `@testable import SaltmarshEngine` for internal engine calls such as `Engine.produce`).
- [ ] **Step 2: Run** `swift test --filter EngineTests` — Expected: the same 129 tests pass (the move is behaviour-neutral; a failing compile is the test).
- [ ] **Step 3: Commit** — `git add -A && git commit -m "test: move engine test helpers into SaltmarshTestSupport"`

---

### Task 2: Opponent protocol, random stand-in and the safety net

**Files:**
- Create: `Sources/SaltmarshAI/Opponent.swift`, `RandomOpponent.swift`, `MoveResolver.swift`
- Delete: `Sources/SaltmarshAI/Placeholder.swift`
- Test: `Tests/AITests/RandomOpponentTests.swift`, `Tests/AITests/BoundaryTests.swift` (delete `Placeholder.swift`)

**Interfaces:**
- Produces:
  - `public protocol Opponent: Sendable { func chooseMove(view: PlayerView, legal: [Move]) async -> Move; func respondToTrade(_ offer: TradeOffer, view: PlayerView) async -> TradeResponse }`
  - `public actor RandomOpponent: Opponent { public init(seed: UInt64) }`: picks a move kind uniformly then a move of that kind uniformly (same rule as `TestGames.randomGame`, kind = enum case name) using its own `SeededRNG`; `respondToTrade` returns `.accepted` when `view.hand.contains(offer.want)` and a coin flip says yes, else `.declined`; never counters.
  - `public enum MoveResolver { public static func resolve(_ proposed: Move, legal: [Move], fallback: () -> Move? = { nil }) -> Move }`: `proposed` when legal, else `fallback()` when that is legal, else `legal[0]`; `precondition(!legal.isEmpty)`.
  - `public enum OpponentFactory { public static func make(level: EffortLevel, seed: UInt64) -> any Opponent }`: every level returns `RandomOpponent` until Plan 2.

- [ ] **Step 1: Write the failing tests**

```swift
@Suite struct RandomOpponentTests {
    @Test func drivesSeededGamesToTheEnd() async throws {
        var ended = 0
        for seed in 0..<10 {
            var s = Engine.newGame(GameConfig(controllers: [.ai(.mate), .ai(.mate), .ai(.mate)], seed: UInt64(seed)))
            let bots = (0..<3).map { RandomOpponent(seed: UInt64(seed * 10 + $0)) }
            for _ in 0..<6000 {
                if case .gameOver = s.phase { ended += 1; break }
                let p = Engine.actingPlayer(s), legal = Engine.legalMoves(s)
                let m = await bots[p].chooseMove(view: Engine.view(s, for: p), legal: legal)
                #expect(legal.contains(m)); try Engine.apply(m, to: &s)
            }
        }
        #expect(ended > 0)
    }
    @Test func sameSeedSameChoice() async {
        let s = TestGames.rolled(8); let v = Engine.view(s, for: 0), legal = Engine.legalMoves(s)
        let a = await RandomOpponent(seed: 4).chooseMove(view: v, legal: legal), b = await RandomOpponent(seed: 4).chooseMove(view: v, legal: legal)
        #expect(a == b)
    }
    @Test func resolverFallsBack() {
        #expect(MoveResolver.resolve(.endTurn, legal: [.roll]) == .roll)
        #expect(MoveResolver.resolve(.endTurn, legal: [.roll, .playKnight], fallback: { .playKnight }) == .playKnight)
        #expect(MoveResolver.resolve(.roll, legal: [.roll, .playKnight], fallback: { .playKnight }) == .roll)
    }
}
@Suite struct BoundaryTests {
    @Test func aiSourcesNeverMentionGameState() throws {
        let dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Sources/SaltmarshAI")
        for file in try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) where file.pathExtension == "swift" {
            let code = try String(contentsOf: file, encoding: .utf8).split(separator: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }.joined(separator: "\n")
            #expect(!code.contains("GameState"), "\(file.lastPathComponent) mentions GameState")
        }
    }
}
```

- [ ] **Step 2: Run** `swift test --filter AITests` — Expected: compile errors (`RandomOpponent` missing).
- [ ] **Step 3: Implement** the three files.
- [ ] **Step 4: Run** — Expected: 4 tests pass.
- [ ] **Step 5: Commit** — `git commit -am "feat(ai): Opponent protocol, seeded RandomOpponent and MoveResolver"` (after `git add -A`).

---

### Task 3: Store and pacing

**Files:**
- Create: `Sources/SaltmarshGame/GameStore.swift`, `Sources/SaltmarshGame/Pacing.swift`; delete `Placeholder.swift`
- Modify: `Package.swift` (add test target `GameTests` depending on `SaltmarshGame`, `SaltmarshAI`, `SaltmarshTestSupport`)
- Test: `Tests/GameTests/StoreTests.swift`

**Interfaces:**
- Produces: `public protocol GameStore: AnyObject { func save(_ state: GameState) throws; func load() throws -> GameState?; func clear() throws }`; `public final class InMemoryGameStore: GameStore { public init(); public private(set) var saveCount: Int }` (holds the last saved state). `public protocol Pacing: Sendable { func pause() async }`; `public struct NoPacing: Pacing`; `public struct RealPacing: Pacing { public init(seconds: Double = 0.5) }` (uses `Task.sleep`).

- [ ] **Step 1: Write the failing test**

```swift
@Suite struct StoreTests {
    @Test func inMemoryRoundTrip() throws {
        let store = InMemoryGameStore(); #expect(try store.load() == nil)
        let s = TestGames.afterSetup(); try store.save(s)
        #expect(try store.load() == s); #expect(store.saveCount == 1)
        try store.clear(); #expect(try store.load() == nil)
    }
}
```

- [ ] **Step 2: Run** `swift test --filter StoreTests` — Expected: compile error. **Step 3: Implement.** **Step 4: Run** — 1 passes.
- [ ] **Step 5: Commit** — `git commit -m "feat(game): GameStore protocol, in-memory store and pacing"`

---

### Task 4: GameViewModel core and the AI turn runner

**Files:**
- Create: `Sources/SaltmarshGame/GameViewModel.swift`, `Sources/SaltmarshGame/TurnRunner.swift`, `Sources/SaltmarshGame/UIState.swift` (the `UIState` struct only; behaviour in Task 5)
- Test: `Tests/GameTests/ViewModelTests.swift`

**Interfaces:**
- Produces:
  - `public struct UIState: Equatable, Sendable { public var buildMode: BuildMode?; public var discardPicks: ResourceCounts; public var offerGive: ResourceCounts; public var offerWant: ResourceCounts; public var offerTarget: Int?; public var overlay: Overlay?; public init() }`, `public enum BuildMode: Equatable, Sendable { case road, settlement, city }`, `public enum Overlay: Equatable, Sendable { case victory(winner: Int), preview(seat: Int) }`.
  - `@MainActor @Observable public final class GameViewModel { public private(set) var state: GameState?; public var ui: UIState; public private(set) var aiThinking: Bool; public init(store: GameStore, pacing: Pacing, opponents: @escaping (Controller, Int) -> (any Opponent)?); public func newGame(_ config: GameConfig); public func resume() -> Bool  /* loads from the store; true when a game was found */; public func apply(_ move: Move) throws  /* human entry: applies, saves, clears build mode and discard picks, then starts AI turns */; public func waitForAI() async  /* tests: awaits the running AI task */ }`. Default `opponents` closure: `{ controller, seat in controller.isAI ? OpponentFactory.make(level: level, seed: seat) : nil }` (seed derived from `state.seed` and seat).
  - `TurnRunner` (internal): `static func step(state: GameState, opponents: [Int: any Opponent]) async -> Move?`: when `Engine.actingPlayer(state)` is an AI seat and the game is not over: in `.tradeOffered` with that seat pending, ask `respondToTrade` and map to `.respondToTrade(seat:, response)` (a counter is validated with `Engine.isLegal`, else `.declined`); otherwise ask `chooseMove(view:legal:)` and pass it through `MoveResolver.resolve` with no fallback. Returns nil when a human must act or the game is over. The view model loops: `while let m = await step(...) { try? apply; save; await pacing.pause() }`, cancellable, `aiThinking` true while looping.
  - Resume: `resume()` loads the store's state; when the acting seat is AI the loop starts at once (Review Focus 2).

- [ ] **Step 1: Write the failing tests**

```swift
@MainActor @Suite struct ViewModelTests {
    func model(_ controllers: [Controller], seed: UInt64 = 1, store: InMemoryGameStore = InMemoryGameStore()) -> GameViewModel {
        let vm = GameViewModel(store: store, pacing: NoPacing()) { c, seat in c.isAI ? RandomOpponent(seed: seed &* 31 &+ UInt64(seat)) : nil }
        vm.newGame(GameConfig(controllers: controllers, seed: seed)); return vm
    }
    @Test func aiOnlyGameRunsToTheEnd() async {
        let vm = model([.ai(.mate), .ai(.mate), .ai(.mate)], seed: 3); await vm.waitForAI()
        if case .gameOver = vm.state!.phase {} else { Issue.record("AI-only game did not finish: \(vm.state!.phase)") }
        #expect(vm.state!.log.last!.contains("wins with"))
    }
    @Test func controlReturnsToTheHuman() async throws {
        let vm = model([.human, .ai(.mate), .ai(.mate)], seed: 2); await vm.waitForAI()
        #expect(Engine.actingPlayer(vm.state!) == 0)                      // AIs rolled for first; human rolls
        while Engine.actingPlayer(vm.state!) == 0, case .rollingForFirst = vm.state!.phase { try vm.apply(.rollForFirst); await vm.waitForAI() }
        while case .setup = vm.state!.phase { try vm.apply(Engine.legalMoves(vm.state!).first!); await vm.waitForAI() }
        #expect(vm.state!.current == vm.state!.firstPlayer)
        if vm.state!.current == 0 { try vm.apply(.roll); await vm.waitForAI(); if case .main = vm.state!.phase { try vm.apply(.endTurn) }; await vm.waitForAI() }
        #expect(Engine.actingPlayer(vm.state!) == 0 || { if case .gameOver = vm.state!.phase { return true } else { return false } }())
        #expect(!vm.aiThinking)
    }
    @Test func savesAfterEveryMoveAndResumes() async throws {
        let store = InMemoryGameStore(); let vm = model([.human, .human, .human], store: store)
        try vm.apply(.rollForFirst); #expect(store.saveCount == 2)         // newGame saves once, the move again
        let again = GameViewModel(store: store, pacing: NoPacing()) { _, _ in nil }
        #expect(again.resume()); #expect(again.state == vm.state)
    }
    @Test func resumeRestartsAnAITurn() async throws {
        let store = InMemoryGameStore(); let vm = model([.ai(.mate), .human, .human], seed: 5, store: store); await vm.waitForAI()
        let saved = try store.load()!; #expect(Engine.actingPlayer(saved) == 1)
        var mid = saved; mid.current = 0; mid.phase = .awaitingRoll; try store.save(mid)   // pretend we quit on the AI's turn
        let again = GameViewModel(store: store, pacing: NoPacing()) { c, seat in c.isAI ? RandomOpponent(seed: 9) : nil }
        #expect(again.resume()); await again.waitForAI()
        #expect(again.state!.turn > mid.turn || Engine.actingPlayer(again.state!) != 0)
    }
    @Test func illegalAIMovesAreResolved() async {                        // Review Focus 1
        struct Stubborn: Opponent { func chooseMove(view: PlayerView, legal: [Move]) async -> Move { .withdrawTrade }; func respondToTrade(_ o: TradeOffer, view: PlayerView) async -> TradeResponse { .declined } }
        let vm = GameViewModel(store: InMemoryGameStore(), pacing: NoPacing()) { _, _ in Stubborn() }
        vm.newGame(GameConfig(controllers: [.ai(.deckhand), .ai(.deckhand)], seed: 1)); await vm.waitForAI()
        #expect(vm.state!.turn > 0 || { if case .gameOver = vm.state!.phase { return true } else { return false } }())
    }
}
```

`Stubborn` always picks the first legal move after resolution; with `legal[0]` being `.placeSettlement`/`.placeRoad`/`.roll`/… the game advances; the test accepts either a finished game or at least one full turn (random `legal[0]` play can loop on trades: cap the runner at 20 000 AI moves per `waitForAI` and stop with `aiThinking = false`).

- [ ] **Step 2: Run** `swift test --filter ViewModelTests` — Expected: compile errors.
- [ ] **Step 3: Implement** `UIState`, `GameViewModel`, `TurnRunner`. `apply` saves through the store after every successful engine move (AI moves included).
- [ ] **Step 4: Run** — Expected: 5 pass; then `swift test` — everything passes.
- [ ] **Step 5: Commit** — `git commit -m "feat(game): GameViewModel with autosave, resume and the AI turn runner"`

---

### Task 5: Human interaction state

**Files:**
- Modify: `Sources/SaltmarshGame/GameViewModel.swift`, `Sources/SaltmarshGame/UIState.swift`
- Test: `Tests/GameTests/InteractionTests.swift`

**Interfaces:**
- Produces, all `public` on `GameViewModel` and each a no-op when the game is over or an AI is acting:
  - Board taps by index (hit-testing from points is the view's job): `tapCorner(_ c: Int)`: setup settlement, `.settlement` mode build, `.city` mode upgrade, or a steal when the corner's owner is a steal candidate; `tapEdge(_ e: Int)`: setup road, `.road` mode build, free road; `tapTile(_ t: Int)`: robber move when legal.
  - `toggleBuildMode(_ m: BuildMode)` (tapping the active mode clears it; modes clear after any applied move and at end of turn), `rollForFirst()`, `rollDice()`, `endTurn()`, `bankTrade(give:get:)`, `harbourTrade(_ h: Int, give:get:)`, `buyCard()`, `playCard(_ index: Int, bumper: (Resource, Resource)? = nil, market: Resource? = nil)` (maps the held card at `index` to the engine move), `steal(from:)`.
  - Discards: `discardAdjust(_ r: Resource, by delta: Int)` clamps to `0...hand[r]` and to the required count; `confirmDiscard()` applies `.discard(ui.discardPicks)` only when the count matches.
  - Player trade: `offerAdjust(give r: Resource, by:)`, `offerAdjust(want r: Resource, by:)`, `offerTarget(_ seat: Int?)`, `proposeOffer()` (applies `.proposeTrade` when `Engine.validate` is nil, then resets the builder), `respondToOffer(accept: Bool)` (for the acting human responder), `executeTrade(with:)`, `withdrawOffer()`.
  - Overlay: `showPreviewWin()` sets `ui.overlay = .preview(seat: current)`; `dismissOverlay()`; a win sets `.victory(winner:)` automatically when the phase becomes `.gameOver`.
  - `public var canConfirmDiscard: Bool`, `public var discardRequired: Int`, `public func offerProblem() -> String?` (the `Engine.validate` reason).

- [ ] **Step 1: Write the failing tests** (humans only, `NoPacing`; `vm.state` is replaced through a test-only `public func load(_ s: GameState)` that saves and clears UI state):

```swift
@MainActor @Suite struct InteractionTests {
    func humans() -> GameViewModel { let vm = GameViewModel(store: InMemoryGameStore(), pacing: NoPacing()) { _, _ in nil }; vm.newGame(GameConfig(controllers: [.human, .human, .human], seed: 1)); return vm }
    @Test func buildModeTogglesAndClears() throws {
        let vm = humans(); var s = TestGames.rolled(8); s.clearBoard(); s.clearHands(); s.place(settlement: 0, owner: 0); s.set(hand: Cost.road, for: 0); vm.load(s)
        vm.toggleBuildMode(.road); #expect(vm.ui.buildMode == .road); vm.toggleBuildMode(.road); #expect(vm.ui.buildMode == nil)
        vm.toggleBuildMode(.road); let e = vm.state!.board.corners[0].edges[0]; vm.tapEdge(e)
        #expect(vm.state!.board.edges[e].owner == 0); #expect(vm.ui.buildMode == nil)
    }
    @Test func discardPickerClamps() {                                    // Review Focus 4
        let vm = humans(); var s = TestGames.afterSetup(); s.clearHands(); s.set(hand: [.timber: 8], for: 1); s.current = 0; s.phase = .awaitingRoll; s.force(roll: 7); try! Engine.apply(.roll, to: &s); vm.load(s)
        #expect(vm.discardRequired == 4)
        for _ in 0..<6 { vm.discardAdjust(.timber, by: 1) }; #expect(vm.ui.discardPicks == [.timber: 4]); #expect(vm.canConfirmDiscard)
        vm.discardAdjust(.timber, by: -1); #expect(!vm.canConfirmDiscard); vm.discardAdjust(.clay, by: -1); #expect(vm.ui.discardPicks[.clay] == 0)
        vm.discardAdjust(.timber, by: 1); vm.confirmDiscard(); #expect(vm.state!.players[1].hand == [.timber: 4]); #expect(vm.ui.discardPicks.isEmpty)
    }
    @Test func offerBuilderAndHumanResponse() {                           // Review Focus 3
        let vm = humans(); var s = TestGames.rolled(8); s.clearBoard(); s.clearHands(); s.set(hand: [.timber: 2], for: 0); s.set(hand: [.ore: 1], for: 1); s.set(hand: [.grain: 1], for: 2); vm.load(s)
        vm.offerAdjust(give: .timber, by: 2); #expect(vm.offerProblem() == "want side is empty")
        vm.offerAdjust(want: .ore, by: 1); #expect(vm.offerProblem() == nil); vm.proposeOffer()
        #expect(Engine.actingPlayer(vm.state!) == 1)
        vm.respondToOffer(accept: true); #expect(Engine.actingPlayer(vm.state!) == 2)
        vm.respondToOffer(accept: true)                                   // Amber cannot pay: ignored, stays pending
        #expect(Engine.actingPlayer(vm.state!) == 2); vm.respondToOffer(accept: false)
        #expect(Engine.actingPlayer(vm.state!) == 0); vm.executeTrade(with: 1)
        #expect(vm.state!.players[0].hand == [.ore: 1]); #expect(vm.ui.offerGive.isEmpty)
    }
    @Test func winOpensTheOverlayAndPreviewDoesNot() throws {
        let vm = humans(); var s = TestGames.rolled(8); s.clearBoard(); s.clearHands()
        let spots = s.spreadCorners(6); for c in spots.prefix(3) { s.place(settlement: c, owner: 0) }; for c in spots.dropFirst(3) { s.place(city: c, owner: 0) }
        let reach = s.addReach(from: spots[0], owner: 0); s.set(hand: Cost.settlement, for: 0); vm.load(s)
        vm.showPreviewWin(); #expect(vm.ui.overlay == .preview(seat: 0)); vm.dismissOverlay(); #expect(vm.ui.overlay == nil)
        vm.toggleBuildMode(.settlement); vm.tapCorner(reach)
        #expect(vm.ui.overlay == .victory(winner: 0)); vm.dismissOverlay(); #expect(vm.ui.overlay == nil)
        vm.tapCorner(reach); #expect(vm.state!.phase == .gameOver(winner: 0))  // locked, no crash
    }
}
```

- [ ] **Step 2: Run** `swift test --filter InteractionTests` — Expected: compile errors. **Step 3: Implement.** **Step 4: Run** — 4 pass, then the full suite.
- [ ] **Step 5: Commit** — `git commit -m "feat(game): human interaction state: build modes, discard picker, offer builder, overlay"`

---

### Task 6: ScreenState, panel half

**Files:**
- Create: `Sources/SaltmarshGame/Strings.swift`, `Sources/SaltmarshGame/ScreenState.swift`, `Sources/SaltmarshGame/ScreenState+Derive.swift`
- Test: `Tests/GameTests/ScreenStateTests.swift`

**Interfaces:**
- Produces `public struct ScreenState: Equatable, Sendable` with, in this task:
  - `header: String` ("Crimson · setup" during setup; "Cobalt · discarding" for the discarder; "Cobalt · trade offer" for a human responder; "Crimson · first roll" during the first roll; otherwise the current player's name), `headerSeat: Seat` (whose colour the panel takes), `status: String`, `dice: [String]` (two strings, "–" when nil), `hand: [(Resource, Int)]` as `handCounts: ResourceCounts`, `holdTitle: String` ("Cobalt's hold"), `bank: ResourceCounts`, `log: [String]`, `orderStrip: [Seat]?` with `orderStripNote: String?` ("Round 2: reverse order" during the second half of setup), `buttons: [String: Bool]` (label → enabled) covering every button the feature file names: "Roll dice", "Roll for first", "Road", "Settlement", "City", "End turn", "Buy a card", "Trade 4 for 1", "Offer", "Withdraw", "Accept", "Decline", "Discard N cards" (exact label with the count), "New game", "Preview win", "See the board", "Back to the game", plus `buildLeft: [BuildMode: Int]` ("N left"), `activeBuildMode: BuildMode?`, `deckCount: Int`.
  - `scoreboard: [ScoreRow]` with `ScoreRow { seat, name, colorHex, cards: Int, devCards: Int, road: Int, roadHighlighted: Bool, knights: Int, knightsHighlighted: Bool, score: String /* "N / 10" */, hidden: String? /* "+N" for the current human seat only */ , isCurrent: Bool }`.
  - `aiThinking: Bool` and the status `"<Name> is thinking…"` while an AI acts; the hand shown during an AI turn is the single human seat's when exactly one human exists, otherwise `handCounts` is empty and `holdTitle` is "".
  - Status strings (`Strings.swift`), exact: setup corner "Tap a glowing corner to place a settlement."; setup road "Tap a dashed edge next to it to lay a road."; first roll "Roll for first player." / "<Name> rolled N for first player."; awaiting roll "Roll the dice to start your turn."; main "Build, trade, or end your turn."; road mode "Tap a dashed edge to build a road."; settlement mode "Tap a glowing corner to build a settlement."; city mode "Tap one of your settlements to upgrade it."; discarding "<Roller> rolled 7. <Name> has more than 7 cards and must give up half. Pass the device to <Name>."; robber "Tap a tile to move the robber there."; victim "Steal a card: tap a glowing building on the robber's tile, or a name below."; free roads "Road crew: tap a dashed edge for a free road (N left)."; trade responder "<Proposer> offers <give> for <want>." with the Accept button disabled and `acceptProblem: String?` = "You don't have <want>"; proposer waiting "Waiting for <Name> to answer."; responses in "Answers are in. Trade with someone or withdraw."; game over "Game over.".
- `GameViewModel.screen: ScreenState` (computed, derived from `state`, `ui`, `aiThinking`).

- [ ] **Step 1: Write the failing tests** — one `@Test` per phase asserting `header`, `headerSeat`, `status`, and the enabled set of buttons: fresh game (first roll), setup corner, setup road, awaiting roll (only "Roll dice" and a playable Knight enabled), main after a roll ("Build, trade, or end your turn."; "End turn" enabled; "Roll dice" disabled), discarding (header "Cobalt · discarding", hold title "Cobalt's hold", everything else disabled), robber, victim, free roads "(2 left)", trade responder (Accept disabled with `acceptProblem` when they cannot pay), game over ("Game over.", every button disabled except "New game"/"See the board"), AI thinking. Plus `scoreboard`: row strings "N / 10", hidden "+1" only on the current human's row, badges highlighted for award holders.
- [ ] **Step 2: Run** — compile errors. **Step 3: Implement.** **Step 4: Run** — all pass; full suite.
- [ ] **Step 5: Commit** — `git commit -m "feat(game): ScreenState panel strings, buttons and scoreboard"`

---

### Task 7: ScreenState, board intent and sub-panels

**Files:**
- Modify: `Sources/SaltmarshGame/ScreenState.swift`, `ScreenState+Derive.swift`
- Test: `Tests/GameTests/ScreenIntentTests.swift`

**Interfaces:**
- Produces on `ScreenState`:
  - Board intent: `glowingCorners: Set<Int>`, `dashedEdges: Set<Int>`, `selectableTiles: Set<Int>`, `pulsingSettlements: Set<Int>` (city mode), `hotNumbers: Set<Int>` (always {6, 8}), `hitNumber: Int?` (the last roll's total while `dice` is set, nil on a 7), `stealTargets: [StealTarget]` with `StealTarget { seat, name, cards: Int, corners: Set<Int> /* glowing buildings */ }`, `robberTile: Int`, `numberDiscBelowRobber: Bool`, `desertLabelBelowRobber: Bool`, `harbourRings: [Int: [Seat]]` (harbour index → owners in seat order), `championCorners: Set<Int>` (the winner's buildings glow gold after a win), `pieces` are read from `board` directly (`board: Board` is included).
  - `discardBox: DiscardBox?` `{ title: String /* "Cobalt, pick 4 cards to give up" */, counter: String /* "0 / 4" */, rows: [(Resource, picked: Int, held: Int)] as `[DiscardRow]` with `label: String /* "0 of N" */, plusEnabled, minusEnabled`, next: String? /* "Next: Amber" */, confirmLabel: String /* "Discard 4 cards" */, confirmEnabled: Bool, outlineSeat: Seat }`.
  - `harbours: HarboursPanel` `{ emptyText: String? /* "None yet. Build a settlement on a corner joined to a harbour by a jetty." */, rows: [HarbourRow] }` with `HarbourRow { index, title: String /* "3:1 any" or "2:1 grain" */, heldBy: String, giveFixed: String? /* "2 wool" */, tradeLabel: String /* "Trade 2 for 1" */, tradeEnabled: Bool /* with the row's selected give/get */ }`; the view model keeps a per-row `(give, get)` selection in `ui.harbourChoice: [Int: (Resource, Resource)]` and a bank choice `ui.bankChoice: (give: Resource, get: Resource)`; `bankTradeEnabled: Bool`, `bankTitle` = "Trade with bank, 4 for 1".
  - `devCards: [DevCardRow]` `{ index, name: String /* displayName */, note: String? /* "bought this turn", "one card per turn", "counts automatically" */, playEnabled: Bool, needsChoices: Bool }`, `buyLabel: String /* "Buy a card (N left)" */`.
  - `tradeSection: TradeSection` `{ offerGive, offerWant: ResourceCounts, target: Int?, targets: [Seat], offerEnabled: Bool, offerProblem: String?, responses: [(seat: Seat, text: String /* "accepted", "declined", "countered: 1 ore for 3 timber" */, canTrade: Bool)] }`.
  - `victory: VictoryCard?` `{ title: String /* "Victory" | "Preview" */, winner: String /* "Crimson wins" */, seat: Seat, subtitle: String /* "Rules the isles after N rounds." | "This is what the win screen looks like. The game carries on." */, breakdown: [(String, Int)] (only sources worth more than 0: "Settlements", "Cities", "Longest road", "Largest army", "Victory point cards"), total: Int, banner: String /* "Crimson rules the isles with 10 points." */, buttons: [String] /* ["See the board", "New game"] or ["Back to the game"] */ , confetti: ConfettiSchedule? }` with `ConfettiSchedule { bursts: [(delay: Double, origin: String /* "centre" | "bottom-left" | "bottom-right" */, pieces: Int)] }` = centre 170 at 0, both corners 90 at 0, then two smaller (60) bursts at 0.55; `victoryAnimation: VictoryAnimation` = `.full` or `.reduced` from an injected `reduceMotion: Bool` on the view model (default false). Rounds = `turn / playerCount + 1`.

- [ ] **Step 1: Write the failing tests** — glow set equals the engine's legal settlement corners in setup and settlement mode; dashed set equals legal road edges in setup road, road mode and free roads; selectable tiles exclude the robber's tile; `hitNumber` after rolling 8 is 8 and nil after a 7; steal targets list names and card counts with glowing corners on the robber tile; discard box strings for the Cobalt 9-card case ("Cobalt, pick 4 cards to give up", "0 / 4", rows only for held resources, "Next: Amber"); harbour rows for the three feature cases; dev card notes for the three cases; trade section responses text; victory card for a settlement win with the breakdown rows and confetti schedule; preview card; `.reduced` with `reduceMotion = true` carries no confetti.
- [ ] **Step 2: Run** — compile errors. **Step 3: Implement.** **Step 4: Run** — all pass; full suite.
- [ ] **Step 5: Commit** — `git commit -m "feat(game): ScreenState board intent, discard box, harbours, cards, trade and victory"`

---

### Task 8: Gherkin parser and step registry

**Files:**
- Create: `Tests/GherkinTests/GherkinParser.swift`, `Tests/GherkinTests/StepRegistry.swift`, `Tests/GherkinTests/ParserTests.swift`; delete `Placeholder.swift`
- Modify: `Package.swift` (`GherkinTests` depends on `SaltmarshGame`, `SaltmarshAI`, `SaltmarshTestSupport`; resources none, the feature file is read by path)

**Interfaces:**
- Produces:
  - `struct Feature { var name: String; var background: [Step]; var rules: [Rule] }`, `struct Rule { var name: String; var background: [Step]; var scenarios: [Scenario] }`, `struct Scenario: CustomTestStringConvertible { var name: String; var rule: String; var tags: Set<String>; var steps: [Step]; var line: Int; var testDescription: String { "\(rule) / \(name)" } }`, `struct Step { var keyword: String /* Given/When/Then; And/But resolve to the previous */; var text: String; var table: [[String]]?; var line: Int }`.
  - `enum GherkinParser { static func parse(_ text: String) throws -> Feature }`: supports `Feature`, `Rule`, `Background` at both levels, `Scenario`, `Scenario Outline` + `Examples` (expanded into one `Scenario` per row with `<name>` substitution in the step text and the scenario name suffixed " (row N)"), tags (`@ui`) on scenarios and outlines, `#` comments, `|` data tables, blank lines. Errors on a step before any scenario, an `Examples` without a table, or an unknown keyword.
  - `final class StepRegistry { func given/when/then(_ pattern: String, _ body: @escaping (World, [String], [[String]]?) throws -> Void) ; func run(_ step: Step, in world: World) throws }`: a pattern is a regex matched anchored to the whole step text; `run` throws `StepError.unmatched(text)` when nothing matches and `StepError.ambiguous` when two do (Review Focus 5).
  - `World` (Task 10) is `@MainActor final class World { let vm: GameViewModel; var store: InMemoryGameStore; var remembered: [String: Any] }`.
- [ ] **Step 1: Write the failing tests**: parsing the real file yields 16 rules and 89 scenarios before expansion and the expected count after (count `Examples` rows: 3 + 5 + 3 + 2 + 6 + 3 + 3 + 5 = 30 rows replacing 8 outlines → 111 scenarios; assert the number the parser reports and fix the expectation to the true count once computed, recording it in the ledger); a rule-level `Background` is prepended to every scenario in that rule after the feature background; a `@ui` tag lands in `tags`; a data table parses into rows of trimmed cells; an unmatched step throws `unmatched` naming the text.
- [ ] **Step 2: Run** `swift test --filter ParserTests` — compile errors. **Step 3: Implement.** **Step 4: Run** — pass.
- [ ] **Step 5: Commit** — `git commit -m "test(gherkin): feature file parser and step registry"`

---

### Task 9: Update the feature file for the native app

**Files:**
- Modify: `saltmarsh-isles.feature`
- Modify: `Tests/GherkinTests/ParserTests.swift` (counts)

Changes, per design section 9 and the master plan's Corrections:
- Header comment: "Matches the native app (SaltmarshCore) and saltmarsh-isles-spec.md."
- Feature Background: `Given a new 3-player game with human seats` (the runner creates a seeded game, no first-roll yet).
- Rule "Starting a new game": "The page opens on a fresh 3-player game" → "A new game starts with the first-player roll" (header "Crimson · first roll", status "Roll for first player.", log "New game with 3 players. Everyone rolls for first player."); the outline keeps its examples with `When I start a <count>-player game`; "Starting a new game closes the win screen" stays.
- New Rule "Choosing who goes first" (after Starting): highest roll goes first ("Crimson rolled 9 for first player." / "<Name> goes first. Place your first settlement."), a tie re-rolls among the tied ("Tie between Crimson and Amber. Roll again."), the order strip shows the placement order from the winner, "Setup done. <Name> rolls first." uses the winner.
- Rule "Setup uses snake order": the outline's `order` keeps Crimson first by forcing Crimson to win the first roll (`Given Crimson won the first roll`); "Setup done. Crimson rolls first." stays.
- Visual scenarios reworded to render intent: "6 and 8 are drawn in red" → "the number discs 6 and 8 are marked hot"; "number discs showing 8 are ringed in the accent colour" → "the number discs showing 8 are marked hit"; "every tile except the robber's current tile has a white outline" → "every tile except the robber's current tile is selectable"; "the robber's centre sits on that tile's centre" → "the robber is on that tile"; "that tile's number disc shrinks and moves below the robber" → "that tile's number disc is marked as sitting below the robber"; "the 'DUNES' label sits below the robber" → "the desert label is marked as sitting below the robber"; "Cobalt's buildings on that tile glow" → "are steal targets"; "Crimson's settlements pulse" → "are marked pulsing"; harbour "has a ring in Crimson's colour" → "carries a Crimson ring"; "Crimson's settlements and cities glow gold and pulse" → "are marked as the champion's"; victory: "a full-screen overlay appears over a blurred board" → "the victory card is showing"; "confetti bursts from the centre and from both bottom corners, then again 0.55 seconds later" → "the confetti schedule has a centre burst, two corner cannons and a second wave 0.55 seconds later"; "Crimson's 'Road' badge is highlighted" keeps its wording (ScreenState has the flag).
- `@ui` on: "The win screen is hidden at load", "Reduce Motion" (both stay as written), and "Closing the win screen" gets a sibling: the Escape half moves to a `@ui` scenario "Escape closes the win screen"; the "See the board" half stays.
- "Reaching 10 points on your own turn wins immediately": `| 8 | builds a city |` → `| 9 | builds a city |`.
- "Each player's row": add "and the current player's hidden victory points as '+N'".
- New Rule "Trading with other players" (after "Trading at captured harbours"): offer builder validity ("Offer" disabled until both sides hold a card, same resource both sides, cannot pay); proposing to everyone ("Crimson offers 2 timber for 1 ore."); human responder panel (header "Cobalt · trade offer", status "Crimson offers 2 timber for 1 ore.", "Accept" disabled with "You don't have 1 ore" when they cannot pay, hand not shown); responders answered one at a time in seat order; closing ("Cobalt accepted the offer.", "Trade with Cobalt" button, "Crimson traded 2 timber with Cobalt for 1 ore."); withdraw ("Crimson withdrew the offer."); unanswerable ("Nobody can answer that offer."); AI counter shown as "countered: 1 ore for 3 timber".
- New Rule "The bank can run out": bank row shows five counts starting at 19; one owed player takes the remainder ("Bank is out of ore."); two owed get nothing; "Trade 4 for 1" disabled for a resource the bank lacks; Bumper harvest pair unavailable.
- New Rule "Piece limits": build buttons show "N left"; the sixth settlement is not offered (button disabled at "0 left"); a city frees a settlement piece; Road crew with one piece left ("No roads left to build.").
- New Rule "Playing against AI seats": new game sheet rows (Human/AI, effort names Deckhand … Admiral); an AI turn runs by itself and control returns ("<Name> is thinking…" status, controls disabled); with one human the human's hand stays visible during AI turns, with two humans no hand shows; an AI never shows "+N"; an AI responds to an offer at once; an AI may propose and the human sees Accept/Decline.
- Every scenario keeps its intent; none is dropped. Update the parser test's counts.

- [ ] **Step 1: Edit the file.** **Step 2: Run** `swift test --filter ParserTests` and update the asserted counts to the new truth (record them in the ledger). **Step 3: Commit** — `git commit -m "docs(feature): native background, first-player roll, player trading, bank limits, piece limits, AI seats"`

---

### Task 10: World, FeatureTests and the first step groups (starting, board, first player, setup)

**Files:**
- Create: `Tests/GherkinTests/World.swift`, `Tests/GherkinTests/FeatureTests.swift`, `Tests/GherkinTests/Steps/Starting.swift`, `Steps/Board.swift`, `Steps/FirstRoll.swift`, `Steps/Setup.swift`

**Interfaces:**
- `World`: `vm` (NoPacing, `InMemoryGameStore`, `reduceMotion` settable, opponents from `OpponentFactory`), `var screen: ScreenState { vm.screen }`, `func load(_ s: GameState)`, `var state: GameState`, helpers `seat(_ name: String) -> Int`, `resources(_ list: String) -> ResourceCounts` ("1 timber, 1 clay and 1 wool" / "3 timber and 1 clay" / "4 timber"), `func give(_ seat: Int, _ hand: ResourceCounts)`, `func forceRoll(_ n: Int)`, `func reachMain(for seat: Int)` (loads `TestGames.rolled(8)` with cleared board and hands, current = seat), `remembered` values ("the chosen tile", "that corner").
- `FeatureTests`: `@Test(arguments: try scenarios())` where `scenarios()` parses `<repo>/saltmarsh-isles.feature` (path from `#filePath`), skips `@ui`; each case builds a fresh `World`, runs background steps then scenario steps through one shared `StepRegistry` assembled from every `Steps/*.swift` `register(_ r: StepRegistry)` function; any thrown `StepError` or engine error fails the case with the step text and line.
- Step groups in this task cover Rules "Starting a new game", "Choosing who goes first", "The board is generated fairly", "Setup uses snake order". Engine-level facts ("the board has 19 tiles…", balancing over 200 boards, harbour layout) are checked through `Engine`/`BoardGenerator` directly inside the step, everything user-visible through `ScreenState`.

- [ ] **Step 1: Write FeatureTests and run it** — Expected: every scenario fails `unmatched` (RED), listing step texts.
- [ ] **Step 2: Implement** World and the four step files until those four rules pass: `swift test --filter FeatureTests` shows failures only in rules not yet covered.
- [ ] **Step 3: Commit** — `git commit -m "test(gherkin): runner, world and steps for starting, first roll, board and setup"`

---

### Task 11: Steps for rolling, sevens, robber, building

**Files:** `Tests/GherkinTests/Steps/Turn.swift`, `Sevens.swift`, `Robber.swift`, `Building.swift`

Covers Rules "Rolling and production", "Rolling a 7 …", "Moving the robber and stealing", "Building". Backgrounds like "setup is complete and it is Crimson's turn" load `TestGames.afterSetup()` (first roll forced so Crimson wins) with cleared board and hands unless a step says otherwise; "Cobalt has a settlement and Amber has a city on a tile numbered 8" uses `place(...)` on `tile(numbered: 8)`; taps go through `vm.tapCorner/tapEdge/tapTile`; "the panel shows 'Steal from Cobalt' with '5 cards'" reads `screen.stealTargets`.

- [ ] **Step 1: Run** `swift test --filter FeatureTests` — note the failing scenarios in these rules (RED). **Step 2: Implement** until they pass. **Step 3: Commit** — `git commit -m "test(gherkin): steps for rolling, sevens, robber and building"`

---

### Task 12: Steps for trading and development cards

**Files:** `Tests/GherkinTests/Steps/Trading.swift` (bank, harbours, players, bank runs out), `Steps/DevCards.swift`

Harbour setup steps place buildings on `board.harbours[i].a/b` for a harbour of the named kind; "chooses timber to give and ore to get" sets `ui.bankChoice` / `ui.harbourChoice[row]`; dev card steps append `DevCard`s with `boughtOnTurn` set as the step says and read `screen.devCards` notes; the Knight scenarios chain `playCard`, `tapTile`, `steal`.

- [ ] **Step 1: RED run. Step 2: Implement. Step 3: Commit** — `git commit -m "test(gherkin): steps for bank, harbour and player trading and development cards"`

---

### Task 13: Steps for awards, scoreboard, winning, victory screen, ending the turn, piece limits, AI seats

**Files:** `Tests/GherkinTests/Steps/Awards.swift`, `Winning.swift`, `Victory.swift`, `NewRules.swift`

Road chains use `firstChain`/`placeChain`; "Crimson has <start> points" builds the `crimson(settlements:cities:)` layout from `WinTests` for 8 and 9; the victory steps read `screen.victory` and `screen.championCorners`; "the device has Reduce Motion turned on" sets `world.vm.reduceMotion = true`; AI-seat steps create games with `.ai(.mate)` controllers and `await vm.waitForAI()` (steps may be `async`; the registry's body type becomes `(World, [String], [[String]]?) async throws -> Void`).

- [ ] **Step 1: RED run. Step 2: Implement until `swift test --filter FeatureTests` passes every non-`@ui` scenario.** **Step 3: Commit** — `git commit -m "test(gherkin): steps for awards, winning, victory, end of turn, piece limits and AI seats"`

---

### Task 14: Label coverage and plan completion

**Files:**
- Test: `Tests/GameTests/LabelCoverageTests.swift`

- [ ] **Step 1:** a test that extracts every double-quoted string from the feature file's `Then`/`And` lines that name a button, header, status or log, and asserts each appears either verbatim in `Strings.swift`, as a `buttons` key the view model can produce, or in the engine's log vocabulary (a small allow-list for parameterised fragments such as "Discard N cards"). Expected: passes; any miss is a missing string, not an allow-list addition.
- [ ] **Step 2:** `swift test` — every suite passes; note counts and time. `xcodegen generate && xcodebuild … macOS build` — succeeds (the app still only shows the board preview).
- [ ] **Step 3:** Self-review against design sections 4, 5, 6.1, 6.5, 6.6, 7, 8 and this plan's Interfaces blocks; ledger findings.
- [ ] **Step 4:** Update the master plan's Roadmap: Plan 3 → done with the scenario count. Commit `docs: mark plan 3 complete`.
