# Saltmarsh Isles Plan 1: Scaffold and Engine (Phases 0, 1, 2)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A buildable package and Xcode project, and a complete, pure, seedable rules engine for Saltmarsh Isles including the four new rules (first-player roll, bank supply, piece limits, player trading), the redacted `PlayerView`, hidden-state sampling, invariants and replay.

**Architecture:** `SaltmarshEngine` is a library of value types plus a stateless `Engine` namespace. `GameState` is `Codable`, `Equatable` and `Sendable`; `Engine.legalMoves` enumerates every legal `Move` for the acting player and `Engine.apply` mutates or throws. Randomness only ever comes from the `SeededRNG` inside the state. Everything else in the package (`SaltmarshAI`, `SaltmarshGame`, `ai-bench`) is a compiling placeholder until later plans.

**Tech Stack:** Swift 6, Swift Package Manager (tools 6.0), Swift Testing, XcodeGen 2.46, Xcode 27.2.

**Spec:** `docs/superpowers/specs/2026-11-02-saltmarsh-native-design.md` sections 4, 5, 6.1 and 8; `saltmarsh-isles-spec.md` sections 1 to 4; `saltmarsh-isles.feature` for exact strings. Global Constraints and Review Focus are in `docs/superpowers/plans/2026-11-02-saltmarsh-native-plan.md` and apply to every task here.

---

## File structure

| File | Responsibility |
|---|---|
| `Package.swift` | targets `SaltmarshEngine`, `SaltmarshAI`, `SaltmarshGame`, `ai-bench`, `EngineTests`, `AITests`, `GherkinTests` |
| `project.yml`, `SaltmarshIsles.xcodeproj` | XcodeGen app + UI test targets |
| `App/SaltmarshIslesApp.swift` | placeholder entry point |
| `AppUITests/LaunchTests.swift` | launch smoke test |
| `Makefile` | `test`, `mac`, `ios` |
| `Sources/SaltmarshEngine/RNG.swift` | `SeededRNG` |
| `Sources/SaltmarshEngine/Resources.swift` | `Resource`, `ResourceCounts`, `Terrain`, `DevCardType`, `DevCard`, `Cost`, `PieceLimit` |
| `Sources/SaltmarshEngine/Seats.swift` | `Seat`, `EffortLevel`, `Controller` |
| `Sources/SaltmarshEngine/Board.swift` | `Point`, `Tile`, `Corner`, `Edge`, `Harbour`, `Board` |
| `Sources/SaltmarshEngine/BoardGenerator.swift` | layout, balancing, harbours, `violations` |
| `Sources/SaltmarshEngine/Trade.swift` | `TradeOffer`, `TradeResponse` |
| `Sources/SaltmarshEngine/Phase.swift` | `Phase` |
| `Sources/SaltmarshEngine/Move.swift` | `Move` |
| `Sources/SaltmarshEngine/GameState.swift` | `Player`, `GameConfig`, `GameState`, derived counts |
| `Sources/SaltmarshEngine/Engine.swift` | `EngineError`, `Engine.newGame`, `legalMoves`, `apply` dispatch, `actingPlayer`, `isLegal` |
| `Sources/SaltmarshEngine/Engine+FirstRoll.swift` | first-player roll |
| `Sources/SaltmarshEngine/Engine+Setup.swift` | snake setup |
| `Sources/SaltmarshEngine/Engine+Turn.swift` | roll, production, discard, robber, steal, end turn |
| `Sources/SaltmarshEngine/Engine+Build.swift` | placement rules, builds, piece limits |
| `Sources/SaltmarshEngine/Engine+Awards.swift` | `roadLength`, `updateAwards` |
| `Sources/SaltmarshEngine/Engine+Trade.swift` | bank, harbour and player trades |
| `Sources/SaltmarshEngine/Engine+DevCards.swift` | buy and play |
| `Sources/SaltmarshEngine/Engine+Scoring.swift` | points, `checkWin`, `capturedHarbours`, `bestRate`, `piecesLeft` |
| `Sources/SaltmarshEngine/Engine+View.swift` | `PlayerView`, `OpponentSummary`, `view`, `sampleFullState` |
| `Sources/SaltmarshEngine/Engine+Invariants.swift` | `invariantViolations`, `replay` |
| `Tests/EngineTests/Helpers.swift` | `TestGames` factories and `GameState` test mutators (defined in Task 8) |
| `Tests/EngineTests/*Tests.swift` | one suite per task |

## Conventions for every task

- Tests use Swift Testing: `import Testing`, `@testable import SaltmarshEngine`, one `@Suite struct` per file.
- Run a single suite with `swift test --filter <SuiteName>`; expected pass output ends with `Test run with N tests passed`.
- All stored properties of engine types are `public var`; all types are `Codable, Equatable, Hashable, Sendable` unless stated. Tests and later layers mutate state directly for setup; no separate test-support module.
- `GameState.log` is append-only, newest last. "The log reads X" means `state.log.last == X`.
- `Engine.apply` throws `EngineError.illegalMove(move)` for anything `legalMoves`/`isLegal` would not allow, except offers which throw `EngineError.invalidOffer(reason)`.
- Commit after each task with a conventional message. No `Co-Authored-By`.

---

### Task 1: Repository, package and Xcode project scaffold (Phase 0)

**Files:**
- Create: `Package.swift`, `project.yml`, `Makefile`
- Create: `Sources/SaltmarshEngine/Engine.swift` (`public enum Engine {}` placeholder, replaced in Task 6)
- Create: `Sources/SaltmarshAI/Placeholder.swift`, `Sources/SaltmarshGame/Placeholder.swift`, `Sources/ai-bench/main.swift`
- Create: `Tests/EngineTests/PackageTests.swift`, `Tests/AITests/Placeholder.swift`, `Tests/GherkinTests/Placeholder.swift`
- Create: `App/SaltmarshIslesApp.swift`, `AppUITests/LaunchTests.swift`

**Interfaces:**
- Produces: the target graph every later task compiles into.

- [x] **Step 1: Initial commit of the existing material** (done when the plans were written)

```bash
git add -A && git commit -m "chore: import web prototype, spec, feature file and design docs"
```

- [ ] **Step 2: Write `Package.swift`**

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SaltmarshCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SaltmarshEngine", targets: ["SaltmarshEngine"]),
        .library(name: "SaltmarshAI", targets: ["SaltmarshAI"]),
        .library(name: "SaltmarshGame", targets: ["SaltmarshGame"]),
        .executable(name: "ai-bench", targets: ["ai-bench"]),
    ],
    targets: [
        .target(name: "SaltmarshEngine"),
        .target(name: "SaltmarshAI", dependencies: ["SaltmarshEngine"]),
        .target(name: "SaltmarshGame", dependencies: ["SaltmarshEngine", "SaltmarshAI"]),
        .executableTarget(name: "ai-bench", dependencies: ["SaltmarshEngine", "SaltmarshAI"]),
        .testTarget(name: "EngineTests", dependencies: ["SaltmarshEngine"]),
        .testTarget(name: "AITests", dependencies: ["SaltmarshEngine", "SaltmarshAI"]),
        .testTarget(name: "GherkinTests", dependencies: ["SaltmarshEngine", "SaltmarshAI", "SaltmarshGame"]),
    ],
    swiftLanguageModes: [.v6]
)
```

- [ ] **Step 3: Write the placeholders**

`Sources/SaltmarshEngine/Engine.swift`: `public enum Engine {}`. `Sources/SaltmarshAI/Placeholder.swift`: `enum AIPlaceholder {}`. `Sources/SaltmarshGame/Placeholder.swift`: `enum GamePlaceholder {}`. `Sources/ai-bench/main.swift`: `print("ai-bench: not implemented yet")`. Each test placeholder: one `@Suite` with one `@Test func placeholder() { #expect(Bool(true)) }`. `Tests/EngineTests/PackageTests.swift`: `@Test func engineModuleLinks() { _ = Engine.self }`.

- [ ] **Step 4: Build and test the package**

Run: `swift build && swift test`
Expected: build succeeds; output ends with `Test run with 4 tests passed`.

- [ ] **Step 5: Write `project.yml`**

```yaml
name: SaltmarshIsles
options:
  bundleIdPrefix: dev.psenger
  deploymentTarget:
    iOS: "17.0"
    macOS: "14.0"
  createIntermediateGroups: true
packages:
  SaltmarshCore:
    path: .
targets:
  SaltmarshIsles:
    type: application
    supportedDestinations: [iOS, macOS]
    sources: [App]
    dependencies:
      - package: SaltmarshCore
        product: SaltmarshEngine
      - package: SaltmarshCore
        product: SaltmarshAI
      - package: SaltmarshCore
        product: SaltmarshGame
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: dev.psenger.SaltmarshIsles
        SWIFT_VERSION: "6.0"
        SWIFT_STRICT_CONCURRENCY: complete
        GENERATE_INFOPLIST_FILE: YES
        INFOPLIST_KEY_UIApplicationSceneManifest_Generation: YES
        INFOPLIST_KEY_UILaunchScreen_Generation: YES
        INFOPLIST_KEY_UISupportedInterfaceOrientations: "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight"
        INFOPLIST_KEY_UISupportedInterfaceOrientations~ipad: "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight"
        TARGETED_DEVICE_FAMILY: "1,2"
        CODE_SIGN_STYLE: Automatic
        CODE_SIGN_IDENTITY: "-"
        ENABLE_PREVIEWS: YES
  AppUITests:
    type: bundle.ui-testing
    supportedDestinations: [iOS, macOS]
    sources: [AppUITests]
    dependencies:
      - target: SaltmarshIsles
    settings:
      base:
        SWIFT_VERSION: "6.0"
        GENERATE_INFOPLIST_FILE: YES
        CODE_SIGN_IDENTITY: "-"
```

`App/SaltmarshIslesApp.swift`:

```swift
import SwiftUI

@main
struct SaltmarshIslesApp: App {
    var body: some Scene {
        WindowGroup { Text("Saltmarsh Isles").font(.largeTitle).padding() }
    }
}
```

`AppUITests/LaunchTests.swift`: an `XCTestCase` with `func testLaunchShowsTitle()` that launches `XCUIApplication()` and asserts `app.staticTexts["Saltmarsh Isles"].waitForExistence(timeout: 10)`.

- [ ] **Step 6: Generate and build the Xcode project**

Run:
```bash
xcodegen generate
xcodebuild -project SaltmarshIsles.xcodeproj -scheme SaltmarshIsles -destination 'platform=macOS' build | tail -3
xcodebuild -project SaltmarshIsles.xcodeproj -scheme SaltmarshIsles -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build | tail -3
```
Expected: both end with `** BUILD SUCCEEDED **`. If macOS signing fails, add `CODE_SIGNING_ALLOWED: "NO"` under the app target's base settings and regenerate.

- [ ] **Step 7: Write `Makefile`**

Targets: `test` runs `swift test` then `xcodebuild test -project SaltmarshIsles.xcodeproj -scheme SaltmarshIsles -destination 'platform=macOS'`; `mac` builds for macOS; `ios` builds for `iPhone 15 Pro` simulator; `project` runs `xcodegen generate`. Use `.PHONY`.

- [ ] **Step 8: Commit**

```bash
git add -A && git commit -m "chore: scaffold SaltmarshCore package and multiplatform Xcode project"
```

---

### Task 2: Seedable random number generator

**Files:**
- Create: `Sources/SaltmarshEngine/RNG.swift`
- Test: `Tests/EngineTests/RNGTests.swift`

**Interfaces:**
- Produces: `public struct SeededRNG: RandomNumberGenerator, Codable, Equatable, Hashable, Sendable { public private(set) var state: UInt64; public init(seed: UInt64); public mutating func next() -> UInt64; public mutating func d6() -> Int }`. SplitMix64. `d6()` returns 1...6 via `Int.random(in: 1...6, using: &self)`.

- [ ] **Step 1: Write the failing tests**

```swift
@Suite struct RNGTests {
    @Test func sameSeedSameSequence() {
        var a = SeededRNG(seed: 42), b = SeededRNG(seed: 42)
        #expect((0..<8).map { _ in a.next() } == (0..<8).map { _ in b.next() })
    }
    @Test func differentSeedsDiffer() {
        var a = SeededRNG(seed: 1), b = SeededRNG(seed: 2)
        #expect(a.next() != b.next())
    }
    @Test func codableRoundTripContinuesSequence() throws {
        var a = SeededRNG(seed: 7); _ = a.next()
        var b = try JSONDecoder().decode(SeededRNG.self, from: JSONEncoder().encode(a))
        #expect(a.next() == b.next())
    }
    @Test func d6InRange() {
        var r = SeededRNG(seed: 3)
        for _ in 0..<1000 { #expect((1...6).contains(r.d6())) }
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter RNGTests` — Expected: compile error, `SeededRNG` not found.

- [ ] **Step 3: Implement `SeededRNG` in `RNG.swift`**

SplitMix64: `state &+= 0x9E3779B97F4A7C15; var z = state; z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9; z = (z ^ (z >> 27)) &* 0x94D049BB133111EB; return z ^ (z >> 31)`.

- [ ] **Step 4: Run to verify pass**

Run: `swift test --filter RNGTests` — Expected: `Test run with 4 tests passed`.

- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(engine): add SplitMix64 SeededRNG"`

---

### Task 3: Resources, cards, costs and seats

**Files:**
- Create: `Sources/SaltmarshEngine/Resources.swift`, `Sources/SaltmarshEngine/Seats.swift`
- Test: `Tests/EngineTests/ResourceTests.swift`

**Interfaces:**
- Produces:
  - `public enum Resource: String, CaseIterable, Codable, Hashable, Sendable, Comparable { case timber, clay, wool, grain, ore }` ordered by `allCases` position.
  - `public struct ResourceCounts: Codable, Equatable, Hashable, Sendable, CustomStringConvertible, ExpressibleByDictionaryLiteral` with `init()`, `init(_: [Resource: Int])`, `static func uniform(_ n: Int) -> ResourceCounts`, `subscript(Resource) -> Int { get set }`, `var total: Int`, `var isEmpty: Bool`, `func contains(_ other: ResourceCounts) -> Bool`, `static func + (ResourceCounts, ResourceCounts) -> ResourceCounts`, `static func - (ResourceCounts, ResourceCounts) -> ResourceCounts`, `var nonZero: [(Resource, Int)]` in `Resource` order, `var description: String` producing `"3 timber, 1 clay"` (empty → `"nothing"`). Storage is a fixed five-element array so zero and missing are the same value.
  - `public enum Terrain: Codable, Hashable, Sendable { case land(Resource), desert }` with `var resource: Resource?`.
  - `public enum DevCardType: String, CaseIterable, Codable, Hashable, Sendable { case knight, victoryPoint, roadCrew, bumperHarvest, cornerMarket }` with `var displayName: String` (`"Knight"`, `"Victory point"`, `"Road crew"`, `"Bumper harvest"`, `"Corner the market"`) and `static let deckComposition: [DevCardType: Int] = [.knight: 14, .victoryPoint: 5, .roadCrew: 2, .bumperHarvest: 2, .cornerMarket: 2]`.
  - `public struct DevCard: Codable, Hashable, Sendable { public var type: DevCardType; public var boughtOnTurn: Int }`.
  - `public enum Cost { public static let road: ResourceCounts = [.timber: 1, .clay: 1]; settlement = [.timber: 1, .clay: 1, .wool: 1, .grain: 1]; city = [.grain: 2, .ore: 3]; devCard = [.wool: 1, .grain: 1, .ore: 1] }`.
  - `public enum PieceLimit { public static let settlements = 5, cities = 4, roads = 15 }`.
  - `public enum Seat: Int, CaseIterable, Codable, Hashable, Sendable { case crimson, cobalt, amber, ivory; public var name: String; public var colorHex: String }` with the Global Constraints colours.
  - `public enum EffortLevel: Int, CaseIterable, Codable, Hashable, Sendable { case deckhand = 1, sailor, mate, captain, admiral; public var name: String }` (`"Deckhand"` …).
  - `public enum Controller: Codable, Hashable, Sendable { case human, ai(EffortLevel); public var isAI: Bool }`.

- [ ] **Step 1: Write the failing tests**

```swift
@Suite struct ResourceTests {
    @Test func countsArithmetic() {
        let a: ResourceCounts = [.timber: 3, .clay: 1], b: ResourceCounts = [.timber: 1]
        #expect((a + b)[.timber] == 4)
        #expect((a - b) == [.timber: 2, .clay: 1])
        #expect(a.total == 4); #expect(a.contains(b)); #expect(!b.contains(a))
        #expect(ResourceCounts().isEmpty); #expect(ResourceCounts.uniform(19)[.ore] == 19)
    }
    @Test func zeroEqualsMissing() { #expect(ResourceCounts([.wool: 0]) == ResourceCounts()) }
    @Test func descriptionOrderAndFormat() {
        #expect(ResourceCounts([.clay: 1, .timber: 3]).description == "3 timber, 1 clay")
        #expect(ResourceCounts().description == "nothing")
    }
    @Test func codableRoundTrip() throws {
        let a: ResourceCounts = [.grain: 2, .ore: 3]
        #expect(try JSONDecoder().decode(ResourceCounts.self, from: JSONEncoder().encode(a)) == a)
    }
    @Test func deckComposition() { #expect(DevCardType.deckComposition.values.reduce(0, +) == 25) }
    @Test func seatsAndColours() {
        #expect(Seat.allCases.map(\.name) == ["Crimson", "Cobalt", "Amber", "Ivory"])
        #expect(Seat.cobalt.colorHex == "#2a5db0")
    }
    @Test func costs() { #expect(Cost.city == [.grain: 2, .ore: 3]); #expect(Cost.devCard.total == 3) }
}
```

- [ ] **Step 2: Run to verify failure** — `swift test --filter ResourceTests` — Expected: compile errors for missing types.
- [ ] **Step 3: Implement the types in `Resources.swift` and `Seats.swift`**
- [ ] **Step 4: Run to verify pass** — `swift test --filter ResourceTests` — Expected: `Test run with 7 tests passed`.
- [ ] **Step 5: Commit** — `git commit -am "feat(engine): resource counts, cards, costs, seats"` (after `git add -A`).

---

### Task 4: Board geometry

**Files:**
- Create: `Sources/SaltmarshEngine/Board.swift`, `Sources/SaltmarshEngine/BoardGenerator.swift` (layout half)
- Test: `Tests/EngineTests/BoardGeometryTests.swift`

**Interfaces:**
- Produces:
  - `public struct Point: Codable, Hashable, Sendable { public var x: Double; public var y: Double }`.
  - `public struct Tile: Codable, Hashable, Sendable { public var center: Point; public var terrain: Terrain; public var number: Int?; public var corners: [Int]  /* 6, corner i at angle 60·i − 30° */; public var edges: [Int] /* 6, edge i joins corners i and i+1 */; public var neighbours: [Int]; public var resource: Resource? { terrain.resource }; public var pips: Int }`.
  - `public struct Corner: Codable, Hashable, Sendable { public var point: Point; public var tiles: [Int]; public var adjacent: [Int]; public var edges: [Int]; public var owner: Int?; public var isCity: Bool }`.
  - `public struct Edge: Codable, Hashable, Sendable { public var a: Int; public var b: Int; public var tiles: [Int]; public var owner: Int?; public var isCoastal: Bool { tiles.count == 1 }; public func other(_ corner: Int) -> Int }`.
  - `public struct Harbour: Codable, Hashable, Sendable { public enum Kind: Codable, Hashable, Sendable { case any, specific(Resource) }; public var kind: Kind; public var ratio: Int; public var a: Int; public var b: Int; public var edge: Int; public var position: Point }`.
  - `public struct Board: Codable, Hashable, Sendable { public var tiles: [Tile]; public var corners: [Corner]; public var edges: [Edge]; public var harbours: [Harbour]; public var desertTile: Int; public static let hexSize = 58.0; public static let size = (width: 680.0, height: 600.0); public static let seaRadius = 335.0; public static func pips(_ n: Int) -> Int /* 6 - |7 - n| */; public func edgeIndex(between a: Int, _ b: Int) -> Int?; public func edges(at corner: Int) -> [Int] }`.
  - `public enum BoardGenerator { public static func layout() -> Board }` producing geometry only: every tile `terrain = .desert`, `number = nil`, no harbours, `desertTile` = index of the `(0,0)` tile. Corner merge key is `"\(Int(x.rounded())),\(Int(y.rounded()))"`; edge key is `"min-max"` of corner indices. Two tiles are neighbours when they share exactly 2 corners.

- [ ] **Step 1: Write the failing tests**

```swift
@Suite struct BoardGeometryTests {
    let b = BoardGenerator.layout()
    @Test func counts() {
        #expect(b.tiles.count == 19); #expect(b.corners.count == 54); #expect(b.edges.count == 72)
        #expect(b.edges.filter(\.isCoastal).count == 30)
    }
    @Test func desertAtCentre() {
        let d = b.tiles[b.desertTile]
        #expect(abs(d.center.x) < 0.001 && abs(d.center.y) < 0.001)
    }
    @Test func cornersTouchOneToThreeTiles() { for c in b.corners { #expect((1...3).contains(c.tiles.count)) } }
    @Test func edgesTouchOneOrTwoTiles() { for e in b.edges { #expect((1...2).contains(e.tiles.count)) } }
    @Test func neighboursShareTwoCorners() {
        for (i, t) in b.tiles.enumerated() { for j in t.neighbours {
            #expect(Set(t.corners).intersection(b.tiles[j].corners).count == 2); #expect(b.tiles[j].neighbours.contains(i)) } }
        #expect(b.tiles[b.desertTile].neighbours.count == 6)
    }
    @Test func cornerAdjacencyMatchesEdges() {
        for (ci, c) in b.corners.enumerated() {
            #expect(Set(c.adjacent) == Set(c.edges.map { b.edges[$0].other(ci) }))
        }
    }
    @Test func pips() { #expect(Board.pips(6) == 5); #expect(Board.pips(2) == 1); #expect(Board.pips(12) == 1); #expect(Board.pips(7) == 6) }
    @Test func hexSizeGeometry() {
        let t = b.tiles[b.desertTile], c0 = b.corners[t.corners[0]]
        #expect(abs(hypot(c0.point.x, c0.point.y) - 58) < 0.01)
    }
}
```

- [ ] **Step 2: Run to verify failure** — `swift test --filter BoardGeometryTests` — Expected: compile errors.
- [ ] **Step 3: Implement `Board.swift` and `BoardGenerator.layout()`**

Axial loop `q in -2...2`, `r in max(-2, -q-2)...min(2, -q+2)`; `centre = (S·√3·(q + r/2), S·1.5·r)`; corner i at angle `(60·i − 30)°`. Fill `Corner.edges`, `Corner.adjacent`, `Tile.edges`, `Tile.neighbours` after all tiles exist.

- [ ] **Step 4: Run to verify pass** — Expected: `Test run with 8 tests passed`.
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(engine): hex board geometry with merged corners and edges"`

---

### Task 5: Board balancing and harbours

**Files:**
- Modify: `Sources/SaltmarshEngine/BoardGenerator.swift`
- Test: `Tests/EngineTests/BoardGeneratorTests.swift`

**Interfaces:**
- Produces: `public static func generate(using rng: inout SeededRNG) -> Board`; `public static let harbourOffsets = [0, 3, 7, 10, 13, 17, 20, 23, 27]`; `public static func violations(_ board: Board) -> [String]` returning one string per broken rule (empty when fair). Rules: (1) no two neighbouring tiles share a resource; (2) no 6/8 neighbours a 6/8; (3) no number neighbours the same number; (4) no corner's adjacent pips exceed 11; (5) each resource's pip total is within 3 of `tileCount × 58 / 18`; (6) harbours: exactly 9, all on coastal edges, four `.any` at ratio 3 and one `.specific(r)` at ratio 2 per resource, and no two `.any` harbours adjacent in coastal ring order. Resource shuffle retries up to 20,000 times, number shuffle up to 50,000.

- [ ] **Step 1: Write the failing tests**

```swift
@Suite struct BoardGeneratorTests {
    @Test func thousandBoardsAreFair() {
        for seed in 0..<1000 {
            var rng = SeededRNG(seed: UInt64(seed))
            let b = BoardGenerator.generate(using: &rng)
            #expect(BoardGenerator.violations(b).isEmpty, "seed \(seed): \(BoardGenerator.violations(b))")
        }
    }
    @Test func resourceAndNumberMix() {
        var rng = SeededRNG(seed: 11); let b = BoardGenerator.generate(using: &rng)
        let res = b.tiles.compactMap(\.resource)
        #expect(res.filter { $0 == .timber }.count == 4 && res.filter { $0 == .clay }.count == 3 && res.filter { $0 == .wool }.count == 4 && res.filter { $0 == .grain }.count == 4 && res.filter { $0 == .ore }.count == 3)
        #expect(b.tiles.compactMap(\.number).sorted() == [2,3,3,4,4,5,5,6,6,8,8,9,9,10,10,11,11,12])
        #expect(b.tiles[b.desertTile].number == nil && b.tiles[b.desertTile].terrain == .desert)
    }
    @Test func harbourLayout() {
        for seed in 0..<500 {
            var rng = SeededRNG(seed: UInt64(seed)); let b = BoardGenerator.generate(using: &rng)
            #expect(b.harbours.count == 9)
            #expect(b.harbours.filter { $0.kind == .any }.count == 4)
            for r in Resource.allCases { #expect(b.harbours.filter { $0.kind == .specific(r) && $0.ratio == 2 }.count == 1) }
            for h in b.harbours { #expect(b.edges[h.edge].isCoastal); #expect(Set([h.a, h.b]) == Set([b.edges[h.edge].a, b.edges[h.edge].b])) }
        }
    }
    @Test func violationsDetectsClusteredNumbers() {
        var rng = SeededRNG(seed: 1); var b = BoardGenerator.generate(using: &rng)
        let i = b.tiles.firstIndex { $0.number == 6 }!, j = b.tiles[i].neighbours.first { b.tiles[$0].number != nil }!
        b.tiles[j].number = 8
        #expect(!BoardGenerator.violations(b).isEmpty)
    }
    @Test func deterministicForSeed() {
        var r1 = SeededRNG(seed: 5), r2 = SeededRNG(seed: 5)
        #expect(BoardGenerator.generate(using: &r1) == BoardGenerator.generate(using: &r2))
    }
}
```

- [ ] **Step 2: Run to verify failure** — Expected: `generate`/`violations` not found.
- [ ] **Step 3: Implement balancing and harbours in `BoardGenerator.swift`**

Harbours: sort coastal edges by `atan2(midY, midX)`, pick a random start index, take `harbourOffsets` from it; kinds alternate `2:1, 3:1, …` with the five `.specific` resources shuffled over the 2:1 slots; `position` is 30 units beyond the edge midpoint along the line from the tile centre through that midpoint.

- [ ] **Step 4: Run to verify pass** — `swift test --filter BoardGeneratorTests` — Expected: 5 passed, under 15 s.
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(engine): fair board generation with balanced numbers and harbours"`

---

### Task 6: Game state, moves, phases and new game

**Files:**
- Create: `Sources/SaltmarshEngine/Trade.swift`, `Phase.swift`, `Move.swift`, `GameState.swift`
- Modify: `Sources/SaltmarshEngine/Engine.swift`
- Test: `Tests/EngineTests/NewGameTests.swift`

**Interfaces:**
- Produces:
  - `public struct TradeOffer: Codable, Hashable, Sendable { public var proposer: Int; public var give: ResourceCounts; public var want: ResourceCounts; public var to: Int?; public var description: String /* "2 timber for 1 ore" */ }`
  - `public enum TradeResponse: Codable, Hashable, Sendable { case pending, accepted, declined, countered(TradeOffer) }`
  - `public indirect enum Phase: Codable, Hashable, Sendable { case rollingForFirst(rolls: [Int?], contenders: [Int]); case setup(step: Int, placingRoad: Bool, lastSettlement: Int?); case awaitingRoll; case discarding(queue: [Int]); case movingRobber(returnTo: Phase); case choosingVictim(candidates: [Int], returnTo: Phase); case placingFreeRoads(remaining: Int); case main; case tradeOffered(offer: TradeOffer, responses: [Int: TradeResponse]); case gameOver(winner: Int) }`
  - `public enum Move: Codable, Hashable, Sendable` exactly as design section 4.2, with `discard(ResourceCounts)`.
  - `public struct Player: Codable, Hashable, Sendable { public var seat: Seat; public var controller: Controller; public var hand: ResourceCounts; public var devCards: [DevCard]; public var knightsPlayed: Int; public var name: String { seat.name } }`
  - `public struct GameConfig: Codable, Hashable, Sendable { public var controllers: [Controller]; public var seed: UInt64; public init(controllers: [Controller], seed: UInt64); public var playerCount: Int }`
  - `public struct GameState: Codable, Equatable, Sendable` with the design's fields as `public var`: `board: Board`, `players: [Player]`, `firstPlayer: Int`, `current: Int`, `turn: Int`, `robberTile: Int`, `dice: [Int]?`, `bank: ResourceCounts`, `devDeck: [DevCardType]`, `devCardPlayedThisTurn: Bool`, `longestRoadHolder: Int?`, `largestArmyHolder: Int?`, `phase: Phase`, `log: [String]`, `rng: SeededRNG`, `seed: UInt64`, `forcedRolls: [[Int]]` (test/debug: when non-empty the next roll pops `first` instead of using `rng`). Derived: `func settlements(of p: Int) -> Int`, `cities(of:)`, `roads(of:)`, `var playerCount: Int`, `mutating func log(_ line: String)`.
  - `public enum EngineError: Error, Equatable { case illegalMove(Move), invalidOffer(String) }`
  - `extension Engine { public static func newGame(_ config: GameConfig) -> GameState; public static func legalMoves(_ s: GameState) -> [Move]; public static func isLegal(_ m: Move, in s: GameState) -> Bool; public static func apply(_ m: Move, to s: inout GameState) throws; public static func actingPlayer(_ s: GameState) -> Int }`. In this task `legalMoves` returns `[.rollForFirst]` in `rollingForFirst` and `[]` otherwise; `apply` throws `illegalMove` for everything (the phase handlers arrive in Tasks 7 to 16, each adding a `case` to the dispatch in `apply` and a branch in `legalMoves`). `actingPlayer`: in `rollingForFirst` the first contender whose roll is nil; in `discarding(queue)` `queue[0]`; in `tradeOffered` the first pending responder if any else `current`; otherwise `current`.
  - `newGame`: `rng = SeededRNG(seed:)`, board from `BoardGenerator.generate`, robber on `desertTile`, bank `uniform(19)`, deck = composition shuffled with `rng`, players from `config.controllers` (2 to 4, `precondition`), `firstPlayer = 0`, `current = 0`, `turn = 0`, phase `.rollingForFirst(rolls: Array(repeating: nil, count: n), contenders: Array(0..<n))`, log `"New game with 3 players. Everyone rolls for first player."`.

- [ ] **Step 1: Write the failing tests**

```swift
@Suite struct NewGameTests {
    let s = Engine.newGame(GameConfig(controllers: [.human, .ai(.mate), .ai(.admiral)], seed: 9))
    @Test func initialFacts() {
        #expect(s.players.map(\.seat) == [.crimson, .cobalt, .amber])
        #expect(s.players.allSatisfy { $0.hand.isEmpty && $0.devCards.isEmpty && $0.knightsPlayed == 0 })
        #expect(s.devDeck.count == 25); #expect(s.devDeck.filter { $0 == .knight }.count == 14)
        #expect(s.bank == .uniform(19)); #expect(s.robberTile == s.board.desertTile)
        #expect(s.phase == .rollingForFirst(rolls: [nil, nil, nil], contenders: [0, 1, 2]))
        #expect(s.log.last == "New game with 3 players. Everyone rolls for first player.")
        #expect(Engine.legalMoves(s) == [.rollForFirst]); #expect(Engine.actingPlayer(s) == 0)
    }
    @Test func sameSeedSameGame() {
        let c = GameConfig(controllers: [.human, .human], seed: 123)
        #expect(Engine.newGame(c) == Engine.newGame(c))
    }
    @Test func codableRoundTrip() throws {
        let data = try JSONEncoder().encode(s)
        #expect(try JSONDecoder().decode(GameState.self, from: data) == s)
    }
    @Test func illegalMoveThrows() {
        var t = s
        #expect(throws: EngineError.illegalMove(.roll)) { try Engine.apply(.roll, to: &t) }
    }
    @Test func offerDescription() {
        #expect(TradeOffer(proposer: 0, give: [.timber: 2], want: [.ore: 1], to: nil).description == "2 timber for 1 ore")
    }
}
```

- [ ] **Step 2: Run to verify failure** — Expected: compile errors.
- [ ] **Step 3: Implement the types and `Engine` skeleton**
- [ ] **Step 4: Run to verify pass** — `swift test --filter NewGameTests` — Expected: 5 passed.
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(engine): game state, phases, moves and newGame"`

---

### Task 7: Roll for first player

**Files:**
- Create: `Sources/SaltmarshEngine/Engine+FirstRoll.swift`
- Modify: `Engine.swift` (dispatch)
- Test: `Tests/EngineTests/FirstRollTests.swift`

**Interfaces:**
- Produces: `internal static func rollDice(_ s: inout GameState) -> [Int]` (pops `forcedRolls.first` when present, else two `rng.d6()`; sets `s.dice`); `internal static func applyRollForFirst(_ s: inout GameState)`; `public static func setupOrder(players n: Int, first: Int) -> [Int]` = `[first, first+1 … wrapping, n entries] + its reverse`.
- Behaviour: acting contender rolls; log `"<Name> rolled N for first player."`. When all contenders have rolled: if one highest, `firstPlayer = winner`, `current = winner`, phase `.setup(step: 0, placingRoad: false, lastSettlement: nil)`, log `"<Name> goes first. Place your first settlement."`; if several tie, log `"Tie between <A> and <B>. Roll again."` (names joined with ", " and " and ") and phase `.rollingForFirst(rolls: all nil, contenders: tied)`. `dice` is set to nil when setup starts.

- [ ] **Step 1: Write the failing tests**

```swift
@Suite struct FirstRollTests {
    func game() -> GameState { Engine.newGame(GameConfig(controllers: [.human, .human, .human], seed: 1)) }
    @Test func highestGoesFirstAndOrderRotates() throws {
        var s = game(); s.forcedRolls = [[1, 2], [6, 6], [3, 3]]
        for _ in 0..<3 { try Engine.apply(.rollForFirst, to: &s) }
        #expect(s.firstPlayer == 1); #expect(s.current == 1)
        #expect(s.phase == .setup(step: 0, placingRoad: false, lastSettlement: nil))
        #expect(s.log.last == "Cobalt goes first. Place your first settlement.")
        #expect(Engine.setupOrder(players: 3, first: 1) == [1, 2, 0, 0, 2, 1])
    }
    @Test func tieRerollsAmongTiedOnly() throws {
        var s = game(); s.forcedRolls = [[6, 6], [1, 1], [6, 6], [2, 2], [5, 5]]
        for _ in 0..<3 { try Engine.apply(.rollForFirst, to: &s) }
        #expect(s.phase == .rollingForFirst(rolls: [nil, nil, nil], contenders: [0, 2]))
        #expect(s.log.last == "Tie between Crimson and Amber. Roll again.")
        #expect(Engine.actingPlayer(s) == 0)
        try Engine.apply(.rollForFirst, to: &s); #expect(Engine.actingPlayer(s) == 2)
        try Engine.apply(.rollForFirst, to: &s)
        #expect(s.firstPlayer == 2)
    }
    @Test func rollLogged() throws {
        var s = game(); s.forcedRolls = [[4, 5]]
        try Engine.apply(.rollForFirst, to: &s)
        #expect(s.log.last == "Crimson rolled 9 for first player.")
    }
    @Test func onlyRollForFirstIsLegal() { #expect(Engine.legalMoves(game()) == [.rollForFirst]) }
}
```

- [ ] **Step 2: Run to verify failure** — Expected: `illegalMove(.rollForFirst)` thrown / `setupOrder` missing.
- [ ] **Step 3: Implement `Engine+FirstRoll.swift` and add the `case .rollForFirst` to `apply`**
- [ ] **Step 4: Run to verify pass** — Expected: 4 passed.
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(engine): roll for first player with tie re-rolls"`

---

### Task 8: Snake setup and the shared test helpers

**Files:**
- Create: `Sources/SaltmarshEngine/Engine+Setup.swift`, `Sources/SaltmarshEngine/Engine+Build.swift` (placement predicates only)
- Create: `Tests/EngineTests/Helpers.swift`
- Test: `Tests/EngineTests/SetupTests.swift`

**Interfaces:**
- Produces in the engine:
  - `public static func canSettle(_ s: GameState, corner: Int, player: Int, setup: Bool) -> Bool` (unowned, no adjacent owner, and in play touches an own road); `public static func canRoad(_ s: GameState, edge: Int, player: Int) -> Bool` (unowned; during `setup(placingRoad: true, lastSettlement: c)` must touch `c`; in play one end is own building, or an empty corner with another own road; an opponent's building at an end blocks continuing from that end).
  - Setup `legalMoves`: `placeSettlement` for every corner with `canSettle(setup: true)`; `placeRoad` for every `canRoad` edge while placing a road. Apply settlement: owner set, `lastSettlement`, `placingRoad = true`, log `"<Name> founded a settlement."`; when `step >= playerCount` pay 1 card per adjacent land tile from the bank. Apply road: owner set, log `"<Name> laid a road."`, `step += 1`; if `step == 2 × playerCount` then phase `.awaitingRoll`, `current = firstPlayer`, log `"Setup done. <Name> rolls first."`; else `current = setupOrder[step]`, phase `.setup(step:, placingRoad: false, lastSettlement: nil)`.
- Produces in tests (`Helpers.swift`):

```swift
enum TestGames {
    static func fresh(players: Int = 3, seed: UInt64 = 1) -> GameState            // all .human
    static func afterSetup(players: Int = 3, seed: UInt64 = 1, first: Int = 0) -> GameState  // forced first roll won by `first`, setup done with first legal corner/edge each step; phase .awaitingRoll
    static func rolled(_ roll: Int, players: Int = 3, seed: UInt64 = 1) -> GameState       // afterSetup then force(roll) and apply .roll
}
extension GameState {
    mutating func force(roll: Int)                              // appends a pair summing to roll
    mutating func set(hand: ResourceCounts, for player: Int)   // replaces the hand, then bank = uniform(19) − Σ all hands
    mutating func clearHands()
    mutating func place(settlement corner: Int, owner: Int)    // no rule checks
    mutating func place(city corner: Int, owner: Int)
    mutating func place(road edge: Int, owner: Int)
    func tile(numbered n: Int) -> Int
    func corner(onTileNumbered n: Int, index k: Int = 0) -> Int
}
```

- [ ] **Step 1: Write `Helpers.swift` and the failing tests**

```swift
@Suite struct SetupTests {
    @Test(arguments: [(2, [0, 1, 1, 0]), (3, [0, 1, 2, 2, 1, 0]), (4, [0, 1, 2, 3, 3, 2, 1, 0])])
    func placementOrder(players: Int, order: [Int]) throws {
        var s = TestGames.fresh(players: players)
        s.forcedRolls = (0..<players).map { $0 == 0 ? [6, 6] : [1, 1] }
        for _ in 0..<players { try Engine.apply(.rollForFirst, to: &s) }
        var seen: [Int] = []
        while case .setup = s.phase {
            seen.append(s.current)
            try Engine.apply(Engine.legalMoves(s).first!, to: &s)   // settlement
            try Engine.apply(Engine.legalMoves(s).first!, to: &s)   // road
        }
        #expect(seen == order); #expect(s.phase == .awaitingRoll); #expect(s.current == 0)
        #expect(s.log.last == "Setup done. Crimson rolls first.")
    }
    @Test func orderStartsFromFirstPlayer() {
        let s = TestGames.afterSetup(players: 3, first: 2)
        #expect(s.current == 2); #expect(s.log.last == "Setup done. Amber rolls first.")
    }
    @Test func onlySecondSettlementPays() throws {
        var s = TestGames.fresh(); s.forcedRolls = [[6, 6], [1, 1], [1, 1]]
        for _ in 0..<3 { try Engine.apply(.rollForFirst, to: &s) }
        try Engine.apply(Engine.legalMoves(s).first!, to: &s)
        #expect(s.players[0].hand.isEmpty)
        // run to Crimson's second placement (step 5 of 6)
        while case .setup(let step, _, _) = s.phase, step < 5 { try Engine.apply(Engine.legalMoves(s).first!, to: &s) }
        let corner = Engine.legalMoves(s).compactMap { if case .placeSettlement(let c) = $0 { c } else { nil } }.first!
        let expected = s.board.corners[corner].tiles.compactMap { s.board.tiles[$0].resource }
        try Engine.apply(.placeSettlement(corner: corner), to: &s)
        #expect(s.players[0].hand.total == expected.count)
        for r in expected { #expect(s.players[0].hand[r] >= 1) }
        #expect(s.bank.total == 19 * 5 - s.players.map(\.hand.total).reduce(0, +))
    }
    @Test func setupRoadMustTouchNewSettlement() throws {
        var s = TestGames.fresh(); s.forcedRolls = [[6, 6], [1, 1], [1, 1]]
        for _ in 0..<3 { try Engine.apply(.rollForFirst, to: &s) }
        let c = 10
        try Engine.apply(.placeSettlement(corner: c), to: &s)
        let legal = Engine.legalMoves(s)
        #expect(legal.count == s.board.corners[c].edges.count)
        for m in legal { if case .placeRoad(let e) = m { #expect(s.board.edges[e].a == c || s.board.edges[e].b == c) } else { Issue.record("non-road move in setup road step") } }
        #expect(s.log.last == "Crimson founded a settlement.")
    }
    @Test func distanceRuleDuringSetup() throws {
        var s = TestGames.fresh(); s.forcedRolls = [[6, 6], [1, 1], [1, 1]]
        for _ in 0..<3 { try Engine.apply(.rollForFirst, to: &s) }
        try Engine.apply(.placeSettlement(corner: 10), to: &s)
        try Engine.apply(Engine.legalMoves(s).first!, to: &s)
        let legal = Engine.legalMoves(s).compactMap { if case .placeSettlement(let c) = $0 { c } else { nil } }
        #expect(!legal.contains(10)); for a in s.board.corners[10].adjacent { #expect(!legal.contains(a)) }
    }
}
```

- [ ] **Step 2: Run to verify failure** — Expected: compile errors / `illegalMove`.
- [ ] **Step 3: Implement `Engine+Setup.swift`, the predicates in `Engine+Build.swift`, dispatch cases, and `Helpers.swift`**
- [ ] **Step 4: Run to verify pass** — `swift test --filter SetupTests` — Expected: 7 passed (3 parameterised + 4).
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(engine): snake-order setup with starting cards; test helpers"`

---

### Task 9: Rolling, production and the bank shortage rule

**Files:**
- Create: `Sources/SaltmarshEngine/Engine+Turn.swift`
- Modify: `Engine.swift` (dispatch), `Tests/EngineTests/Helpers.swift` (add `mutating func clearBoard()`: removes every owner, city flag and road)
- Test: `Tests/EngineTests/RollTests.swift`

**Interfaces:**
- Produces: `.roll` legal only in `.awaitingRoll`. `internal static func produce(roll: Int, in s: inout GameState) -> String` pays every tile whose `number == roll` and index `!= robberTile`, 1 per settlement and 2 per city, subject to the bank rule, and returns `"Cobalt +1, Amber +2"` (players in seat order who received at least one card) or `"Nobody harvested."`. Bank rule per resource: if the bank holds at least the total owed, pay everyone; else if exactly one player is owed it they take `min(owed, bank)`; else nobody gets it; in both shortage cases append the log line `"Bank is out of <resource>."` after the roll line. Apply `.roll`: `rollDice`, then for a non-7 log `"<Name> rolled N. " + fragment` and set phase `.main`; for a 7 log `"<Name> rolled 7."`, build `queue` = players in seat order with `hand.total > 7`, phase `.discarding(queue:)` if non-empty else `.movingRobber(returnTo: .main)` (the discard, robber and steal moves themselves are Task 10).

- [ ] **Step 1: Write the failing tests**

```swift
@Suite struct RollTests {
    func crimsonToRoll(_ roll: Int) -> GameState {
        var s = TestGames.afterSetup(); s.clearBoard(); s.clearHands()
        s.current = 0; s.phase = .awaitingRoll; s.force(roll: roll); return s
    }
    @Test func rollThatProduces() throws {
        var s = crimsonToRoll(8)
        s.place(settlement: s.corner(onTileNumbered: 8, index: 0), owner: 1)
        s.place(city: s.corner(onTileNumbered: 8, index: 3), owner: 2)
        let res = s.board.tiles[s.tile(numbered: 8)].resource!
        try Engine.apply(.roll, to: &s)
        #expect(s.players[1].hand[res] == 1); #expect(s.players[2].hand[res] == 2)
        #expect(s.log.last == "Crimson rolled 8. Cobalt +1, Amber +2")
        #expect(s.phase == .main); #expect(s.dice!.reduce(0, +) == 8)
    }
    @Test func rollThatProducesNothing() throws {
        var s = crimsonToRoll(8); try Engine.apply(.roll, to: &s)
        #expect(s.log.last == "Crimson rolled 8. Nobody harvested.")
    }
    @Test func robberBlocksProduction() throws {
        var s = crimsonToRoll(6)
        s.place(settlement: s.corner(onTileNumbered: 6), owner: 1); s.robberTile = s.tile(numbered: 6)
        try Engine.apply(.roll, to: &s)
        #expect(s.players[1].hand.isEmpty)
    }
    @Test func rollIsSingleUse() throws {
        var s = crimsonToRoll(5); try Engine.apply(.roll, to: &s)
        #expect(!Engine.legalMoves(s).contains(.roll))
        #expect(throws: EngineError.illegalMove(.roll)) { try Engine.apply(.roll, to: &s) }
    }
    @Test func singleOwedPlayerTakesRemainder() throws {
        var s = crimsonToRoll(8); let res = s.board.tiles[s.tile(numbered: 8)].resource!
        s.set(hand: [res: 18], for: 0)                       // bank now holds 1
        s.place(city: s.corner(onTileNumbered: 8), owner: 2)
        try Engine.apply(.roll, to: &s)
        #expect(s.players[2].hand[res] == 1); #expect(s.bank[res] == 0)
        #expect(s.log.last == "Bank is out of \(res.rawValue).")
    }
    @Test func twoOwedPlayersGetNothing() throws {
        var s = crimsonToRoll(8); let res = s.board.tiles[s.tile(numbered: 8)].resource!
        s.set(hand: [res: 18], for: 0)
        s.place(settlement: s.corner(onTileNumbered: 8, index: 0), owner: 1)
        s.place(settlement: s.corner(onTileNumbered: 8, index: 3), owner: 2)
        try Engine.apply(.roll, to: &s)
        #expect(s.players[1].hand[res] == 0); #expect(s.players[2].hand[res] == 0); #expect(s.bank[res] == 1)
        #expect(s.log.suffix(2).first == "Crimson rolled 8. Nobody harvested.")
    }
    @Test func sevenBuildsDiscardQueueOrGoesToRobber() throws {
        var s = crimsonToRoll(7)
        s.set(hand: .uniform(2), for: 1)                     // 10 cards
        try Engine.apply(.roll, to: &s)
        #expect(s.phase == .discarding(queue: [1])); #expect(s.log.last == "Crimson rolled 7.")
        var t = crimsonToRoll(7); try Engine.apply(.roll, to: &t)
        #expect(t.phase == .movingRobber(returnTo: .main))
    }
}
```

- [ ] **Step 2: Run to verify failure** — `swift test --filter RollTests` — Expected: `illegalMove(.roll)`.
- [ ] **Step 3: Implement `.roll` and `produce` in `Engine+Turn.swift`, add `clearBoard()` to Helpers**
- [ ] **Step 4: Run to verify pass** — Expected: 7 passed.
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(engine): dice roll, production and bank supply limits"`

---

### Task 10: Sevens: discarding, moving the robber, stealing

**Files:**
- Modify: `Sources/SaltmarshEngine/Engine+Turn.swift`, `Engine.swift`
- Test: `Tests/EngineTests/RobberTests.swift`

**Interfaces:**
- Produces:
  - `public static func discardOptions(hand: ResourceCounts, count: Int) -> [ResourceCounts]`: every sub-multiset of `hand` with `total == count` when there are at most 256 of them, otherwise the single greedy choice that repeatedly removes one card from the resource with the largest remaining count (ties broken in `Resource` order).
  - `.discard(c)` legal in `.discarding(queue)` for `actingPlayer == queue[0]` when `c.total == hand.total / 2` and `hand.contains(c)`. Apply: hand −= c, bank += c, log `"<Name> discarded <c>."`, drop `queue[0]`; when the queue empties, phase `.movingRobber(returnTo: .main)` and log `"<Roller> now moves the robber."`.
  - `.moveRobber(t)` legal in `.movingRobber` for every `t != robberTile`. Apply: `robberTile = t`, log `"<Name> moved the robber."`; candidates = distinct owners of the tile's corners, excluding `current`, with `hand.total > 0`, in seat order; if empty log `"Nobody on that tile has cards to steal."` and phase `returnTo`; else phase `.choosingVictim(candidates:, returnTo:)`.
  - `.steal(from: v)` legal in `.choosingVictim` for each candidate. Apply: one card chosen uniformly among the victim's cards using `rng`, moved to `current`; log `"<Name> stole a card from <Victim>."`; phase `returnTo`.

- [ ] **Step 1: Write the failing tests**

```swift
@Suite struct RobberTests {
    func sevenRolled(crimson: Int = 4, cobalt: Int = 9, amber: Int = 10) -> GameState {
        var s = TestGames.afterSetup(); s.clearBoard(); s.clearHands()
        func hand(_ n: Int) -> ResourceCounts { var h = ResourceCounts(); for i in 0..<n { h[Resource.allCases[i % 5]] += 1 }; return h }
        s.set(hand: hand(crimson), for: 0); s.set(hand: hand(cobalt), for: 1); s.set(hand: hand(amber), for: 2)
        s.current = 0; s.phase = .awaitingRoll; s.force(roll: 7); try! Engine.apply(.roll, to: &s); return s
    }
    @Test func queueFormsInSeatOrder() {
        let s = sevenRolled()
        #expect(s.phase == .discarding(queue: [1, 2])); #expect(Engine.actingPlayer(s) == 1)
        #expect(Engine.legalMoves(s).allSatisfy { if case .discard(let c) = $0 { c.total == 4 } else { false } })
    }
    @Test func rollerDiscardsTooWhenOverSeven() {       // Review Focus 1
        let s = sevenRolled(crimson: 9)
        #expect(s.phase == .discarding(queue: [0, 1, 2]))
    }
    @Test func wrongCountIsIllegal() {
        var s = sevenRolled(); let c = Engine.legalMoves(s).first!
        #expect(throws: EngineError.self) { try Engine.apply(.discard([.timber: 1]), to: &s) }
        #expect(throws: Never.self) { try Engine.apply(c, to: &s) }
    }
    @Test func confirmingMovesQueueThenRobber() throws {
        var s = sevenRolled(); let before = s.players[1].hand, bank = s.bank
        let pick: ResourceCounts = [.timber: 2, .clay: 2]
        try Engine.apply(.discard(pick), to: &s)
        #expect(s.players[1].hand == before - pick); #expect(s.bank == bank + pick)
        #expect(s.log.last == "Cobalt discarded 2 timber, 2 clay."); #expect(Engine.actingPlayer(s) == 2)
        try Engine.apply(Engine.legalMoves(s).first!, to: &s)
        #expect(s.phase == .movingRobber(returnTo: .main)); #expect(s.log.last == "Crimson now moves the robber.")
    }
    @Test func nobodyOverSevenSkipsToRobber() {
        #expect(sevenRolled(cobalt: 7, amber: 3).phase == .movingRobber(returnTo: .main))
    }
    @Test func robberMustChangeTile() {
        var s = sevenRolled(cobalt: 7, amber: 3)
        #expect(Engine.legalMoves(s).count == 18)
        #expect(throws: EngineError.self) { try Engine.apply(.moveRobber(tile: s.robberTile), to: &s) }
    }
    @Test func stealIsAVisibleStepEvenWithOneVictim() throws {
        var s = sevenRolled(cobalt: 5, amber: 3)
        let t = s.tile(numbered: 8); s.place(settlement: s.board.tiles[t].corners[0], owner: 1)
        try Engine.apply(.moveRobber(tile: t), to: &s)
        #expect(s.robberTile == t); #expect(s.phase == .choosingVictim(candidates: [1], returnTo: .main))
        #expect(s.log.last == "Crimson moved the robber.")
        try Engine.apply(.steal(from: 1), to: &s)
        #expect(s.players[1].hand.total == 4); #expect(s.players[0].hand.total == 5)
        #expect(s.log.last == "Crimson stole a card from Cobalt."); #expect(s.phase == .main)
    }
    @Test func twoVictimsOffered() throws {
        var s = sevenRolled(cobalt: 5, amber: 5)
        let t = s.tile(numbered: 8)
        s.place(settlement: s.board.tiles[t].corners[0], owner: 1); s.place(settlement: s.board.tiles[t].corners[3], owner: 2)
        try Engine.apply(.moveRobber(tile: t), to: &s)
        #expect(s.phase == .choosingVictim(candidates: [1, 2], returnTo: .main))
    }
    @Test func noVictimsLogsAndContinues() throws {
        var s = sevenRolled(cobalt: 7, amber: 0)
        let t = s.tile(numbered: 8); s.place(settlement: s.board.tiles[t].corners[0], owner: 2)
        try Engine.apply(.moveRobber(tile: t), to: &s)
        #expect(s.log.last == "Nobody on that tile has cards to steal."); #expect(s.phase == .main)
    }
    @Test func discardOptionsEnumerateOrGreedy() {
        #expect(Set(Engine.discardOptions(hand: [.timber: 3, .clay: 1], count: 2)) == Set([[.timber: 2], [.timber: 1, .clay: 1]] as [ResourceCounts]))
        #expect(Engine.discardOptions(hand: .uniform(4), count: 10) == [.uniform(2)])
    }
}
```

- [ ] **Step 2: Run to verify failure** — Expected: `illegalMove` for `.discard`, `.moveRobber`.
- [ ] **Step 3: Implement the three moves and `discardOptions`**
- [ ] **Step 4: Run to verify pass** — `swift test --filter RobberTests` — Expected: 10 passed.
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(engine): discards, robber movement and stealing"`

---

### Task 11: Longest road and largest army

**Files:**
- Create: `Sources/SaltmarshEngine/Engine+Awards.swift`
- Modify: `Tests/EngineTests/Helpers.swift` (add `func chain(from start: Int, length: Int, avoiding: inout Set<Int>) -> [Int]`: walks from `start` to the lowest-index adjacent corner not in `avoiding`, adding every visited corner (including `start`) to `avoiding`, returns exactly `length` edge indices and `precondition`s that it got there; `mutating func placeChain(_ edges: [Int], owner: Int)`)
- Test: `Tests/EngineTests/AwardTests.swift`

**Interfaces:**
- Produces: `public static func roadLength(_ s: GameState, player: Int) -> Int` (the spec's DFS: longest trail of the player's edges without reusing an edge; a trail may enter but not pass a corner with an opponent's building). `public static func updateAwards(_ s: inout GameState)`: longest road needs ≥ 5; holder keeps it on a tie; a strictly longer player takes it; when the holder is no longer uniquely longest, the unique longest takes it, a tie between others leaves nobody, and below 5 nobody; log `"<Name> takes longest road (N)."` or `"Nobody holds longest road now."` on change. Largest army: first to 3 knights takes it, strictly more takes it over, never lost otherwise; log `"<Name> takes largest army (N knights)."`.

- [ ] **Step 1: Write the failing tests**

```swift
@Suite struct AwardTests {
    func board() -> (GameState, Set<Int>) { var s = TestGames.afterSetup(); s.clearBoard(); return (s, []) }
    @Test func sixRoadsClaimLongestRoad() {
        var (s, used) = board(); s.placeChain(s.chain(from: 0, length: 6, avoiding: &used), owner: 0)
        #expect(Engine.roadLength(s, player: 0) == 6)
        Engine.updateAwards(&s)
        #expect(s.longestRoadHolder == 0); #expect(s.log.last == "Crimson takes longest road (6).")
    }
    @Test func yShapeMeasuresTwo() {
        var (s, _) = board(); for e in s.board.corners[20].edges { s.place(road: e, owner: 0) }
        #expect(s.board.corners[20].edges.count == 3); #expect(Engine.roadLength(s, player: 0) == 2)
    }
    @Test func tieKeepsHolderStrictlyLongerTakes() {
        var (s, used) = board()
        s.placeChain(s.chain(from: 0, length: 6, avoiding: &used), owner: 0); Engine.updateAwards(&s)
        let cobalt = s.chain(from: 30, length: 7, avoiding: &used)
        s.placeChain(Array(cobalt.prefix(6)), owner: 1); Engine.updateAwards(&s)
        #expect(s.longestRoadHolder == 0)
        s.place(road: cobalt[6], owner: 1); Engine.updateAwards(&s)
        #expect(s.longestRoadHolder == 1); #expect(s.log.last == "Cobalt takes longest road (7).")
    }
    @Test func settlementCutsRoad() {
        var (s, used) = board(); let edges = s.chain(from: 0, length: 6, avoiding: &used)
        s.placeChain(edges, owner: 0); Engine.updateAwards(&s)
        let middle = s.board.edges[edges[3]].a == s.board.edges[edges[2]].other(s.board.edges[edges[2]].a) ? s.board.edges[edges[3]].a : s.board.edges[edges[3]].b
        s.place(settlement: middle, owner: 1); Engine.updateAwards(&s)
        #expect(Engine.roadLength(s, player: 0) == 3); #expect(s.longestRoadHolder == nil)
        #expect(s.log.last == "Nobody holds longest road now.")
    }
    @Test func cutHolderWithTwoOthersTiedLeavesNobody() {
        var (s, used) = board(); let crimson = s.chain(from: 0, length: 6, avoiding: &used)
        s.placeChain(crimson, owner: 0); Engine.updateAwards(&s)
        s.placeChain(s.chain(from: 25, length: 6, avoiding: &used), owner: 1)
        s.placeChain(s.chain(from: 45, length: 6, avoiding: &used), owner: 2); Engine.updateAwards(&s)
        #expect(s.longestRoadHolder == 0)
        let shared = Set([s.board.edges[crimson[2]].a, s.board.edges[crimson[2]].b]).intersection([s.board.edges[crimson[3]].a, s.board.edges[crimson[3]].b]).first!
        s.place(settlement: shared, owner: 1); Engine.updateAwards(&s)
        #expect(s.longestRoadHolder == nil)
    }
    @Test func trailStopsAtOpponentBuilding() {
        var (s, used) = board(); let edges = s.chain(from: 0, length: 4, avoiding: &used); s.placeChain(edges, owner: 0)
        let shared = Set([s.board.edges[edges[1]].a, s.board.edges[edges[1]].b]).intersection([s.board.edges[edges[2]].a, s.board.edges[edges[2]].b]).first!
        s.place(settlement: shared, owner: 1)
        #expect(Engine.roadLength(s, player: 0) == 2)
    }
    @Test func largestArmy() {
        var (s, _) = board()
        s.players[0].knightsPlayed = 3; Engine.updateAwards(&s)
        #expect(s.largestArmyHolder == 0); #expect(s.log.last == "Crimson takes largest army (3 knights).")
        s.players[1].knightsPlayed = 3; Engine.updateAwards(&s); #expect(s.largestArmyHolder == 0)
        s.players[1].knightsPlayed = 4; Engine.updateAwards(&s); #expect(s.largestArmyHolder == 1)
    }
}
```

- [ ] **Step 2: Run to verify failure** — Expected: `roadLength`/`updateAwards` not found.
- [ ] **Step 3: Implement `Engine+Awards.swift` and the Helpers additions**
- [ ] **Step 4: Run to verify pass** — `swift test --filter AwardTests` — Expected: 7 passed.
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(engine): longest road and largest army awards"`

---

### Task 12: Building roads, settlements and cities with piece limits

**Files:**
- Modify: `Sources/SaltmarshEngine/Engine+Build.swift`, `Engine.swift`
- Create: `Sources/SaltmarshEngine/Engine+Scoring.swift` (only `PiecesLeft` and `piecesLeft` for now)
- Test: `Tests/EngineTests/BuildTests.swift`

**Interfaces:**
- Produces: `public struct PiecesLeft: Equatable, Sendable { public var settlements: Int; public var cities: Int; public var roads: Int }`; `public static func piecesLeft(_ s: GameState, player: Int) -> PiecesLeft` (5 − settlements, 4 − cities, 15 − roads). In `.main`: `.placeRoad(e)` legal when `canRoad`, `hand.contains(Cost.road)`, `roads > 0`; `.placeSettlement(c)` when `canSettle(setup: false)`, `hand.contains(Cost.settlement)`, `settlements > 0`; `.upgradeCity(c)` when own non-city corner, `hand.contains(Cost.city)`, `cities > 0`. Apply: pay to bank, set owner / `isCity`, log `"<Name> built a road."`, `"<Name> built a settlement."`, `"<Name> upgraded to a city."`; `updateAwards` after a road or settlement. (Win checks are wired in Task 15.)

- [ ] **Step 1: Write the failing tests**

```swift
@Suite struct BuildTests {
    /// Crimson has rolled; one Crimson settlement at corner 0 with a road along its first edge; empty hands.
    func base() -> GameState {
        var s = TestGames.rolled(8); s.clearBoard(); s.clearHands()
        s.place(settlement: 0, owner: 0); s.place(road: s.board.corners[0].edges[0], owner: 0); return s
    }
    func has(_ s: GameState, _ test: (Move) -> Bool) -> Bool { Engine.legalMoves(s).contains(where: test) }
    @Test func buildsFollowCost() {
        var s = base()
        #expect(!has(s) { if case .placeRoad = $0 { true } else { false } })
        s.set(hand: Cost.road, for: 0); #expect(has(s) { if case .placeRoad = $0 { true } else { false } })
        s.set(hand: Cost.city, for: 0); #expect(has(s) { $0 == .upgradeCity(corner: 0) })
        #expect(!has(s) { if case .placeSettlement = $0 { true } else { false } })
    }
    @Test func roadPaysAndLogs() throws {
        var s = base(); s.set(hand: Cost.road, for: 0)
        let e = Engine.legalMoves(s).compactMap { if case .placeRoad(let e) = $0 { e } else { nil } }.first!
        try Engine.apply(.placeRoad(edge: e), to: &s)
        #expect(s.board.edges[e].owner == 0); #expect(s.players[0].hand.isEmpty); #expect(s.bank == .uniform(19))
        #expect(s.log.last == "Crimson built a road.")
    }
    @Test func roadsMustConnect() {
        var s = base(); s.set(hand: Cost.road, for: 0)
        for m in Engine.legalMoves(s) { if case .placeRoad(let e) = m {
            let ed = s.board.edges[e]
            #expect([ed.a, ed.b].contains { c in s.board.corners[c].owner == 0 || s.board.corners[c].edges.contains { $0 != e && s.board.edges[$0].owner == 0 } }) } }
    }
    @Test func roadCannotPassOpponentBuilding() {
        var s = base(); s.set(hand: Cost.road, for: 0)
        let e = s.board.corners[0].edges[0], far = s.board.edges[e].other(0)
        s.place(settlement: far, owner: 1)
        for m in Engine.legalMoves(s) { if case .placeRoad(let x) = m { #expect(s.board.edges[x].a != far && s.board.edges[x].b != far) } }
    }
    @Test func opponentRoadsDoNotBlock() {
        var s = base(); s.set(hand: Cost.road, for: 0)
        let e = s.board.corners[0].edges[0], far = s.board.edges[e].other(0)
        let other = s.board.corners[far].edges.first { $0 != e }!; s.place(road: other, owner: 1)
        #expect(has(s) { if case .placeRoad(let x) = $0 { s.board.edges[x].a == far || s.board.edges[x].b == far } else { false } })
    }
    @Test func settlementRulesAndLog() throws {
        var s = base(); s.set(hand: Cost.settlement, for: 0)
        let e = s.board.corners[0].edges[0], mid = s.board.edges[e].other(0)
        let e2 = s.board.corners[mid].edges.first { $0 != e }!; s.place(road: e2, owner: 0)
        let far = s.board.edges[e2].other(mid)
        let spots = Engine.legalMoves(s).compactMap { if case .placeSettlement(let c) = $0 { c } else { nil } }
        #expect(spots == [far])                                       // mid is adjacent to corner 0, far is reachable
        try Engine.apply(.placeSettlement(corner: far), to: &s)
        #expect(s.board.corners[far].owner == 0); #expect(s.players[0].hand.isEmpty); #expect(s.log.last == "Crimson built a settlement.")
    }
    @Test func sharedCrossroadIsARace() throws {
        var s = base(); s.set(hand: Cost.settlement, for: 0); s.set(hand: Cost.settlement, for: 1)
        // Crimson: 0 -e- mid -e2- far, where far has three edges. Cobalt: cob -e3- far.
        let e = s.board.corners[0].edges[0], mid = s.board.edges[e].other(0)
        let e2 = s.board.corners[mid].edges.first { $0 != e && s.board.corners[s.board.edges[$0].other(mid)].edges.count == 3 }!
        s.place(road: e2, owner: 0)
        let far = s.board.edges[e2].other(mid)
        let e3 = s.board.corners[far].edges.first { $0 != e2 }!, cob = s.board.edges[e3].other(far)
        s.place(road: e3, owner: 1); s.place(settlement: cob, owner: 1)
        // Cobalt's settlement is one segment from far, so far is blocked for everyone
        #expect(!Engine.canSettle(s, corner: far, player: 0, setup: false)); #expect(!Engine.canSettle(s, corner: far, player: 1, setup: false))
        // move Cobalt's settlement one segment further away: far becomes a shared crossroad
        s.board.corners[cob].owner = nil
        let e4 = s.board.corners[cob].edges.first { $0 != e3 }!; s.place(road: e4, owner: 1); s.place(settlement: s.board.edges[e4].other(cob), owner: 1)
        #expect(Engine.canSettle(s, corner: far, player: 0, setup: false)); #expect(Engine.canSettle(s, corner: far, player: 1, setup: false))
        try Engine.apply(.placeSettlement(corner: far), to: &s)
        #expect(!Engine.canSettle(s, corner: far, player: 1, setup: false))
        let third = s.board.corners[far].edges.first { $0 != e2 && $0 != e3 }!
        #expect(!Engine.canRoad(s, edge: third, player: 1))
    }
    @Test func cityUpgrade() throws {
        var s = base(); s.set(hand: Cost.city, for: 0)
        try Engine.apply(.upgradeCity(corner: 0), to: &s)
        #expect(s.board.corners[0].isCity); #expect(s.players[0].hand.isEmpty); #expect(s.log.last == "Crimson upgraded to a city.")
        #expect(!has(s) { $0 == .upgradeCity(corner: 0) })
    }
    @Test func pieceLimits() throws {
        var s = base(); s.set(hand: Cost.settlement + Cost.city + Cost.road, for: 0)
        #expect(Engine.piecesLeft(s, player: 0) == PiecesLeft(settlements: 4, cities: 4, roads: 14))
        for c in [10, 20, 30, 40] { s.place(settlement: c, owner: 0) }     // 5 settlements
        #expect(Engine.piecesLeft(s, player: 0).settlements == 0)
        #expect(!has(s) { if case .placeSettlement = $0 { true } else { false } })
        try Engine.apply(.upgradeCity(corner: 10), to: &s)
        #expect(Engine.piecesLeft(s, player: 0).settlements == 1)
        for e in 0..<72 where s.board.edges[e].owner == nil && s.roads(of: 0) < 15 { s.place(road: e, owner: 0) }
        #expect(Engine.piecesLeft(s, player: 0).roads == 0); #expect(!has(s) { if case .placeRoad = $0 { true } else { false } })
        for c in [20, 30, 40] { s.place(city: c, owner: 0) }
        #expect(Engine.piecesLeft(s, player: 0).cities == 0); #expect(!has(s) { if case .upgradeCity = $0 { true } else { false } })
    }
}
```

- [ ] **Step 2: Run to verify failure** — Expected: `illegalMove` / `piecesLeft` missing.
- [ ] **Step 3: Implement the build moves, `PiecesLeft`, `piecesLeft`**
- [ ] **Step 4: Run to verify pass** — `swift test --filter BuildTests` — Expected: 9 passed.
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(engine): building with placement rules and piece limits"`

---

### Task 13: Bank and harbour trades

**Files:**
- Create: `Sources/SaltmarshEngine/Engine+Trade.swift`
- Modify: `Engine+Scoring.swift` (`capturedHarbours`, `bestRate`), `Engine.swift`
- Test: `Tests/EngineTests/BankTradeTests.swift`

**Interfaces:**
- Produces: `public struct CapturedHarbour: Equatable, Sendable { public var index: Int; public var harbour: Harbour; public var buildings: [String]  /* "settlement" or "city" for corner a then b when owned */; public var heldByDescription: String /* "your settlement", "your settlement and city" */ }`; `public static func capturedHarbours(_ s: GameState, player: Int) -> [CapturedHarbour]` in harbour index order; `public static func bestRate(_ s: GameState, player: Int, giving r: Resource) -> Int` (2, 3 or 4). In `.main`: `.bankTrade(give, get)` legal when `give != get`, `hand[give] >= 4`, `bank[get] >= 1`; apply moves 4 to the bank and 1 back, log `"<Name> traded 4 timber for 1 ore with the bank."`. `.harbourTrade(h, give, get)` legal when the player holds harbour `h`, `give != get`, kind is `.any` or `.specific(give)`, `hand[give] >= ratio`, `bank[get] >= 1`; log `"<Name> traded 2 wool for 1 ore at the 2:1 wool harbour."` or `"… 3 clay for 1 grain at the 3:1 harbour."`.

- [ ] **Step 1: Write the failing tests**

```swift
@Suite struct BankTradeTests {
    func base() -> GameState { var s = TestGames.rolled(8); s.clearBoard(); s.clearHands(); return s }
    func harbour(_ s: GameState, _ kind: Harbour.Kind) -> Int { s.board.harbours.firstIndex { $0.kind == kind }! }
    @Test func bankTradeFourForOne() throws {
        var s = base(); s.set(hand: [.timber: 4], for: 0)
        try Engine.apply(.bankTrade(give: .timber, get: .ore), to: &s)
        #expect(s.players[0].hand == [.ore: 1]); #expect(s.bank[.timber] == 19); #expect(s.bank[.ore] == 18)
        #expect(s.log.last == "Crimson traded 4 timber for 1 ore with the bank.")
    }
    @Test func bankTradeInvalidCases() {
        var s = base(); s.set(hand: [.timber: 3], for: 0)
        #expect(!Engine.legalMoves(s).contains(.bankTrade(give: .timber, get: .ore)))
        s.set(hand: [.timber: 4], for: 0)
        #expect(!Engine.legalMoves(s).contains(.bankTrade(give: .timber, get: .timber)))
        s.set(hand: [.ore: 19], for: 1)                                 // bank now has 0 ore
        #expect(!Engine.legalMoves(s).contains(.bankTrade(give: .timber, get: .ore)))
        var t = TestGames.afterSetup(); t.set(hand: [.timber: 4], for: t.current)
        #expect(!Engine.legalMoves(t).contains { if case .bankTrade = $0 { true } else { false } })
    }
    @Test func bankRateNeverChanges() {
        var s = base(); let h = harbour(s, .specific(.wool)); s.place(settlement: s.board.harbours[h].a, owner: 0); s.set(hand: [.wool: 4], for: 0)
        #expect(Engine.legalMoves(s).contains(.bankTrade(give: .wool, get: .ore))); #expect(Engine.bestRate(s, player: 0, giving: .wool) == 2); #expect(Engine.bestRate(s, player: 0, giving: .ore) == 4)
    }
    @Test func noHarboursCaptured() { #expect(Engine.capturedHarbours(base(), player: 0).isEmpty) }
    @Test func capturedHarbourAndHolding() {
        var s = base(); let h = harbour(s, .any)
        s.place(settlement: s.board.harbours[h].a, owner: 0)
        #expect(Engine.capturedHarbours(s, player: 0).map(\.heldByDescription) == ["your settlement"])
        s.place(city: s.board.harbours[h].b, owner: 0)
        #expect(Engine.capturedHarbours(s, player: 0).first?.heldByDescription == "your settlement and city")
    }
    @Test func severalHarboursSeveralRows() {
        var s = base(); s.place(settlement: s.board.harbours[harbour(s, .any)].a, owner: 0); s.place(settlement: s.board.harbours[harbour(s, .specific(.grain))].a, owner: 0)
        #expect(Engine.capturedHarbours(s, player: 0).count == 2)
    }
    @Test func twoForOneTakesTwo() throws {
        var s = base(); let h = harbour(s, .specific(.wool)); s.place(settlement: s.board.harbours[h].a, owner: 0); s.set(hand: [.wool: 2], for: 0)
        #expect(!Engine.legalMoves(s).contains(.harbourTrade(harbour: h, give: .grain, get: .ore)))
        try Engine.apply(.harbourTrade(harbour: h, give: .wool, get: .ore), to: &s)
        #expect(s.players[0].hand == [.ore: 1]); #expect(s.log.last == "Crimson traded 2 wool for 1 ore at the 2:1 wool harbour.")
    }
    @Test func threeForOne() throws {
        var s = base(); let h = harbour(s, .any); s.place(settlement: s.board.harbours[h].a, owner: 0); s.set(hand: [.clay: 3], for: 0)
        try Engine.apply(.harbourTrade(harbour: h, give: .clay, get: .grain), to: &s)
        #expect(s.players[0].hand == [.grain: 1]); #expect(s.log.last == "Crimson traded 3 clay for 1 grain at the 3:1 harbour.")
    }
    @Test func notEnoughCardsAndUnownedHarbour() {
        var s = base(); let h = harbour(s, .specific(.wool)); s.place(settlement: s.board.harbours[h].a, owner: 0); s.set(hand: [.wool: 1], for: 0)
        #expect(!Engine.legalMoves(s).contains(.harbourTrade(harbour: h, give: .wool, get: .ore)))
        s.set(hand: [.wool: 2], for: 0); let other = harbour(s, .specific(.ore)); s.set(hand: [.ore: 2], for: 0)
        #expect(!Engine.legalMoves(s).contains(.harbourTrade(harbour: other, give: .ore, get: .wool)))
    }
    @Test func sharedHarbour() {
        var s = base(); let h = harbour(s, .any); s.place(settlement: s.board.harbours[h].a, owner: 0); s.place(settlement: s.board.harbours[h].b, owner: 1)
        #expect(Engine.capturedHarbours(s, player: 0).count == 1); #expect(Engine.capturedHarbours(s, player: 1).count == 1)
    }
}
```

- [ ] **Step 2: Run to verify failure** — Expected: compile errors / `illegalMove`.
- [ ] **Step 3: Implement bank and harbour trades, `capturedHarbours`, `bestRate`**
- [ ] **Step 4: Run to verify pass** — `swift test --filter BankTradeTests` — Expected: 10 passed.
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(engine): bank and harbour trades"`

---

### Task 14: Development cards

**Files:**
- Create: `Sources/SaltmarshEngine/Engine+DevCards.swift`
- Modify: `Engine.swift`
- Test: `Tests/EngineTests/DevCardTests.swift`

**Interfaces:**
- Produces: `internal static func playableCard(_ s: GameState, _ type: DevCardType) -> Int?` (index of a card of that type with `boughtOnTurn != turn`, nil when `devCardPlayedThisTurn` or for `.victoryPoint`). In `.main`: `.buyDevCard` legal when `devDeck` non-empty and `hand.contains(Cost.devCard)`; apply pays the bank, pops `devDeck.last`, appends `DevCard(type:, boughtOnTurn: turn)`, logs `"<Name> bought a development card."`. `.playKnight` legal in `.awaitingRoll` and `.main`: remove card, `knightsPlayed += 1`, `devCardPlayedThisTurn = true`, log `"<Name> played a Knight."`, `updateAwards`, phase `.movingRobber(returnTo: <phase before>)`. `.playRoadCrew` (main only): remove, flag, log `"<Name> played Road crew."`; then if `piecesLeft.roads == 0` log `"No roads left to build."` and stay `.main`; else if no `canRoad` edge log `"No room for new roads."` and stay; else phase `.placingFreeRoads(remaining: 2)`. In `.placingFreeRoads`, `.placeRoad(e)` for every `canRoad` edge: set owner without paying, log `"<Name> built a free road."`, `updateAwards`, `remaining −= 1`, then return to `.main` when remaining is 0, when roads run out (log `"No roads left to build."`) or when no legal edge remains (log `"No room for new roads."`). `.playBumperHarvest(a, b)` legal with `a <= b` when the bank holds the pair (2 of `a` when `a == b`): bank −, hand +, log `"<Name> played Bumper harvest: ore and ore."`. `.playCornerMarket(r)`: take all `r` from every other player, log `"<Name> cornered the ore market and took 5."`.

- [ ] **Step 1: Write the failing tests**

```swift
@Suite struct DevCardTests {
    func base() -> GameState { var s = TestGames.rolled(8); s.clearBoard(); s.clearHands(); s.place(settlement: 0, owner: 0); s.place(road: s.board.corners[0].edges[0], owner: 0); return s }
    func give(_ s: inout GameState, _ type: DevCardType, turn: Int? = nil) { s.players[0].devCards.append(DevCard(type: type, boughtOnTurn: turn ?? (s.turn - 1))) }
    @Test func buyingACard() throws {
        var s = base(); s.set(hand: Cost.devCard, for: 0); let top = s.devDeck.last!
        try Engine.apply(.buyDevCard, to: &s)
        #expect(s.players[0].hand.isEmpty); #expect(s.players[0].devCards == [DevCard(type: top, boughtOnTurn: s.turn)]); #expect(s.devDeck.count == 24)
        #expect(s.log.last == "Crimson bought a development card.")
    }
    @Test func buyingNotAllowed() {
        var s = base(); #expect(!Engine.legalMoves(s).contains(.buyDevCard))
        s.set(hand: Cost.devCard, for: 0); s.devDeck = []; #expect(!Engine.legalMoves(s).contains(.buyDevCard))
        var t = TestGames.afterSetup(); t.set(hand: Cost.devCard, for: t.current); #expect(!Engine.legalMoves(t).contains(.buyDevCard))
    }
    @Test func cannotPlayCardBoughtThisTurn() { var s = base(); give(&s, .knight, turn: s.turn); #expect(!Engine.legalMoves(s).contains(.playKnight)) }
    @Test func oneCardPerTurn() throws {
        var s = base(); give(&s, .bumperHarvest); give(&s, .cornerMarket)
        try Engine.apply(.playCornerMarket(.ore), to: &s)
        #expect(!Engine.legalMoves(s).contains { if case .playBumperHarvest = $0 { true } else { false } })
    }
    @Test func knightBeforeRollOthersAfter() {
        var s = TestGames.afterSetup(); s.players[s.current].devCards = [DevCard(type: .knight, boughtOnTurn: -1), DevCard(type: .bumperHarvest, boughtOnTurn: -1)]
        #expect(Engine.legalMoves(s).contains(.playKnight)); #expect(!Engine.legalMoves(s).contains { if case .playBumperHarvest = $0 { true } else { false } })
    }
    @Test func knightBeforeRollFlow() throws {
        var s = TestGames.afterSetup(); s.clearBoard(); s.clearHands(); s.current = 0; s.players[0].devCards = [DevCard(type: .knight, boughtOnTurn: -1)]
        let t = s.tile(numbered: 8); s.place(settlement: s.board.tiles[t].corners[0], owner: 1); s.set(hand: [.ore: 2], for: 1)
        try Engine.apply(.playKnight, to: &s)
        #expect(s.players[0].knightsPlayed == 1); #expect(s.log.last == "Crimson played a Knight."); #expect(s.phase == .movingRobber(returnTo: .awaitingRoll))
        #expect(!Engine.legalMoves(s).contains(.roll))
        try Engine.apply(.moveRobber(tile: t), to: &s); try Engine.apply(.steal(from: 1), to: &s)
        #expect(s.phase == .awaitingRoll); #expect(Engine.legalMoves(s).contains(.roll)); #expect(s.players[0].hand == [.ore: 1])
    }
    @Test func knightAfterRollReturnsToMain() throws {
        var s = base(); give(&s, .knight); try Engine.apply(.playKnight, to: &s)
        #expect(s.phase == .movingRobber(returnTo: .main))
    }
    @Test func knightWithNoVictimsReturnsToAwaitingRoll() throws {          // Review Focus 4
        var s = TestGames.afterSetup(); s.clearBoard(); s.clearHands(); s.current = 0; s.players[0].devCards = [DevCard(type: .knight, boughtOnTurn: -1)]
        let t = s.tile(numbered: 8); s.place(settlement: s.board.tiles[t].corners[0], owner: 0)
        try Engine.apply(.playKnight, to: &s); try Engine.apply(.moveRobber(tile: t), to: &s)
        #expect(s.phase == .awaitingRoll); #expect(Engine.legalMoves(s) == [.roll])
    }
    @Test func victoryPointIsNeverPlayable() { var s = base(); give(&s, .victoryPoint); #expect(Engine.legalMoves(s).allSatisfy { !"\($0)".hasPrefix("play") }) }
    @Test func roadCrewTwoFreeRoads() throws {
        var s = base(); give(&s, .roadCrew)
        try Engine.apply(.playRoadCrew, to: &s); #expect(s.phase == .placingFreeRoads(remaining: 2)); #expect(s.log.last == "Crimson played Road crew.")
        for _ in 0..<2 { try Engine.apply(Engine.legalMoves(s).first!, to: &s) }
        #expect(s.roads(of: 0) == 3); #expect(s.bank == .uniform(19)); #expect(Array(s.log.suffix(2)) == ["Crimson built a free road.", "Crimson built a free road."]); #expect(s.phase == .main)
    }
    @Test func roadCrewNoRoom() throws {
        var s = TestGames.rolled(8); s.clearBoard(); s.clearHands(); s.place(settlement: 0, owner: 0)
        for e in s.board.corners[0].edges { s.place(road: e, owner: 1) }
        give(&s, .roadCrew); try Engine.apply(.playRoadCrew, to: &s)
        #expect(s.log.last == "No room for new roads."); #expect(s.phase == .main)
    }
    @Test func roadCrewWithOneLegalEdgeStopsEarly() throws {                 // Review Focus 2
        var s = TestGames.rolled(8); s.clearBoard(); s.clearHands(); s.place(settlement: 0, owner: 0)
        let open = s.board.corners[0].edges[0]; for e in s.board.corners[0].edges.dropFirst() { s.place(road: e, owner: 1) }
        let far = s.board.edges[open].other(0); for e in s.board.corners[far].edges where e != open { s.place(road: e, owner: 1) }
        give(&s, .roadCrew); try Engine.apply(.playRoadCrew, to: &s); try Engine.apply(.placeRoad(edge: open), to: &s)
        #expect(s.phase == .main); #expect(s.log.last == "No room for new roads."); #expect(s.roads(of: 0) == 1)
    }
    @Test func roadCrewWithOneRoadPieceLeft() throws {                        // Review Focus 2
        var s = base(); for e in 0..<72 where s.board.edges[e].owner == nil && s.roads(of: 0) < 14 { s.place(road: e, owner: 0) }
        give(&s, .roadCrew); try Engine.apply(.playRoadCrew, to: &s); try Engine.apply(Engine.legalMoves(s).first!, to: &s)
        #expect(s.roads(of: 0) == 15); #expect(s.phase == .main); #expect(s.log.last == "No roads left to build.")
        var t = s; t.players[0].devCards = [DevCard(type: .roadCrew, boughtOnTurn: -1)]; t.devCardPlayedThisTurn = false
        try Engine.apply(.playRoadCrew, to: &t); #expect(t.log.last == "No roads left to build."); #expect(t.phase == .main)
    }
    @Test func bumperHarvest() throws {
        var s = base(); give(&s, .bumperHarvest); try Engine.apply(.playBumperHarvest(.ore, .ore), to: &s)
        #expect(s.players[0].hand == [.ore: 2]); #expect(s.bank[.ore] == 17); #expect(s.log.last == "Crimson played Bumper harvest: ore and ore.")
    }
    @Test func bumperHarvestRespectsBank() {                                   // Review Focus 3
        var s = base(); give(&s, .bumperHarvest); s.set(hand: [.ore: 18], for: 1)
        #expect(!Engine.legalMoves(s).contains(.playBumperHarvest(.ore, .ore))); #expect(Engine.legalMoves(s).contains(.playBumperHarvest(.grain, .ore)))
    }
    @Test func cornerTheMarket() throws {
        var s = base(); give(&s, .cornerMarket); s.set(hand: [.ore: 3], for: 1); s.set(hand: [.ore: 2], for: 2)
        try Engine.apply(.playCornerMarket(.ore), to: &s)
        #expect(s.players[0].hand[.ore] == 5); #expect(s.players[1].hand[.ore] == 0); #expect(s.players[2].hand[.ore] == 0)
        #expect(s.log.last == "Crimson cornered the ore market and took 5.")
    }
}
```

- [ ] **Step 2: Run to verify failure** — Expected: `illegalMove`.
- [ ] **Step 3: Implement `Engine+DevCards.swift` and the free-road branch**
- [ ] **Step 4: Run to verify pass** — `swift test --filter DevCardTests` — Expected: 16 passed.
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(engine): development cards with timing rules"`

---

### Task 15: Scoring, ending the turn and winning

**Files:**
- Modify: `Sources/SaltmarshEngine/Engine+Scoring.swift`, `Engine+Turn.swift`, `Engine+Build.swift`, `Engine+DevCards.swift`, `Engine.swift`
- Modify: `Tests/EngineTests/Helpers.swift` (add `func spreadCorners(_ n: Int, avoiding: Set<Int> = []) -> [Int]`: the first `n` corners in index order that are not in `avoiding`, not owned, and not adjacent to a chosen or owned corner; `mutating func addReach(from owned: Int, owner: Int) -> Int`: places two roads `owned → x → y` along lowest-index unowned corners and returns `y`, a corner where `canSettle(setup: false)` holds for `owner`)
- Test: `Tests/EngineTests/WinTests.swift`

**Interfaces:**
- Produces: `public static func publicPoints(_ s: GameState, player: Int) -> Int` (settlements + 2 × cities + 2 per held award); `public static func hiddenPoints(_ s: GameState, player: Int) -> Int` (victory point cards); `public static func totalPoints(_ s: GameState, player: Int) -> Int`; `@discardableResult internal static func checkWin(_ s: inout GameState) -> Bool`: when not already over and `totalPoints(current) >= 10`, phase `.gameOver(winner: current)` and log `"<Name> wins with N points!"` or `"<Name> wins with N points, including K hidden victory point card!"` (`cards` when K > 1). `checkWin` runs after `placeSettlement`, `placeRoad` (paid and free, after `updateAwards`), `upgradeCity`, `buyDevCard`, `playKnight` (after `updateAwards`), and at the start of every turn. `.endTurn` legal in `.main`: `current = (current + 1) % playerCount`, `dice = nil`, `devCardPlayedThisTurn = false`, `turn += 1`, phase `.awaitingRoll`, then `checkWin`. In `.gameOver` `legalMoves` is `[]` and every `apply` throws.

- [ ] **Step 1: Write the failing tests**

```swift
@Suite struct WinTests {
    /// Crimson has rolled; board and hands empty; Crimson owns `settlements` + `cities` buildings on spread corners and a two-road reach to `reach`.
    func crimson(settlements: Int, cities: Int) -> (s: GameState, reach: Int) {
        var s = TestGames.rolled(8); s.clearBoard(); s.clearHands()
        let spots = s.spreadCorners(settlements + cities)
        for c in spots.prefix(settlements) { s.place(settlement: c, owner: 0) }
        for c in spots.dropFirst(settlements) { s.place(city: c, owner: 0) }
        let reach = s.addReach(from: spots[0], owner: 0); return (s, reach)
    }
    @Test func pointsAreCounted() {
        var (s, _) = crimson(settlements: 3, cities: 3)
        #expect(Engine.publicPoints(s, player: 0) == 9); #expect(Engine.totalPoints(s, player: 0) == 9)
        s.players[0].devCards = [DevCard(type: .victoryPoint, boughtOnTurn: 0)]
        #expect(Engine.publicPoints(s, player: 0) == 9); #expect(Engine.hiddenPoints(s, player: 0) == 1); #expect(Engine.totalPoints(s, player: 0) == 10)
    }
    @Test func settlementAtNineWins() throws {
        var (s, reach) = crimson(settlements: 3, cities: 3); s.set(hand: Cost.settlement, for: 0)
        try Engine.apply(.placeSettlement(corner: reach), to: &s)
        #expect(s.phase == .gameOver(winner: 0)); #expect(s.log.last == "Crimson wins with 10 points!")
    }
    @Test func cityAtNineWins() throws {
        // A city replaces a settlement's 1 point with 2, so it adds one point. The feature file's
        // "| 8 | builds a city |" row is wrong and is corrected to 9 in Plan 3.
        var (s, _) = crimson(settlements: 3, cities: 3); s.set(hand: Cost.city, for: 0)
        let c = s.board.corners.indices.first { s.board.corners[$0].owner == 0 && !s.board.corners[$0].isCity }!
        try Engine.apply(.upgradeCity(corner: c), to: &s); #expect(s.phase == .gameOver(winner: 0))
    }
    @Test func longestRoadAtEightWins() throws {
        var (s, _) = crimson(settlements: 4, cities: 2); s.set(hand: Cost.road, for: 0)
        var used: Set<Int> = Set(s.board.corners.indices.filter { s.board.corners[$0].owner != nil })
        let start = s.board.corners.indices.first { s.board.corners[$0].owner == 0 }!
        let chain = s.chain(from: start, length: 5, avoiding: &used); s.placeChain(Array(chain.prefix(4)), owner: 0)
        try Engine.apply(.placeRoad(edge: chain[4]), to: &s)
        #expect(s.longestRoadHolder == 0); #expect(s.phase == .gameOver(winner: 0))
    }
    @Test func thirdKnightAtEightWins() throws {
        var (s, _) = crimson(settlements: 4, cities: 2); s.players[0].knightsPlayed = 2; s.players[0].devCards = [DevCard(type: .knight, boughtOnTurn: -1)]
        try Engine.apply(.playKnight, to: &s)
        #expect(s.largestArmyHolder == 0); #expect(s.phase == .gameOver(winner: 0))
    }
    @Test func victoryPointCardAtNineWins() throws {
        var (s, _) = crimson(settlements: 3, cities: 3); s.set(hand: Cost.devCard, for: 0); s.devDeck[s.devDeck.count - 1] = .victoryPoint
        try Engine.apply(.buyDevCard, to: &s)
        #expect(s.phase == .gameOver(winner: 0)); #expect(s.log.last == "Crimson wins with 10 points, including 1 hidden victory point card!")
    }
    @Test func hiddenCardsCountAtStartOfTurn() throws {
        var (s, _) = crimson(settlements: 4, cities: 2); s.players[0].devCards = [DevCard(type: .victoryPoint, boughtOnTurn: 0), DevCard(type: .victoryPoint, boughtOnTurn: 0)]
        s.current = 2; s.phase = .main
        try Engine.apply(.endTurn, to: &s)
        #expect(s.phase == .gameOver(winner: 0)); #expect(s.log.last == "Crimson wins with 10 points, including 2 hidden victory point cards!")
    }
    @Test func passiveWinIsCaughtAtStartOfTurn() throws {
        var (s, _) = crimson(settlements: 4, cities: 2)
        var used: Set<Int> = Set(s.board.corners.indices.filter { s.board.corners[$0].owner != nil }.flatMap { [$0] + s.board.corners[$0].adjacent })
        s.placeChain(s.chain(from: s.board.corners.indices.first { !used.contains($0) }!, length: 6, avoiding: &used), owner: 0)
        let amber = s.chain(from: s.board.corners.indices.first { !used.contains($0) && s.board.corners[$0].edges.count == 3 }!, length: 7, avoiding: &used)
        s.placeChain(amber, owner: 2); Engine.updateAwards(&s)
        #expect(s.longestRoadHolder == 2); #expect(Engine.totalPoints(s, player: 0) == 8)
        // a corner inside Amber's chain with a third, free edge
        // corners between edges 1-2 … 4-5 of Amber's chain: cutting there leaves pieces of at most 5
        let inner = (1..<5).map { Set([s.board.edges[amber[$0]].a, s.board.edges[amber[$0]].b]).intersection([s.board.edges[amber[$0 + 1]].a, s.board.edges[amber[$0 + 1]].b]).first! }
        let m = inner.first { s.board.corners[$0].edges.count == 3 }!
        let spur = s.board.corners[m].edges.first { s.board.edges[$0].owner == nil }!
        s.place(road: spur, owner: 1); s.set(hand: Cost.settlement, for: 1); s.current = 1; s.phase = .main
        try Engine.apply(.placeSettlement(corner: m), to: &s)
        #expect(s.longestRoadHolder == 0); #expect(Engine.totalPoints(s, player: 0) == 10)
        if case .gameOver = s.phase { Issue.record("won on someone else's turn") }
        try Engine.apply(.endTurn, to: &s); #expect(s.current == 2); if case .gameOver = s.phase { Issue.record("Amber's turn should not end the game") }
        s.phase = .main; try Engine.apply(.endTurn, to: &s)
        #expect(s.phase == .gameOver(winner: 0))
    }
    @Test func gameLocksAfterWin() throws {
        var (s, reach) = crimson(settlements: 3, cities: 3); s.set(hand: Cost.settlement, for: 0)
        try Engine.apply(.placeSettlement(corner: reach), to: &s)
        #expect(Engine.legalMoves(s).isEmpty)
        #expect(throws: EngineError.illegalMove(.endTurn)) { try Engine.apply(.endTurn, to: &s) }
    }
    @Test func endTurnResets() throws {
        var s = TestGames.rolled(8); s.devCardPlayedThisTurn = true; let turn = s.turn, cur = s.current
        try Engine.apply(.endTurn, to: &s)
        #expect(s.current == (cur + 1) % 3); #expect(s.dice == nil); #expect(!s.devCardPlayedThisTurn); #expect(s.turn == turn + 1); #expect(s.phase == .awaitingRoll)
    }
    @Test func endTurnLockedUntilRoll() { #expect(!Engine.legalMoves(TestGames.afterSetup()).contains(.endTurn)) }
}
```

- [ ] **Step 2: Run to verify failure** — Expected: compile errors / `illegalMove(.endTurn)`.
- [ ] **Step 3: Implement scoring, `checkWin`, wire it in, add `.endTurn`, add the two Helpers**
- [ ] **Step 4: Run to verify pass** — `swift test --filter WinTests` — Expected: 11 passed. Then run `swift test` and confirm every earlier suite still passes (the win wiring changes `apply`).
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(engine): scoring, end turn and win detection"`

---

### Task 16: Trading between players

**Files:**
- Modify: `Sources/SaltmarshEngine/Engine+Trade.swift`, `Engine.swift`
- Test: `Tests/EngineTests/PlayerTradeTests.swift`

**Interfaces:**
- Produces: `public static func validate(_ offer: TradeOffer, in s: GameState) -> String?` returning nil when valid, else one of `"give side is empty"`, `"want side is empty"`, `"same resource on both sides"`, `"proposer cannot pay"`, `"target is the proposer"`, `"target out of range"`. In `.main`, `.proposeTrade(o)` legal when `o.proposer == current` and `validate == nil`; `legalMoves` lists the canonical set: every offer with `to == nil`, one resource on each side, quantities 1 or 2, `give != want`, payable. Apply: responders = (`o.to` alone, or every other seat) with `hand.total > 0`; when none, log `"Nobody can answer that offer."` and stay in `.main`; otherwise log `"<Name> offers 2 timber for 1 ore."` (or `"… for 1 ore to Cobalt."` when targeted) and phase `.tradeOffered(offer: o, responses: [seat: .pending …])`. `.respondToTrade(seat, r)` legal when `responses[seat] == .pending` and `r != .pending`; `.accepted` requires `hand(seat).contains(o.want)`; `.countered(c)` requires `c.proposer == o.proposer`, `c.to == seat`, `validate(c) == nil`, `hand(seat).contains(c.want)`, else `invalidOffer`. Logs `"Cobalt accepted the offer."`, `"Cobalt declined the offer."`, `"Cobalt countered: 1 ore for 3 timber."`. `.executeTrade(with: seat)` legal when no response is `.pending` and `responses[seat]` is `.accepted` or `.countered`: cards move between the two hands on the accepted or countered terms, log `"Crimson traded 2 timber with Cobalt for 1 ore."`, phase `.main`. `.withdrawTrade` legal whenever in `.tradeOffered`: log `"Crimson withdrew the offer."`, phase `.main`. `actingPlayer` in `.tradeOffered` is the lowest-index pending responder, else `current`.

- [ ] **Step 1: Write the failing tests**

```swift
@Suite struct PlayerTradeTests {
    func base() -> GameState { var s = TestGames.rolled(8); s.clearBoard(); s.clearHands(); s.set(hand: [.timber: 3, .wool: 1], for: 0); s.set(hand: [.ore: 2], for: 1); s.set(hand: [.grain: 2, .ore: 1], for: 2); return s }
    let offer = TradeOffer(proposer: 0, give: [.timber: 2], want: [.ore: 1], to: nil)
    @Test func validation() {
        let s = base()
        #expect(Engine.validate(offer, in: s) == nil)
        #expect(Engine.validate(TradeOffer(proposer: 0, give: [], want: [.ore: 1], to: nil), in: s) == "give side is empty")
        #expect(Engine.validate(TradeOffer(proposer: 0, give: [.timber: 1], want: [], to: nil), in: s) == "want side is empty")
        #expect(Engine.validate(TradeOffer(proposer: 0, give: [.timber: 1], want: [.timber: 1, .ore: 1], to: nil), in: s) == "same resource on both sides")
        #expect(Engine.validate(TradeOffer(proposer: 0, give: [.timber: 4], want: [.ore: 1], to: nil), in: s) == "proposer cannot pay")
        #expect(Engine.validate(TradeOffer(proposer: 0, give: [.timber: 1], want: [.ore: 1], to: 0), in: s) == "target is the proposer")
        #expect(Engine.validate(TradeOffer(proposer: 0, give: [.timber: 1], want: [.ore: 1], to: 3), in: s) == "target out of range")
    }
    @Test func proposeToEveryoneSkipsEmptyHands() throws {
        var s = base(); s.set(hand: [:], for: 2)
        try Engine.apply(.proposeTrade(offer), to: &s)
        #expect(s.phase == .tradeOffered(offer: offer, responses: [1: .pending])); #expect(s.log.last == "Crimson offers 2 timber for 1 ore."); #expect(Engine.actingPlayer(s) == 1)
    }
    @Test func unanswerableOfferStaysInMain() throws {                            // Review Focus 5
        var s = base(); s.set(hand: [:], for: 1); s.set(hand: [:], for: 2)
        try Engine.apply(.proposeTrade(offer), to: &s)
        #expect(s.phase == .main); #expect(s.log.last == "Nobody can answer that offer.")
    }
    @Test func acceptRequiresPayment() throws {
        var s = base(); try Engine.apply(.proposeTrade(TradeOffer(proposer: 0, give: [.timber: 1], want: [.grain: 1], to: nil)), to: &s)
        #expect(throws: EngineError.self) { try Engine.apply(.respondToTrade(seat: 1, .accepted), to: &s) }   // Cobalt has no grain
        #expect(Engine.legalMoves(s).contains(.respondToTrade(seat: 1, .declined))); #expect(!Engine.legalMoves(s).contains(.respondToTrade(seat: 1, .accepted)))
    }
    @Test func respondThenExecute() throws {
        var s = base(); try Engine.apply(.proposeTrade(offer), to: &s)
        #expect(!Engine.legalMoves(s).contains(.executeTrade(with: 1)))
        try Engine.apply(.respondToTrade(seat: 1, .accepted), to: &s); #expect(s.log.last == "Cobalt accepted the offer.")
        #expect(!Engine.legalMoves(s).contains(.executeTrade(with: 1)))              // Amber still pending
        try Engine.apply(.respondToTrade(seat: 2, .declined), to: &s); #expect(s.log.last == "Amber declined the offer.")
        #expect(Engine.actingPlayer(s) == 0); #expect(Engine.legalMoves(s).contains(.executeTrade(with: 1))); #expect(!Engine.legalMoves(s).contains(.executeTrade(with: 2)))
        let bank = s.bank
        try Engine.apply(.executeTrade(with: 1), to: &s)
        #expect(s.players[0].hand == [.timber: 1, .wool: 1, .ore: 1]); #expect(s.players[1].hand == [.timber: 2, .ore: 1]); #expect(s.bank == bank)
        #expect(s.log.last == "Crimson traded 2 timber with Cobalt for 1 ore."); #expect(s.phase == .main)
    }
    @Test func counterIsValidatedAndExecutesOnItsTerms() throws {
        var s = base(); try Engine.apply(.proposeTrade(offer), to: &s)
        let bad = TradeOffer(proposer: 0, give: [.timber: 5], want: [.ore: 1], to: 1)
        #expect(throws: EngineError.self) { try Engine.apply(.respondToTrade(seat: 1, .countered(bad)), to: &s) }
        let counter = TradeOffer(proposer: 0, give: [.timber: 3], want: [.ore: 1], to: 1)
        try Engine.apply(.respondToTrade(seat: 1, .countered(counter)), to: &s); #expect(s.log.last == "Cobalt countered: 3 timber for 1 ore.")
        try Engine.apply(.respondToTrade(seat: 2, .declined), to: &s)
        try Engine.apply(.executeTrade(with: 1), to: &s)
        #expect(s.players[0].hand == [.wool: 1, .ore: 1]); #expect(s.players[1].hand == [.timber: 3, .ore: 1])
    }
    @Test func withdrawLeavesHandsUnchanged() throws {
        var s = base(); let hands = s.players.map(\.hand); try Engine.apply(.proposeTrade(offer), to: &s)
        try Engine.apply(.withdrawTrade, to: &s)
        #expect(s.players.map(\.hand) == hands); #expect(s.phase == .main); #expect(s.log.last == "Crimson withdrew the offer.")
    }
    @Test func targetedOfferAsksOnlyThatSeat() throws {
        var s = base(); var o = offer; o.to = 2
        try Engine.apply(.proposeTrade(o), to: &s)
        #expect(s.phase == .tradeOffered(offer: o, responses: [2: .pending])); #expect(s.log.last == "Crimson offers 2 timber for 1 ore to Amber.")
    }
    @Test func canonicalOffersInLegalMoves() {
        let offers = Engine.legalMoves(base()).compactMap { if case .proposeTrade(let o) = $0 { o } else { nil } }
        #expect(!offers.isEmpty)
        for o in offers {
            #expect(o.to == nil); #expect(o.give.nonZero.count == 1 && o.want.nonZero.count == 1)
            #expect((1...2).contains(o.give.total) && (1...2).contains(o.want.total)); #expect(Engine.validate(o, in: base()) == nil)
        }
        #expect(offers.contains(TradeOffer(proposer: 0, give: [.timber: 2], want: [.ore: 2], to: nil))); #expect(!offers.contains { $0.give[.wool] == 2 })
    }
    @Test func proposingIsOnlyLegalAfterRolling() { #expect(!Engine.legalMoves(TestGames.afterSetup()).contains { if case .proposeTrade = $0 { true } else { false } }) }
}
```

- [ ] **Step 2: Run to verify failure** — Expected: `validate` missing / `illegalMove`.
- [ ] **Step 3: Implement player trading in `Engine+Trade.swift`, extend `actingPlayer` and dispatch**
- [ ] **Step 4: Run to verify pass** — `swift test --filter PlayerTradeTests` — Expected: 10 passed.
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(engine): trading between players with accept, decline, counter"`

---

### Task 17: The redacted player view and hidden-state sampling

**Files:**
- Create: `Sources/SaltmarshEngine/Engine+View.swift`
- Modify: `Tests/EngineTests/Helpers.swift` (add `static func midGame(seed: UInt64, moves: Int = 60) -> GameState`: `afterSetup(seed:)` then `moves` uniformly random legal moves chosen with `SeededRNG(seed: seed)`, stopping early at `gameOver`)
- Test: `Tests/EngineTests/ViewTests.swift`

**Interfaces:**
- Produces:
  - `public struct OpponentSummary: Codable, Equatable, Sendable { public var index: Int; public var seat: Seat; public var controller: Controller; public var cardCount: Int; public var devCardCount: Int; public var knightsPlayed: Int; public var roadLength: Int; public var publicPoints: Int }`
  - `public struct PlayerView: Codable, Equatable, Sendable { public var me: Int; public var playerCount: Int; public var controllers: [Controller]; public var hand: ResourceCounts; public var devCards: [DevCard]; public var knightsPlayed: Int; public var opponents: [OpponentSummary]  /* every other seat, seat order */; public var board: Board; public var robberTile: Int; public var bank: ResourceCounts; public var dice: [Int]?; public var deckCount: Int; public var devCardPlayedThisTurn: Bool; public var longestRoadHolder: Int?; public var largestArmyHolder: Int?; public var phase: Phase; public var turn: Int; public var firstPlayer: Int; public var current: Int }`
  - `public static func view(_ s: GameState, for player: Int) -> PlayerView`
  - `public static func sampleFullState(from v: PlayerView, using rng: inout SeededRNG) -> GameState`: `me` gets the real hand and cards; each opponent gets `cardCount` cards drawn one at a time with weight `1 + Σ over their buildings of (pips of each adjacent land tile producing that resource) × (2 for a city)`, and `devCardCount` cards drawn from `remaining` = `deckComposition` minus `v.devCards` minus every player's `knightsPlayed` (clamped at 0) as `DevCard(type:, boughtOnTurn: -1)`; `devDeck` = what is left of `remaining`, shuffled, trimmed to `deckCount` (padded with `.knight` if short); `bank`, `board`, `robberTile`, `dice`, `phase`, `turn`, `firstPlayer`, `current`, awards and flags copied; `rng = SeededRNG(seed: rng.next())`; `seed = 0`; `log = []`; `forcedRolls = []`.

- [ ] **Step 1: Write the failing tests**

```swift
@Suite struct ViewTests {
    @Test func viewHidesOpponentCardsAndKeepsCounts() {
        let s = TestGames.midGame(seed: 3), v = Engine.view(s, for: 0)
        #expect(v.me == 0); #expect(v.hand == s.players[0].hand); #expect(v.devCards == s.players[0].devCards)
        #expect(v.opponents.map(\.index) == [1, 2])
        for o in v.opponents { #expect(o.cardCount == s.players[o.index].hand.total); #expect(o.devCardCount == s.players[o.index].devCards.count); #expect(o.roadLength == Engine.roadLength(s, player: o.index)); #expect(o.publicPoints == Engine.publicPoints(s, player: o.index)) }
        let json = String(decoding: try! JSONEncoder().encode(v), as: UTF8.self)
        #expect(!json.contains("\"devDeck\"")); #expect(v.deckCount == s.devDeck.count)
    }
    @Test func viewCarriesPublicFacts() {
        let s = TestGames.midGame(seed: 4), v = Engine.view(s, for: 1)
        #expect(v.board == s.board && v.bank == s.bank && v.robberTile == s.robberTile && v.phase == s.phase && v.dice == s.dice && v.longestRoadHolder == s.longestRoadHolder && v.current == s.current && v.turn == s.turn)
    }
    @Test func sampledStateRespectsCounts() {
        let s = TestGames.midGame(seed: 5), v = Engine.view(s, for: 0); var rng = SeededRNG(seed: 99)
        let g = Engine.sampleFullState(from: v, using: &rng)
        #expect(g.players[0].hand == s.players[0].hand && g.players[0].devCards == s.players[0].devCards)
        for o in v.opponents { #expect(g.players[o.index].hand.total == o.cardCount); #expect(g.players[o.index].devCards.count == o.devCardCount); #expect(g.players[o.index].knightsPlayed == o.knightsPlayed) }
        #expect(g.devDeck.count == v.deckCount); #expect(g.bank == v.bank); #expect(g.board == v.board); #expect(g.phase == v.phase); #expect(g.current == v.current)
        #expect(g.devDeck.count + g.players.flatMap(\.devCards).count + g.players.map(\.knightsPlayed).reduce(0, +) <= 25)
    }
    @Test func sampledStateIsPlayable() throws {
        let s = TestGames.midGame(seed: 6), v = Engine.view(s, for: s.current); var rng = SeededRNG(seed: 1)
        var g = Engine.sampleFullState(from: v, using: &rng)
        for _ in 0..<50 { let legal = Engine.legalMoves(g); if legal.isEmpty { break }; try Engine.apply(legal[Int(rng.next() % UInt64(legal.count))], to: &g) }
    }
    @Test func samplingCannotReproduceHiddenHands() {
        var differs = false
        for seed in 1...20 {
            let s = TestGames.midGame(seed: UInt64(seed)); var rng = SeededRNG(seed: UInt64(seed))
            let g = Engine.sampleFullState(from: Engine.view(s, for: 0), using: &rng)
            if (1..<3).contains(where: { g.players[$0].hand != s.players[$0].hand }) { differs = true }
        }
        #expect(differs)
    }
    @Test func sampleIsDeterministicForSeed() {
        let v = Engine.view(TestGames.midGame(seed: 7), for: 0); var a = SeededRNG(seed: 2), b = SeededRNG(seed: 2)
        #expect(Engine.sampleFullState(from: v, using: &a) == Engine.sampleFullState(from: v, using: &b))
    }
}
```

- [ ] **Step 2: Run to verify failure** — Expected: compile errors.
- [ ] **Step 3: Implement `Engine+View.swift` and `TestGames.midGame`**
- [ ] **Step 4: Run to verify pass** — `swift test --filter ViewTests` — Expected: 6 passed.
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(engine): redacted PlayerView and hidden-state sampling"`

---

### Task 18: Invariants, replay and the random-game property test

**Files:**
- Create: `Sources/SaltmarshEngine/Engine+Invariants.swift`
- Modify: `Tests/EngineTests/Helpers.swift` (add `static func randomGame(seed: UInt64, maxMoves: Int = 6000, check: ((GameState) -> Void)? = nil) -> (final: GameState, moves: [Move])`: a fresh 3-player game, uniformly random legal moves from `SeededRNG(seed:)`, calling `check` after every move, stopping at `gameOver` or `maxMoves`)
- Test: `Tests/EngineTests/InvariantTests.swift`

**Interfaces:**
- Produces: `public static func invariantViolations(_ s: GameState) -> [String]`, one line per broken rule: a negative hand or bank count; `bank[r] + Σ hands[r] != 19` for any `r`; two adjacent owned corners; a road touching neither an own building nor another own road; outside setup, a building with no own road at it; a longest road holder with fewer than 5 or not the unique maximum (ties with the holder allowed); a largest army holder with fewer than 3 or not the maximum; `devDeck.count + Σ devCards.count > 25`; any player over a piece limit; `robberTile` out of range; `current` or `firstPlayer` out of range. `public static func replay(_ config: GameConfig, moves: [Move]) throws -> GameState` applies the moves to `newGame(config)`.

- [ ] **Step 1: Write the failing tests**

```swift
@Suite struct InvariantTests {
    static let games = Int(ProcessInfo.processInfo.environment["SALTMARSH_GAMES"] ?? "") ?? 1000
    @Test func randomGamesKeepEveryInvariant() {
        var finished = 0
        for seed in 0..<Self.games {
            let (final, _) = TestGames.randomGame(seed: UInt64(seed)) { s in
                let bad = Engine.invariantViolations(s); #expect(bad.isEmpty, "seed \(seed) turn \(s.turn): \(bad)")
            }
            if case .gameOver = final.phase { finished += 1 }
        }
        #expect(finished > 0)
    }
    @Test func replayReproducesFinalState() throws {
        for seed in 0..<50 {
            let (final, moves) = TestGames.randomGame(seed: UInt64(seed), maxMoves: 800)
            let config = GameConfig(controllers: [.human, .human, .human], seed: UInt64(seed))
            #expect(try Engine.replay(config, moves: moves) == final, "seed \(seed)")
        }
    }
    @Test func invariantsDetectBrokenStates() {
        var s = TestGames.afterSetup(); s.players[0].hand[.ore] = -1
        #expect(Engine.invariantViolations(s).contains { $0.contains("negative") || $0.contains("-1") })
        var t = TestGames.afterSetup(); t.longestRoadHolder = 1
        #expect(!Engine.invariantViolations(t).isEmpty)
        var u = TestGames.afterSetup(); u.bank[.timber] += 1
        #expect(Engine.invariantViolations(u).contains { $0.contains("timber") })
    }
    @Test func cleanStatesHaveNoViolations() {
        #expect(Engine.invariantViolations(TestGames.afterSetup()).isEmpty)
        #expect(Engine.invariantViolations(TestGames.midGame(seed: 2)).isEmpty)
    }
}
```

- [ ] **Step 2: Run to verify failure** — Expected: compile errors.
- [ ] **Step 3: Implement `Engine+Invariants.swift` and `TestGames.randomGame`**

`randomGame` must use the seed for both `GameConfig(seed:)` and the move picker so `replay` with the same config reproduces it; `forcedRolls` stays empty.

- [ ] **Step 4: Run to verify pass and time it**

Run: `time swift test --filter InvariantTests`
Expected: 4 passed. If the suite takes more than 90 s in debug, change the default in `games` to 200 and note in the test that `SALTMARSH_GAMES=1000` runs the full set; record the measured times in the commit message.

- [ ] **Step 5: Commit** — `git add -A && git commit -m "test(engine): invariants, replay and random-game property test"`

---

## Plan completion

- [ ] Run the whole suite: `swift test` — every suite passes; note the total test count and wall time.
- [ ] Regenerate and build the app project to prove the package still links: `xcodegen generate && xcodebuild -project SaltmarshIsles.xcodeproj -scheme SaltmarshIsles -destination 'platform=macOS' build | tail -2` — `** BUILD SUCCEEDED **`.
- [ ] Whole-branch review per subagent-driven-development, with the design's section 4, 5 and 6.1 and this plan's Interfaces blocks as the checklist. Fix anything found; commit.
- [ ] Update the Roadmap table in `docs/superpowers/plans/2026-11-02-saltmarsh-native-plan.md`: Plan 1 → done, with the test count; commit `docs: mark plan 1 complete`.
