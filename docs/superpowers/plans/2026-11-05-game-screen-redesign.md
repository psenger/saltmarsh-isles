# Game Screen Redesign Implementation Plan

> **For agentic workers:** executed inline with superpowers:executing-plans, on the owner's instruction. No implementer subagents. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix every control in one place on Mac and iPhone, split the panel into tabs under a full-width header, draw real dice, and hide the game between different humans.

**Architecture:** `ScreenState` gains an optional `handover`; `GameScreen` renders only the handover view while it is set. Existing `ScreenState` fields keep their meaning, so the three-human feature file background stands. All layout changes are in `App/Views`.

**Tech Stack:** Swift 6, SwiftUI, Swift Testing, XCUITest.

**Spec:** `docs/superpowers/specs/2026-11-05-game-screen-redesign-design.md`

## Global Constraints

- No rule changes; the engine is untouched.
- Text and enabled flags live in `ScreenState` and `Strings`; no rules or test-relevant strings in `App/`.
- Fits 760 by 520 on Mac and iPhone 15 Pro portrait.
- Existing accessibility identifiers stay where the element still exists.
- One commit per task. No `Co-Authored-By` trailers. No em-dashes or section signs.

## Review Focus

- Two humans with the first setup placement by an AI: the first real turn of the last human to place shows no blank (`HandoverTests.setupHandsOverSilently`).
- Reopening during an AI's turn with two humans: no blank until a human must act (`HandoverTests.noBlankWhileAnAIActs`).
- A roller who discards first keeps the device; the next discarder is blanked (`HandoverTests.discardQueueBlanksOnlyOnAChangeOfHuman`).
- Four players on the minimum Mac window: chips, status and dice stay on one row (screenshot in Task 2).
- The longest status strings stay inside the status slot (`testControlsNeverMove` plus screenshots in Task 2).

---

### Task 1: Handover in the model

**Files:**
- Modify: `Sources/SaltmarshGame/ScreenState.swift`, `ScreenState+Derive.swift`, `UIState.swift`, `Strings.swift`, `GameViewModel.swift`, `GameViewModel+Interaction.swift`
- Test: `Tests/GameTests/HandoverTests.swift` (new), `Tests/GameTests/ScreenStateTests.swift`, `Tests/GherkinTests/Steps/NewRules.swift`, `Tests/GherkinTests/ParserTests.swift`, `saltmarsh-isles.feature`

**Interfaces:**
- Produces: `public struct Handover: Equatable, Sendable { var player: Int; var seat: Seat; var message: String; var button: String }`, `ScreenState.handover: Handover?`, `UIState.revealedTo: Int?`, `GameViewModel.revealHand()`, `GameViewModel.concealHand()`.
- Produces: `Strings.passDevice(_:)` "Pass the device to X", `startTurn(_:)` "Start turn, X", `handoverDiscard(_:)` "Discard, X", `seeOffer(_:)` "See the offer, X", `continueTurn(_:)` "Continue, X".

- [ ] **Step 1: Write failing tests.** `HandoverTests` covers: `endTurnBlanksForTheNextHuman` (message and "Start turn, Cobalt"), `revealClearsIt`, `oneHumanNeverSeesIt`, `aiBetweenHumansBlanksOnlyWhenTheHumanIsDue`, `noBlankWhileAnAIActs`, `discardQueueBlanksOnlyOnAChangeOfHuman` ("Discard, Cobalt"), `offerBlanksForTheResponderAndBackForTheProposer` ("See the offer, Cobalt", then "Continue, Crimson"), `setupHandsOverSilently`, `noBlankAtGameOver`, `reopeningBlanksForWhoeverMustAct`, `reopeningDuringSetupDoesNotBlank`, `backgroundBlanksAgain`, `backgroundDuringSetupDoesNotBlank`. Feature file: new rule "Handing the device to another human" with the same moments, and the discard status scenario loses "Pass the device to Cobalt."; `ScreenStateTests` line 53 and the `ParserTests` count follow.
- [ ] **Step 2: Run `swift test`.** Expected: fails to compile on `handover`.
- [ ] **Step 3: Implement.** In `derive`: the private owner is `panelOwner` when `!aiThinking` and that seat is human. `handover` is set when there are two or more humans, the phase is not `.rollingForFirst`, `.setup` or `.gameOver`, and `ui.revealedTo != owner`. Button by phase: `.discarding` discard, responder pending see-offer, `.awaitingRoll` start turn, otherwise continue. In `GameViewModel`, `install` and `afterMove` record `ui.revealedTo = acting` while the phase is first roll or setup and the acting seat is human. `revealHand()` sets `ui.revealedTo = screen.handover?.player`. `concealHand()` clears `ui.revealedTo` except during first roll and setup; `GameScreen` calls it when `scenePhase` becomes `.background`. Remove the sentence from `Strings.discarding`.
- [ ] **Step 4: Run `swift test`.** Expected: all pass.
- [ ] **Step 5: Commit** `feat(game): hand the device privately between different humans`.

### Task 2: Fixed layout, tabs and dice

**Files:**
- Create: `App/Views/GameHeader.swift` (chips, status slot, dice, menu), `App/Views/DieView.swift`, `App/Views/HandoverView.swift`
- Modify: `App/Views/GameScreen.swift`, `GamePanel.swift`, `TradeAndCards.swift`
- Modify: `Sources/SaltmarshGame/ScreenState.swift` and `ScreenState+Derive.swift` (`ScoreRow.points: Int`), `Strings.swift` (`offerToPlayers` "Offer a trade to players…", `back` "Back")
- Test: `AppUITests/GameFlowTests.swift`

**Interfaces:**
- Consumes: `ScreenState.handover`, `GameViewModel.revealHand()`.
- Produces: `GameHeader(vm:screen:compact:onNewGame:)`, `DieView(face: String)`, `HandoverView(handover:onReveal:)`, identifiers `tab Trade`, `tab Cards`, `tab Players`, `tab Log`, `menu`, `handover`.

- [ ] **Step 1: Update the UI tests.** `startNewGame` taps `handover` if present, then opens `menu` for "New game". Log, bank and offer box checks open their tab first. Add `testControlsNeverMove`: records frames of `status`, `hold timber`, `Roll dice` or `Roll for first`, `End turn`, `Road` and `tab Trade` at each new moment through setup, the first roll and a turn, and asserts they never change and stay hittable. Add `testHandoverHidesTheNextHand`: a game with Crimson and Cobalt human, played to Crimson's first End turn; `hold timber` must not exist until `handover` is tapped, and a relaunch opens on `handover`.
- [ ] **Step 2: Run the iPhone UI tests.** Expected: fail on the missing identifiers.
- [ ] **Step 3: Implement** per spec section 3. `GameScreen` shows only `HandoverView` when `screen.handover` is set. `compact` is width below 600. Tall layouts give the board about 36 percent of the height. `ResourceBox.amount` becomes `Int?` so a hidden hand keeps its boxes. Tabs are a plain row of buttons, with the selection held in `GamePanel` so a handover resets it to Trade. A moment, including a proposer's list of answers, replaces the tab content and disables the tabs. During an AI's turn, Trade and Cards are disabled and the area shows Log unless Players is picked. During first roll and setup, the order strip sits above the log and only Log and Players are enabled.
- [ ] **Step 4: Verify.** Run the iPhone UI tests, `make mac`, `swift test`. Screenshot Mac at 760 by 520 with four players and with the longest status strings.
- [ ] **Step 5: Commit** `feat(app): fixed header, tabbed panel, real dice and the handover screen`.

### Task 3: Records

**Files:** `docs/superpowers/specs/2026-11-02-saltmarsh-native-design.md`, `docs/superpowers/plans/2026-11-02-saltmarsh-native-plan.md`, memory.

- [ ] **Step 1:** Point section 7 of the main spec at the redesign; add the handover to section 10; mark R17 and R18 replaced and add new rulings to the master plan; update the Roadmap and memory.
- [ ] **Step 2: Commit** `docs: record the game screen redesign`.
- [ ] **Step 3:** Restart the Mac app on the new build for the owner, then run one fresh reviewer over the branch diff for this plan.
