# Contributing to Saltmarsh Isles

Thanks for your interest. Bug reports, rule corrections, screen polish and new features are all
welcome. This guide covers how to set up, how the tests and the Gherkin scenarios fit together,
and what a good pull request looks like here.

## Ways to help

- **Report a bug** with the [bug report form](https://github.com/psenger/saltmarsh-isles/issues/new?template=bug_report.yml). Steps to
  reproduce and the lines from the Log tab are the two things that matter most.
- **Suggest a feature** with the [feature request form](https://github.com/psenger/saltmarsh-isles/issues/new?template=feature_request.yml).
- **Fix something small.** Typos, a wrong cost in a label, a missing accessibility label: open a
  pull request straight away.
- **Change the rules or add a feature.** Open an issue first so we can agree on the behaviour
  before you write it. Rule changes touch the spec, the scenarios and the engine together, and
  it is cheaper to talk before all three move.

## Setting up

You need a Mac with Xcode 26 or later, because the app icon uses the `.icon` format. The project is
tested with Xcode 27.2.

```bash
git clone https://github.com/psenger/saltmarsh-isles.git
cd saltmarsh-isles
swift test                      # engine, AI, game and Gherkin tests, no Xcode project needed
open SaltmarshIsles.xcodeproj   # run the app from Xcode
make help                       # list every make target with a line on what it does
```

The Xcode project is generated from `project.yml`. If you add, move or delete a file under
`App/` or `AppUITests/`, or edit `project.yml`, regenerate it and commit the result:

```bash
brew install xcodegen
make project
```

Files under `Sources/` and `Tests/` are picked up by Swift Package Manager automatically, so they
need no regeneration.

Two more things to know when you build:

- Running on a real iPhone or iPad needs your own signing team in `Config/Local.xcconfig`. The
  README's [iPhone and iPad](README.md#iphone-and-ipad) section walks through it.
- After changing the rules text in `Sources/SaltmarshGame/Help.swift`, run `make helpbook` to rebuild
  the Mac help book and its search index.

### Where builds go

Each build target prints where it put its output as its last line.

| Target | Output |
|---|---|
| `make mac` | Debug app in Xcode's DerivedData: `~/Library/Developer/Xcode/DerivedData/SaltmarshIsles-<hash>/Build/Products/Debug/` |
| `make ios` | Debug app in the same DerivedData folder, under `Build/Products/Debug-iphonesimulator/` |
| `make build` | Release app in `build/Build/Products/Release/` |
| `make run` | the `make build` app, copied to `~/Applications/SaltmarshIslesDev/` and opened |
| `make dmg` | `build/SaltmarshIsles-<version>.dmg`, built from `build/release/` |
| `swift test`, `make dial`, `make bench` | Swift Package Manager's `.build/` |

`make clean` removes all of these except the copy in `~/Applications/SaltmarshIslesDev/`.

## How the code is laid out

The [README's architecture section](README.md#architecture) has the map. The rules that matter
when you change things:

- **The engine has no UI code.** `Sources/SaltmarshEngine/` is pure Swift. If you find yourself
  importing SwiftUI there, the change belongs in `SaltmarshGame` or `App/`.
- **The engine is the only place rules live.** Screens and opponents ask the engine what is legal.
  They never work it out themselves.
- **Opponents see only their own seat.** An AI receives a `PlayerView`, never the full
  `GameState`. Do not widen that view to make an opponent smarter.
- **The spec is the source of truth for the rules.** If a change alters how the game plays,
  update `saltmarsh-isles-spec.md` in the same pull request.

## Tests and scenarios

Every change to behaviour needs a test. There are two kinds.

**Unit tests** live in `Tests/EngineTests`, `Tests/AITests` and `Tests/GameTests`, and use
Swift Testing (`@Test`, `#expect`). Seeded boards and state helpers for setting up a position are
in `Sources/SaltmarshTestSupport/`. Reach for those before hand-building a `GameState`.

**Scenarios** live in `saltmarsh-isles.feature`. The file describes every player interaction in
Given/When/Then, grouped under a `Rule:` per area of the game, and the test suite runs it directly.
Anything a player can see or do should have a scenario. To add one:

1. Write the scenario under the right `Rule:` block. Use the seat colours Crimson, Cobalt, Amber
   and Ivory, and write "taps" for a click or a tap.
2. Run `swift test --filter GherkinTests`. An unmatched step fails with the line number.
3. If a step is new, register it in the matching file under `Tests/GherkinTests/Steps/` with
   `r.given`, `r.when` or `r.then`. Reuse an existing pattern when one says the same thing.
4. A new `Steps/*.swift` file also needs its `register…` function added to `StepLibrary.groups`.
5. Tag a scenario `@ui` only when it needs the running app. Those run from `AppUITests` on the
   simulator, not from `swift test`.

Run everything before you push:

```bash
swift test
```

One test only runs as a release build, because a searched game takes seconds in debug: `make dial`
plays forty seeded games of a small-budget Captain against Mate. Run it when you touch the search or the
evaluator. `make bench BENCH_ARGS="--fast --games 4"` prints the level-versus-level win table.

The UI tests, when you touched a screen:

```bash
xcodebuild test -project SaltmarshIsles.xcodeproj -scheme SaltmarshIsles \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.5' \
  -only-testing:AppUITests
```

`make test` runs the package tests and then the full scheme on the Mac. The Mac UI runner can stop
with "Authentication cancelled" unless you are there to approve its prompt.

## Code style

- Swift 6 with strict concurrency set to complete. Keep the build free of warnings.
- Match the surrounding code. Small extensions per concern (`Engine+Trade.swift`,
  `Engine+Awards.swift`) rather than one long file.
- No new dependencies without an issue first. The package currently has none.
- Status, header and button text lives in `Sources/SaltmarshGame/Strings.swift`, not inline in
  views, and its wording matches the feature file word for word. Change both together.
- Animations must respect Reduce Motion. Check the existing views for the pattern.

## Commits

Commit messages follow the Conventional Commits shape already in the history:

```
feat(app): animate rolls and payouts, show awards, and explain a grey Offer
fix(app): grey the Give and Get labels on a disabled trade row
test(gherkin): feature file parser and step registry
docs: rewrite the README for the native app
chore: ignore the superpowers working files
```

Types in use: `feat`, `fix`, `test`, `docs`, `chore`. Scopes in use: `engine`, `ai`, `game`,
`app`, `gherkin`, `ui`. Write the subject in the imperative, lower case, no full stop.
Say what changed for the player or the reader, not which files moved.

## Pull requests

- Branch from `main`. One change per pull request.
- Say what the player sees differently, and link the issue if there is one.
- `swift test` passes, and the UI tests pass if you touched a screen.
- A screen change includes a screenshot from an iPhone and from a Mac. Both layouts matter.
- If behaviour changed, the scenario, the spec and the README's rules section agree with the code.
- If you ran `make project`, the regenerated `.xcodeproj` is in the commit.

Reviews aim to be prompt and specific. Expect questions about rules edge cases. The engine has
an invariant check that `InvariantTests` runs over whole played games, so a wrong ruling tends
to surface there rather than in the change itself.

## Writing docs

Headings in sentence case. Plain words over jargon. Describe what the game does, not what the
code is called, unless the reader has to go and find it. The README and the spec follow this
voice, so read a section of either before adding to them.

## License

By contributing you agree that your work is released under the [MIT License](LICENSE) that covers
the rest of the project.
