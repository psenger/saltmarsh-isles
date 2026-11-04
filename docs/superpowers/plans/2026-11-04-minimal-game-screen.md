# Minimal playable game screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (this repo's subagent dispatches hang on permission prompts; see the master plan's Execution notes) to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the board preview with a screen that plays a whole game on Mac and iPhone, so the owner can play before the AI plans start.

**Architecture:** Views only turn `ScreenState` into pixels and call `GameViewModel` entry points. Everything testable (board hit-testing, labels, the file store) goes in `SaltmarshGame` under `swift test`. Every move the engine allows is reachable from the screen. Plan 5 keeps these views and adds polish: confetti, animation, effort descriptions, the order strip highlight, iPad tuning.

**Tech Stack:** Swift 6, SwiftUI, `@Observable`, Swift Testing, XCUITest.

**Spec:** `docs/superpowers/specs/2026-11-02-saltmarsh-native-design.md` (sections 2, 4, 5.5, 6.6, 7), `saltmarsh-isles-spec.md` section 5, `saltmarsh-isles.feature`.

## Global Constraints

- Inherits the master plan's Global Constraints, including no `Co-Authored-By` trailer.
- No rules, AI or test-relevant strings in `App/`; labels come from `Strings`.
- Layout: board beside panel when wider than tall, board above a scrolling panel otherwise.
- New game defaults: 3 players, Crimson human, the rest Mate.
- "Preview win" is Debug builds only. AI pacing is `RealPacing()` (0.5 s).
- No animation is load-bearing; this screen has none.

## Review Focus

1. A tap on the board while an AI acts, or away from any target: nothing happens. (Task 1)
2. A tap between two targets on an iPhone-sized board: the nearest legal target wins. (Task 1)
3. A save file that is corrupt or from an older build: `load` throws, `resume()` returns false, and the app offers a new game. (Task 2)
4. Quitting during a phase that nests state (trade offered, choosing a victim): the save round-trips exactly. (Task 2)
5. An AI proposes a trade to the human: the panel swaps to Accept and Decline, hides the hand, and the game continues after either. (Task 3, manual on the simulator if the random stand-in does not propose during the UI test)

---

## File structure

```
Sources/SaltmarshGame/Strings.swift          public, plus stealFrom, tradeWith, cardCount, piecesLeft
Sources/SaltmarshGame/BoardTap.swift         BoardTap, ScreenState.boardTap(x:y:), GameViewModel.tapBoard(x:y:)
Sources/SaltmarshGame/FileGameStore.swift    GameStore on a directory
Tests/GameTests/BoardTapTests.swift
Tests/GameTests/FileGameStoreTests.swift
App/SaltmarshIslesApp.swift                  shows GameScreen
App/Views/BoardView.swift                    draws from ScreenState, reports taps
App/Views/GameScreen.swift                   owns the view model, layout, sheet, overlay
App/Views/GamePanel.swift                    header, status, dice, hold, bank, turn buttons, discard, steal, responder, scoreboard, log
App/Views/TradeAndCards.swift                bank, harbour and player trading, development cards
App/Views/NewGameSheet.swift
App/Views/VictoryOverlay.swift
App/Views/BoardPreviewScreen.swift           deleted
AppUITests/GameFlowTests.swift
```

---

### Task 1: Board hit-testing and shared labels

**Files:** Create `Sources/SaltmarshGame/BoardTap.swift`; modify `Sources/SaltmarshGame/Strings.swift`; test `Tests/GameTests/BoardTapTests.swift`.

**Interfaces:** Produces `public enum BoardTap: Equatable { case corner(Int), edge(Int), tile(Int) }`; `ScreenState.boardTap(x: Double, y: Double) -> BoardTap?` in board space (origin at the board centre); `GameViewModel.tapBoard(x: Double, y: Double)`; public `Strings` with `stealFrom(_:) "Steal from Cobalt"`, `tradeWith(_:) "Trade with Cobalt"`, `cardCount(_:) "5 cards"`, `piecesLeft(_:) "3 left"`.

- [ ] **Step 1:** Write `BoardTapTests`: a setup-phase tap 5 units off a glowing corner gives `.corner`; a road-phase tap at a dashed edge's midpoint gives `.edge`; a robber-phase tap at a selectable tile's centre gives `.tile`; a tap at the robber's current tile centre, or at (1000, 1000), gives nil; a choosing-victim tap on a steal target corner gives `.corner`; a state derived with `aiThinking: true` gives nil; a tap midway between two glowing corners picks the nearer one; `tapBoard` during setup places the settlement; the four `Strings` labels read as above.
- [ ] **Step 2:** `swift test --filter BoardTapTests`. Expected: fails to compile, `boardTap` is missing.
- [ ] **Step 3:** Implement. Targets are `glowingCorners`, `pulsingSettlements` and steal target corners within 40 board units, `dashedEdges` by midpoint within 40, `selectableTiles` by centre within 58. Nearest target wins. Make `Strings` and its members public.
- [ ] **Step 4:** `swift test --filter BoardTapTests`. Expected: pass.
- [ ] **Step 5:** Commit `feat(game): board hit-testing and shared panel labels`.

### Task 2: File store

**Files:** Create `Sources/SaltmarshGame/FileGameStore.swift`; test `Tests/GameTests/FileGameStoreTests.swift`.

**Interfaces:** Produces `public final class FileGameStore: GameStore` with `public init(directory: URL)`, saving JSON to `<directory>/game.json`, creating the directory on save.

- [ ] **Step 1:** Write `FileGameStoreTests` against a unique temp directory: `load` with no file is nil; save then load equals the state, for a mid-game state, a `tradeOffered` state and a `choosingVictim` state; `clear` makes `load` nil and is safe with no file; a corrupt file makes `load` throw and `GameViewModel.resume()` return false.
- [ ] **Step 2:** `swift test --filter FileGameStoreTests`. Expected: fails to compile, `FileGameStore` is missing.
- [ ] **Step 3:** Implement with `JSONEncoder`, `JSONDecoder` and an atomic write.
- [ ] **Step 4:** `swift test --filter FileGameStoreTests`. Expected: pass.
- [ ] **Step 5:** Commit `feat(game): file store for autosave`.

### Task 3: The game screen

**Files:** Create `App/Views/GameScreen.swift`, `GamePanel.swift`, `TradeAndCards.swift`, `NewGameSheet.swift`, `VictoryOverlay.swift`, `AppUITests/GameFlowTests.swift`; modify `App/Views/BoardView.swift`, `App/SaltmarshIslesApp.swift`; delete `App/Views/BoardPreviewScreen.swift`.

**Interfaces:** Consumes Task 1 and Task 2. `BoardView(screen: ScreenState, onTap: (Double, Double) -> Void)`. Accessibility identifiers: `board`, `header`, `status`; buttons use their label.

- [ ] **Step 1:** Write `testPlaysThroughSetupToTheFirstRoll`: tap "New game" if a saved game resumed; tap "Start game"; repeat "Roll for first" until setup; on each of Crimson's placements, sweep taps across a grid over `board` until `status` changes; when `status` reads "Roll the dice to start your turn." tap "Roll dice" and assert the status changes.
- [ ] **Step 2:** `make project`, then `xcodebuild test -only-testing:AppUITests/GameFlowTests` on the iPhone 15 Pro 17.5 simulator. Expected: fails, there is no "Start game".
- [ ] **Step 3:** `BoardView`: keep the existing layers; add roads, settlements and cities in seat colours, glowing corners, dashed edges, selectable tile outlines, pulsing settlement and steal target rings, hit number disc ring, harbour rings, champion rings; convert a `SpatialTapGesture` location to board space.
- [ ] **Step 4:** `GamePanel`: a title reading "Saltmarsh Isles", header in `headerSeat` colour, status, dice, order strip, hold, bank row, then by moment: Accept and Decline with `acceptProblem` when Decline is enabled; `discardBox`; steal buttons; otherwise roll, build with "N left", end turn. Scoreboard, last 30 log lines, New game, and Preview win under `#if DEBUG`.
- [ ] **Step 5:** `TradeAndCards`: hidden during AI turns. Bank trade pickers on `ui.bankChoice`; harbour rows on `ui.harbourChoice`; development cards with Buy and Play, using menus of legal choices for Bumper harvest and Corner the market; offer builder, target picker, Offer, responses with "Trade with", Withdraw.
- [ ] **Step 6:** `NewGameSheet` per design section 7, without the effort descriptions. `VictoryOverlay` from `screen.victory`, with its close button on `.cancelAction`. `GameScreen` wires `FileGameStore` in Application Support and `RealPacing()`, resumes on launch, and otherwise opens the sheet.
- [ ] **Step 7:** Run the Step 2 command, then `make mac`. Expected: the UI test passes and the Mac build succeeds.
- [ ] **Step 8:** Commit `feat(app): playable game screen on Mac and iPhone`.

### Task 4: Launch scenarios, resume and verification

**Files:** Modify `AppUITests/GameFlowTests.swift`, `docs/superpowers/plans/2026-11-02-saltmarsh-native-plan.md`.

- [ ] **Step 1:** Add `testTheWinScreenIsHiddenAtLoad` (no "Victory" or "Preview" title on launch), `testEscapeClosesTheWinScreen` (macOS only, opening it with "Preview win"), `testPreviewWinClosesWithBackToTheGame`, and `testRelaunchResumesTheGame` (start a game, terminate, launch, no "Start game" sheet and the same `header`). Name them after the `@ui` scenarios.
- [ ] **Step 2:** Run all of `AppUITests` on the iPhone simulator. Expected: pass. Mac XCUITest needs the owner's authentication, so it runs only when they are present.
- [ ] **Step 3:** `swift test`. Expected: all pass. Screenshot the running app on the iPhone simulator and on the Mac and read both images: board, pieces and panel visible, nothing clipped.
- [ ] **Step 4:** Update the master plan: record the inserted screen in Execution and link this plan from the Roadmap. Commit `test(ui): launch scenarios and resume; docs: record the playable screen`.
