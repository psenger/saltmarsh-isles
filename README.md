<div align="center">

<img src="App/AppIcon.icon/Assets/icon.svg" width="140" alt="Saltmarsh Isles icon">

# Saltmarsh Isles

**Settle a hex-tile island, trade for what you lack, and race to 10 points, on iPhone, iPad and Mac.**

![Platforms: iOS 17+ and macOS 14+](https://img.shields.io/badge/platforms-iOS%2017%2B%20%7C%20macOS%2014%2B-3f6472)
![Swift 6](https://img.shields.io/badge/Swift-6-d68910)
![Status: in development](https://img.shields.io/badge/status-in%20development-b5643c)
[![License: MIT](https://img.shields.io/badge/license-MIT-3f6b3a)](LICENSE)

[Quick start](#quick-start) • [How to play](#how-to-play) • [Status](#status) • [Testing](#testing) • [Architecture](#architecture)

<img src="docs/images/ipad-game.png" height="520" alt="A game in progress on iPad, with the board above the player's hand and trade panel">
&nbsp;&nbsp;
<img src="docs/images/iphone-game.png" height="520" alt="The same game on iPhone">

</div>

---

Saltmarsh Isles is a native SwiftUI board game for two to four players sharing one device. Every
game deals a new island of 19 tiles and nine harbours, and any seat can be a person or the computer.

- **Pass and play.** A handover screen sits between human players, so nobody sees the next hand.
- **Picks up where you left off.** Your game saves after every move and reopens when you return.
- **Rolls you can feel.** The dice tumble, paying hexes celebrate, resources pulse as they arrive,
  and a win ends in confetti. Reduce Motion turns the animation off.
- **Rules at hand.** Searchable help is in the **Help** menu on Mac and the **⋯** menu on iPhone and
  iPad.

## Quick start

You need a Mac with Xcode 26 or later, because the app icon uses the `.icon` format. The project is
tested with Xcode 27.2.

```bash
open SaltmarshIsles.xcodeproj
```

Choose the `SaltmarshIsles` scheme and a destination, then press **Cmd-R**.

macOS only loads help pages for an app in an Applications folder, so the Help window is blank under
**Cmd-R**. To check it on a Mac, build and run from `~/Applications`:

```bash
make run
```

## How to play

Roll two dice each turn. Every settlement and city next to a tile with that number collects its
resource: timber, clay, wool, grain or ore. Spend them on these:

| Build | Cost | Points |
|---|---|---|
| Road | 1 timber, 1 clay | 0 |
| Settlement | 1 timber, 1 clay, 1 wool, 1 grain | 1 |
| City (upgrades a settlement) | 2 grain, 3 ore | 2 |
| Development card | 1 wool, 1 grain, 1 ore | Depends on the card |

The longest road (5 or more) and the largest army (3 or more Knights) are worth 2 points each. The
first player to reach 10 points on their own turn wins.

- **Trading:** deal with the bank at 4 for 1, at better rates through the harbours you hold, or
  directly with other players.
- **The robber:** a rolled 7 makes anyone holding more than 7 cards give up half. The roller then
  moves the robber to block a tile and steals a card.
- **Development cards:** a deck of 25 holds Knight, Victory point, Road crew, Bumper harvest and
  Corner the market cards.

The app's help covers all of this, and the [build spec](saltmarsh-isles-spec.md) has the exact rules.

## Status

In development.

| Area | State |
|---|---|
| Rules engine | Done |
| Game screen, animation and in-app help | Done |
| Pass and play for 2 to 4 people | Done |
| Resuming the game in progress | Done |
| AI opponents | **Not built yet.** Computer seats play random legal moves at every effort level |
| `ai-bench` benchmark tool | Placeholder only |

The [master plan](docs/superpowers/plans/2026-11-02-saltmarsh-native-plan.md) holds the roadmap.

## Building from the command line

```bash
make mac    # build for Mac
make ios    # build for the iPhone 15 Pro simulator on iOS 17.5
```

The Xcode project is generated from `project.yml`. After adding or removing files, or changing
`project.yml`, regenerate it with [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```bash
brew install xcodegen
make project
```

After changing the rules text in `Sources/SaltmarshGame/Help.swift`, rebuild the Mac help book and
its search index with `make help`.

## Testing

```bash
swift test
```

This runs the engine, AI and game tests, plus every scenario in
[`saltmarsh-isles.feature`](saltmarsh-isles.feature). That file describes each player interaction
in plain Given/When/Then language, and the test suite executes it directly.

To run the UI tests on the iPhone simulator:

```bash
xcodebuild test -project SaltmarshIsles.xcodeproj -scheme SaltmarshIsles \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.5' \
  -only-testing:AppUITests
```

`make test` runs `swift test` and then the full test scheme on the Mac. The Mac UI test runner can
fail with "Authentication cancelled" unless someone is there to approve its prompt.

## Architecture

The rules live in a pure Swift engine with no UI code. The AI and the screens both go through it,
and an opponent receives a `PlayerView` that holds only what that seat is allowed to see.

```mermaid
flowchart TD
    App["App: SwiftUI screens"] --> Game["SaltmarshGame: game layer and autosave"]
    App --> AI
    App --> Engine
    Game --> AI["SaltmarshAI: opponents"]
    Game --> Engine["SaltmarshEngine: rules"]
    AI --> Engine
```

| Path | What it is |
|---|---|
| `App/` | The SwiftUI app: views, app entry point and icon. |
| `AppUITests/` | UI tests that drive the real screen. |
| `Sources/SaltmarshEngine/` | The rules engine. |
| `Sources/SaltmarshAI/` | The opponent interface and the random stand-in. |
| `Sources/SaltmarshGame/` | The game layer between the engine and the screen, including the help text. |
| `Sources/SaltmarshTestSupport/` | State helpers and seeded game builders shared by the tests. |
| `Tests/` | Engine, AI, game and Gherkin tests. |
| `saltmarsh-isles-spec.md` | The build spec: rules, data model, UI, AI plan and test checklist. |
| `saltmarsh-isles.feature` | Gherkin scenarios for every player interaction. |
| `docs/superpowers/` | Design documents and implementation plans. |

The [native app design](docs/superpowers/specs/2026-11-02-saltmarsh-native-design.md) explains the
reasoning behind this structure.

## Web prototype

The game began as a rapid prototype in a single HTML file, which proved the rules and screen flow
before the native build. The app doesn't use it. To try it, open
[`prototype/saltmarsh.html`](prototype/saltmarsh.html) in any browser.

<details>
<summary>Prototype files and test scripts</summary>

| Path | What it is |
|---|---|
| `prototype/saltmarsh.html` | The whole prototype in one file. |
| `prototype/tests/playgame.py` | Plays a full 3-player game with bots in Chrome, records a video and checks rule invariants after every action. |
| `prototype/tests/steps.py` | Captures every screen of a rolled 7 and of a Knight, into `steps/`. |
| `prototype/media/` | The recording of a full bot game, its final frame, and step-by-step screenshots. |

The test scripts need `pip install playwright`. They still point to another machine, so before
running them, update these paths to match yours:

- **`playgame.py`:** `GAME` on line 9 and `executable_path` on line 97.
- **`steps.py`:** `executable_path` on line 8 and the `goto` path on line 11.

Run the full game with `python3 playgame.py <output-folder>`.

</details>

## License

[MIT](LICENSE) © 2026 Philip A. Senger

---

<div align="center">

**A pass-and-play island board game, written natively for Apple devices.**

[Build spec](saltmarsh-isles-spec.md) • [Scenarios](saltmarsh-isles.feature) • [Design](docs/superpowers/specs/2026-11-02-saltmarsh-native-design.md)

</div>
