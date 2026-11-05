# Game screen redesign

Owner request, 2026-11-05. Changes how the game screen is laid out on Mac and iPhone and adds a private handover between human players. It replaces the panel description in section 7 of `2026-11-02-saltmarsh-native-design.md`; that spec stays the authority for everything else.

Approved mockups: `2026-11-05-game-screen-mockups/combined.html` (layout, dice, moments) and `2026-11-05-game-screen-mockups/handover.html`. They are rough layouts: they fix where things go, not the final artwork.

## 1. Why

The owner played the first build on Mac and reported two problems: "things move, when they should not", because content wraps and pushes what is below it; and "we are trying to put too many things into one space". Reading the code confirms both. `GamePanel` is one scrolling stack whose sections appear and disappear with the phase, and the status line grows with its text. At a normal window size the offer builder runs off the bottom, with the scoreboard and log below that.

The owner also found a secrecy problem: with two humans sharing a phone, tapping "End turn" shows the next player's hand to the person still holding it.

## 2. Goals, non-goals, anti-goals

**Goals**

- Nothing moves when the game state changes. Every control has one fixed place.
- At any moment a player can see whose turn it is, the scores, the dice, their hand and their turn buttons without scrolling.
- One human never sees another human's hand, development cards or hidden points.
- The same arrangement on Mac and iPhone.

**Non-goals**

- No rule changes. The engine is untouched.
- No AI work. Plan 2 stays as planned, and its open questions in the master plan are still required before it starts.
- No new artwork, animation or sound. The board drawing stays as it is, apart from its size.

**Anti-goals: a failure even if everything else works**

- A panel section that grows, shrinks, appears or vanishes and shifts anything around it.
- A control that disappears when it cannot be used. It greys out where it is.
- A hand visible to the wrong human for even one frame during a handover.
- A handover screen in a game with only one human.

## 3. The layout

Two regions: a **header** across the full width, and below it the **board** and the **panel**. Wide windows put the panel to the right of the board; tall ones put it under the board, the existing `GameScreen` rule. The panel keeps today's width rule on wide windows.

### Header (from mockup option B)

Left to right, on one row:

- A chip for each player: seat dot, name, "N / 10". The current player's chip is outlined. On iPhone a chip shrinks to the dot and the score number.
- The status line.
- Two dice.
- A menu button holding "New game", and "Preview win" in debug builds. It is not in the mockups; see section 7.

On iPhone the status line drops to its own row directly under the chips and dice.

The header's height never changes. The status slot has a fixed height that fits two lines; text may wrap and shrink inside the slot but the slot never grows. Mac at minimum window width with four players is the tight case, and the longest strings (the offer text, "Pick a pocket! Tap a glowing building on the robber's tile, or a name below.") must be checked there.

### Dice

Real dice: a rounded square with pips, faces 1 to 6. Before a roll, an empty dashed outline in the same size and place. Drawn from the existing `screen.dice` strings, with "–" meaning not rolled, so `ScreenState` and the scenario "both dice show –" do not change. Each die needs an accessibility label stating its value or that it has not been rolled, since the digit is no longer text.

### Panel, top to bottom

1. **Who line.** A dot in `headerSeat`'s colour, then `screen.header` ("Cobalt · discarding"), then `holdTitle` ("Cobalt's hold"). This replaces the large coloured bar and takes over its job of showing who the panel belongs to. The mockups show only the hold label; see section 7. Always one line, always present.
2. **Hand.** Five resource boxes, the existing `ResourceBox`. When no hand may be shown (two or more humans during an AI turn), the same five boxes stay in place with no numbers, so nothing shifts.
3. **Turn buttons.** "Roll dice" and "End turn". "Roll for first" takes the Roll dice position during the first roll.
4. **Build buttons.** Road, Settlement, City and Card, in one row, each with "N left" and its cost. Card buys a development card, and its count is what is left in the deck.
5. **Tabs.** Trade, Cards, Players, Log, always in this order.
6. **Tab area.** Takes all remaining height at a size that does not depend on its content. Content that does not fit scrolls inside the area. This is the only scrolling in the panel.

Items 1 to 5 never scroll. All of them stay on screen in every state; when one cannot be used it greys out.

### Tab contents

- **Trade.** A one-line bank supply (five small coloured counts, no names), the bank trade row, one row per captured harbour (or the "None yet" text), and "Offer a trade to players…". That button replaces the tab's content with the offer builder and a way back. After an offer is made, the tab shows the responses with Trade and Withdraw until it closes.
- **Help.** On Mac, the menu bar's Help menu opens a real Apple help book, with Command-?, in the system's help window with its index and search. `make help` builds the book from `Help.sections`. Its pages stay blank unless the app runs from an Applications folder, so `make run` runs it from `~/Applications`. iPhone and iPad have no help window, so a Help item in the header's menu opens the same topics as a searchable list.
- **Cards.** The cards still to play and, once any are played, how many Knights the player has played, then a "Victory points" section: the total out of 10, a row per source worth more than 0, including hidden victory point cards, and a pill for each award held, such as "Longest road 8 +2". Buying a card shows "You drew: <card>!" over the panel for a few seconds, to the buyer only.
- **Players.** The full scoreboard, including cards, development cards, road and army, and the "+N" hidden points for the current human.
- **Log.** The whole log, newest first.

### When the game asks for something

Discarding, answering an offer, choosing who to rob and a proposer's list of answers (Trade with X, Withdraw) take over the tab area, in the same place and size. Trade, Cards, Players and Log grey out until it is answered, then the previous tab returns. The proposer's answers take over so that "Answers are in" can never appear with its buttons behind another tab.

While an AI is playing, Roll, End turn and the build buttons are grey. Trade and Cards grey out too, because their content belongs to the current player: showing them would reveal the AI's harbours, and the offer builder's limits would reveal its hand. Players and Log stay available, and the tab area shows Players unless Log is picked.

During the first roll and setup, the order strip sits at the top of the tab area with the log below it, Trade and Cards are grey, and Players stays available.

Victory and preview stay as today's overlay. The new game sheet is unchanged.

## 4. The handover screen

**The rule:** whenever the private view would change from one human to a different human, the screen goes blank until the new person taps a button. Games with one human never see it. An AI needs no handover.

**What it shows:** a plain background, "Eyes off! Pass the device to Cobalt", and one button in that player's colour. Nothing of the game shows: no board, scores, log or menu. The game view must not be rendered underneath, so it cannot leak through accessibility, screenshots or a frame of animation.

**The button names the person and why:**

| Moment | Button |
|---|---|
| A human's turn begins | "Start turn, Cobalt" |
| A human must discard after a 7 | "Discard, Cobalt" |
| A human has an offer to answer | "See the offer, Cobalt" |
| Any other return to a human, such as back to the proposer after answers | "Continue, Crimson" |

**Examples of when it appears, with Crimson and Cobalt human:**

- Crimson taps End turn and Cobalt is next: blank at once.
- Crimson taps End turn and Amber (AI) is next: no blank. Amber plays with no hand showing, as the spec already requires. The blank appears when Cobalt's turn comes.
- A 7 is rolled: each human who must discard gets it in queue order, and it returns to the roller the same way. A human who is already holding the device (the roller discarding first) sees no blank.
- Crimson offers a trade: Cobalt gets it to answer, and then it returns to Crimson. With three humans, each responder in seat order.
- An AI offers Cobalt a trade or rolls a 7 during its turn: the blank appears before Cobalt's prompt.

**When it does not appear:**

- During the first roll and setup. Hands are empty or come from what is on the board, and blanking would only add taps. The first blank is the first handover after setup; the person who placed last also takes the first turn and sees none.
- At game over.
- In a game with one human.

**Reopening a saved game or returning from the background:** with two or more humans, the game shows the handover screen for whoever must act, so the app never shows the last player's cards to whoever picks it up. On iPhone this includes locking the phone or switching apps; on Mac, hiding or minimising the app. The exceptions above still apply: a game in setup or after the end opens normally.

## 5. Consequences for the model and tests

`ScreenState` gains an optional handover value (who, message, button label). When it is set, `GameScreen` renders only the handover view. Who has last seen the private view is UI state, not game state: it is not saved, which is what makes a relaunch open on the blank screen.

The feature file's background is a three-human game, so most scenarios cross handovers. **Existing `ScreenState` fields such as `buttons`, `handCounts` and `header` keep their current values and meaning during a handover**; the blank is expressed by the new value and enforced by the view rendering nothing else. Existing scenarios therefore stand unchanged. The handover view is the only thing the player can reach while it is up, because the game view is not rendered.

**Copy change:** the discard status currently ends "Eyes off! Pass the device to Cobalt." Once the handover screen exists that sentence is read by Cobalt, after the device has reached them, and it already appears in one-human games, which section 6.6 of the main spec forbids. It becomes "Crimson rolled a 7! Cobalt has more than 7 cards and must give up half." Update the scenario and `Strings` together.

**New feature-file scenarios** go under a new rule, "Handing the device to another human", covering each row and example in section 4, including "With one human no handover ever appears" and the setup, game-over and reopen exceptions.

**How "nothing moves" is proved:** a UI test on iPhone records the frames of the status slot, hand, Roll dice, End turn, Road and the tab bar at a series of moments (first roll, before and after a roll, build mode on, an AI's turn, an offer or discard if reachable), and asserts that each is unchanged at every moment, plus `isHittable` for each. Mac is checked by build, launch and screenshot, because Mac XCUITest needs the owner present to authenticate.

**Existing UI tests:** `AppUITests/GameFlowTests.swift` finds the log, bank and "New game" by identifier, some of which are now inside a tab or the menu. Update them to navigate first; keep the same identifiers where the element still exists. Add one two-human UI test that plays an End turn across a handover, confirms the next player's hold is not on screen until the button is tapped, and relaunches into the blank screen.

## 6. Constraints

- All rules stay in the engine and all text and enabled flags stay in `ScreenState` and `Strings`. No rules or test-relevant strings in `App/`.
- Existing wording stays word for word apart from the one copy change above. New strings go in `Strings`, and into the feature file.
- Fits the current minimum Mac window (760 by 520) and iPhone 15 Pro portrait. iPhone landscape must work but may scroll more in the tab area.
- One commit per task. No `Co-Authored-By` trailers. No em-dashes or section signs in docs.
- Update section 7 of the main spec and the master plan's Roadmap and rulings when this lands. R17 and R18 (hand pinned above the scroll, log in a 140 point box) are replaced by this design.

## 7. Calls not yet seen by the owner

The owner approved the mockups and the handover examples. These were decided while writing this up and are not in the mockups; the owner sees this list on handover:

- The menu button in the header for "New game" and "Preview win".
- The who line showing `screen.header` as well as the hold label. The mockups show only the hold label. Without it, "Cobalt · discarding" and its colour would be in the model but nowhere on screen.
- A two-line status slot, rather than the single line shown to the owner, because the longest messages cannot fit one legible line beside the chips on Mac.
- Empty resource boxes during an AI turn with two humans.
- The "See the offer", "Discard" and "Continue" wording on the handover button. Mockup wording; the owner agreed the moments, not the words.
- The discard status copy change.
- A Players tab that stays available during setup; a tab area that returns to the previous tab after a request.
- Trade and Cards grey during an AI's turn, where the mockup left them looking available, because their content would reveal the AI's harbours and hand.
- The blank screen after locking the phone or switching apps with two or more humans, which means one extra tap when the same player comes back.
- A proposer's list of answers taking over the tab area.

## 8. Left to the builder

- Exact sizes, spacing and breakpoints, within the fixed-place rule. The iPhone board must stay large enough to tap corners and edges accurately on a real device; about 240 points tall is the mockup's proportion, and the balance against the tab area is the builder's to tune.
- How the view model records who last saw the private view, and how setup hands over silently to the first turn.
- Which tab a new human's turn opens on. Trade is the default in the mockup.
- Styling of the handover background and the dice.
