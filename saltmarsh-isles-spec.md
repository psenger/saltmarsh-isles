# Saltmarsh Isles: Build Spec for a Native Apple App

This document describes the web prototype `prototype/saltmarsh.html` in enough detail to rebuild it in Swift and SwiftUI, then add AI opponents. Read it alongside the HTML file; every rule and number here matches that file.

Every player interaction is also written as executable behaviour in **`saltmarsh-isles.feature`** (Gherkin, 23 rules, 146 scenarios). This spec explains *how* the game works; the feature file states *what the screen must do* in testable Given/When/Then form. When the two disagree, fix whichever is wrong and update both. Section 7 explains how to run the feature file.

> **Naming and art.** Game mechanics are free to reuse, but the name and artwork of the commercial game this is modelled on are trademarked. Keep the original name ("Saltmarsh Isles" or your own), original card names and original art if you ship to the App Store.

---

## 1. Game rules as implemented

### Pieces, costs and points

| Item | Cost | Points |
|---|---|---|
| Road | 1 timber, 1 clay | 0 |
| Settlement | 1 timber, 1 clay, 1 wool, 1 grain | 1 |
| City (upgrades your own settlement) | 2 grain, 3 ore | 2 (replaces the settlement's 1) |
| Development card | 1 wool, 1 grain, 1 ore | see section 1.5 |
| Longest road award | earned | 2 |
| Largest army award | earned | 2 |

- **Players:** 2 to 4, pass-and-play on one device.
- **Win:** the first player to reach 10 points on their own turn wins. The total includes hidden victory point cards. The check runs after every build, card purchase, card play and award change, and at the **start of every turn**. The start-of-turn check catches passive wins, for example when longest road passes to a player because someone else cut the holder's road. The game then ends at once: all actions lock, and the win screen plays (see "Victory screen" in section 5). The log and the win banner both show the full total, including hidden victory point cards, and the board stays visible so players can study the final position.

### 1.1 Placement rules

- **Distance rule:** no settlement on a corner directly next to any settlement or city, whoever owns it.
- **Settlement connection:** outside setup, a settlement must touch at least one of your own roads.
- **Road connection:** a road must touch your own road, settlement or city. A road cannot continue through a corner holding an opponent's building. Opponents' roads never block you.
- **Shared crossroads:** when roads of different colours meet at an empty corner, any of those players may settle there, provided the distance rule passes. The first to build takes it. If every road reaching the crossroad is only one segment from its owner's settlement, the distance rule blocks it for everyone.

### 1.2 Setup phase

Placement follows **snake order**: round 1 runs forward, round 2 runs backward.

| Players | Order |
|---|---|
| 2 | P1, P2, P2, P1 |
| 3 | P1, P2, P3, P3, P2, P1 |
| 4 | P1, P2, P3, P4, P4, P3, P2, P1 |

Each step is "place a settlement, then a road touching that settlement". Setup settlements ignore the connection rule but obey the distance rule. Each player's **second** settlement pays 1 card from every adjacent non-desert tile. Player 1 takes the first proper turn.

The snake makes the picks fair. In a 3-player game every player's two pick positions add up to 7 (1+6, 2+5, 3+4). In a forward-only order they would add up to 5, 7 and 9. The last player's back-to-back picks let them plan a pair of settlements, which makes up for picking last.

The prototype always starts with player 1. The official rules have everyone roll and the highest roller goes first. The native app should add that roll, plus an on-screen order strip and a "Round 2: back the other way!" label so the double turn doesn't look like a bug.

### 1.3 Turn flow

```
(optional) PLAY KNIGHT ─▶ move robber ▶ steal
        │
        ▼
      ROLL ─▶ (7?) ─yes─▶ discard ▶ move robber ▶ steal (pick victim if >1)
        │                                              │
        no ─▶ produce ◀────────────────────────────────┘
                 │
                 ▼
     BUILD / TRADE / BUY & PLAY DEV CARDS (any order, repeatable)
                 │
                 ▼
             END TURN ─▶ next player
```

Building, trading, buying cards and ending the turn are all locked until the dice are rolled and any robber action is finished. While Road crew is being resolved, only the free roads can be placed.

### 1.4 Production and the robber

- Each tile whose number matches the roll pays 1 card per adjacent settlement and 2 per adjacent city.
- The tile under the robber pays nothing. The robber starts on the desert.
- **A roll of 7:**
  1. Nobody produces.
  2. Every player holding more than 7 cards discards half, rounded down, and **chooses which cards**. Players discard one at a time, in seat order, passing the device. The discard box is outlined in the discarding player's colour and shows:
     - "Oh NO! <Name>, the robber needs N cards from your deck", with the robber icon in front of it, and a running "picked / N" counter;
     - one row per resource they hold, with − and + buttons and "x of y";
     - a "Discard N cards" button, enabled only when exactly N are picked;
     - "Next: <names>" when others are still waiting.

     While discards are pending, everything else is locked. **The panel belongs to the discarding player, not the roller:**
     - the header shows their colour and "<Name> · discarding";
     - the hold is labelled "<Name>'s hold" and shows their cards;
     - the status line reads "<Roller> rolled a 7! <Name> has more than 7 cards and must give up half. Pass the device to <Name>."

     When the last discard is confirmed, the panel returns to the roller for the robber move.
  3. The roller taps any other tile to move the robber there.
  4. **Steal:** if anyone with a building on that tile has cards, the roller must choose a victim, even when only one qualifies, so the steal is always a visible step. The roller can either:
     - tap one of the victim's buildings on that tile, which glow and pulse; or
     - tap a "Steal from <Name> (N cards)" button in the panel.

     1 random card moves from the victim to the roller, and the log names the victim. If nobody there has cards, the log says so and play continues.
- A Knight card triggers steps 3 and 4 without the discard.

### 1.5 Development cards

The deck holds 25 cards and is shuffled at the start of the game.

| Card (prototype name) | Count | Effect |
|---|---|---|
| Knight | 14 | Move the robber and steal 1 card. Adds 1 to your knight count |
| Victory point | 5 | Worth 1 point. Never played; stays hidden in your hand |
| Road crew | 2 | Build 2 roads for free, following normal road rules. Ends early if no legal edge remains |
| Bumper harvest | 2 | Take any 2 resource cards from the bank (the same type twice is allowed) |
| Corner the market | 2 | Name a resource. Every other player gives you all of that resource |

**Timing rules:**

- Buy as many cards as you can afford, after rolling.
- Play at most **one** card per turn. Victory point cards don't count; they're never played.
- You can't play a card on the turn you bought it.
- A Knight can be played before or after rolling. Every other card needs the roll first.
- When the deck is empty, buying is disabled.

**Visibility:** each player's card count is public. Card types are private. In pass-and-play only the current player's cards are shown, and hidden victory points appear as "+N" next to their own score.

### 1.6 Longest road

- **Road length** is the longest trail of your road segments that never reuses a segment. A trail may branch, but only one path through a branch counts. For example, three roads meeting at a corner in a Y shape count as 2, not 3.
- A trail **stops at** a corner holding an opponent's building. The segment leading into that corner still counts, but the trail cannot continue past it.
- **Claiming it:** you need 5 or more segments. The first player to reach that takes the award (+2 points).
- **Taking it from someone:** another player must be strictly longer. A tie leaves it with the current holder.
- **Losing it:** if an opponent's settlement cuts the holder's road so it's no longer the longest:
  - the single longest player takes it;
  - if two or more players tie for longest, nobody holds it;
  - if nobody has 5 or more segments, nobody holds it.

Recompute all players' lengths after every road and every settlement, since a settlement can cut a road.

### 1.7 Largest army

- **Claiming it:** the first player to play 3 Knights takes the award (+2 points).
- **Taking it:** another player must play strictly more Knights than the holder. A tie leaves it with the holder.
- **Losing it:** never, because played Knights can't be lost.

### 1.8 Trading

The UI shows trading in two separate parts.

**Trade with bank (always 4:1).** Give 4 of one resource, get 1 of any other.

**Your harbours.** This lists every harbour the current player has captured. You capture a harbour by having a settlement or city on either of its two corners. Each row shows:

| Field | Example |
|---|---|
| Harbour type | "2:1 grain" or "3:1 any" |
| What holds it | "held by your settlement", or "held by your settlement and city" when you're on both corners |
| Give | fixed to the harbour's resource for 2:1; any resource for 3:1 |
| Get | any other resource |
| Trade button | enabled only when you have enough of the give resource |

- A player with several harbours sees one row per harbour.
- Two players can share one harbour by each holding one of its corners. It appears in both players' lists.
- On the board, a captured harbour gets a ring in each owner's colour, so a shared harbour shows two rings.
- With no harbours captured, the section shows: "None yet. Build a settlement on a corner joined to a harbour by a jetty."

Trading is only allowed on your own turn, after rolling, and can be repeated.

### 1.9 Saving and loading games

The game saves itself after every move and reopens where it left off. That automatic save is separate from the player's saves.

- **Named saves:** up to 5, each with a name of up to 30 characters and the date it was saved. They stay on the device they were made on.
- **When all 5 are used:** the player picks one to replace, or deletes one. Nothing is deleted automatically.
- **Deleting:** a trash can on each save in the Save Game window, after a confirmation. It isn't in any menu.
- **Saving** is not offered once a game has ended, and doesn't change the game in progress.
- **Loading** asks for confirmation, because it replaces the game in progress.
- **Where:** the File menu on Mac, with Command-N, Command-O and Command-S. The Game button on iPhone and iPad.

### 1.10 Left out of the prototype

These are the main gaps against the full game, in rough priority order:

1. **Player-to-player trading.** The current player offers any mix of cards; others accept, decline or counter. Players can only trade with the current player.
2. **Bank supply limits.** 19 cards of each resource:
   - you can't receive cards the bank doesn't hold;
   - if a roll would pay out more of a resource than the bank holds, nobody gets it, unless only one player is owed it, in which case they take what's left.
3. **Roll for first player** and the setup order strip (section 1.2).
4. **Piece limits:** 5 settlements, 4 cities and 15 roads per player.

---

## 2. Board geometry

### Tiles

The board has 19 hexes in axial coordinates `(q, r)`, with radius 2:

```
for q in -2...2
  for r in max(-2, -q-2) ... min(2, -q+2)
```

The layout is pointy-top, with hex size `S = 58` measured from centre to corner:

```
centreX = S * √3 * (q + r/2)
centreY = S * 1.5 * r
corner i (0...5) at angle (60·i − 30)°
```

- The desert is always at `(0, 0)`, and the robber starts there.
- The board's coordinate space is 680 × 600, centred on 0,0. The sea is a hexagon of radius 335.

### Corners (vertices) and edges

Adjacent hexes share corners, so build each tile's 6 corners, round the coordinates, and use `"x,y"` as a dictionary key to merge duplicates. That gives **54 corners**.

Each tile's edge `i` joins corners `i` and `i+1`. Key edges by `"min-max"` of their two corner indices to merge duplicates, giving **72 edges**.

While building, record:

| Field | Holds |
|---|---|
| `corner.tiles` | tiles touching this corner (1 to 3) |
| `corner.adjacent` | neighbouring corners, for the distance rule |
| `edge.tiles` | tiles touching this edge. An edge with 1 tile is on the coast; there are 30 coastal edges |

Two tiles are neighbours when they share exactly 2 corners.

### Robber placement

The robber piece is drawn relative to an anchor point, and its area centroid sits 0.68 units below that anchor.

On **every** tile, put the centroid on the hex centre, at `anchor.y = centre.y − 0.68`. Measured in the browser, the drawn piece's box centre lands within 0.3 units of the hex centre.

- **Desert:** move the "DUNES" label 32 units down so the piece doesn't cover it.
- **Numbered tile:** shrink the number disc to 72% and move it 31 units below the centre, at 85% opacity. The number being blocked stays readable, and the dimming signals that the tile isn't producing.

---

## 3. Board balancing

A plain shuffle can cluster high numbers. Board generation reshuffles until every rule below passes.

**Resources.** There are 4 timber, 3 clay, 4 wool, 4 grain and 3 ore, spread over the 18 non-desert tiles.

1. No two tiles of the same resource are neighbours.

**Numbers.** The 18 number discs are 2, 3, 3, 4, 4, 5, 5, 6, 6, 8, 8, 9, 9, 10, 10, 11, 11, 12.

2. A 6 or 8 never neighbours another 6 or 8.
3. No number neighbours the same number.
4. No corner touches more than 11 **pips**. Pips are the number of ways to roll a number with 2 dice, `pips(n) = 6 − |7 − n|`. A 6 or 8 has 5 pips, and a 2 or 12 has 1. The whole island has 58 pips.
5. Each resource's total pips is within 3 of its fair share, which is `tileCount × 58 / 18`.

Resource shuffles retry up to 20,000 times, and number shuffles up to 50,000 times. In testing, all 200 generated boards passed, at about 20 ms per board in a browser. Swift will be faster.

### Harbours

There are 9 harbours on the 30 coastal edges.

1. Sort the coastal edges by angle around the island centre.
2. Pick a random starting edge.
3. Take the edges at offsets `[0, 3, 7, 10, 13, 17, 20, 23, 27]` from that start. This spaces 9 harbours round 30 edges as evenly as possible.

The harbour types alternate, so no two 3:1 harbours are ever neighbours:

```
slot:  0    1    2    3    4    5    6    7    8
type:  2:1  3:1  2:1  3:1  2:1  3:1  2:1  3:1  2:1
```

- The five 2:1 slots get the five resources in shuffled order.
- Slots 8 and 0 are neighbours round the ring. Both are 2:1 harbours, but always for different resources.
- A harbour belongs to the two corners of its edge.
- Draw it 30 units outward from the edge midpoint, along the line from the tile centre through that midpoint, with a jetty line to each of its two corners.

---

## 4. State model (Swift)

```swift
enum Resource: String, CaseIterable, Codable { case timber, clay, wool, grain, ore }
enum Terrain: Codable { case land(Resource), desert }
enum DevCardType: String, Codable { case knight, victoryPoint, roadCrew, bumperHarvest, cornerMarket }

struct Tile: Codable {
    var center: CGPoint
    var terrain: Terrain
    var number: Int?          // nil for desert
    var corners: [Int]        // 6 corner indices
}

struct Corner: Codable {
    var point: CGPoint
    var tiles: [Int]
    var adjacent: [Int]
    var owner: Int?           // player index
    var isCity = false
}

struct Edge: Codable {
    var a: Int, b: Int
    var tiles: [Int]          // count == 1 means coastal
    var owner: Int?
}

struct Harbour: Codable {
    enum Kind: Codable { case any, specific(Resource) }
    var kind: Kind
    var ratio: Int            // 3 or 2
    var a: Int, b: Int        // corner indices
    var position: CGPoint
}

struct DevCard: Codable {
    var type: DevCardType
    var boughtOnTurn: Int     // can't be played while == state.turn
}

struct Player: Codable {
    var name: String
    var color: String         // hex string
    var hand: [Resource: Int]
    var devCards: [DevCard]
    var knightsPlayed = 0
    var isAI = false
}

enum Phase: Codable {
    case setup(step: Int, placingRoad: Bool, lastSettlement: Int?)
    case awaitingRoll
    case movingRobber
    case choosingVictim([Int])
    case placingFreeRoads(remaining: Int)
    case main                 // build, trade, buy/play cards, end turn
    case gameOver(winner: Int)
}

struct GameState: Codable {
    var tiles: [Tile], corners: [Corner], edges: [Edge], harbours: [Harbour]
    var players: [Player]
    var current: Int
    var turn: Int             // increments on every end turn
    var robberTile: Int
    var dice: [Int]?          // two values
    var devDeck: [DevCardType]
    var devCardPlayedThisTurn: Bool
    var longestRoadHolder: Int?
    var largestArmyHolder: Int?
    var phase: Phase
    var log: [String]
}
```

Making everything `Codable` gives you save and resume for free. It's also the format you'll send to an AI.

### Engine API

Keep all rules in a pure engine with no UI code. Both the human UI and the AI call the same functions, so the AI can never cheat.

```swift
enum Move: Codable, Equatable {
    case placeSettlement(corner: Int)
    case placeRoad(edge: Int)
    case upgradeCity(corner: Int)
    case roll
    case moveRobber(tile: Int)
    case steal(from: Int)
    case bankTrade(give: Resource, get: Resource)                 // always 4:1
    case harbourTrade(harbour: Int, give: Resource, get: Resource) // 3:1 or 2:1
    case buyDevCard
    case playKnight
    case playRoadCrew
    case playBumperHarvest(Resource, Resource)
    case playCornerMarket(Resource)
    case endTurn
}

struct Engine {
    static func newGame(players: Int, seed: UInt64) -> GameState
    static func legalMoves(_ s: GameState) -> [Move]
    static func apply(_ m: Move, to s: inout GameState) throws   // throws on illegal move

    // Scoring
    static func publicPoints(_ s: GameState, player: Int) -> Int  // buildings + awards
    static func totalPoints(_ s: GameState, player: Int) -> Int   // public + hidden VP cards
    static func roadLength(_ s: GameState, player: Int) -> Int
    static func updateAwards(_ s: inout GameState)                // after roads, settlements, knights

    // Trading helpers for the UI
    static func capturedHarbours(_ s: GameState, player: Int) -> [(index: Int, heldBy: [Corner])]
}
```

`legalMoves` is the key function. The UI uses it to decide which corners glow, which edges show as dashed, and which buttons are enabled. The AI chooses its moves from the same list.

### Longest road algorithm

```
best = 0
func dfs(corner, usedEdges, length):
    best = max(best, length)
    if length > 0 and corner has an opponent's building: return
    for edge in edges at corner where edge.owner == player and edge not in usedEdges:
        dfs(other end of edge, usedEdges + edge, length + 1)

for edge in player's roads:
    dfs(edge.a, [], 0)
    dfs(edge.b, [], 0)
```

This is exhaustive, which is fine for up to 15 roads.

---

## 5. SwiftUI app structure

```
SaltmarshIsles/
├── Engine/
│   ├── Models.swift          // structs above
│   ├── BoardGenerator.swift  // geometry, balancing, harbours
│   ├── Engine.swift          // legalMoves, apply, scoring
│   ├── Awards.swift          // road length, longest road, largest army
│   ├── DevCards.swift        // deck, buy, play, timing rules
│   └── RNG.swift             // seedable generator for tests and replays
├── AI/
│   ├── Opponent.swift        // protocol
│   ├── HeuristicOpponent.swift
│   └── LLMOpponent.swift
├── UI/
│   ├── GameViewModel.swift   // @Observable, owns GameState
│   ├── BoardView.swift       // Canvas drawing + tap hit-testing
│   ├── ControlPanel.swift    // dice, hand, build, scores, log
│   ├── TradePanel.swift      // bank box + harbour rows
│   ├── DevCardPanel.swift    // buy button + held cards with Play
│   ├── SetupOrderStrip.swift // snake order indicator
│   └── NewGameSheet.swift
└── Tests/
    └── EngineTests.swift
```

### Platform and UI notes

- **Targets:** iOS 17+ and macOS 14+, for the `@Observable` macro. One multiplatform SwiftUI target covers iPhone, iPad and Mac.
- **Board drawing:** use `Canvas` and `Path`. Scale the 680 × 600 board space to fit the view with a single transform.
- **Tap handling:**
  1. Convert the tap point back to board coordinates.
  2. Pick the nearest legal corner within 14 units, or the nearest legal edge within 9 units (measuring distance to the line segment).
  3. Failing both, pick the tile whose hexagon contains the point. This is used when moving the robber.
- **Layout:** the board sits beside the panel on iPad and Mac, and above a scrolling panel on iPhone.
- **Animation:** use `withAnimation` for dice changes and new pieces, and respect Reduce Motion.

### Panel contents, top to bottom

1. Current player and a status line telling them what to tap next.
2. Steal-victim buttons, shown only when several players qualify.
3. The win banner.
4. Dice and the Roll button.
5. The player's hand: 5 resource cards with counts.
6. Build buttons for road, settlement and city, with their costs, plus End turn.
7. Development cards: a Buy button showing how many cards are left in the deck, then one row per held card with its name, effect, any choices it needs and a Play button. The row notes "bought this turn", "one card per turn" or "counts automatically" when relevant.
8. Trade with bank, 4 for 1.
9. Your harbours.
10. Points: each player with their card count, dev card count, a "Road N" badge and a "Knights N" badge. A badge is highlighted when that player holds the award. Score is shown as "N / 10", with "+N" hidden victory points shown for the current player only.
11. Log.
12. Player count, New Game, Load Game, Save Game and, in debug builds, Preview win and Preview lose. The previews play the win or defeat screen without ending the game; they're for testing.

### Victory screen

A full-screen overlay over a blurred view of the board:

- **Card:** bordered and glowing in the winner's colour. It contains:
  - a crown badge in the winner's colour;
  - "Victory" (or "Preview" when previewing) and "<Name> wins";
  - a points breakdown: settlements, cities (2 each), longest road, largest army and victory point cards, listing only sources worth more than 0, then the total;
  - buttons: "See the board", which closes the overlay, and New game. Escape also closes it.
- **Card animation:** zooms in from 15% scale, tilted 8° and blurred, overshoots slightly and settles over 1 second. The crown spins in, two rings pulse outward from it in a loop, the name rises into place, then the breakdown rows slide in one after another.
- **Confetti:**
  - a burst of 170 pieces from the middle of the screen;
  - two cannons of 90 pieces each firing from the bottom corners;
  - a second wave of two smaller bursts 0.55 seconds later.

  Pieces use the winner's colour, gold, white and the five resource colours, mixing tumbling rectangles, thin streamers and dots. They fall under gravity with drag and a sideways flutter, and stop after 6 seconds or once all have fallen off screen. Draw them on a full-screen layer that ignores touches.
- **Board:** the winner's settlements and cities glow gold and pulse, during the overlay and after it's closed.
- **Reduce Motion:** skip the confetti and all animations. The card still appears.
- **Losing:** when an AI beats every human, the card reads "Defeat" and "Better luck next time, captain." with no confetti. An all-AI game still celebrates.

In SwiftUI:

- **Confetti:** a `TimelineView(.animation)` with a `Canvas` that steps a particle array each frame. Alternatively, a `CAEmitterLayer` wrapped in a representable view.
- **Card zoom:** a `.transition(.scale(scale: 0.15).combined(with: .opacity))` with a spring animation, plus a short `.blur` that clears as it lands.
- **Reduce Motion:** check `@Environment(\.accessibilityReduceMotion)`.

> **Web prototype note:** an overlay that uses `display: grid` overrides the HTML `hidden` attribute unless the page also has `[hidden]{display:none!important}`. Without that rule, a downloaded copy of the file showed an empty "Victory" card on load. This doesn't apply to SwiftUI, but shows why the overlay must be driven by state, never by a default-visible view.

### Colours used in the prototype

| Token | Hex | Use |
|---|---|---|
| timber | `#3f6b3a` | forest tiles |
| clay | `#b5643c` | clay tiles |
| wool | `#9cc46a` | pasture tiles |
| grain | `#e0b84a` | field tiles |
| ore | `#7d8794` | mountain tiles |
| desert | `#d9c79e` | centre tile |
| sea | `#4f7f8f` | water |
| players | `#c0392b`, `#2a5db0`, `#d68910`, `#ece6d6` | Crimson, Cobalt, Amber, Ivory |

- **Number discs** show the number with pip dots underneath. 6 and 8 are drawn in red.
- **Harbour discs** show the ratio. A 2:1 disc is filled with its resource colour and labelled with the resource; a 3:1 disc is plain.

---

## 6. Wiring in AI

### 6.1 Start with a heuristic opponent

Build this first. It plays instantly, works offline, and is the fallback whenever a model call fails.

- **Settlement spot score:** the sum of pips of the adjacent tiles, plus a bonus for resources the player lacks, plus a bonus for a harbour matching a resource the player produces a lot of.
- **Each turn:**
  1. Play a Knight before rolling if the robber is on one of its own tiles.
  2. Roll.
  3. Then, in priority order: build a city; build a settlement on the best reachable spot; build a road toward the best spot; buy a development card, unless a city, settlement or road is one or two cards short and the card would spend cards it needs; trade at the best available rate if that completes one of these.
- **Card play:**
  - Knights: play one when it would win or keep largest army.
  - Road crew: play it when it reaches a good settlement spot, or wins longest road.
  - Bumper harvest: play it when it completes a build.
  - Corner the market: play it on the resource opponents hold most of, and never on one no opponent holds. 19 of each resource exist, so the bank and its own hand tell it how many the others have.
- **Robber:** move it to the tile that blocks the most pips from the current points leader, without blocking any of its own tiles.

### 6.2 Language model opponent

The model never edits game state. It receives the state and the legal moves, picks one, and the engine validates it.

```swift
protocol Opponent {
    func chooseMove(state: GameState, legal: [Move], player: Int) async -> Move
}
```

Each request sends:

1. **A system prompt** with the rules from section 1 and a personality, such as "cautious builder" or "aggressive expander".
2. **A compact JSON summary of the state** from that player's point of view:
   - its own hand and development cards;
   - each opponent's card count and development card count, but not their actual cards;
   - buildings, the robber's tile, the dice, public points, award holders, road lengths and knight counts.
3. **The legal moves** as a numbered list.

Ask for a structured reply, for example `{"move_index": 3, "reason": "short explanation"}`. Use the provider's tool calling or structured output feature so the reply always parses. If the index is missing or out of range, use the heuristic opponent's move instead.

To keep latency and cost down, only call the model for real decisions: setup placements, where to build, robber targets, which card to play and trades. Let the heuristic handle obvious steps like rolling.

### 6.3 Where the model runs

| Option | Pros | Cons |
|---|---|---|
| Apple's on-device Foundation Models framework (iOS 26, macOS 26, on Apple Intelligence devices) | Free, private, offline, structured output via `@Generable` types | Smaller model, so weaker strategy; only on supported devices |
| Cloud model (Claude API or similar) via tool calling | Much stronger strategy and better table talk | Needs network, costs per call |

For a cloud model, **do not put the API key in the app.** Ship a small backend, such as a serverless function, that holds the key, checks each request and forwards it. The app calls your backend.

A good setup uses both: on-device for quick moves, and cloud for a "hard" difficulty setting.

### 6.4 Nice extras once AI works

- **Table talk:** a one-line comment from each AI after its move, using the `reason` field.
- **Coach mode:** ask the model to explain the best move for the human player without making it.
- **Player trading:** once section 1.10 item 1 exists, the model proposes and answers trades, chosen from engine-generated legal offers.

---

## 7. Testing checklist

Use a seedable random generator so failures can be replayed.

**Behaviour scenarios.** `saltmarsh-isles.feature` holds one Gherkin Feature with a Rule for each area below. It parses cleanly with the official Gherkin parser.

| Rule | Covers |
|---|---|
| Starting a new game | player counts, new game, closing the win screen |
| The board is generated fairly | board structure, tile and number mix, the 5 balancing rules, harbour layout |
| Setup uses snake order | placement order for 2 to 4 players, setup taps, starting cards |
| Rolling and production | start of turn, payouts, the robber blocking a tile |
| Rolling a 7 | the discard queue, the discarding player's panel, + and − pickers, locks |
| Moving the robber and stealing | tile choice, robber centring, choosing a victim on the board or in the panel |
| Building | cost gating, build modes, placement rules, crossroads, cities |
| Trading with the bank | 4 for 1, disabled states |
| Trading at captured harbours | the harbour list, what holds each one, 2:1 and 3:1 trades, shared harbours |
| Development cards | buying, timing rules, each of the 5 card types |
| Longest road | claiming it, branching roads, ties, cut roads |
| Largest army | claiming it, ties, taking it over |
| Scoreboard | each player's row |
| Winning | 10 points on your own turn, hidden points, passive wins, locking |
| Victory screen | overlay, confetti, preview, Reduce Motion, hidden at load |
| Ending the turn | passing the dice, resets |

To run the scenarios against the native app:
- use XCUITest step definitions, or Cucumberish, or a small custom runner;
- drive the engine directly for the board and rules scenarios, and the UI for the screen scenarios;
- give every interactive view an accessibility identifier matching the button labels in the scenarios ("Roll dice", "Discard 4 cards", "Steal from Cobalt"…), so steps can find them.

The web prototype can be driven the same way with Playwright, using `prototype/tests/playgame.py` as a starting point.

**Automated full-game run.** `prototype/tests/playgame.py` plays a whole 3-player game in Chrome with simple bots and records a video. The bots press the real buttons; board taps call the same handler the board uses. After every action it checks:
- no negative card counts;
- the distance rule is never broken;
- every road and settlement is connected;
- the longest road and largest army holders are valid;
- there are never more than 25 development cards.

The first run lasted 63 turns and 222 actions, with Amber winning with 5 cities. No checks failed and the page threw no errors. That run never awarded longest road and never drew Road crew, Corner the market or victory point cards, so the native app's batch tests should cover those. `prototype-tests/steps.py` captures every screen of a rolled 7 and of a Knight; the storyboards are in `media/steps/`. Items marked ✅ were checked against the prototype.

### Board

- [ ] ✅ Board has 19 tiles, 54 corners, 72 edges and 30 coastal edges
- [ ] ✅ Desert is at the centre with no number, and the robber starts there
- [ ] ✅ 200 generated boards all pass balancing rules 1 to 5 (run 1,000 in the native app)
- [ ] ✅ 500 boards never have neighbouring 3:1 harbours, and always have four 3:1 harbours and one 2:1 per resource

### Setup

- [ ] ✅ Placement order is P1…Pn then Pn…P1 for 2, 3 and 4 players
- [ ] ✅ The second setup settlement pays starting cards; the first does not
- [ ] Setup roads must touch the settlement just placed

### Placement

- [ ] Distance rule rejects a settlement next to any building
- [ ] A road cannot extend through an opponent's settlement
- [ ] Two players' roads meeting at an empty legal corner: both may settle there, and the first to build takes it
- [ ] Roads one segment from their owners' settlements meeting at a corner: nobody may settle there

### Robber and 7s

- [ ] The robber's tile produces nothing
- [ ] ✅ The robber's centroid sits on the hex centre on every tile; the number disc moves below it
- [ ] ✅ On a 7, every player over 7 cards gets a discard turn in seat order (tested: Cobalt 9 cards → 4, Amber 10 → 5)
- [ ] ✅ The Discard button stays disabled until exactly half are picked; the chosen cards are removed
- [ ] ✅ Roll, build, trade and card play are locked until all discards are done; then the robber must be moved
- [ ] ✅ With players on the robber's tile, the roller must pick a victim; their buildings there glow and can be tapped
- [ ] ✅ Tapping a victim's building moves exactly 1 card to the roller and logs the victim's name
- [ ] Moving the robber to a tile with nobody holding cards logs that and continues

### Trading

- [ ] ✅ The bank trade is always 4:1
- [ ] ✅ A harbour is listed when the player holds either of its corners, with the right building types
- [ ] ✅ A 2:1 trade takes exactly 2 of the harbour's resource
- [ ] A shared harbour appears for both owners and draws two rings

### Development cards

- [ ] ✅ The deck has 25 cards: 14 Knight, 5 victory point, 2 Road crew, 2 Bumper harvest, 2 Corner the market
- [ ] ✅ A card bought this turn can't be played
- [ ] ✅ Only one card can be played per turn
- [ ] ✅ A Knight can be played before rolling; other cards can't
- [ ] ✅ Corner the market collects every opponent's cards of that resource
- [ ] Road crew stops early when no legal edge remains
- [ ] Buying is disabled when the deck is empty

### Awards and winning

- [ ] ✅ A 6-segment road takes longest road (+2 points)
- [ ] ✅ An opponent's settlement splitting that road drops it to 3, and the award is lost when nobody has 5+
- [ ] ✅ A Y-shaped road of 3 segments measures 2
- [ ] Holder keeps longest road on a tie; when the holder is cut and two others tie, nobody holds it
- [ ] ✅ 3 Knights take largest army; a tie keeps the holder; 4 Knights take it from a holder with 3
- [ ] ✅ Hidden victory point cards count toward 10, and the win message reveals them
- [ ] Reaching 10 points ends the game immediately, on the player's own turn
- [ ] A player who reaches 10 between turns (for example by gaining longest road) wins at the start of their next turn
- [ ] ✅ The win banner and victory screen totals include hidden victory point cards

### Victory screen

- [ ] ✅ The overlay is hidden at load, including in a downloaded copy of the file
- [ ] ✅ Preview win shows "<Name> wins" and draws confetti, with no errors
- [ ] The breakdown lists only sources worth more than 0, and its rows add up to the total
- [ ] "See the board" and Escape close the overlay; the winner's pieces keep glowing
- [ ] With Reduce Motion on, the card appears with no confetti or animation

### AI

- [ ] An AI that always returns an invalid move still finishes games, by falling back to the heuristic
- [ ] 1,000 heuristic-vs-heuristic games complete without crashing or stalling
