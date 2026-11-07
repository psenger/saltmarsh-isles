# The game log

Every game writes a log: the engine appends one line per thing that happened, in the order it happened. The
app shows it in the Log tab, saves it inside `game.json` and every named save, and a replay can rebuild the
whole game from it: the board, every move, and every roll, steal and draw. This file is the contract for that
log: every kind of line with a real example, the numbering the IDs follow, and how to replay a game to look
for mistakes.

The log is not a private record. It names the card a seat stole and the development card a seat bought,
because a replay needs them. Whether the shipped app shows the log to players during a game is a separate
decision.

Two rules hold for every line:

- A line's wording is exact and pinned by the scenarios in `saltmarsh-isles.feature`; the replay parser
  matches it literally.
- Resources are always listed in the order timber, clay, wool, grain, ore, as `2 timber, 1 ore`.

## Where to find a log

| Where | What |
|---|---|
| The Log tab in the app | the current game's log, as it grows |
| `~/Library/Application Support/SaltmarshIsles/game.json` | the autosave of the game in progress; its `log` array |
| `~/Library/Application Support/SaltmarshIsles/saves/<id>.json` | each named save, same shape |
| `~/Library/Application Support/SaltmarshIsles/game-crashed-<date>.json` | a game the app set aside because the previous launch crashed while resuming it; replay it to find the bug |
| `GameState.log` | in code, after any move |

## The header

The first lines, before anyone rolls, record who is playing and the board, so nothing about the game has to
be guessed. From a real test game (`TestGames.randomGame(seed: 2)`):

```
New game with 3 players. Everyone rolls for first player.
Crimson is human.
Cobalt is human.
Amber is human.
SEED 2
H0 timber 4
H1 ore 10
H2 timber 6
H3 grain 10
H4 wool 5
H5 clay 11
H6 wool 3
H7 wool 9
H8 timber 11
H9 desert -
H10 timber 8
H11 grain 12
H12 ore 6
H13 wool 2
H14 grain 3
H15 clay 5
H16 grain 9
H17 clay 8
H18 ore 4
PORT 17-27 ore 2:1
PORT 25-40 3:1
PORT 47-48 grain 2:1
PORT 51-52 3:1
PORT 45-46 timber 2:1
PORT 23-37 3:1
PORT 11-12 wool 2:1
PORT 8-9 3:1
PORT 4-5 clay 2:1
ROBBER H9
Crimson rolled 6 (3+3) for first player.
Cobalt rolled 9 (5+4) for first player.
Amber rolled 7 (1+6) for first player.
Cobalt goes first. Place your first settlement.
Cobalt founded a settlement at V11.
Cobalt laid a road E11-24.
Amber founded a settlement at V18.
Amber laid a road E18-19.
Crimson founded a settlement at V28.
Crimson laid a road E27-28.
Crimson founded a settlement at V2.
Crimson collected 1 timber, 1 ore.
Crimson laid a road E2-9.
Amber founded a settlement at V50.
Amber collected 1 clay.
Amber laid a road E50-51.
Cobalt founded a settlement at V0.
Cobalt collected 1 timber, 1 wool, 1 grain.
Cobalt laid a road E0-15.
Setup done. Cobalt rolls first.
```

Line by line:

| Line | Meaning |
|---|---|
| `New game with 3 players. Everyone rolls for first player.` | always first |
| `Crimson is human.` / `Cobalt is an AI Mate.` | one per seat, in seat order; the AI line names the effort level |
| `SEED 2` | the seed the board, the deck order, the dice and the steals come from |
| `H0 timber 4` … `H18 ore 4` | one per hex in hex order: terrain and number disc; the desert is `H9 desert -` |
| `PORT 17-27 ore 2:1` / `PORT 25-40 3:1` | one per harbour in slot order, named by the edge it sits on |
| `ROBBER H9` | where the robber starts |

## The numbering

IDs are the engine's own indices, which never change because the geometry never changes. The authoritative
description is the comment on `BoardGenerator.layout()` in `Sources/SaltmarshEngine/BoardGenerator.swift`;
the helpers that write and read IDs are in `Board+IDs.swift`. In short:

- **Hexes `H0` to `H18`.** Axial coordinates `(q, r)` of a radius-2 hexagon, visited column by column: `q` from
  −2 to 2, and within a column `r` from `max(−2, −q−2)` to `min(2, −q+2)`, top to bottom. So H0 to H2 are the
  left column, H16 to H18 the right, and the desert `(0, 0)` is always H9. The board is pointy-top; a hex's
  centre is `x = 58·√3·(q + r/2)`, `y = 87·r`, with y growing downwards.
- **Vertices `V0` to `V53`.** Numbered in the order they are first met walking the hexes in that order and,
  within a hex, its six corners clockwise from the upper-right one (angles −30°, 30°, 90°, 150°, 210°, 270°).
  A corner shared with an earlier hex keeps its number, so H0 owns V0 to V5 and every later hex adds only the
  corners nobody has seen.
- **Edges `E14-15`.** An edge is written as its two vertices, smaller first. Hex edge i joins the hex's
  corners i and i+1. (The engine also numbers edges 0 to 71 in first-met order; `Board.edgeIndex(ofID:)` maps a
  pair back to that index.)
- **Harbours `PORT 14-15`.** A harbour is named by its edge. The nine harbours sit on the 30 coastal edges,
  sorted by the angle of their midpoint around the island centre, at offsets 0, 3, 7, 10, 13, 17, 20, 23 and
  27 from a random start; their kinds alternate 2:1, 3:1, 2:1, … The header's PORT lines are in that slot
  order.

The whole map, as the generator lays it out. Corners and edges are in corner order i = 0 to 5:

| Hex | (q, r) | Vertices, corners 0 to 5 | Edges, corner i to i+1 |
|---|---|---|---|
| H0 | (-2,0) | V0 V1 V2 V3 V4 V5 | E0-1 E1-2 E2-3 E3-4 E4-5 E0-5 |
| H1 | (-2,1) | V6 V7 V8 V9 V2 V1 | E6-7 E7-8 E8-9 E2-9 E1-2 E1-6 |
| H2 | (-2,2) | V10 V11 V12 V13 V8 V7 | E10-11 E11-12 E12-13 E8-13 E7-8 E7-10 |
| H3 | (-1,-1) | V14 V15 V0 V5 V16 V17 | E14-15 E0-15 E0-5 E5-16 E16-17 E14-17 |
| H4 | (-1,0) | V18 V19 V6 V1 V0 V15 | E18-19 E6-19 E1-6 E0-1 E0-15 E15-18 |
| H5 | (-1,1) | V20 V21 V10 V7 V6 V19 | E20-21 E10-21 E7-10 E6-7 E6-19 E19-20 |
| H6 | (-1,2) | V22 V23 V24 V11 V10 V21 | E22-23 E23-24 E11-24 E10-11 E10-21 E21-22 |
| H7 | (0,-2) | V25 V26 V14 V17 V27 V28 | E25-26 E14-26 E14-17 E17-27 E27-28 E25-28 |
| H8 | (0,-1) | V29 V30 V18 V15 V14 V26 | E29-30 E18-30 E15-18 E14-15 E14-26 E26-29 |
| H9 | (0,0) | V31 V32 V20 V19 V18 V30 | E31-32 E20-32 E19-20 E18-19 E18-30 E30-31 |
| H10 | (0,1) | V33 V34 V22 V21 V20 V32 | E33-34 E22-34 E21-22 E20-21 E20-32 E32-33 |
| H11 | (0,2) | V35 V36 V37 V23 V22 V34 | E35-36 E36-37 E23-37 E22-23 E22-34 E34-35 |
| H12 | (1,-2) | V38 V39 V29 V26 V25 V40 | E38-39 E29-39 E26-29 E25-26 E25-40 E38-40 |
| H13 | (1,-1) | V41 V42 V31 V30 V29 V39 | E41-42 E31-42 E30-31 E29-30 E29-39 E39-41 |
| H14 | (1,0) | V43 V44 V33 V32 V31 V42 | E43-44 E33-44 E32-33 E31-32 E31-42 E42-43 |
| H15 | (1,1) | V45 V46 V35 V34 V33 V44 | E45-46 E35-46 E34-35 E33-34 E33-44 E44-45 |
| H16 | (2,-2) | V47 V48 V41 V39 V38 V49 | E47-48 E41-48 E39-41 E38-39 E38-49 E47-49 |
| H17 | (2,-1) | V50 V51 V43 V42 V41 V48 | E50-51 E43-51 E42-43 E41-42 E41-48 E48-50 |
| H18 | (2,0) | V52 V53 V45 V44 V43 V51 | E52-53 E45-53 E44-45 E43-44 E43-51 E51-52 |

Coastal edges, where harbours can sit: E2-3, E3-4, E4-5, E8-9, E2-9, E11-12, E12-13, E8-13, E5-16, E16-17, E23-24, E11-24, E17-27, E27-28, E25-28, E35-36, E36-37, E23-37, E25-40, E38-40, E45-46, E35-46, E47-48, E38-49, E47-49, E50-51, E48-50, E52-53, E45-53, E51-52.

To place an ID by hand: find its hex row above. V26, for example, is corner 1 of H7 and also appears on H8
and H12, so it is the vertex where those three hexes meet. E14-26 is H7's edge from corner 1 to corner 2,
shared with H8.

## Turn lines

Each line below is quoted from the same test game unless marked otherwise. A move always produces a line
that names it; the lines that follow it (production, awards, a win) are consequences of the same move.

**Choosing who goes first**

```
Crimson rolled 6 (3+3) for first player.
Tie between Crimson and Amber. Roll again.
Cobalt goes first. Place your first settlement.
```

**Setup.** The second settlement pays its starting cards, and the collected line says which.

```
Cobalt founded a settlement at V11.
Cobalt laid a road E11-24.
Crimson collected 1 timber, 1 ore.
Setup done. Cobalt rolls first.
```

**Rolling and production.** Both dice, then who received what. A `Bank is out of ore.` line (from the engine
tests) precedes the roll line when the bank could not pay a resource in full.

```
Cobalt rolled 10 (4+6). Crimson +1 ore, Cobalt +1 grain
Cobalt rolled 4 (3+1). Nobody harvested.
Amber rolled 7 (1+6).
```

**A 7, discards and the robber.** The roller's move to the robber is announced once every discard is in.
The steal names the card.

```
Crimson discarded 3 timber, 1 wool.
Crimson now moves the robber.
Amber moved the robber to H0.
Amber stole 1 grain from Cobalt.
Nobody on that tile has cards to steal.
```

**Building**

```
Amber built a road E6-19.
Amber built a settlement at V20.
Crimson upgraded to a city at V2.
```

**Trading with the bank and at harbours.** The harbour trade names its port.

```
Cobalt traded 4 grain for 1 timber with the bank.
Cobalt traded 2 wool for 1 grain at the 2:1 wool harbour (PORT 11-12).
```

**Trading with other players.** An offer to everyone, or `to Amber` for one seat; each answer; then the
proposer trades with one responder or withdraws. The counter line is from the engine tests: random games never
counter.

```
Cobalt offers 1 grain for 2 clay.
Amber declined the offer.
Amber accepted the offer.
Cobalt countered: 3 timber for 1 ore.
Crimson traded 1 timber with Amber for 1 grain.
Cobalt withdrew the offer.
Nobody can answer that offer.
```

**Development cards.** Buying names the card drawn. Playing says what the card did; Road crew is followed by
up to two free roads, or by `No roads left to build.` / `No room for new roads.` (engine tests) when it
cannot place them.

```
Amber bought a development card: Knight.
Amber played a Knight.
Cobalt played Road crew.
Cobalt built a free road E0-1.
Crimson played Bumper harvest: ore and ore.
Crimson cornered the clay market and took 3 (Amber 3).
Amber cornered the timber market and took 0.
```

**Awards and the end**

```
Amber takes longest road (5).
Nobody holds longest road now.
Cobalt takes largest army (3 knights).
Crimson ended the turn.
Cobalt wins with 11 points!
Crimson wins with 10 points, including 2 hidden victory point cards!
```

**Thinking lines.** When a Captain or Admiral searches, the game layer, not the engine, adds a line before
the move it chose:

```
Amber weighed 4 moves over 32 guessed hands (128 playouts, 0.6 s) and stuck with its first instinct.
```

The replay skips these; the engine cannot produce them.

## Replaying a game

`LogReplay`, in `Sources/SaltmarshTestSupport/LogReplay.swift`, rebuilds a game from its log and nothing else:

1. It reads the seat lines and `SEED`, starts a fresh game from them, and checks the header it writes,
   board record included, against the log line by line.
2. It turns every turn line that describes a move back into that move (`LogReplay.move(for:in:)`) and
   applies it.
3. After each move it compares the lines the replay just wrote with the lines it read. Because the dice,
   the stolen card and the drawn card are written as facts, any of them disagreeing with the real game stops
   the replay at that line.

The result is a `GameState` equal to the one the game ended in; `LogReplayTests` prove that for random games,
`LogReplayAITests` for a game the AI played, and `LogReplayGameTests` for a game the view model ran,
thinking lines and all.

To replay a real game, point the test at the log, a text file with one line per log entry or a saved game's
JSON:

```bash
SALTMARSH_LOG=~/Library/Application\ Support/SaltmarshIsles/game.json \
  swift test --filter replaysTheLogFileFromTheEnvironment
```

It prints where the game stands and every seat's points, hand and card count, or fails with the first line
it cannot reproduce:

```
line 212: log says "Amber stole 1 grain from Cobalt.", replay says "Amber stole 1 wool from Cobalt."
line 41: cannot read "Crimson sneezed."
line 300: upgradeCity(corner: 2) is not legal here: illegalMove(...)
```

A mismatch means the log and the engine disagree, which is either a corrupted log or an engine bug worth
chasing. From code, `try LogReplay.replay(lines)` gives the state and `LogReplay.move(for:in:)` the move a
single line stands for, which is enough to step through a game and inspect any position on the way.

## What a reader can take from a log

With the header and the turn lines a person or a model can reconstruct the board, each seat's hand after
every move, what every seat could see, and what it chose. The thinking lines add how hard a searching seat
worked and whether the search overruled its instinct. Putting a seat's choice next to the position it faced,
and next to what the dice then did, is how to spot a mistake: a settlement on V20 when V26 was open, a Knight
held while the robber sat on an own hex, a trade accepted that gave away the last card of a nearly complete
city.
