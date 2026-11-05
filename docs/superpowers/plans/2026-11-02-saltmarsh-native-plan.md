# Saltmarsh Isles Native App Implementation Plan (master)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the Saltmarsh Isles web prototype as one SwiftUI app for iPhone, iPad and Mac, with every seat selectable as Human or AI at five effort levels, the four missing rules (player trading, bank supply, first-player roll, piece limits) added, and the Gherkin feature file executed by the test suite.

**Architecture:** A pure, `Codable`, seedable rules engine (`SaltmarshEngine`) that both humans and AI drive through `legalMoves` and `apply`; an AI layer (`SaltmarshAI`) that only ever sees a redacted `PlayerView` and searches over engine-sampled guesses of hidden cards; a game layer (`SaltmarshGame`) holding the `@Observable` view model, `ScreenState` render model, AI turn runner and save protocol; a thin SwiftUI app target with views and the file store.

**Tech Stack:** Swift 6, SwiftUI, `@Observable`, Swift Testing, Swift Package Manager, XcodeGen 2.46, XCUITest. iOS 17+, macOS 14+. No network.

**Spec:** `docs/superpowers/specs/2026-11-02-saltmarsh-native-design.md` (the design), read together with `saltmarsh-isles-spec.md` (rules and screens) and `saltmarsh-isles.feature` (scenarios).

## Global Constraints

- Swift 6 language mode; minimum iOS 17.0 and macOS 14.0; one multiplatform app target.
- No network calls, no API keys, no third-party dependencies.
- Seats are fixed: Crimson `#c0392b`, Cobalt `#2a5db0`, Amber `#d68910`, Ivory `#ece6d6`, in that order; player index equals seat index.
- Costs: road 1 timber 1 clay; settlement 1 timber 1 clay 1 wool 1 grain; city 2 grain 3 ore; dev card 1 wool 1 grain 1 ore. Points: settlement 1, city 2, longest road 2, largest army 2, victory point card 1. Win at 10 on your own turn.
- Piece limits 5 settlements, 4 cities, 15 roads. Bank 19 of each resource. Dev deck 14 Knight, 5 Victory point, 2 Road crew, 2 Bumper harvest, 2 Corner the market.
- Board: 19 tiles (4 timber, 3 clay, 4 wool, 4 grain, 3 ore, 1 desert at the centre), numbers 2,3,3,4,4,5,5,6,6,8,8,9,9,10,10,11,11,12, 54 corners, 72 edges, 30 coastal edges, 9 harbours at coastal offsets `[0,3,7,10,13,17,20,23,27]` alternating 2:1/3:1 starting with 2:1. Hex size 58, board space 680 × 600, sea radius 335.
- Log lines and screen strings are exact copies of the feature file's quoted text. Resource lists are written "3 timber, 1 clay" in the order timber, clay, wool, grain, ore.
- The AI receives only `PlayerView`; the live `GameState` never enters `SaltmarshAI`.
- Every randomness source is a `SeededRNG` stored in state; a game is reproducible from its seed and move list.
- Reduce Motion is respected; no animation is load-bearing.
- `saltmarsh.html`, `tests/*.py` and `media/` are never modified.
- Commit messages carry no `Co-Authored-By` trailer.

## Review Focus

Input classes the spec implies but a straight reading of the scenarios would not test. Each is pinned by a test in the task named.

1. The roller holds more than 7 cards when they roll a 7: they are in the discard queue too, in seat order with everyone else. (Plan 1, Task 10)
2. Road crew when exactly one legal edge exists, or when the player has one road piece left: the first free road is placed, then the phase returns to main with "No room for new roads." or "No roads left to build." (Plan 1, Task 14)
3. Bumper harvest asking for two of a resource when the bank holds one: that pair is not legal; one of it plus another resource still is. (Plan 1, Task 14)
4. Knight played before rolling, robber moved to a tile with only the player's own buildings: no victim step, phase returns to awaiting roll, and `roll` is legal. (Plan 1, Task 14)
5. A trade offer whose only possible responder has an empty hand: no trade phase starts, the offer is logged as unanswerable, and the turn continues. (Plan 1, Task 16)

---

## Open questions: REQUIRED to resolve in the next session

Raised 2026-11-05 at the end of the Plan 3 and playable screen session. Resolve every item before starting Plan 2. Record each answer here and remove the item once it is settled. Do not treat any of these as decided.

1. **Hand-off file never read.** `/var/folders/sb/1szn9lh95nd_vnbt29d8j7dh0000gn/T/hand-off.md` was blocked by `permissions.blockReadsOutsideWorkingDirectories`. Owner: run `/add-dir` on its folder or paste it. Then check it for anything the session missed. The file is in a temp folder and may be gone.
2. **Mac UI tests have never run.** The runner needs the owner's Touch ID or password. Owner: run `make test` at the machine. `testEscapeClosesTheWinScreen` and Mac board clicks stay unverified until then. This also runs the 3.5 minute soak test.
3. **Owner's Mac play-test result.** Owner: play a game on the Mac build and report what is wrong. Fix or schedule each report. First round of four UI reports fixed on 2026-11-05 (resource boxes, responder's hand, offer builder labels, scrolling log); the owner has not yet confirmed them on the rebuilt app, and the play-test is not finished.
4. **No independent review yet.** Plan 3 and the playable screen had self-reviews only. Decide: run a fresh whole-branch review now, or before merge. Subagents have hung here on permission prompts, so the owner should be present for it.
5. **Paths not driven through the UI.** Stealing, accepting a trade, the player's own offers, harbour and bank trades, development cards, and a real win screen (only the preview was opened). Decide: extend `AppUITests`, accept the owner's play-test as coverage, or leave them to Plan 5.
6. **Owner has not accepted the Rulings below.** Review them, above all R1 and R2. Change any that are wrong.
7. **Owner has not assigned the Carried forward items below.** Confirm or change the proposed plan for each.

## Roadmap

| Plan | Phases | Deliverable | Status |
|---|---|---|---|
| [Plan 1: scaffold and engine](2026-11-03-plan-1-engine.md) | 0, 1, 2 | Package, Xcode project, full rules engine with the four new rules, redaction and sampling, property tests | done (129 tests passing) |
| Plan 2: heuristic AI | 3 | Deckhand, Sailor, Mate; move resolver; dial-effect test. Must also close design section 6.5: `TurnRunner`'s stand-in fallback never builds, so an always-wrong opponent's game stalls at the move cap instead of finishing; put the heuristic ahead of it and assert the game ends in `illegalAIMovesAreResolved` | after the playable screen (reordered 2026-11-04 so the owner sees a game sooner; Plan 3 ships a seeded random stand-in opponent) |
| [Plan 3: game layer and Gherkin runner](2026-11-04-plan-3-game-layer.md) | 4, 5 | View model, `ScreenState`, turn runner, store, parser, steps, updated feature file | done (142 scenario cases pass under `swift test`; the 2 `@ui` scenarios wait for `AppUITests`) |
| Plan 4: rollout search and benchmark | 6 | Captain, Admiral, `ai-bench`, tuned budgets | after Plan 3 |
| Plan 5: SwiftUI app, spec update | 7, 8 | Polish on the playable screen, remaining UI tests, spec and README rewrite | after Plan 4 |

Each later plan is written when its predecessor's code exists, so its signatures are copied from real code rather than guessed. Each plan starts with the header above and inherits this file's Global Constraints and Review Focus.

## Execution

- Method: subagent-driven development (one fresh implementer per task, one fresh reviewer per task, a whole-branch review at the end of each plan).
- Test-first: every rule gets a failing test before the code.
- One commit per task; plain conventional messages.
- Verification commands per phase are in the approved plan at `/Users/psenger/.claude/plans/wild-leaping-grove.md` Part 2 and repeated in each plan.
- Change of method on 2026-11-04: Plan 1 Tasks 7 to 18 were executed inline (superpowers:executing-plans) with a self-review at the end, after three implementer subagents in a row hung on unanswered permission prompts and blocked the session. Later plans run inline unless the owner is present to answer subagent prompts.
- Inserted after Plan 1 at the owner's request to see something on screen early: `App/Views/BoardView.swift` (Canvas drawing of a board in the prototype's style) and `App/Views/BoardPreviewScreen.swift` (generated board plus a "New board" button), built for macOS and the iPhone 15 Pro simulator. Plan 5 extends `BoardView` with pieces, glow and dash intent rather than replacing it.
- Inserted after Plan 3 at the owner's request: [the minimal playable game screen](2026-11-04-minimal-game-screen.md). It replaces `BoardPreviewScreen`, draws pieces and board intent in `BoardView`, and makes every engine move reachable, with autosave and resume. Plan 5 keeps these views and adds what is left: confetti, animation, effort descriptions, iPad tuning, spec and README rewrite. `FileGameStore` lives in `SaltmarshGame` so it runs under `swift test`. Mac XCUITest needs the owner's authentication, so it does not run unattended.
- Inserted after that at the owner's request: [the game screen redesign](2026-11-05-game-screen-redesign.md). It replaces the panel layout from the minimal screen with a full-width header, a fixed panel with tabs and real dice, and adds a handover screen between different humans. Plan 5's polish builds on this layout.

## Rulings (awaiting owner review)

Decisions made on the owner's behalf during execution. The plan ledgers were deleted when each plan finished, so this list is the record.

Plan 3:

- **R1. Design section 6.5 is not met yet.** `TurnRunner`'s stand-in fallback (end turn, withdraw, roll) never builds, so an always-wrong opponent's game stops at `aiMoveCap` with no winner. This comes from reading the code, not from a test; `illegalAIMovesAreResolved` only asserts `turn > 0`. It stands until Plan 2 because `RandomOpponent` only returns legal moves. Cost if wrong: an all-AI game with such an opponent stalls.
- **R2. Label coverage test dropped (Task 14).** Plan 3 called for `LabelCoverageTests`. Every quoted feature string is already asserted by a passing scenario, and a substring scan cannot handle interpolated names and numbers without a brittle allow-list. Cost if wrong: string drift is caught by a scenario, not a dedicated test.
- **R3. Step bodies are `async throws` from the start (Task 8).** Task 13 needs `await`. Cost if wrong: none.
- **R4. AI fallback prefers end turn, withdraw or roll before `legal[0]` (Task 4).** With `legal[0]` alone, two stubborn bots re-propose the same trade forever. Cost if wrong: none, Plan 2's heuristic goes ahead of it.
- **R5. Reduce Motion stays an executable scenario (Task 9).** Only "Escape closes the win screen" and "The win screen is hidden at load" are `@ui`, which gives more coverage under `swift test`. Cost if wrong: none.
- **R6. Trading Background gives Crimson 3 timber (Task 9).** A 3-timber counter is then payable; the invalid-offer example uses 4 timber. Cost if wrong: not recorded.
- **R7. `FeatureTests` ran only covered rules until Task 13 (Task 10).** This kept the suite green between tasks; the filter is now removed. Cost if wrong: none.
- **R8. Robber log line (Task 11).** The engine logs "Nobody on that tile has cards to steal." only when the robber's new tile holds an opponent building, because the feature file expects "Crimson moved the robber." as the last line on an empty tile. Cost if wrong: one log line.
- **R9. Seat-name captures use `([A-Z]\w+)` (Task 13).** Otherwise a capture could swallow "nobody". Cost if wrong: not recorded.

Playable screen:

- **R10. `FileGameStore` lives in `SaltmarshGame`, not `App` as design section 4 draws it.** It then runs under `swift test`. Cost if wrong: one file move.
- **R11. The plan was not held for owner review.** The owner said to write and execute without stopping. Cost if wrong: rework of the screen.
- **R12. Mac is verified by build, launch and screenshot; XCUITest runs on the iPhone simulator only.** The Mac runner fails with "Authentication cancelled" when unattended. Cost if wrong: a Mac-only UI bug survives until the owner runs `make test`.
- **R13. Header, dice and status are pinned above the scrolling panel, with the moment's buttons first.** Screenshots showed a trade offer scrolled off screen; `isHittable` assertions now cover it. Cost if wrong: panel order changes.

Owner's UI feedback, 2026-11-05 (the owner's instruction is recorded in design section 5.2; these are how it was read):

- **R14. Resource boxes use the board's terrain colours.** The owner's item 3 said "color position" of item 1, which named no colour. Cost if wrong: one fill colour.
- **R15. The bank uses the same boxes as the hold, and the discard rows do not.** The bank shares the component; discards were not mentioned. Cost if wrong: one view.
- **R16. The offer builder became two rows of five boxes (Give, Want), with minus and plus under each box.** Each box has one amount, so the rule applies exactly. It replaces the steppers. Cost if wrong: one view.
- **R17. (Replaced by the 2026-11-05 redesign.) The hand is pinned above the scrolling panel.** The owner asked for it to be visible on the player's turn. Cost if wrong: less scrolling room on iPhone.
- **R18. (Replaced by the 2026-11-05 redesign: the log is a tab.) The whole log is kept, newest first, in a 140 point box inside the scrolling panel.** Pinning it too would leave too little room on iPhone. Cost if wrong: one view.

- **R19. Answered by the owner, 2026-11-05: Give lists only what the row can trade, and an untouched row starts on a legal trade.** A pick stays while its Give can still be traded; otherwise the row moves to a legal pair and keeps the picked Get if it can.
- **R20. The Get dropdown still lists every resource, so picking the same resource on both sides, or one the bank has run out of, disables Trade.** Not asked for, and the scenario "Crimson chooses the same resource to give and get" pins it. Cost if wrong: filter a second dropdown and retire that scenario row.

The rest of these came from the 2026-11-05 game screen redesign. The owner approved the mockups and the handover moments; these calls were made during the build and reported to the owner, who has not answered them yet.

- **R21. The status slot holds up to two lines and keeps one fixed height.** The owner was shown one line, but the longest messages cannot fit one legible line beside the chips on Mac. Cost if wrong: shorten the messages.
- **R22. New game and Preview win live in a menu in the header.** Not in the mockups. Cost if wrong: one view and the UI test helper.
- **R23. A who line above the hand shows `screen.header` and the hold label.** The mockups show only the hold label; without this, "Cobalt · discarding" and its colour would be nowhere on screen. Cost if wrong: one view.
- **R24. With two humans during an AI's turn, the five resource boxes stay in place with no numbers.** Keeps the layout fixed while showing no hand. Cost if wrong: one view.
- **R25. The handover button says "Start turn", "Discard", "See the offer" or "Continue", then the name, and the discard status no longer says "Pass the device to X".** The owner agreed the moments, not the words. Cost if wrong: `Strings` and the scenarios.
- **R26. Trade and Cards grey out during an AI's turn and during setup.** The mockup left them looking available, but they would show the AI's harbours and the offer limits would reveal its hand. Cost if wrong: splitting "whose private data" from `current` in `derive`.
- **R27. With two or more humans, leaving the app shows the handover screen on return.** Closes the case of a locked phone being passed on, at the cost of one tap when the same player returns. Cost if wrong: one line in `GameScreen`.
- **R28. A proposer's list of answers takes over the tab area.** Otherwise "Answers are in" could show with Trade and Withdraw behind another tab. Cost if wrong: one view and a tab rule.
- **R29. "Discard N cards" and "Offer" sit above their rows, not below.** On iPhone the tab area scrolls and the buttons fell out of view. Cost if wrong: one view.
- **R30. The "Saltmarsh Isles" footer text is gone from the game screen.** The redesign has no place for it; the title remains on the Mac window and the new game sheet. Cost if wrong: one line.
- **R31. Costs are small squares in the resource's board colour with the number inside, and stay in full colour on a greyed button.** The owner asked for costs on Road, Settlement, City and the card, and for buttons that are not plain. The values come from the engine's `Cost`. Solid sea blue, dark for Roll and End turn, amber for the active build mode, and icons were my choice. Cost if wrong: `GameButtonStyle` and `CostChips`.
- **R32. On Mac the handover returns only when the app is hidden or minimised; on iPhone as soon as the app stops being active.** Blanking on every click into another Mac window would get in the way. Not yet tried on a real iPhone. Cost if wrong: one line in `GameScreen`.
- **R33. "+N" hidden points show only to the human holding the device, on their own row, and Preview win is off when someone other than the current human holds it.** Both leaked in the first build. The final review found them.

Deferred from the final review of the redesign, not fixed:

- iPhone landscape leaves a tab area of about 75 points, so Accept and Withdraw can start partly out of view. They scroll into view.
- A kept pick whose Get side has become illegal greys Trade with no reason given. Related to R20.
- An offer nobody can answer clears the builder, and "Nobody can answer that offer." appears only in the Log tab.

## Carried forward (proposed plan, awaiting owner confirmation)

| Item | Proposed plan |
|---|---|
| Close design section 6.5 and strengthen `illegalAIMovesAreResolved` to assert the game ends | Plan 2 (already in its Roadmap row) |
| `ScreenState.orderStrip` has no "next to place" highlight (design section 5.1); the panel approximates it by marking the current seat | Plan 5 |
| An unsent offer carries over to the next player's turn, because `UIState` is only cleared by a sent offer or a new game | Plan 5 |
| `HarbourRow.defaultChoice` reads the current player's hand, so an AI's 3:1 row hints at what it holds in the game layer; the panel hides it during AI turns | Plan 2 |
| At game over, the panel can show an AI winner's development cards (the hand is fixed) | Plan 5 |
| With no game, the board behind the new game sheet shows every tile as DUNES, and stays that way after Cancel | Plan 5 |
| A second Mac window has its own view model and both write the same save | Plan 5 |
| The soak test adds about 3.5 minutes to every `AppUITests` run | Plan 5 |
| Effort descriptions on the new game sheet, confetti, animation, iPad tuning | Plan 5 |

## Corrections to carry into the feature file (Plan 3)

Found while writing engine tests; the engine follows the spec and these scenarios are fixed when the feature file is updated.

- Rule "Winning", Scenario Outline "Reaching 10 points on your own turn wins immediately": the row `| 8 | builds a city |` must read `| 9 | builds a city |`. A city replaces a settlement's 1 point with 2, so it adds one point.
