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

## Roadmap

| Plan | Phases | Deliverable | Status |
|---|---|---|---|
| [Plan 1: scaffold and engine](2026-11-03-plan-1-engine.md) | 0, 1, 2 | Package, Xcode project, full rules engine with the four new rules, redaction and sampling, property tests | done (129 tests passing) |
| Plan 2: heuristic AI | 3 | Deckhand, Sailor, Mate; move resolver; dial-effect test | after Plan 1 |
| Plan 3: game layer and Gherkin runner | 4, 5 | View model, `ScreenState`, turn runner, store, parser, steps, updated feature file | after Plan 2 |
| Plan 4: rollout search and benchmark | 6 | Captain, Admiral, `ai-bench`, tuned budgets | after Plan 3 |
| Plan 5: SwiftUI app, spec update | 7, 8 | Views, file store, UI tests, spec and README rewrite | after Plan 4 |

Each later plan is written when its predecessor's code exists, so its signatures are copied from real code rather than guessed. Each plan starts with the header above and inherits this file's Global Constraints and Review Focus.

## Execution

- Method: subagent-driven development (one fresh implementer per task, one fresh reviewer per task, a whole-branch review at the end of each plan).
- Test-first: every rule gets a failing test before the code.
- One commit per task; plain conventional messages.
- Verification commands per phase are in the approved plan at `/Users/psenger/.claude/plans/wild-leaping-grove.md` Part 2 and repeated in each plan.

## Corrections to carry into the feature file (Plan 3)

Found while writing engine tests; the engine follows the spec and these scenarios are fixed when the feature file is updated.

- Rule "Winning", Scenario Outline "Reaching 10 points on your own turn wins immediately": the row `| 8 | builds a city |` must read `| 9 | builds a city |`. A city replaces a settlement's 1 point with 2, so it adds one point.
