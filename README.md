# Saltmarsh Isles

| Path | What it is |
|---|---|
| `saltmarsh.html` | The whole game in one file. Open it in any browser. |
| `saltmarsh-isles-spec.md` | Build spec for the native Apple app, including rules, data model, UI, AI plan and test checklist. |
| `saltmarsh-isles.feature` | Gherkin BDD scenarios for every player interaction: 16 rules, 89 scenarios. Referenced from the spec. |
| `prototype-tests/playgame.py` | Plays a full 3-player game with bots in Chrome, records a video and checks rule invariants after every action. Run: `python3 playgame.py <output-folder>` |
| `prototype-tests/steps.py` | Captures every screen of a rolled 7 and of a Knight, into `steps/`. |
| `media/saltmarsh-full-game.mp4` | Recording of a full bot game, half speed. |
| `media/final.png` | Final frame of that game (win screen). |
| `media/discard.png`, `media/steal.png` | Discard picker and steal step. |
| `media/steps/` | Step-by-step captures, plus `flow-A-rolled-7.jpg` and `flow-B-knight.jpg` storyboards. |

The test scripts expect `saltmarsh.html` at `/home/claude/saltmarsh.html`, and Chrome at `/usr/bin/google-chrome`. Change the `GAME` path and `executable_path` at the top of each script to match your machine. They need `pip install playwright`.
